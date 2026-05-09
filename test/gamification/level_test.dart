import 'package:flutter_test/flutter_test.dart';
import 'package:spotted/features/gamification/domain/level.dart';

void main() {
  group('levelFromPoints (formule 1 + floor(sqrt(pts/100)))', () {
    test('0 pts → niv 1', () => expect(levelFromPoints(0), 1));
    test('-10 pts → niv 1 (clamp)', () => expect(levelFromPoints(-10), 1));
    test('99 pts → niv 1', () => expect(levelFromPoints(99), 1));
    test('100 pts → niv 2', () => expect(levelFromPoints(100), 2));
    test('250 pts → niv 2', () => expect(levelFromPoints(250), 2));
    test('399 pts → niv 2', () => expect(levelFromPoints(399), 2));
    test('400 pts → niv 3', () => expect(levelFromPoints(400), 3));
    test('1599 pts → niv 4', () => expect(levelFromPoints(1599), 4));
    test('1600 pts → niv 5', () => expect(levelFromPoints(1600), 5));
    test('4900 pts → niv 8', () => expect(levelFromPoints(4900), 8));
  });

  group('thresholdForLevel (seuil pour atteindre N)', () {
    test('niv 1 → 0', () => expect(thresholdForLevel(1), 0));
    test('niv 2 → 100', () => expect(thresholdForLevel(2), 100));
    test('niv 3 → 400', () => expect(thresholdForLevel(3), 400));
    test('niv 5 → 1600', () => expect(thresholdForLevel(5), 1600));
    test('niv 8 → 4900', () => expect(thresholdForLevel(8), 4900));
  });

  group('computeLevel — état complet', () {
    test('0 pts : niv 1, span 0..100, fraction 0', () {
      final info = computeLevel(0);
      expect(info.value, 1);
      expect(info.currentThreshold, 0);
      expect(info.nextThreshold, 100);
      expect(info.pointsToNext, 100);
      expect(info.progressFraction, 0);
    });

    test('100 pts : niv 2, span 100..400, fraction 0', () {
      final info = computeLevel(100);
      expect(info.value, 2);
      expect(info.currentThreshold, 100);
      expect(info.nextThreshold, 400);
      expect(info.pointsToNext, 300);
      expect(info.progressFraction, 0);
    });

    test('250 pts : niv 2, fraction = 50% (au milieu de 100..400)', () {
      final info = computeLevel(250);
      expect(info.value, 2);
      expect(info.progressFraction, closeTo(0.5, 0.001));
      expect(info.pointsToNext, 150);
    });

    test('399 pts : niv 2, fraction proche de 1', () {
      final info = computeLevel(399);
      expect(info.value, 2);
      expect(info.progressFraction, closeTo(0.99666, 0.001));
      expect(info.pointsToNext, 1);
    });
  });
}
