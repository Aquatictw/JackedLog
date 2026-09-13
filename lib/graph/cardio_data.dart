class CardioData {
  CardioData({
    required this.created,
    required this.value,
    required this.unit,
    this.workoutId,
    this.activityId,
  });
  final DateTime created;
  final double value;
  final String unit;
  final int? workoutId;
  final String? activityId;
}
