import 'package:flutter/material.dart';

import '../database/database.dart';
import '../main.dart';

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
}
