import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../database/database.dart';
import '../fivethreeone/fivethreeone_state.dart';
import '../fivethreeone/schemes.dart';
import '../main.dart';
import '../settings/settings_state.dart';

/// 5/3/1 powerlifting calculator dialog
/// Helps calculate weights for the 5/3/1 program based on Training Max
class FiveThreeOneCalculator extends StatefulWidget {

  const FiveThreeOneCalculator({
    required this.exerciseName, super.key,
  });
  final String exerciseName;

  @override
  State<FiveThreeOneCalculator> createState() => _FiveThreeOneCalculatorState();
}

class _FiveThreeOneCalculatorState extends State<FiveThreeOneCalculator> {
  late TextEditingController _tmController;
  int _currentWeek = 1;
  double? _trainingMax;
  String _unit = 'kg';

  // Block-aware state fields
  bool _isBlockMode = false;
  int _blockCycleType = 0;
  int _blockWeek = 1;

  // Map exercise names to their settings field
  static const Map<String, String> exerciseMapping = {
    'Squat': 'squat',
    'Bench Press': 'bench',
    'Deadlift': 'deadlift',
    'Overhead Press': 'press',
    'Press': 'press', // Alternative name
  };

  @override
  void initState() {
    super.initState();
    _tmController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final fiveThreeOneState = context.read<FiveThreeOneState>();

    if (fiveThreeOneState.hasActiveBlock) {
      // Block mode: resolve data from active block
      final block = fiveThreeOneState.activeBlock!;
      setState(() {
        _isBlockMode = true;
        _blockCycleType = block.currentCycle;
        _blockWeek = block.currentWeek;
        _unit = block.unit;

        // Resolve TM from block fields
        final exerciseKey = _getExerciseKey();
        switch (exerciseKey) {
          case 'squat':
            _trainingMax = block.squatTm;
            break;
          case 'bench':
            _trainingMax = block.benchTm;
            break;
          case 'deadlift':
            _trainingMax = block.deadliftTm;
            break;
          case 'press':
            _trainingMax = block.pressTm;
            break;
        }

        if (_trainingMax != null) {
          _tmController.text = _trainingMax!.toStringAsFixed(1);
        }
      });
    } else {
      // Manual mode: existing settings-based code path
      final settings = context.read<SettingsState>().value;
      _unit = settings.strengthUnit;

      final setting = await db.settings.select().getSingle();
      setState(() {
        _currentWeek = setting.fivethreeoneWeek;

        // Load appropriate TM based on exercise
        final exerciseKey = _getExerciseKey();
        switch (exerciseKey) {
          case 'squat':
            _trainingMax = setting.fivethreeoneSquatTm;
            break;
          case 'bench':
            _trainingMax = setting.fivethreeoneBenchTm;
            break;
          case 'deadlift':
            _trainingMax = setting.fivethreeoneDeadliftTm;
            break;
          case 'press':
            _trainingMax = setting.fivethreeonePressTm;
            break;
        }

        if (_trainingMax != null) {
          _tmController.text = _trainingMax!.toStringAsFixed(1);
        }
      });
    }
  }

  String _getExerciseKey() {
    for (final entry in exerciseMapping.entries) {
      if (widget.exerciseName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    return 'squat'; // Default fallback
  }

  Future<void> _saveTrainingMax() async {
    final tm = double.tryParse(_tmController.text);
    if (tm == null || tm <= 0) return;

    final exerciseKey = _getExerciseKey();

    // Update appropriate TM field
    switch (exerciseKey) {
      case 'squat':
        await db.settings.update().write(
              SettingsCompanion(
                fivethreeoneSquatTm: Value(tm),
              ),
            );
        break;
      case 'bench':
        await db.settings.update().write(
              SettingsCompanion(
                fivethreeoneBenchTm: Value(tm),
              ),
            );
        break;
      case 'deadlift':
        await db.settings.update().write(
              SettingsCompanion(
                fivethreeoneDeadliftTm: Value(tm),
              ),
            );
        break;
      case 'press':
        await db.settings.update().write(
              SettingsCompanion(
                fivethreeonePressTm: Value(tm),
              ),
            );
        break;
    }

    setState(() {
      _trainingMax = tm;
    });

    HapticFeedback.mediumImpact();
  }

  Future<void> _updateWeek(int week) async {
    await db.settings.update().write(
          SettingsCompanion(
            fivethreeoneWeek: Value(week),
          ),
        );

    setState(() {
      _currentWeek = week;
    });

    HapticFeedback.selectionClick();
  }

  Future<void> _progressCycle() async {
    final tm = _trainingMax;
    if (tm == null) return;

    // Increment TM based on exercise type
    final exerciseKey = _getExerciseKey();
    double increment;

    // Press exercises: +5 lb (2.5 kg), Lower body: +10 lb (5 kg)
    if (exerciseKey == 'press' || exerciseKey == 'bench') {
      increment = _unit == 'kg' ? 2.5 : 5.0;
    } else {
      increment = _unit == 'kg' ? 5.0 : 10.0;
    }

    final newTM = tm + increment;
    _tmController.text = newTM.toStringAsFixed(1);
    await _saveTrainingMax();

    // Reset to week 1
    await _updateWeek(1);

    if (mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cycle complete! New TM: ${newTM.toStringAsFixed(1)} $_unit',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<({double percentage, int reps, bool amrap})> _getWorkingSetScheme() {
    switch (_currentWeek) {
      case 1: // 5s week
        return [
          (percentage: 0.65, reps: 5, amrap: false),
          (percentage: 0.75, reps: 5, amrap: false),
          (percentage: 0.85, reps: 5, amrap: true),
        ];
      case 2: // 3s week
        return [
          (percentage: 0.70, reps: 3, amrap: false),
          (percentage: 0.80, reps: 3, amrap: false),
          (percentage: 0.90, reps: 3, amrap: true),
        ];
      case 3: // 5/3/1 week
        return [
          (percentage: 0.75, reps: 5, amrap: false),
          (percentage: 0.85, reps: 3, amrap: false),
          (percentage: 0.95, reps: 1, amrap: true),
        ];
      case 4: // Deload
        return [
          (percentage: 0.40, reps: 5, amrap: false),
          (percentage: 0.50, reps: 5, amrap: false),
          (percentage: 0.60, reps: 5, amrap: false),
        ];
      default:
        return [];
    }
  }

  double _calculateWeight(double percentage) {
    if (_trainingMax == null) return 0;
    final weight = _trainingMax! * percentage;

    // Round to nearest 2.5 for kg, 5 for lb
    final roundTo = _unit == 'kg' ? 2.5 : 5.0;
    return (weight / roundTo).round() * roundTo;
  }

  @override
  void dispose() {
    _tmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scheme = _isBlockMode
        ? getMainScheme(cycleType: _blockCycleType, week: _blockWeek)
        : _getWorkingSetScheme();

    // weekName only used in manual mode
    final weekName = !_isBlockMode
        ? (_currentWeek == 4
            ? 'Deload'
            : _currentWeek == 3
                ? '5/3/1'
                : '${[5, 5, 3][_currentWeek - 1]}s Week')
        : '';

    // Pre-compute supplemental data for block mode
    final supplemental = _isBlockMode
        ? getSupplementalScheme(
            cycleType: _blockCycleType, week: _blockWeek)
        : <SetScheme>[];

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '5/3/1 Calculator',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                            ),
                            Text(
                              widget.exerciseName,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Training Max Input
                    Text(
                      'Training Max (TM)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_isBlockMode)
                      TextField(
                        controller: _tmController,
                        readOnly: true,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Enter your Training Max',
                          suffixText: _unit,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.monitor_weight_outlined),
                        ),
                      )
                    else
                      TextField(
                        controller: _tmController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'Enter your Training Max',
                          suffixText: _unit,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.monitor_weight_outlined),
                        ),
                        onChanged: (_) => _saveTrainingMax(),
                      ),

                    const SizedBox(height: 24),

                    // Week Selector / Block position header
                    if (_isBlockMode)
                      Text(
                        '${getMainSchemeName(_blockCycleType)} — ${cycleNames[_blockCycleType]}, Week $_blockWeek',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      )
                    else
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 1,
                            label: Text('W1'),
                          ),
                          ButtonSegment(
                            value: 2,
                            label: Text('W2'),
                          ),
                          ButtonSegment(
                            value: 3,
                            label: Text('W3'),
                          ),
                          ButtonSegment(
                            value: 4,
                            label: Text('W4'),
                          ),
                        ],
                        selected: {_currentWeek},
                        onSelectionChanged: (Set<int> newSelection) {
                          _updateWeek(newSelection.first);
                        },
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12,),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Working Sets
                    if (_trainingMax != null) ...[
                      if (!_isBlockMode)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Week $_currentWeek: $weekName',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (_currentWeek == 4)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Recovery',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (!_isBlockMode) const SizedBox(height: 12),
                      ...scheme.asMap().entries.map((entry) {
                        final index = entry.key;
                        final set = entry.value;
                        final weight = _calculateWeight(set.percentage);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: set.amrap
                                ? Border.all(
                                    color: colorScheme.primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: set.amrap
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: set.amrap
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${weight.toStringAsFixed(1)} $_unit',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '×${set.reps}${set.amrap ? '+' : ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${(set.percentage * 100).toInt()}% of TM${set.amrap ? ' · AMRAP' : ''}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: set.amrap
                                                ? colorScheme.primary
                                                : colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Supplemental section (block mode only)
                      if (_isBlockMode && supplemental.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Divider(color: colorScheme.outlineVariant),
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          final weight = _calculateWeight(
                              supplemental.first.percentage);
                          final name =
                              getSupplementalName(_blockCycleType);
                          return Text(
                            '$name @ ${weight.toStringAsFixed(1)} $_unit',
                            style:
                                Theme.of(context).textTheme.titleMedium,
                          );
                        }),
                      ],

                      // TM Test feedback banner (block mode only)
                      if (_isBlockMode &&
                          _blockCycleType == cycleTmTest) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color:
                                      colorScheme.onTertiaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You should be able to get 5 strong reps at 100%. If not, lower your TM.',
                                  style: TextStyle(
                                      color: colorScheme
                                          .onTertiaryContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Progress Cycle Button (manual mode only)
                      if (!_isBlockMode && _currentWeek == 4)
                        FilledButton.icon(
                          onPressed: _progressCycle,
                          icon: const Icon(Icons.upgrade),
                          label: const Text('Complete Cycle & Increase TM'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Enter your Training Max to see the prescribed sets',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Info Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TM should be 90% of your true 1RM',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
