import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import '../../graph/add_exercise_page.dart';
import '../../main.dart';
import '../bodypart_tag.dart';

class ExercisePickerModal extends StatefulWidget {
  const ExercisePickerModal({super.key});

  @override
  State<ExercisePickerModal> createState() => _ExercisePickerModalState();
}

class _ExercisePickerModalState extends State<ExercisePickerModal> {
  String _search = '';
  List<({String name, String? brandName, String? category, int workoutCount})>
      _allExercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    const workoutCountCol = CustomExpression<int>(
      'COUNT(DISTINCT workout_id)',
    );

    final results = await (db.gymSets.selectOnly()
          ..addColumns([
            db.gymSets.name,
            db.gymSets.brandName,
            db.gymSets.category,
            workoutCountCol,
          ])
          ..orderBy([
            OrderingTerm(expression: workoutCountCol, mode: OrderingMode.desc),
            OrderingTerm(expression: db.gymSets.name),
          ])
          ..groupBy([db.gymSets.name]))
        .get();

    final exerciseList = results
        .map(
          (r) => (
            name: r.read(db.gymSets.name)!,
            brandName: r.read(db.gymSets.brandName),
            category: r.read(db.gymSets.category),
            workoutCount: r.read(workoutCountCol) ?? 0,
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        _allExercises = exerciseList;
        _loading = false;
      });
    }
  }

  List<({String name, String? brandName, String? category, int workoutCount})>
      get _filteredExercises {
    if (_search.isEmpty) return _allExercises;
    return _allExercises
        .where((e) => e.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  Future<void> _showCreateExerciseDialog(BuildContext parentContext) async {
    final result = await Navigator.push<String>(
      parentContext,
      MaterialPageRoute(
        builder: (context) => const AddExercisePage(),
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (parentContext.mounted) {
        Navigator.pop(parentContext, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.95],
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_circle,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Add Exercise',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12,),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              // Create Custom Exercise Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showCreateExerciseDialog(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withValues(alpha: 0.3),
                            colorScheme.secondaryContainer
                                .withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_box,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Create Custom Exercise',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Divider with text
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'RECENT EXERCISES',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Exercise list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredExercises.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No exercises found',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (_search.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  FilledButton.tonal(
                                    onPressed: () =>
                                        Navigator.pop(context, _search),
                                    child: Text('Create "$_search"'),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _filteredExercises.length,
                            itemBuilder: (context, index) {
                              final exercise = _filteredExercises[index];

                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 2,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.fitness_center,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        exercise.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (exercise.category != null &&
                                        exercise.category!.isNotEmpty) ...[
                                      const SizedBox(width: 5),
                                      BodypartTag(
                                          bodypart: exercise.category,
                                          fontSize: 9,),
                                    ],
                                    if (exercise.brandName != null &&
                                        exercise.brandName!.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondaryContainer
                                              .withValues(alpha: 0.7),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          exercise.brandName!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme
                                                .onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: exercise.workoutCount > 0
                                    ? Text(
                                        '${exercise.workoutCount} workout${exercise.workoutCount == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      )
                                    : null,
                                trailing: Icon(
                                  Icons.add_circle_outline,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                onTap: () =>
                                    Navigator.pop(context, exercise.name),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
