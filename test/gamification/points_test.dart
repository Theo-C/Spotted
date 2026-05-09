import 'package:flutter_test/flutter_test.dart';
import 'package:spotted/features/gamification/domain/points.dart';
import 'package:spotted/shared/models/rarity.dart';

void main() {
  group('firstObservationPoints', () {
    test('common = 10', () {
      expect(firstObservationPoints(Rarity.common), 10);
    });
    test('rare = 30', () {
      expect(firstObservationPoints(Rarity.rare), 30);
    });
    test('epic = 100', () {
      expect(firstObservationPoints(Rarity.epic), 100);
    });
    test('legendary = 300', () {
      expect(firstObservationPoints(Rarity.legendary), 300);
    });
  });

  group('reobservationPoints (20% du base, arrondi sup)', () {
    test('common 10 → 2', () {
      expect(reobservationPoints(Rarity.common), 2);
    });
    test('rare 30 → 6', () {
      expect(reobservationPoints(Rarity.rare), 6);
    });
    test('epic 100 → 20', () {
      expect(reobservationPoints(Rarity.epic), 20);
    });
    test('legendary 300 → 60', () {
      expect(reobservationPoints(Rarity.legendary), 60);
    });
  });

  group('withPhotoBonus (+50%)', () {
    test('10 → 15', () => expect(withPhotoBonus(10), 15));
    test('30 → 45', () => expect(withPhotoBonus(30), 45));
    test('100 → 150', () => expect(withPhotoBonus(100), 150));
    test('300 → 450', () => expect(withPhotoBonus(300), 450));
    // Re-obs avec photo
    test('2 → 3', () => expect(withPhotoBonus(2), 3));
    test('6 → 9', () => expect(withPhotoBonus(6), 9));
    test('20 → 30', () => expect(withPhotoBonus(20), 30));
    test('60 → 90', () => expect(withPhotoBonus(60), 90));
  });

  group('observationPoints (combo cases — table CDC §règles métier)', () {
    test('common 1ère sans photo = 10', () {
      expect(
        observationPoints(
          rarity: Rarity.common,
          isFirst: true,
          hasPhoto: false,
        ),
        10,
      );
    });
    test('common 1ère avec photo = 15', () {
      expect(
        observationPoints(
          rarity: Rarity.common,
          isFirst: true,
          hasPhoto: true,
        ),
        15,
      );
    });
    test('common re-obs sans photo = 2', () {
      expect(
        observationPoints(
          rarity: Rarity.common,
          isFirst: false,
          hasPhoto: false,
        ),
        2,
      );
    });
    test('common re-obs avec photo = 3', () {
      expect(
        observationPoints(
          rarity: Rarity.common,
          isFirst: false,
          hasPhoto: true,
        ),
        3,
      );
    });
    test('legendary 1ère avec photo = 450', () {
      expect(
        observationPoints(
          rarity: Rarity.legendary,
          isFirst: true,
          hasPhoto: true,
        ),
        450,
      );
    });
    test('legendary re-obs avec photo = 90', () {
      expect(
        observationPoints(
          rarity: Rarity.legendary,
          isFirst: false,
          hasPhoto: true,
        ),
        90,
      );
    });
  });

  group('retroactivePhotoBonus (delta vs no-photo first obs)', () {
    test('common = 5 (15-10)', () {
      expect(retroactivePhotoBonus(Rarity.common), 5);
    });
    test('rare = 15 (45-30)', () {
      expect(retroactivePhotoBonus(Rarity.rare), 15);
    });
    test('epic = 50 (150-100)', () {
      expect(retroactivePhotoBonus(Rarity.epic), 50);
    });
    test('legendary = 150 (450-300)', () {
      expect(retroactivePhotoBonus(Rarity.legendary), 150);
    });
  });

  group('rarityStars (1 à 4)', () {
    test('common = 1', () => expect(rarityStars(Rarity.common), 1));
    test('rare = 2', () => expect(rarityStars(Rarity.rare), 2));
    test('epic = 3', () => expect(rarityStars(Rarity.epic), 3));
    test('legendary = 4', () => expect(rarityStars(Rarity.legendary), 4));
  });
}
