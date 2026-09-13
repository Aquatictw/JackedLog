import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jackedlog/cardio/activity_detail_page.dart';
import 'package:jackedlog/cardio/activity_history.dart';
import 'package:jackedlog/cardio/cardio_trends.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/database/database_connection_native.dart';
import 'package:jackedlog/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline cardio entry and 10,000 activity history',
      (tester) async {
    if (databaseFilename != 'cardio-test.sqlite') {
      throw StateError(
        'Pass --dart-define=JACKEDLOG_DATABASE_FILENAME=cardio-test.sqlite',
      );
    }
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    final database = AppDatabase(createNativeConnection());
    await database.delete(database.cardioActivities).go();
    await tester.pumpWidget(
      MaterialApp(
        theme: jlTheme(jlScheme(0xFFFF5C1F, Brightness.dark)),
        home: ActivityEditorPage(database: database, unit: 'km'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Distance (km)'),
      '5',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Duration (minutes)'),
      '29',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Save activity'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save activity'));
    await tester.pumpAndSettle();
    for (var i = 0;
        i < 100 && find.text('5:48 min/km').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('5:48 min/km'), findsOneWidget);
    final saved =
        (await database.select(database.cardioActivities).get()).single;
    expect(saved.distanceMeters, 5000);
    final now = DateTime.now();
    await database.batch(
      (batch) => batch.insertAll(database.cardioActivities, [
        for (var i = 0; i < 9999; i++)
          CardioActivitiesCompanion.insert(
            id: 'benchmark:$i',
            name: 'Benchmark run',
            recordedAt: now.subtract(Duration(minutes: i)),
            distanceMeters: const Value(5000),
            durationSeconds: const Value(1800),
            sport: const Value('run'),
            durationBasis: const Value('elapsed'),
          ),
      ]),
    );
    final times = <int>[];
    for (var i = 0; i < 31; i++) {
      final watch = Stopwatch()..start();
      final page = await ActivityHistory(database).query(offset: i * 100).get();
      watch.stop();
      expect(page.length, 100);
      if (i > 0) times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    debugPrint(
      'CARDIO_HISTORY_10000 page=100 samples=30 p50_us=${times[14]} p95_us=${times[28]} max_us=${times.last}',
    );
    final summaries = <int>[];
    for (var i = 0; i < 31; i++) {
      final watch = Stopwatch()..start();
      final weeks = await CardioTrends(database).weekly(through: now).get();
      watch.stop();
      expect(weeks.fold<int>(0, (sum, week) => sum + week.sessions), 10000);
      expect(weeks.length, lessThanOrEqualTo(12));
      if (i > 0) summaries.add(watch.elapsedMicroseconds);
    }
    summaries.sort();
    debugPrint(
        'CARDIO_TRENDS_10000 weeks=12 samples=30 p50_us=${summaries[14]} p95_us=${summaries[28]} max_us=${summaries.last}',);
    // Leave the detail visible for an adb screenshot during this interval.
    await Future<void>.delayed(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await database.close();
  });
}
