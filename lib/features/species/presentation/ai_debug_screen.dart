import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../data/species_identification_service.dart';

/// Écran de debug du dernier appel d'identification IA — utile pour comprendre
/// pourquoi le modèle propose une espèce inattendue. Affiche le prompt user,
/// la réponse brute, et le système prompt. Tout est copiable au presse-papier
/// pour aller demander une analyse à Claude dans une autre conversation.
class AiDebugScreen extends ConsumerWidget {
  const AiDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(lastAiCallProvider);

    return Scaffold(
      backgroundColor: surfaceBase,
      appBar: AppBar(
        title: Text(
          'Diagnostic IA',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: forestGreen,
          ),
        ),
        actions: [
          if (snapshot != null)
            IconButton(
              tooltip: 'Tout copier',
              icon: const Icon(Icons.copy_all, color: forestGreen),
              onPressed: () => _copyAll(context, snapshot),
            ),
        ],
      ),
      body: snapshot == null
          ? _empty()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Meta(snapshot: snapshot),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Prompt utilisateur',
                    body: snapshot.userPrompt,
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Réponse brute du modèle',
                    body: snapshot.rawResponse.isEmpty
                        ? '(vide)'
                        : snapshot.rawResponse,
                    error: snapshot.error,
                  ),
                  if (snapshot.parsed != null) ...[
                    const SizedBox(height: 14),
                    _ParsedBlock(parsed: snapshot.parsed!),
                  ],
                  const SizedBox(height: 14),
                  _Section(
                    title: 'System prompt (statique)',
                    body: SpeciesIdentificationService.systemPrompt,
                    collapsed: true,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            "Aucun appel IA dans cette session.\nDéclenche une identification depuis une nouvelle obs, puis reviens ici.",
            textAlign: TextAlign.center,
            style: GoogleFonts.karla(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: textMuted,
            ),
          ),
        ),
      );

  Future<void> _copyAll(BuildContext context, AiCallSnapshot s) async {
    final buf = StringBuffer()
      ..writeln('=== Spotted IA — Diagnostic ===')
      ..writeln('Timestamp : ${s.timestamp.toIso8601String()}')
      ..writeln('Modèle    : ${s.model}')
      ..writeln('Durée     : ${s.durationMs} ms')
      ..writeln('Erreur    : ${s.error ?? "(aucune)"}')
      ..writeln()
      ..writeln('--- USER PROMPT ---')
      ..writeln(s.userPrompt)
      ..writeln()
      ..writeln('--- RAW RESPONSE ---')
      ..writeln(s.rawResponse)
      ..writeln()
      ..writeln('--- PARSED ---');
    final parsed = s.parsed;
    if (parsed == null) {
      buf.writeln('(rien parsé)');
    } else {
      buf
        ..writeln('detected : ${parsed.detected}')
        ..writeln('rationale: ${parsed.rationale}');
      for (var i = 0; i < parsed.candidates.length; i++) {
        final c = parsed.candidates[i];
        buf.writeln(
          '${i + 1}. ${c.commonName} (${c.scientificName}) · '
          '${c.categoryKey}/${c.rarityKey} · conf=${c.confidence.toStringAsFixed(2)}',
        );
      }
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: forestGreen,
        content: Text(
          'Diagnostic copié dans le presse-papier',
          style: GoogleFonts.karla(color: surfaceBase),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.snapshot});
  final AiCallSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ts = DateFormat('d MMM HH:mm:ss', 'fr').format(snapshot.timestamp);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metaRow('Quand', ts),
          _metaRow('Modèle', snapshot.model),
          _metaRow('Durée', '${snapshot.durationMs} ms'),
          if (snapshot.error != null)
            _metaRow('Erreur', snapshot.error!, color: terracotta),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: GoogleFonts.karla(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.karla(
                fontSize: 12,
                color: color ?? textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.body,
    this.error,
    this.collapsed = false,
  });

  final String title;
  final String body;
  final String? error;

  /// Si true, démarre replié (long system prompt → on évite le mur de texte).
  final bool collapsed;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = !widget.collapsed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.error != null
              ? terracotta.withValues(alpha: 0.5)
              : const Color(0xFFE8E0CE),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                    color: textSecondary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: forestGreen),
                tooltip: 'Copier',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: widget.body));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: forestGreen,
                      duration: const Duration(seconds: 1),
                      content: Text(
                        '${widget.title} copié',
                        style: GoogleFonts.karla(color: surfaceBase),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: forestGreen,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            SelectableText(
              widget.body,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParsedBlock extends StatelessWidget {
  const _ParsedBlock({required this.parsed});
  final dynamic parsed; // SpeciesIdentification

  @override
  Widget build(BuildContext context) {
    final candidates = parsed.candidates as List;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E0CE), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CANDIDATS PARSÉS',
            style: GoogleFonts.karla(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'detected : ${parsed.detected}',
            style: GoogleFonts.karla(fontSize: 12, color: textPrimary),
          ),
          if ((parsed.rationale as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'rationale : ${parsed.rationale}',
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < candidates.length; i++) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ${candidates[i].commonName}',
                    style: GoogleFonts.karla(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: forestGreen,
                    ),
                  ),
                  Text(
                    '${candidates[i].scientificName} · '
                    '${candidates[i].categoryKey}/${candidates[i].rarityKey} · '
                    'conf=${(candidates[i].confidence as double).toStringAsFixed(2)}',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
