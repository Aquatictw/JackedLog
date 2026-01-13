import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/database/gym_sets.dart';
import 'package:jackedlog/database/workouts.dart';
import 'package:jackedlog/spotify/spotify_service.dart';
import 'package:jackedlog/spotify/spotify_web_api_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Mock annotations for code generation
@GenerateMocks([SpotifyService, SpotifyWebApiService])
void main() {}

/// Create in-memory database for testing
Future<AppDatabase> createTestDatabase() async {
  // Use in-memory database that gets cleaned up automatically
  return AppDatabase(NativeDatabase.memory());
}

/// Create test GymSet with sensible defaults
GymSetsCompanion createTestSet({
  int? workoutId,
  String name = 'Test Exercise',
  double weight = 100.0,
  double reps = 10.0,
  int sequence = 0,
  int? setOrder,
  bool warmup = false,
  bool dropSet = false,
  bool cardio = false,
  String? notes,
  String unit = 'kg',
}) {
  return GymSetsCompanion.insert(
    name: name,
    reps: reps,
    weight: weight,
    unit: unit,
    created: DateTime.now(),
    cardio: cardio,
    warmup: Value(warmup),
    dropSet: Value(dropSet),
    sequence: Value(sequence),
    setOrder: Value(setOrder),
    workoutId: Value(workoutId),
    notes: Value(notes),
    hidden: const Value(false),
  );
}

/// CSV fixtures for backward compatibility testing
const csvV59Format = '''id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,planId,workoutId,sequence,setOrder,image,category,notes,warmup,dropSet,exerciseType,brandName
1,Bench Press,10,225.0,kg,2026-01-13 10:00:00,0,,,,120000,0,,,0,0,,,Test notes,0,0,,''';

const csvV58Format = '''id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,planId,workoutId,sequence,setorder,image,category,notes,warmup,dropSet,exerciseType,brandName
1,Bench Press,10,225.0,kg,2026-01-13 10:00:00,0,,,,120000,0,,,0,0,,,Test notes,0,0,,''';

const csvV57Format = '''id,name,reps,weight,unit,created,cardio,duration,distance,incline,restMs,hidden,planId,workoutId,sequence,image,category,notes,warmup,dropSet,exerciseType,brandName
1,Bench Press,10,225.0,kg,2026-01-13 10:00:00,0,,,,120000,0,,,0,,,Test notes,0,0,,''';

/// Edge case test data
const unicodeExerciseName = '벤치프레스 💪';
const specialCharsNote = '''Test "quotes" & <brackets>
with newlines''';
