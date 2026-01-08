import 'package:jackedlog/records/records_service.dart';

class SetData {
  double weight;
  int reps;
  bool completed;
  int? savedSetId;
  bool isWarmup;
  bool isDropSet;
  Set<RecordType> records;

  SetData({
    required this.weight,
    required this.reps,
    this.completed = false,
    this.savedSetId,
    this.isWarmup = false,
    this.isDropSet = false,
    Set<RecordType>? records,
  }) : records = records ?? {};
}
