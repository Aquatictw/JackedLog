import '../database/database.dart';

double cardioUnitMeters(String unit) => unit == 'mi' ? 1609.344 : 1000;
String cardioDisplayUnit(String unit) => unit == 'mi' ? 'mi' : 'km';

DateTime activityDisplayDate(CardioActivity activity) {
  if (activity.startedAt == null) return activity.recordedAt.toUtc();
  final offset = activity.startUtcOffsetMinutes;
  return offset == null ? activity.startedAt!.toLocal()
      : activity.startedAt!.toUtc().add(Duration(minutes: offset));
}

String activityDateLabel(CardioActivity activity) {
  if (activity.startedAt == null) return 'Recording date (UTC) · start time unknown';
  final offset = activity.startUtcOffsetMinutes;
  if (offset == null) return 'Start time · device time zone';
  final hours = (offset.abs() ~/ 60).toString().padLeft(2, '0');
  final minutes = (offset.abs() % 60).toString().padLeft(2, '0');
  return 'Start time · UTC${offset < 0 ? '-' : '+'}$hours:$minutes';
}

String activityPace(CardioActivity activity, String unit) {
  final distance = activity.distanceMeters;
  final duration = activity.durationSeconds;
  if (!['elapsed', 'timer', 'moving'].contains(activity.durationBasis)) {
    return 'Pace unavailable: time basis unknown';
  }
  if (distance == null || distance <= 0 || duration == null || duration <= 0) {
    return 'Pace unavailable: distance and duration required';
  }
  if (activity.sport == 'cycle') {
    return '${(distance / cardioUnitMeters(unit) * 3600 / duration).toStringAsFixed(1)} ${cardioDisplayUnit(unit)}/h';
  }
  if (!['run', 'walk'].contains(activity.sport)) {
    return 'Pace unavailable: sport unclassified';
  }
  final seconds = (duration / distance * cardioUnitMeters(unit)).round();
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min/${cardioDisplayUnit(unit)}';
}

String activitySummary(CardioActivity activity, String unit) => [
      if (activity.distanceMeters != null)
        '${(activity.distanceMeters! / cardioUnitMeters(unit)).toStringAsFixed(2)} ${cardioDisplayUnit(unit)}'
      else
        'Distance unavailable',
      if (activity.durationSeconds != null)
        '${(activity.durationSeconds! / 60).toStringAsFixed(1)} min'
      else
        'Duration unavailable',
    ].join(' · ');
