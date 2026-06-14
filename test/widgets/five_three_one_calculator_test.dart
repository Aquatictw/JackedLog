import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/fivethreeone/fivethreeone_state.dart';
import 'package:jackedlog/main.dart' as app;
import 'package:jackedlog/widgets/five_three_one_calculator.dart';
import 'package:provider/provider.dart';

import '../test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Point the global db at a fresh in-memory database with an active block.
    app.db = await createTestDatabase();
    await app.db.into(app.db.fiveThreeOneBlocks).insert(
          FiveThreeOneBlocksCompanion.insert(
            created: DateTime.now(),
            squatTm: 100,
            benchTm: 80,
            deadliftTm: 120,
            pressTm: 50,
            unit: 'kg',
            startSquatTm: const Value(100),
          ),
        );
  });

  testWidgets(
      'shows the calculator on first open even though the block loads async',
      (tester) async {
    await tester.pumpWidget(
      // ChangeNotifierProvider is lazy by default, so the state (and its async
      // block load) only starts when the calculator first reads it — exactly
      // the production first-open scenario.
      ChangeNotifierProvider(
        create: (_) => FiveThreeOneState(),
        child: const MaterialApp(
          home: Scaffold(
            body: FiveThreeOneCalculator(exerciseName: 'Squat'),
          ),
        ),
      ),
    );

    // Let the async block load complete.
    await tester.pumpAndSettle();

    expect(find.text('No active 5/3/1 block'), findsNothing);
    expect(find.text('5/3/1 Calculator'), findsOneWidget);
  });
}
