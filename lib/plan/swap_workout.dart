import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database.dart';
import '../main.dart';
import 'plan_state.dart';

class SwapWorkout extends StatefulWidget {

  const SwapWorkout({required this.exercise, required this.planId, super.key});
  final String exercise;
  final int planId;

  @override
  State<SwapWorkout> createState() => _SwapWorkoutState();
}

class _SwapWorkoutState extends State<SwapWorkout> {
  late Stream<List<String>> _distinctExercises;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });

    _distinctExercises = (db.gymSets.selectOnly(distinct: true)
          ..addColumns([db.gymSets.name])
          ..orderBy([
            drift.OrderingTerm(expression: db.gymSets.name),
          ]))
        .map((row) => row.read(db.gymSets.name)!)
        .watch()
        .map((event) => event.where((name) => name.isNotEmpty).toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PlanState>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Swap workout'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Exercises',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _distinctExercises,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const SizedBox();
                }

                final exercises = snapshot.data!
                    .where(
                      (name) => name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()),
                    )
                    .toList();

                return ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final exercise = exercises[index];
                    return ListTile(
                      title: Text(exercise),
                      onTap: () async {
                        final old = await (db.planExercises.select()
                              ..where(
                                (tbl) =>
                                    tbl.planId.equals(widget.planId) &
                                    tbl.exercise.equals(widget.exercise),
                              )
                              ..limit(1))
                            .getSingle();
                        await db.planExercises.deleteOne(old);
                        await db.planExercises.insertOne(
                          PlanExercisesCompanion.insert(
                            enabled: true,
                            exercise: exercise,
                            planId: widget.planId,
                            sequence: drift.Value(old.sequence),
                          ),
                        );

                        if (!context.mounted) return;

                        state.updatePlans(null);
                        Navigator.pop(context, true);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
