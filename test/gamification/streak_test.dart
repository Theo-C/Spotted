import 'package:flutter_test/flutter_test.dart';
import 'package:spotted/features/gamification/domain/streak.dart';
import 'package:spotted/shared/models/observation.dart';

/// Helper : construit une obs avec une date donnée (autres champs bidons).
Observation _obsAt(DateTime when) => Observation(
      id: 'fake-${when.millisecondsSinceEpoch}',
      userId: 'u1',
      speciesId: 'sp1',
      observedAt: when,
      latitude: 0,
      longitude: 0,
      isFirstForUser: true,
      pointsEarned: 0,
      createdAt: when,
    );

void main() {
  // On fige "aujourd'hui" à un timestamp choisi pour des tests déterministes.
  final today = DateTime(2026, 5, 12);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  group('computeStreak — cas de base', () {
    test('aucune obs → série vide', () {
      final s = computeStreak([], now: today);
      expect(s.current, 0);
      expect(s.longest, 0);
      expect(s.isActiveToday, false);
      expect(s.isInGrace, false);
    });

    test('1 obs aujourd\'hui → série 1, active', () {
      final s = computeStreak([_obsAt(today)], now: today);
      expect(s.current, 1);
      expect(s.longest, 1);
      expect(s.isActiveToday, true);
      expect(s.isInGrace, false);
    });

    test('1 obs hier → série 1, in grace (tolérance 1 jour)', () {
      final s = computeStreak([_obsAt(daysAgo(1))], now: today);
      expect(s.current, 1);
      expect(s.isActiveToday, false);
      expect(s.isInGrace, true);
    });

    test('1 obs avant-hier → série en pause (rattrapable aujourd\'hui)', () {
      // J-2 : la série n'est pas encore perdue, l'user peut la rattraper en
      // observant aujourd'hui (gap 2 toléré dans le comptage interne).
      final s = computeStreak([_obsAt(daysAgo(2))], now: today);
      expect(s.current, 1);
      expect(s.isPaused, true);
      expect(s.isInGrace, false);
      expect(s.isActiveToday, false);
      // Multiplicateur reset à 1.0 pendant la pause (1 jour de grâce strict,
      // pas 2) — l'user doit obs aujourd'hui pour le récupérer.
      expect(s.xpMultiplier, 1.0);
    });

    test('1 obs il y a 3 jours → série vraiment rompue (gap 3 = trop)', () {
      // J-3 : plus rattrapable, le gap dépasse la tolérance de chaîne.
      final s = computeStreak([_obsAt(daysAgo(3))], now: today);
      expect(s.current, 0);
      expect(s.isPaused, false);
      expect(s.isInGrace, false);
      expect(s.isActiveToday, false);
    });
  });

  group('computeStreak — séries multi-jours', () {
    test('3 jours consécutifs (J-2, J-1, J) → série 3 active', () {
      final s = computeStreak([
        _obsAt(daysAgo(2)),
        _obsAt(daysAgo(1)),
        _obsAt(today),
      ], now: today);
      expect(s.current, 3);
      expect(s.isActiveToday, true);
    });

    test('Gap toléré dans la série : J-3, J-1, J → série 3 (J-2 sauté)', () {
      final s = computeStreak([
        _obsAt(daysAgo(3)),
        _obsAt(daysAgo(1)),
        _obsAt(today),
      ], now: today);
      // Gap J-3 → J-1 = 2 jours = toléré (1 jour de grâce)
      expect(s.current, 3);
    });

    test('Gap > 1 jour rompt la série historique', () {
      final s = computeStreak([
        _obsAt(daysAgo(10)),
        _obsAt(daysAgo(9)),
        _obsAt(daysAgo(3)), // ← gap de 6 jours, casse
        _obsAt(daysAgo(2)),
        _obsAt(daysAgo(1)),
        _obsAt(today),
      ], now: today);
      expect(s.current, 4); // J-3 à J, série actuelle
      // longest historique = max(2, 4) = 4
      expect(s.longest, 4);
    });

    test('Plusieurs obs le même jour ne comptent qu\'1 jour', () {
      final s = computeStreak([
        _obsAt(today.add(const Duration(hours: 1))),
        _obsAt(today.add(const Duration(hours: 5))),
        _obsAt(today.add(const Duration(hours: 18))),
      ], now: today);
      expect(s.current, 1);
    });
  });

  group('Streak.xpMultiplier — paliers', () {
    test('< 7 jours → 1.0 (pas de bonus)', () {
      const s = Streak(
          current: 6,
          longest: 6,
          isActiveToday: true,
          isInGrace: false);
      expect(s.xpMultiplier, 1.0);
    });

    test('7 ≤ < 30 → 1.10 (+10%)', () {
      const s = Streak(
          current: 7,
          longest: 7,
          isActiveToday: true,
          isInGrace: false);
      expect(s.xpMultiplier, 1.10);
    });

    test('30 ≤ < 100 → 1.25 (+25%)', () {
      const s = Streak(
          current: 30,
          longest: 30,
          isActiveToday: true,
          isInGrace: false);
      expect(s.xpMultiplier, 1.25);
    });

    test('≥ 100 → 1.5 (+50%, cap)', () {
      const s = Streak(
          current: 200,
          longest: 200,
          isActiveToday: true,
          isInGrace: false);
      expect(s.xpMultiplier, 1.5);
    });
  });

  group('Streak.nextThreshold + daysToNextThreshold', () {
    test('3 jours → next = 7, daysTo = 4', () {
      const s = Streak(
          current: 3,
          longest: 3,
          isActiveToday: true,
          isInGrace: false);
      expect(s.nextThreshold, 7);
      expect(s.daysToNextThreshold, 4);
    });

    test('30 jours → next = 100, daysTo = 70', () {
      const s = Streak(
          current: 30,
          longest: 30,
          isActiveToday: true,
          isInGrace: false);
      expect(s.nextThreshold, 100);
      expect(s.daysToNextThreshold, 70);
    });

    test('400 jours → next = null (cap atteint)', () {
      const s = Streak(
          current: 400,
          longest: 400,
          isActiveToday: true,
          isInGrace: false);
      expect(s.nextThreshold, null);
      expect(s.daysToNextThreshold, null);
    });
  });
}
