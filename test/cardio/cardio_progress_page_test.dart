import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/cardio/cardio_activity_store.dart';
import 'package:jackedlog/cardio/cardio_progress_page.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

void main() {
  testWidgets(
      'progress filters show paired pace and update to the latest group',
      (tester) async {
    final database = await createTestDatabase();
    final now = DateTime.now();
    for (final entry in [('short', 1000.0, 300.0), ('long', 4000.0, 1440.0)]) {
      await CardioActivityStore(database).save(
        CardioActivity(
          id: entry.$1,
          name: 'Run',
          sport: 'run',
          environment: 'outdoor',
          recordedAt: now,
          startedAt: now,
          startUtcOffsetMinutes: now.timeZoneOffset.inMinutes,
          durationBasis: 'elapsed',
          distanceMeters: entry.$2,
          durationSeconds: entry.$3,
          warmup: false,
          source: 'manual',
        ),
      );
    }
    await tester.pumpWidget(
        MaterialApp(home: CardioProgressPage(database: database, unit: 'km')),);
    await tester.pumpAndSettle();
    Future<void> choose(int index, String label) async {
      final dropdown = find.byType(DropdownButtonFormField<String>).at(index);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await choose(0, 'Run');
    await choose(1, 'Outdoors');
    await choose(2, 'Total time');
    final scrollable = find
        .descendant(
            of: find.byType(ListView), matching: find.byType(Scrollable),)
        .first;
    await tester.scrollUntilVisible(find.text('5:48 min/km'), 200,
        scrollable: scrollable,);
    expect(find.text('5:48 min/km'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sport'), -200,
        scrollable: scrollable,);
    await choose(0, 'Ride');
    await tester.scrollUntilVisible(
        find.text(
            'No activities match these filters. Try All, or log a cardio activity.',),
        200,
        scrollable: scrollable,);
    expect(find.text('5:48 min/km'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(database.close);
  });
}
