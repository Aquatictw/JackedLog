import 'package:flutter_test/flutter_test.dart';
import 'package:jackedlog/records/records_service.dart';

void main() {
  group('Brzycki 1RM calculation', () {
    test('calculates 1RM correctly for 5 reps', () {
      final result = calculate1RM(225.0, 5.0);
      expect(result, closeTo(253.9, 0.1));
    });

    test('calculates 1RM correctly for 10 reps', () {
      final result = calculate1RM(135.0, 10.0);
      expect(result, closeTo(180.0, 0.1));
    });

    test('returns weight for 1 rep', () {
      final result = calculate1RM(315.0, 1.0);
      expect(result, equals(315.0));
    });

    test('handles 0 reps', () {
      final result = calculate1RM(100.0, 0.0);
      expect(result, equals(0.0));
    });

    test('handles 0 weight', () {
      final result = calculate1RM(0.0, 10.0);
      expect(result, equals(0.0));
    });
  });

  group('Volume calculation', () {
    test('calculates volume correctly', () {
      final result = calculateVolume(225.0, 10.0);
      expect(result, equals(2250.0));
    });

    test('handles zero weight', () {
      final result = calculateVolume(0.0, 10.0);
      expect(result, equals(0.0));
    });

    test('handles zero reps', () {
      final result = calculateVolume(100.0, 0.0);
      expect(result, equals(0.0));
    });

    test('handles fractional reps', () {
      final result = calculateVolume(100.0, 5.5);
      expect(result, equals(550.0));
    });
  });
}
