import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../fivethreeone/fivethreeone_state.dart';
import '../fivethreeone/schemes.dart';

/// 5/3/1 powerlifting calculator dialog
/// Shows block-based layout from active FiveThreeOneBlock
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
  double? _trainingMax;
  String _unit = 'kg';

  // Block state fields
  int _blockCycleType = 0;
  int _blockWeek = 1;
  bool _hasActiveBlock = false;

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
    _loadBlockData();
  }

  void _loadBlockData() {
    final fiveThreeOneState = context.read<FiveThreeOneState>();

    if (fiveThreeOneState.hasActiveBlock) {
      final block = fiveThreeOneState.activeBlock!;
      _hasActiveBlock = true;
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

  void _saveBlockTm() {
    final tm = double.tryParse(_tmController.text);
    if (tm == null || tm <= 0) return;

    context.read<FiveThreeOneState>().updateTm(
      exercise: _getExerciseKey(),
      value: tm,
    );

    setState(() {
      _trainingMax = tm;
    });
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

    // No active block: show informational message
    if (!_hasActiveBlock) {
      return Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fitness_center,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No active 5/3/1 block',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a block from the 5/3/1 page to use the calculator',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    final scheme = getMainScheme(cycleType: _blockCycleType, week: _blockWeek);
    final supplemental = getSupplementalScheme(
        cycleType: _blockCycleType, week: _blockWeek);

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
                            Text(
                              '${cycleNames[_blockCycleType]} \u2014 Week $_blockWeek',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
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
                      onChanged: (_) => _saveBlockTm(),
                    ),

                    const SizedBox(height: 16),

                    // Block position header
                    Text(
                      '${getDescriptiveLabel(_blockCycleType)} — Week $_blockWeek',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 24),

                    // Working Sets
                    if (_trainingMax != null) ...[
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
                                          '\u00d7${set.reps}${set.amrap ? '+' : ''}',
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
                                      '${(set.percentage * 100).toInt()}% of TM${set.amrap ? ' \u00b7 AMRAP' : ''}',
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

                      // Supplemental section
                      if (supplemental.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Divider(color: colorScheme.outlineVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Supplemental Work',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
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

                      // TM Test feedback banner
                      if (_blockCycleType == cycleTmTest) ...[
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
                      'TM should be 85% of your true 1RM',
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
