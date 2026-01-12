import 'package:fl_chart/fl_chart.dart';
import '../database/database.dart';

/// Calculates a moving average over a specified window of days.
///
/// Returns a list of FlSpot points representing the moving average.
/// Uses a trailing window approach based on calendar days, not entry count.
///
/// For each entry, calculates the average of all entries within the past
/// [windowDays] days (including the current entry).
List<FlSpot> calculateMovingAverage(
  List<BodyweightEntry> entries,
  int windowDays,
) {
  if (entries.isEmpty) return [];

  // Ensure entries are sorted by date ascending
  final sorted = entries.toList()..sort((a, b) => a.date.compareTo(b.date));

  final List<FlSpot> result = [];

  // For each point in the dataset
  for (int i = 0; i < sorted.length; i++) {
    final currentDate = sorted[i].date;

    // Define the window: current date and (windowDays-1) days before
    final windowStart = currentDate.subtract(Duration(days: windowDays - 1));

    // Get all entries within the window
    final windowEntries = sorted.where((entry) {
      return !entry.date.isBefore(windowStart) &&
          !entry.date.isAfter(currentDate);
    }).toList();

    // Calculate average if we have at least one entry (the current one)
    if (windowEntries.isNotEmpty) {
      final sum = windowEntries.fold<double>(
        0,
        (sum, entry) => sum + entry.weight,
      );
      final average = sum / windowEntries.length;

      result.add(FlSpot(i.toDouble(), average));
    }
  }

  return result;
}

/// Calculates the arithmetic mean of all bodyweight entries.
///
/// Returns null if the list is empty.
double? calculateAverageWeight(List<BodyweightEntry> entries) {
  if (entries.isEmpty) return null;

  final sum = entries.fold<double>(
    0,
    (sum, entry) => sum + entry.weight,
  );

  return sum / entries.length;
}

/// Calculates the weight change from the first to the last entry.
///
/// Returns null if there are fewer than 2 entries.
/// Positive values indicate weight gain, negative values indicate weight loss.
double? calculateWeightChange(List<BodyweightEntry> entries) {
  if (entries.length < 2) return null;

  // Ensure entries are sorted by date
  final sorted = entries.toList()..sort((a, b) => a.date.compareTo(b.date));

  return sorted.last.weight - sorted.first.weight;
}

/// Finds the minimum weight in the list of entries.
///
/// Returns null if the list is empty.
double? calculateMinWeight(List<BodyweightEntry> entries) {
  if (entries.isEmpty) return null;

  return entries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
}

/// Finds the maximum weight in the list of entries.
///
/// Returns null if the list is empty.
double? calculateMaxWeight(List<BodyweightEntry> entries) {
  if (entries.isEmpty) return null;

  return entries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
}
