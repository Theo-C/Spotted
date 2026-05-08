import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/utils/category_icons.dart';
import '../data/territory_progress_provider.dart';
import '../data/zone_repository.dart';

class TerritoryScreen extends ConsumerWidget {
  const TerritoryScreen({super.key, required this.zoneId});

  final String zoneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoneAsync = ref.watch(_zoneByIdProvider(zoneId));
    final progressAsync = ref.watch(categoriesWithProgressProvider(zoneId));

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BackButton(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: zoneAsync.when(
                  loading: () => const SizedBox(height: 80),
                  error: (e, _) => Text(
                    'Zone introuvable',
                    style: GoogleFonts.karla(color: textMuted),
                  ),
                  data: (zone) => _TerritoryHeader(
                    name: zone.name,
                    shortCode: zone.shortCode ?? '',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: progressAsync.when(
                  loading: () => const _OverallProgressSkeleton(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: _OverallProgress.new,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'CATÉGORIES — 4',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: progressAsync.when(
                  loading: () => const _CategoriesGridSkeleton(),
                  error: (e, _) => Text(
                    'Erreur de chargement',
                    style: GoogleFonts.karla(color: textMuted),
                  ),
                  data: (items) =>
                      _CategoriesGrid(items: items, zoneId: zoneId),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider local — résout une Zone par son UUID.
final _zoneByIdProvider = FutureProvider.family((ref, String id) async {
  return ref.watch(zoneRepositoryProvider).getById(id);
});

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: forestGreen, size: 24),
          label: Text(
            'Retour',
            style: GoogleFonts.karla(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: forestGreen,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }
}

class _TerritoryHeader extends StatelessWidget {
  const _TerritoryHeader({required this.name, required this.shortCode});

  final String name;
  final String shortCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DÉPARTEMENT · $shortCode',
          style: GoogleFonts.karla(
            fontSize: 11,
            letterSpacing: 2.5,
            fontWeight: FontWeight.bold,
            color: terracotta,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 44,
            fontWeight: FontWeight.w600,
            color: forestGreen,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _OverallProgress extends StatelessWidget {
  const _OverallProgress(this.items);

  final List<CategoryProgress> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (acc, e) => acc + e.total);
    final observed = items.fold<int>(0, (acc, e) => acc + e.observed);
    final pct = total == 0 ? 0 : ((observed / total) * 100).round();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: forestGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$observed / $total',
            style: GoogleFonts.karla(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: surfaceBase,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$pct % complété',
          style: GoogleFonts.karla(fontSize: 12, color: textSecondary),
        ),
      ],
    );
  }
}

class _OverallProgressSkeleton extends StatelessWidget {
  const _OverallProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Container(
            width: 60,
            decoration: BoxDecoration(
              color: forestGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({required this.items, required this.zoneId});

  final List<CategoryProgress> items;
  final String zoneId;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: items
          .map((p) => _CategoryTile(progress: p, zoneId: zoneId))
          .toList(),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.progress, required this.zoneId});

  final CategoryProgress progress;
  final String zoneId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.go('/territory/$zoneId/category/${progress.category.id}');
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8E0CE), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emojiForCategory(progress.category.icon),
                    style: const TextStyle(fontSize: 30),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${progress.observed}',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: forestGreen,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/${progress.total}',
                        style: GoogleFonts.karla(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                progress.category.name,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: forestGreen,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE8E0CE),
                  valueColor: const AlwaysStoppedAnimation<Color>(terracotta),
                ),
              ),
              const Spacer(),
              Text(
                '${progress.remaining} À TROUVER',
                style: GoogleFonts.karla(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoriesGridSkeleton extends StatelessWidget {
  const _CategoriesGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: surfaceCard,
            border: Border.all(color: const Color(0xFFE8E0CE), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
