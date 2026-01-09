import 'package:flutter/material.dart';
import 'package:jackedlog/widgets/superset/superset_utils.dart';

/// A badge that displays superset label (A1, A2, B1, B2, etc.)
class SupersetBadge extends StatelessWidget {
  final int supersetIndex; // 0-based (A=0, B=1, etc.)
  final int position; // 0-based position within superset
  final bool isCompact; // Compact mode for smaller displays

  const SupersetBadge({
    super.key,
    required this.supersetIndex,
    required this.position,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = getSupersetLabel(supersetIndex, position);
    final backgroundColor = getSupersetColor(context, supersetIndex);
    final textColor = getSupersetTextColor(context, supersetIndex);

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor,
            backgroundColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A horizontal indicator bar showing all exercises in a superset
class SupersetIndicator extends StatelessWidget {
  final int supersetIndex;
  final int totalExercises;
  final int currentPosition; // 0-based

  const SupersetIndicator({
    super.key,
    required this.supersetIndex,
    required this.totalExercises,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = getSupersetColor(context, supersetIndex);
    final textColor = getSupersetTextColor(context, supersetIndex);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.15),
        border: Border.all(
          color: backgroundColor.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Superset ${getSupersetLabel(supersetIndex, 0)[0]}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          ...List.generate(totalExercises, (index) {
            final isActive = index == currentPosition;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: isActive ? 8 : 6,
                height: isActive ? 8 : 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? backgroundColor
                      : backgroundColor.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
