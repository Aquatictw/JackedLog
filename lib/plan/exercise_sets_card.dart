import 'package:drift/drift.dart' hide Column;
import 'package:flexify/database/database.dart';
import 'package:flexify/main.dart';
import 'package:flexify/plan/plan_state.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flexify/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class SetData {
  double weight;
  int reps;
  bool completed;
  int? savedSetId;

  SetData({
    required this.weight,
    required this.reps,
    this.completed = false,
    this.savedSetId,
  });
}

class ExerciseSetsCard extends StatefulWidget {
  final PlanExercise exercise;
  final int planId;
  final int? workoutId;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onSetCompleted;

  const ExerciseSetsCard({
    super.key,
    required this.exercise,
    required this.planId,
    required this.workoutId,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onSetCompleted,
  });

  @override
  State<ExerciseSetsCard> createState() => _ExerciseSetsCardState();
}

class _ExerciseSetsCardState extends State<ExerciseSetsCard> {
  List<SetData> sets = [];
  bool _initialized = false;
  String unit = 'kg';
  double _defaultWeight = 0.0;
  int _defaultReps = 8;

  @override
  void initState() {
    super.initState();
    _loadSetsData();
  }

  @override
  void didUpdateWidget(ExerciseSetsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workoutId != widget.workoutId) {
      _loadSetsData();
    }
  }

  Future<void> _loadSetsData() async {
    final settings = context.read<SettingsState>().value;
    final maxSets = widget.exercise.maxSets ?? settings.maxSets;

    // Get the last set for this exercise to get default weight
    final lastSet = await (db.gymSets.select()
          ..where((tbl) => tbl.name.equals(widget.exercise.exercise))
          ..orderBy([
            (u) => OrderingTerm(expression: u.created, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();

    _defaultWeight = lastSet?.weight ?? 0.0;
    _defaultReps = lastSet?.reps.toInt() ?? 8;
    final defaultUnit = lastSet?.unit ?? settings.strengthUnit;

    // Get sets already completed in this workout
    List<GymSet> completedSets = [];
    if (widget.workoutId != null) {
      completedSets = await (db.gymSets.select()
            ..where((tbl) =>
                tbl.name.equals(widget.exercise.exercise) &
                tbl.workoutId.equals(widget.workoutId!) &
                tbl.hidden.equals(false))
            ..orderBy([
              (u) => OrderingTerm(expression: u.created, mode: OrderingMode.asc),
            ]))
          .get();
    }

    if (!mounted) return;

    setState(() {
      unit = defaultUnit;
      sets = List.generate(maxSets, (index) {
        if (index < completedSets.length) {
          final set = completedSets[index];
          return SetData(
            weight: set.weight,
            reps: set.reps.toInt(),
            completed: true,
            savedSetId: set.id,
          );
        }
        return SetData(
          weight: _defaultWeight,
          reps: _defaultReps,
          completed: false,
        );
      });
      _initialized = true;
    });
  }

  int get completedCount => sets.where((s) => s.completed).length;

  Future<void> _toggleSet(int index) async {
    if (sets[index].completed) {
      await _uncompleteSet(index);
    } else {
      await _completeSet(index);
    }
  }

  Future<void> _completeSet(int index) async {
    if (sets[index].completed) return;

    final settings = context.read<SettingsState>().value;
    final setData = sets[index];

    // Haptic feedback
    HapticFeedback.mediumImpact();

    double? bodyWeight;
    if (settings.showBodyWeight) {
      final weightSet = await (db.gymSets.select()
            ..where((tbl) => tbl.name.equals('Weight'))
            ..orderBy([
              (u) =>
                  OrderingTerm(expression: u.created, mode: OrderingMode.desc),
            ])
            ..limit(1))
          .getSingleOrNull();
      bodyWeight = weightSet?.weight;
    }

    final gymSet = await db.into(db.gymSets).insertReturning(
          GymSetsCompanion.insert(
            name: widget.exercise.exercise,
            reps: setData.reps.toDouble(),
            weight: setData.weight,
            unit: unit,
            created: DateTime.now().toLocal(),
            planId: Value(widget.planId),
            workoutId: Value(widget.workoutId),
            bodyWeight: Value.absentIfNull(bodyWeight),
          ),
        );

    setState(() {
      sets[index].completed = true;
      sets[index].savedSetId = gymSet.id;
    });

    // Start rest timer if not last set
    final isLastSet = completedCount == sets.length;
    if (!isLastSet && settings.restTimers) {
      final timerState = context.read<TimerState>();
      final restMs = settings.timerDuration;
      timerState.startTimer(
        "${widget.exercise.exercise} (${completedCount})",
        Duration(milliseconds: restMs),
        settings.alarmSound,
        settings.vibrate,
      );
    }

    // Update plan state
    final planState = context.read<PlanState>();
    await planState.updateGymCounts(widget.planId, widget.workoutId);

    widget.onSetCompleted();
  }

  Future<void> _uncompleteSet(int index) async {
    if (!sets[index].completed || sets[index].savedSetId == null) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Delete the set from database
    await (db.gymSets.delete()
          ..where((tbl) => tbl.id.equals(sets[index].savedSetId!)))
        .go();

    setState(() {
      sets[index].completed = false;
      sets[index].savedSetId = null;
    });

    // Update plan state
    final planState = context.read<PlanState>();
    await planState.updateGymCounts(widget.planId, widget.workoutId);
  }

  void _addSet() {
    HapticFeedback.selectionClick();
    setState(() {
      sets.add(SetData(
        weight: sets.isNotEmpty ? sets.last.weight : _defaultWeight,
        reps: sets.isNotEmpty ? sets.last.reps : _defaultReps,
        completed: false,
      ));
    });
  }

  Future<void> _deleteSet(int index) async {
    HapticFeedback.mediumImpact();

    // If the set was completed, delete from database
    if (sets[index].completed && sets[index].savedSetId != null) {
      await (db.gymSets.delete()
            ..where((tbl) => tbl.id.equals(sets[index].savedSetId!)))
          .go();

      // Update plan state
      final planState = context.read<PlanState>();
      await planState.updateGymCounts(widget.planId, widget.workoutId);
    }

    setState(() {
      sets.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allCompleted = sets.isNotEmpty && sets.every((s) => s.completed);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
      child: Column(
        children: [
          // Exercise Header
          InkWell(
            onTap: widget.onToggleExpand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: allCompleted
                    ? LinearGradient(
                        colors: [
                          colorScheme.primaryContainer.withValues(alpha: 0.6),
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: allCompleted
                          ? colorScheme.primary
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      allCompleted ? Icons.check : Icons.fitness_center,
                      color: allCompleted
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exercise.exercise,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        if (_initialized)
                          Row(
                            children: [
                              Icon(
                                Icons.repeat,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$completedCount / ${sets.length} sets',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              if (completedCount > 0) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.fitness_center,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${_getTotalVolume()} $unit',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Progress bar
          if (_initialized)
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: sets.isEmpty ? 0 : completedCount / sets.length,
              ),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  allCompleted ? colorScheme.primary : colorScheme.tertiary,
                ),
                minHeight: 4,
              ),
            ),
          // Set rows (when expanded)
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _initialized
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Column(
                      children: [
                        ...List.generate(sets.length, (index) {
                          return _SetRow(
                            key: ValueKey('set_$index'),
                            index: index,
                            setData: sets[index],
                            unit: unit,
                            onWeightChanged: (value) {
                              setState(() => sets[index].weight = value);
                            },
                            onRepsChanged: (value) {
                              setState(() => sets[index].reps = value);
                            },
                            onToggle: () => _toggleSet(index),
                            onDelete: () => _deleteSet(index),
                          );
                        }),
                        // Add set button
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: InkWell(
                            onTap: _addSet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 1,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 20,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add Set',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(),
            crossFadeState: widget.isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _getTotalVolume() {
    final total = sets
        .where((s) => s.completed)
        .fold<double>(0, (sum, s) => sum + (s.weight * s.reps));
    if (total >= 1000) {
      return '${(total / 1000).toStringAsFixed(1)}k';
    }
    return total.toStringAsFixed(0);
  }
}

class _SetRow extends StatelessWidget {
  final int index;
  final SetData setData;
  final String unit;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _SetRow({
    super.key,
    required this.index,
    required this.setData,
    required this.unit,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final completed = setData.completed;

    return Dismissible(
      key: Key('dismissible_set_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        onDelete();
        return false; // We handle deletion ourselves
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.error,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: completed
              ? colorScheme.primaryContainer.withValues(alpha: 0.4)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: completed
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Set number badge
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: completed
                    ? colorScheme.primary.withValues(alpha: 0.2)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: completed
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Weight input
            Expanded(
              flex: 3,
              child: _WeightInput(
                value: setData.weight,
                unit: unit,
                enabled: !completed,
                onChanged: onWeightChanged,
              ),
            ),
            const SizedBox(width: 8),
            // Reps input with +/- buttons
            Expanded(
              flex: 4,
              child: _RepsInput(
                value: setData.reps,
                enabled: !completed,
                onChanged: onRepsChanged,
              ),
            ),
            const SizedBox(width: 8),
            // Complete/Toggle button
            _CompleteButton(
              completed: completed,
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightInput extends StatefulWidget {
  final double value;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _WeightInput({
    required this.value,
    required this.unit,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_WeightInput> createState() => _WeightInputState();
}

class _WeightInputState extends State<_WeightInput> {
  late TextEditingController _controller;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatWeight(widget.value));
  }

  @override
  void didUpdateWidget(_WeightInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_hasFocus) {
      _controller.text = _formatWeight(widget.value);
    }
  }

  String _formatWeight(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      onFocusChange: (hasFocus) => _hasFocus = hasFocus,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: widget.enabled ? colorScheme.onSurface : colorScheme.primary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          suffixText: widget.unit,
          suffixStyle: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: widget.enabled
              ? colorScheme.surface
              : Colors.transparent,
        ),
        onChanged: (value) {
          final parsed = double.tryParse(value);
          if (parsed != null) {
            widget.onChanged(parsed);
          }
        },
        onTap: () {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        },
      ),
    );
  }
}

class _RepsInput extends StatefulWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _RepsInput({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_RepsInput> createState() => _RepsInputState();
}

class _RepsInputState extends State<_RepsInput> {
  late TextEditingController _controller;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_RepsInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_hasFocus) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: widget.enabled ? colorScheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (widget.enabled)
            _RepsButton(
              icon: Icons.remove,
              onPressed: widget.value > 1
                  ? () {
                      HapticFeedback.selectionClick();
                      widget.onChanged(widget.value - 1);
                    }
                  : null,
            ),
          Expanded(
            child: Focus(
              onFocusChange: (hasFocus) => _hasFocus = hasFocus,
              child: TextField(
                controller: _controller,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.enabled
                      ? colorScheme.onSurface
                      : colorScheme.primary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                  suffixText: 'reps',
                  suffixStyle: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0 && parsed < 100) {
                    widget.onChanged(parsed);
                  }
                },
                onTap: () {
                  _controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controller.text.length,
                  );
                },
              ),
            ),
          ),
          if (widget.enabled)
            _RepsButton(
              icon: Icons.add,
              onPressed: widget.value < 99
                  ? () {
                      HapticFeedback.selectionClick();
                      widget.onChanged(widget.value + 1);
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}

class _RepsButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _RepsButton({
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 32,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: onPressed != null
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _CompleteButton extends StatelessWidget {
  final bool completed;
  final VoidCallback onPressed;

  const _CompleteButton({
    required this.completed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: completed
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            completed ? Icons.check : Icons.check,
            key: ValueKey(completed),
            color: completed
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            size: 22,
          ),
        ),
      ),
    );
  }
}
