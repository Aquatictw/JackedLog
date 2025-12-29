import 'package:drift/drift.dart' hide Column;
import 'package:flexify/database/database.dart';
import 'package:flexify/main.dart';
import 'package:flexify/plan/exercise_sets_card.dart';
import 'package:flexify/plan/plan_state.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flexify/workouts/active_workout_bar.dart';
import 'package:flexify/workouts/workout_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StartPlanPage extends StatefulWidget {
  final Plan plan;

  const StartPlanPage({super.key, required this.plan});

  @override
  createState() => _StartPlanPageState();
}

class _StartPlanPageState extends State<StartPlanPage> {
  int? workoutId;
  late Stream<List<PlanExercise>> stream;
  late String title = widget.plan.days.replaceAll(",", ", ");
  Set<int> expandedExercises = {};
  final TextEditingController _notesController = TextEditingController();
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    title = widget.plan.title?.isNotEmpty == true
        ? widget.plan.title!
        : widget.plan.days.replaceAll(",", ", ");

    // Listen for workout state changes to pop when workout ends
    final workoutState = context.read<WorkoutState>();
    workoutState.addListener(_onWorkoutStateChanged);

    _loadExercises();
  }

  void _onWorkoutStateChanged() {
    final workoutState = context.read<WorkoutState>();
    // If workout was ended (no active workout), pop this page
    if (!workoutState.hasActiveWorkout && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadExercises() async {
    setState(() {
      stream = (db.planExercises.select()
            ..where(
              (pe) => pe.planId.equals(widget.plan.id) & pe.enabled,
            )
            ..orderBy(
              [
                (u) => OrderingTerm(
                      expression: u.sequence,
                      mode: OrderingMode.asc,
                    ),
              ],
            ))
          .watch();
    });

    // Use WorkoutState to get or create workout session
    final workoutState = context.read<WorkoutState>();
    if (workoutState.activeWorkout != null &&
        workoutState.activePlan?.id == widget.plan.id) {
      // Resume existing workout
      setState(() {
        workoutId = workoutState.activeWorkout!.id;
        _notesController.text = workoutState.activeWorkout!.notes ?? '';
      });
    } else if (workoutState.activeWorkout == null) {
      // Create a new workout session
      final workout = await workoutState.startWorkout(widget.plan);
      if (workout != null) {
        setState(() {
          workoutId = workout.id;
        });
      }
    } else {
      // There's an active workout for a different plan - use its ID
      setState(() {
        workoutId = workoutState.activeWorkout!.id;
        _notesController.text = workoutState.activeWorkout!.notes ?? '';
      });
    }

    // Update gym counts with workoutId to show only this workout's progress
    final planState = context.read<PlanState>();
    await planState.updateGymCounts(widget.plan.id, workoutId);

    // Expand first exercise by default
    final exercises = await stream.first;
    if (exercises.isNotEmpty && mounted) {
      setState(() {
        expandedExercises.add(0);
      });
    }
  }

  Future<void> _saveNotes() async {
    if (workoutId == null) return;
    await (db.workouts.update()..where((w) => w.id.equals(workoutId!)))
        .write(WorkoutsCompanion(notes: Value(_notesController.text)));
  }

  @override
  void dispose() {
    _saveNotes();
    _notesController.dispose();
    final workoutState = context.read<WorkoutState>();
    workoutState.removeListener(_onWorkoutStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plan.title?.isNotEmpty == true) title = widget.plan.title!;
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final exercises = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showNotes ? Icons.note : Icons.note_outlined,
                  color: _showNotes ? colorScheme.primary : null,
                ),
                tooltip: 'Workout notes',
                onPressed: () {
                  setState(() {
                    _showNotes = !_showNotes;
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Notes section
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: _NotesSection(
                  controller: _notesController,
                  onChanged: _saveNotes,
                ),
                crossFadeState: _showNotes
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              // Exercises list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ExerciseSetsCard(
                      key: ValueKey(exercise.id),
                      exercise: exercise,
                      planId: widget.plan.id,
                      workoutId: workoutId,
                      isExpanded: expandedExercises.contains(index),
                      onToggleExpand: () {
                        setState(() {
                          if (expandedExercises.contains(index)) {
                            expandedExercises.remove(index);
                          } else {
                            expandedExercises.add(index);
                          }
                        });
                      },
                      onSetCompleted: () {
                        _checkAutoExpandNext(exercises, index);
                      },
                    );
                  },
                ),
              ),
              // Active workout bar at bottom
              const ActiveWorkoutBar(),
            ],
          ),
        );
      },
    );
  }

  void _checkAutoExpandNext(List<PlanExercise> exercises, int currentIndex) {
    // Auto-expand next exercise could be implemented here
    // For now, we just let the user manually expand
  }
}

class _NotesSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _NotesSection({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Workout Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: TextField(
              controller: controller,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Add notes about your workout...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
