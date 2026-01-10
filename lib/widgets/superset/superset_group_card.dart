import 'package:flutter/material.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/widgets/superset/superset_badge.dart';
import 'package:jackedlog/widgets/superset/superset_utils.dart';

/// A card that displays a group of exercises in a superset with visual connections
class SupersetGroupCard extends StatelessWidget {
  final List<({String name, List<GymSet> sets})> exercises;
  final int supersetIndex; // 0-based (A=0, B=1, etc.)
  final bool showImages;
  final Function(GymSet) onSetTap;

  const SupersetGroupCard({
    super.key,
    required this.exercises,
    required this.supersetIndex,
    required this.showImages,
    required this.onSetTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final supersetColor = getSupersetColor(context, supersetIndex);
    final textColor = getSupersetTextColor(context, supersetIndex);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: supersetColor.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: supersetColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              supersetColor.withValues(alpha: 0.05),
              colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Superset header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: supersetColor.withValues(alpha: 0.15),
                border: Border(
                  bottom: BorderSide(
                    color: supersetColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          supersetColor,
                          supersetColor.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: supersetColor.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.link,
                      color: textColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Superset ${getSupersetLabel(supersetIndex, 0)[0]}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor.withValues(alpha: 0.9),
                              ),
                        ),
                        Text(
                          '${exercises.length} exercises',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Position indicators
                  Row(
                    children: List.generate(exercises.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: supersetColor.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: supersetColor,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // Exercises
            ...exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              final isLast = index == exercises.length - 1;

              return _buildExerciseRow(
                context,
                exercise.name,
                exercise.sets,
                index,
                isLast,
                supersetColor,
                textColor,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseRow(
    BuildContext context,
    String exerciseName,
    List<GymSet> sets,
    int position,
    bool isLast,
    Color supersetColor,
    Color textColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left connector bracket
          SizedBox(
            width: 24,
            child: CustomPaint(
              painter: _SupersetConnectorPainter(
                color: supersetColor,
                isFirst: position == 0,
                isLast: isLast,
              ),
            ),
          ),

          // Exercise content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise header with badge
                  Row(
                    children: [
                      SupersetBadge(
                        supersetIndex: supersetIndex,
                        position: position,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          exerciseName,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sets summary
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: sets.map((set) {
                      return InkWell(
                        onTap: () => onSetTap(set),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: supersetColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${set.weight.toStringAsFixed(set.weight.truncateToDouble() == set.weight ? 0 : 1)}${set.unit} x ${set.reps.toInt()}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the superset connector bracket
class _SupersetConnectorPainter extends CustomPainter {
  final Color color;
  final bool isFirst;
  final bool isLast;

  _SupersetConnectorPainter({
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerX = size.width / 2;
    final radius = 8.0;

    if (isFirst && isLast) {
      // Single exercise - just a circle
      canvas.drawCircle(
        Offset(centerX, size.height / 2),
        4,
        paint..style = PaintingStyle.fill,
      );
    } else if (isFirst) {
      // First exercise - top curve
      path.moveTo(centerX, size.height);
      path.lineTo(centerX, size.height / 2);
      path.quadraticBezierTo(
        centerX,
        radius,
        centerX + radius,
        radius,
      );
    } else if (isLast) {
      // Last exercise - bottom curve
      path.moveTo(centerX, 0);
      path.lineTo(centerX, size.height / 2);
      path.quadraticBezierTo(
        centerX,
        size.height - radius,
        centerX + radius,
        size.height - radius,
      );
    } else {
      // Middle exercise - straight line
      path.moveTo(centerX, 0);
      path.lineTo(centerX, size.height);
    }

    canvas.drawPath(path, paint);

    // Draw connection point
    canvas.drawCircle(
      Offset(centerX, size.height / 2),
      4,
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
