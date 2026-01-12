class StrengthData {

  StrengthData({
    required this.created,
    required this.reps,
    required this.unit,
    required this.value,
    required this.weight, this.category,
    this.workoutId,
  });
  final DateTime created;
  final double reps;
  final String unit;
  final double value;
  final String? category;
  final int? workoutId;
  final double weight;
}
