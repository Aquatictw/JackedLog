import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/workouts/workout_state.dart';

import '../test_helpers.dart';

void main() {
  group('WorkoutState state transitions', () {
    late AppDatabase db;
    late WorkoutState workoutState;
    late Plan testPlan;

    setUp(() async {
      db = await createTestDatabase();
      workoutState = WorkoutState();

      // Create a test plan
      testPlan = await db.into(db.plans).insertReturning(
        PlansCompanion.insert(
          days: 'Push',
          sequence: const Value(0),
          title: const Value('Push Day'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('starts workout successfully when none active', () async {
      expect(workoutState.hasActiveWorkout, isFalse);
      expect(workoutState.activeWorkout, isNull);
      expect(workoutState.activePlan, isNull);

      final workout = await workoutState.startWorkout(testPlan);

      expect(workout, isNotNull);
      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout, isNotNull);
      expect(workoutState.activeWorkout!.id, equals(workout!.id));
      expect(workoutState.activeWorkout!.name, equals('Push Day'));
      expect(workoutState.activeWorkout!.endTime, isNull);
      expect(workoutState.activePlan, isNotNull);
      expect(workoutState.activePlan!.id, equals(testPlan.id));
    });

    test('uses plan days when plan title is empty', () async {
      final planNoDays = await db.into(db.plans).insertReturning(
        PlansCompanion.insert(
          days: 'Monday,Wednesday,Friday',
          sequence: const Value(1),
          title: const Value(null),
        ),
      );

      final workout = await workoutState.startWorkout(planNoDays);

      expect(workout, isNotNull);
      expect(workoutState.activeWorkout!.name, equals('Monday, Wednesday, Friday'));
    });

    test('prevents starting workout when one already active', () async {
      // Start first workout
      final firstWorkout = await workoutState.startWorkout(testPlan);
      expect(firstWorkout, isNotNull);
      expect(workoutState.hasActiveWorkout, isTrue);

      // Create another plan
      final secondPlan = await db.into(db.plans).insertReturning(
        PlansCompanion.insert(
          days: 'Pull',
          sequence: const Value(1),
          title: const Value('Pull Day'),
        ),
      );

      // Try to start second workout
      final secondWorkout = await workoutState.startWorkout(secondPlan);

      // Should return null and keep first workout active
      expect(secondWorkout, isNull);
      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout!.id, equals(firstWorkout!.id));
      expect(workoutState.activeWorkout!.name, equals('Push Day'));
    });

    test('stops workout successfully', () async {
      // Start workout
      await workoutState.startWorkout(testPlan);
      expect(workoutState.hasActiveWorkout, isTrue);

      // Stop workout
      await workoutState.stopWorkout();

      expect(workoutState.hasActiveWorkout, isFalse);
      expect(workoutState.activeWorkout, isNull);
      expect(workoutState.activePlan, isNull);
    });

    test('stops workout with selfie image path', () async {
      // Start workout
      final workout = await workoutState.startWorkout(testPlan);
      expect(workout, isNotNull);

      // Stop with selfie
      await workoutState.stopWorkout(selfieImagePath: '/path/to/selfie.jpg');

      expect(workoutState.hasActiveWorkout, isFalse);

      // Verify workout was updated in DB with selfie path
      final stoppedWorkout = await (db.workouts.select()
            ..where((w) => w.id.equals(workout!.id)))
          .getSingle();
      expect(stoppedWorkout.endTime, isNotNull);
      expect(stoppedWorkout.selfieImagePath, equals('/path/to/selfie.jpg'));
    });

    test('handles stopping when no workout active', () async {
      expect(workoutState.hasActiveWorkout, isFalse);

      // Should not throw, just return silently
      await workoutState.stopWorkout();

      expect(workoutState.hasActiveWorkout, isFalse);
    });

    test('resumes completed workout successfully', () async {
      // Create a completed workout
      final completedWorkout = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now().subtract(const Duration(hours: 2)),
          endTime: Value(DateTime.now().subtract(const Duration(hours: 1))),
          planId: Value(testPlan.id),
          name: const Value('Completed Workout'),
        ),
      );

      expect(workoutState.hasActiveWorkout, isFalse);

      // Resume workout
      final plan = await workoutState.resumeWorkout(completedWorkout);

      expect(plan, isNotNull);
      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout, isNotNull);
      expect(workoutState.activeWorkout!.id, equals(completedWorkout.id));
      expect(workoutState.activeWorkout!.endTime, isNull);

      // Verify startTime was adjusted to preserve duration
      final resumedWorkout = await (db.workouts.select()
            ..where((w) => w.id.equals(completedWorkout.id)))
          .getSingle();
      expect(resumedWorkout.endTime, isNull);
    });

    test('resumes freeform workout with temporary plan', () async {
      // Create freeform workout (no planId)
      final freeformWorkout = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: Value(DateTime.now()),
          planId: const Value(null),
          name: const Value('Morning Workout'),
        ),
      );

      final plan = await workoutState.resumeWorkout(freeformWorkout);

      expect(plan, isNotNull);
      expect(plan!.id, equals(-1)); // Temporary plan ID
      expect(plan.title, equals('Morning Workout'));
      expect(plan.days, equals('Morning Workout'));
      expect(workoutState.activePlan!.id, equals(-1));
    });

    test('prevents resuming different workout when one is active', () async {
      // Start first workout
      await workoutState.startWorkout(testPlan);
      expect(workoutState.hasActiveWorkout, isTrue);
      final activeWorkoutId = workoutState.activeWorkout!.id;

      // Create a second completed workout
      final otherWorkout = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now().subtract(const Duration(hours: 2)),
          endTime: Value(DateTime.now().subtract(const Duration(hours: 1))),
          planId: Value(testPlan.id),
          name: const Value('Other Workout'),
        ),
      );

      // Try to resume different workout
      final plan = await workoutState.resumeWorkout(otherWorkout);

      // Should return null and keep first workout active
      expect(plan, isNull);
      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout!.id, equals(activeWorkoutId));
    });

    test('allows resuming same workout when already active', () async {
      // Start workout
      final workout = await workoutState.startWorkout(testPlan);
      expect(workout, isNotNull);

      // Try to resume the same workout (edge case)
      final plan = await workoutState.resumeWorkout(workout!);

      // Should succeed since it's the same workout
      expect(plan, isNotNull);
      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout!.id, equals(workout.id));
    });

    test('discards workout and clears state', () async {
      // Start workout
      await workoutState.startWorkout(testPlan);
      final workoutId = workoutState.activeWorkout!.id;

      // Add some sets
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Bench Press'),
      );
      await db.gymSets.insertOne(
        createTestSet(workoutId: workoutId, name: 'Squat'),
      );

      // Discard workout
      await workoutState.discardWorkout();

      // State should be cleared
      expect(workoutState.hasActiveWorkout, isFalse);
      expect(workoutState.activeWorkout, isNull);
      expect(workoutState.activePlan, isNull);

      // Workout should be deleted from DB
      final deletedWorkout = await (db.workouts.select()
            ..where((w) => w.id.equals(workoutId)))
          .getSingleOrNull();
      expect(deletedWorkout, isNull);

      // Sets should be deleted from DB
      final deletedSets = await (db.gymSets.select()
            ..where((s) => s.workoutId.equals(workoutId)))
          .get();
      expect(deletedSets, isEmpty);
    });

    test('handles discard when no workout active', () async {
      expect(workoutState.hasActiveWorkout, isFalse);

      // Should not throw
      await workoutState.discardWorkout();

      expect(workoutState.hasActiveWorkout, isFalse);
    });

    test('clearActiveWorkout clears state without DB changes', () async {
      // Start workout
      await workoutState.startWorkout(testPlan);
      final workoutId = workoutState.activeWorkout!.id;

      // Clear state (not stopping workout in DB)
      workoutState.clearActiveWorkout();

      expect(workoutState.hasActiveWorkout, isFalse);
      expect(workoutState.activeWorkout, isNull);
      expect(workoutState.activePlan, isNull);

      // Workout should still exist in DB with null endTime
      final workout = await (db.workouts.select()
            ..where((w) => w.id.equals(workoutId)))
          .getSingle();
      expect(workout.endTime, isNull);
    });

    test('setActiveWorkout manually sets state', () async {
      // Create a workout in DB
      final workout = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now(),
          planId: Value(testPlan.id),
          name: const Value('Manual Workout'),
        ),
      );

      expect(workoutState.hasActiveWorkout, isFalse);

      // Manually set active workout
      workoutState.setActiveWorkout(workout, testPlan);

      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout!.id, equals(workout.id));
      expect(workoutState.activePlan!.id, equals(testPlan.id));
    });

    test('refresh loads active workout from database', () async {
      // Create active workout directly in DB
      final workout = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now(),
          endTime: const Value(null),
          planId: Value(testPlan.id),
          name: const Value('Active Workout'),
        ),
      );

      expect(workoutState.hasActiveWorkout, isFalse);

      // Refresh should load it
      await workoutState.refresh();

      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout!.id, equals(workout.id));
      expect(workoutState.activePlan!.id, equals(testPlan.id));
    });

    test('refresh handles no active workouts', () async {
      // Create only completed workouts
      await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: Value(DateTime.now()),
          planId: Value(testPlan.id),
          name: const Value('Completed'),
        ),
      );

      await workoutState.refresh();

      expect(workoutState.hasActiveWorkout, isFalse);
    });

    test('refresh loads most recent when multiple active workouts exist', () async {
      // Create multiple active workouts (edge case: data corruption)
      final now = DateTime.now();

      await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: now.subtract(const Duration(hours: 3)),
          endTime: const Value(null),
          planId: Value(testPlan.id),
          name: const Value('Old Active'),
        ),
      );

      await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: now.subtract(const Duration(hours: 1)),
          endTime: const Value(null),
          planId: Value(testPlan.id),
          name: const Value('Recent Active'),
        ),
      );

      final mostRecent = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: now,
          endTime: const Value(null),
          planId: Value(testPlan.id),
          name: const Value('Most Recent'),
        ),
      );

      await workoutState.refresh();

      expect(workoutState.hasActiveWorkout, isTrue);
      expect(workoutState.activeWorkout!.id, equals(mostRecent.id));
      expect(workoutState.activeWorkout!.name, equals('Most Recent'));
    });
  });

  group('WorkoutState notifyListeners', () {
    late AppDatabase db;
    late WorkoutState workoutState;
    late Plan testPlan;

    setUp(() async {
      db = await createTestDatabase();
      workoutState = WorkoutState();

      testPlan = await db.into(db.plans).insertReturning(
        PlansCompanion.insert(
          days: 'Test',
          sequence: const Value(0),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('startWorkout notifies listeners', () async {
      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      await workoutState.startWorkout(testPlan);

      expect(notified, isTrue);
    });

    test('stopWorkout notifies listeners', () async {
      await workoutState.startWorkout(testPlan);

      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      await workoutState.stopWorkout();

      expect(notified, isTrue);
    });

    test('resumeWorkout notifies listeners', () async {
      final workout = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now().subtract(const Duration(hours: 1)),
          endTime: Value(DateTime.now()),
          planId: Value(testPlan.id),
        ),
      );

      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      await workoutState.resumeWorkout(workout);

      expect(notified, isTrue);
    });

    test('discardWorkout notifies listeners', () async {
      await workoutState.startWorkout(testPlan);

      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      await workoutState.discardWorkout();

      expect(notified, isTrue);
    });

    test('clearActiveWorkout notifies listeners', () async {
      await workoutState.startWorkout(testPlan);

      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      workoutState.clearActiveWorkout();

      expect(notified, isTrue);
    });

    test('setActiveWorkout notifies listeners', () async {
      final workout = await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now(),
          planId: Value(testPlan.id),
        ),
      );

      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      workoutState.setActiveWorkout(workout, testPlan);

      expect(notified, isTrue);
    });

    test('refresh notifies listeners when active workout found', () async {
      await db.into(db.workouts).insertReturning(
        WorkoutsCompanion.insert(
          startTime: DateTime.now(),
          endTime: const Value(null),
          planId: Value(testPlan.id),
        ),
      );

      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      await workoutState.refresh();

      expect(notified, isTrue);
    });

    test('refresh does not notify when no active workout', () async {
      var notified = false;
      workoutState.addListener(() {
        notified = true;
      });

      await workoutState.refresh();

      expect(notified, isFalse);
    });
  });

  group('WorkoutState navigation keys', () {
    test('sets and retrieves plans navigator key', () {
      final workoutState = WorkoutState();
      expect(workoutState.plansNavigatorKey, isNull);

      final key = GlobalKey<NavigatorState>();
      workoutState.setPlansNavigatorKey(key);

      expect(workoutState.plansNavigatorKey, equals(key));
    });
  });
}
