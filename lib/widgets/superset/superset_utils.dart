import 'package:flutter/material.dart';

/// Generates a superset ID for grouping exercises
String generateSupersetId(int workoutId) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'workout_${workoutId}_ss_$timestamp';
}

/// Gets the superset label (A1, A2, B1, B2, etc.)
String getSupersetLabel(int supersetIndex, int position) {
  const letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
  if (supersetIndex >= letters.length) {
    // Fallback for more than 8 supersets (unlikely)
    return '${String.fromCharCode(65 + supersetIndex)}${position + 1}';
  }
  return '${letters[supersetIndex]}${position + 1}';
}

/// Gets the color for a superset based on its index
Color getSupersetColor(BuildContext context, int supersetIndex) {
  final colorScheme = Theme.of(context).colorScheme;
  final colors = [
    colorScheme.primaryContainer,
    colorScheme.tertiaryContainer,
    colorScheme.secondaryContainer,
    colorScheme.errorContainer.withValues(alpha: 0.7),
  ];
  return colors[supersetIndex % colors.length];
}

/// Gets the text color for a superset label
Color getSupersetTextColor(BuildContext context, int supersetIndex) {
  final colorScheme = Theme.of(context).colorScheme;
  final textColors = [
    colorScheme.onPrimaryContainer,
    colorScheme.onTertiaryContainer,
    colorScheme.onSecondaryContainer,
    colorScheme.onErrorContainer,
  ];
  return textColors[supersetIndex % textColors.length];
}

/// Data class representing a superset group
class SupersetGroup {

  SupersetGroup({
    required this.supersetId,
    required this.index,
    required this.exercises,
  });
  final String supersetId;
  final int index; // 0-based index (A=0, B=1, etc.)
  final List<SupersetExercise> exercises;

  String get label =>
      getSupersetLabel(index, 0)[0]; // Just the letter (A, B, C, etc.)
}

/// Data class representing an exercise within a superset
class SupersetExercise {

  SupersetExercise({
    required this.exerciseName,
    required this.sequence,
    required this.position,
    this.supersetId,
  });
  final String exerciseName;
  final int sequence;
  final int position; // Position within superset (0-based)
  final String? supersetId;

  String getLabel(int supersetIndex) =>
      getSupersetLabel(supersetIndex, position);
}
