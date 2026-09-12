import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../legal/legal_repository.dart';
import '../legal/markdown.dart';
import '../theme/tessa_theme.dart';

/// Impressum, Datenschutz, AGB und Widerruf.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final betreiber = ref.watch(betreiberProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Rechtliches')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (betreiber != null && !betreiber.istAusgefuellt)
            Card(
              key: const Key('legal-warning'),
              color: const Color(0xFF3A2416),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFC44D),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Diese Texte sind Vorlagen und noch nicht ausgefüllt. '
                        'Vor einer Veröffentlichung müssen die Angaben in '
                        'assets/legal/betreiber.json eingetragen und die Texte '
                        'rechtlich geprüft werden.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final doc in LegalDoc.values)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                key: Key('legal-${doc.name}'),
                leading: const Icon(
                  Icons.description_outlined,
                  color: tessaAccent,
                ),
                title: Text(doc.titel),
                subtitle: Text(doc.beschreibung),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LegalTextScreen(doc: doc),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ein einzelner Text.
class LegalTextScreen extends ConsumerWidget {
  const LegalTextScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(legalTextProvider(doc));

    return Scaffold(
      appBar: AppBar(title: Text(doc.titel)),
      body: text.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (fehler, _) => Center(
          key: const Key('legal-error'),
          child: Text('Der Text ließ sich nicht laden.\n$fehler'),
        ),
        data: (inhalt) => ListView(
          key: Key('legal-text-${doc.name}'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: _absaetze(context, inhalt),
        ),
      ),
    );
  }

  /// Stellt die Blöcke aus `markdown.dart` dar.
  List<Widget> _absaetze(BuildContext context, String inhalt) {
    final theme = Theme.of(context);
    final teile = <Widget>[];

    for (final block in parseLegal(inhalt)) {
      switch (block.art) {
        case BlockArt.titel:
          teile.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                block.text,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        case BlockArt.abschnitt:
          teile.add(
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 6),
              child: Text(
                block.text,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        case BlockArt.absatz:
          teile.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                block.text,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          );
        case BlockArt.punkte:
        case BlockArt.schritte:
          for (var i = 0; i < block.zeilen.length; i++) {
            teile.add(
              _eintrag(
                theme,
                block.art == BlockArt.punkte ? '\u2022' : '${i + 1}.',
                block.zeilen[i],
              ),
            );
          }
      }
    }
    return teile;
  }

  /// Ein Listeneintrag: Zeichen links, Text daneben — damit Folgezeilen
  /// eingerückt bleiben.
  Widget _eintrag(ThemeData theme, String zeichen, String text) {
    final stil = theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Text(zeichen, style: stil)),
          Expanded(child: Text(text, style: stil)),
        ],
      ),
    );
  }
}
