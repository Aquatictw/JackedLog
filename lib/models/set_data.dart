import '../records/records_service.dart';

class SetData {

  SetData({
    required this.weight,
    required this.reps,
    this.completed = false,
    this.savedSetId,
    this.isWarmup = false,
    this.isDropSet = false,
    Set<RecordType>? records,
  }) : records = records ?? {};
  double weight;
  int reps;
  bool completed;
  int? savedSetId;
  bool isWarmup;
  bool isDropSet;
  Set<RecordType> records;
}
