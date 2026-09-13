import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/cardio/activity_detail_page.dart';
import 'package:jackedlog/database/database.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase database;
  setUp(() async {
    database = await createTestDatabase();
  });
  tearDown(() async {
    await database.close();
  });

  testWidgets('off-screen invalid measurements cannot save as missing', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ActivityEditorPage(database: database, unit: 'km')));
    await tester.enterText(find.byKey(const ValueKey('activity-distance')), '-1');
    await tester.scrollUntilVisible(find.text('Save activity'), 250,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,);
    await tester.tap(find.text('Save activity'));
    await tester.pumpAndSettle();
    expect(await database.select(database.cardioActivities).get(), isEmpty);
    expect(find.textContaining('Enter a name and valid'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('manual miles save, detail, edit and delete use the real store',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ActivityEditorPage(database: database, unit: 'mi')),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Distance (mi)'),
      '1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Duration (minutes)'),
      '10',
    );
    await tester.scrollUntilVisible(
      find.text('Save activity'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save activity'));
    await tester.pumpAndSettle();
    expect(find.text('10:00 min/mi'), findsOneWidget);
    final saved =
        (await database.select(database.cardioActivities).get()).single;
    expect(saved.distanceMeters, 1609.344);
    expect(saved.durationSeconds, 600);
    expect(
      await (database.select(database.gymSets)
            ..where((s) => s.hidden.equals(false)))
          .get(),
      isEmpty,
    );
    await tester.scrollUntilVisible(find.text('Edit activity'), 250,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable),)
            .first,);
    await tester.tap(find.text('Edit activity'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Distance (mi)'),
      '',
    );
    await tester.scrollUntilVisible(
      find.text('Save activity'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Save activity'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining('Pace unavailable:'), -250,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable),)
            .first,);
    expect(find.textContaining('Pace unavailable:'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Delete activity'), 250,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable),)
            .first,);
    await tester.tap(find.text('Delete activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await database.select(database.cardioActivities).get(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
