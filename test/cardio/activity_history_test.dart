import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/cardio/activity_history.dart';
import 'package:jackedlog/cardio/activity_presentation.dart';
import 'package:jackedlog/cardio/cardio_activity_store.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase database;
  final day = DateTime(2026, 9, 1, 12);
  CardioActivity run(String id, {int? workoutId}) => CardioActivity(
        id: id,
        workoutId: workoutId,
        name: 'Morning run',
        sport: 'run',
        environment: 'outdoor',
        recordedAt: day,
        distanceMeters: 5000,
        durationSeconds: 1740,
        durationBasis: 'elapsed',
        warmup: false,
        source: 'manual',
      );
  setUp(() async {
    database = await createTestDatabase();
  });
  tearDown(() async {
    await database.close();
  });

  test('mixed pages have stable typed identities and no attached duplicates',
      () async {
    final workout = await database
        .into(database.workouts)
        .insert(WorkoutsCompanion.insert(startTime: day));
    final store = CardioActivityStore(database);
    await store.save(run('$workout'));
    await store.save(run('attached-a', workoutId: workout));
    await store.save(run('attached-b', workoutId: workout));
    final history = ActivityHistory(database);
    final first = await history.query(limit: 1).get();
    final second = await history.query(limit: 1, offset: 1).get();
    expect(
      {...first.map((e) => e.key), ...second.map((e) => e.key)},
      {'workout:$workout', 'activity:$workout'},
    );
    expect(await history.query(offset: 2).get(), isEmpty);
    expect((await history.query(search: 'Morning').get()).length, 2);
    await store.delete('$workout');
    expect((await history.query().get()).single.key, 'workout:$workout');
    expect((await database.select(database.cardioActivities).get()).length, 2);
  });

  test('search and date filters precede pagination and escape wildcards',
      () async {
    final store = CardioActivityStore(database);
    await store.save(
      run('older').copyWith(
        name: '100% run',
        startedAt: Value(day.subtract(const Duration(days: 1))),
      ),
    );
    await store.save(run('newer'));
    expect(
      (await ActivityHistory(database).query(limit: 1, search: '100%').get())
          .single
          .id,
      'older',
    );
    expect(await ActivityHistory(database).query(search: '_').get(), isEmpty);
    expect(
      (await ActivityHistory(database).query(start: day).get()).single.id,
      'newer',
    );
  });

  test('pace uses known paired evidence and the preferred distance unit', () {
    expect(activityPace(run('a'), 'km'), '5:48 min/km');
    expect(activityPace(run('a'), 'mi'), '9:20 min/mi');
    expect(
      activityPace(run('a').copyWith(durationBasis: 'unspecified'), 'km'),
      contains('time basis unknown'),
    );
    expect(
      activityPace(
        run('a').copyWith(distanceMeters: const Value(null)),
        'km',
      ),
      contains('required'),
    );
    expect(
      activityPace(run('a').copyWith(sport: 'other'), 'km'),
      contains('unclassified'),
    );
  });
}
