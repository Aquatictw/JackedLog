import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../database/database.dart';
import '../main.dart';
import 'schemes.dart';

class FiveThreeOneState extends ChangeNotifier {
  FiveThreeOneState() {
    _loadActiveBlock().catchError((error) {
      print('Warning: Error loading active 5/3/1 block: $error');
    });
  }

  FiveThreeOneBlock? _activeBlock;

  FiveThreeOneBlock? get activeBlock => _activeBlock;
  bool get hasActiveBlock => _activeBlock != null;

  /// Current cycle position (0-4), defaults to 0 if no active block
  int get currentCycle => _activeBlock?.currentCycle ?? 0;

  /// Current week within cycle (1-3), defaults to 1 if no active block
  int get currentWeek => _activeBlock?.currentWeek ?? 1;

  /// Whether TM bump dialog should be shown before advancing
  bool get needsTmBump {
    if (_activeBlock == null) return false;
    final block = _activeBlock!;
    return block.currentWeek >= cycleWeeks[block.currentCycle] &&
        cycleBumpsTm[block.currentCycle];
  }

  /// Whether the block has reached completion
  bool get isBlockComplete {
    if (_activeBlock == null) return false;
    final block = _activeBlock!;
    return block.currentCycle == cycleTmTest &&
        block.currentWeek >= cycleWeeks[cycleTmTest];
  }

  /// Human-readable position label for display
  String get positionLabel {
    if (_activeBlock == null) return '';
    final block = _activeBlock!;
    final cycleName = cycleNames[block.currentCycle];
    return '$cycleName - Week ${block.currentWeek}';
  }

  Future<void> _loadActiveBlock() async {
    _activeBlock = await (db.select(db.fiveThreeOneBlocks)
          ..where((b) => b.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();
    notifyListeners();
  }

  /// Reload active block from database (call after mutations)
  Future<void> refresh() async {
    await _loadActiveBlock();
  }

  /// Create a new block, deactivating any existing active block first
  Future<void> createBlock({
    required double squatTm,
    required double benchTm,
    required double deadliftTm,
    required double pressTm,
    required String unit,
  }) async {
    // Deactivate any existing active block
    await (db.update(db.fiveThreeOneBlocks)
          ..where((b) => b.isActive.equals(true)))
        .write(
      FiveThreeOneBlocksCompanion(
        isActive: const Value(false),
        completed: Value(DateTime.now()),
      ),
    );

    // Insert new block (defaults: cycle=0, week=1, isActive=true)
    await db.into(db.fiveThreeOneBlocks).insert(
          FiveThreeOneBlocksCompanion.insert(
            created: DateTime.now(),
            squatTm: squatTm,
            benchTm: benchTm,
            deadliftTm: deadliftTm,
            pressTm: pressTm,
            unit: unit,
          ),
        );

    await refresh();
  }

  /// Advance to the next week or cycle, or complete the block
  Future<void> advanceWeek() async {
    if (_activeBlock == null) return;
    final block = _activeBlock!;
    final maxWeeks = cycleWeeks[block.currentCycle];

    FiveThreeOneBlocksCompanion companion;

    if (block.currentWeek < maxWeeks) {
      // Advance within current cycle
      companion = FiveThreeOneBlocksCompanion(
        currentWeek: Value(block.currentWeek + 1),
      );
    } else if (block.currentCycle < cycleTmTest) {
      // Move to next cycle, reset week to 1
      companion = FiveThreeOneBlocksCompanion(
        currentCycle: Value(block.currentCycle + 1),
        currentWeek: const Value(1),
      );
    } else {
      // Block complete
      companion = FiveThreeOneBlocksCompanion(
        isActive: const Value(false),
        completed: Value(DateTime.now()),
      );
    }

    await (db.update(db.fiveThreeOneBlocks)
          ..where((b) => b.id.equals(block.id)))
        .write(companion);

    await refresh();
  }

  /// Bump training max values: +4.5 for lower body, +2.2 for upper body
  Future<void> bumpTms() async {
    if (_activeBlock == null) return;
    final block = _activeBlock!;

    await (db.update(db.fiveThreeOneBlocks)
          ..where((b) => b.id.equals(block.id)))
        .write(
      FiveThreeOneBlocksCompanion(
        squatTm: Value(double.parse((block.squatTm + 4.5).toStringAsFixed(1))),
        benchTm: Value(double.parse((block.benchTm + 2.2).toStringAsFixed(1))),
        deadliftTm: Value(double.parse((block.deadliftTm + 4.5).toStringAsFixed(1))),
        pressTm: Value(double.parse((block.pressTm + 2.2).toStringAsFixed(1))),
      ),
    );

    await refresh();
  }
}
