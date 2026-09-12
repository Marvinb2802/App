import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/ui/legal/legal_repository.dart';
import 'package:tessa/ui/screens/legal_screen.dart';
import 'package:tessa/ui/theme/tessa_theme.dart';

import '../support/fake_sound.dart';
import '../support/legal_vorlagen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLegal(
    WidgetTester tester, {
    required LegalRepository repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
          legalRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(theme: tessaTheme(), home: const LegalScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('listet alle vier Texte auf', (tester) async {
    await pumpLegal(tester, repository: VorlagenRepo());

    for (final doc in LegalDoc.values) {
      expect(
        find.byKey(Key('legal-${doc.name}')),
        findsOneWidget,
        reason: 'Eintrag fuer ${doc.titel} fehlt',
      );
      expect(find.text(doc.titel), findsOneWidget);
    }
  });

  testWidgets('warnt, solange die Angaben Platzhalter enthalten', (
    tester,
  ) async {
    // Die ausgelieferte betreiber.json ist bis zur Veroeffentlichung Vorlage.
    await pumpLegal(tester, repository: VorlagenRepo());

    expect(find.byKey(const Key('legal-warning')), findsOneWidget);
  });

  testWidgets('warnt nicht mehr, sobald die Angaben stehen', (tester) async {
    await pumpLegal(
      tester,
      repository: VorlagenRepo(angaben: ausgefuellterBetreiber),
    );

    expect(find.byKey(const Key('legal-warning')), findsNothing);
  });

  testWidgets('oeffnet jeden Text und zeigt ihn ohne Platzhalter an', (
    tester,
  ) async {
    await pumpLegal(
      tester,
      repository: VorlagenRepo(angaben: ausgefuellterBetreiber),
    );

    for (final doc in LegalDoc.values) {
      await tester.tap(find.byKey(Key('legal-${doc.name}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('legal-text-${doc.name}')),
        findsOneWidget,
        reason: '${doc.titel} liess sich nicht oeffnen',
      );
      expect(find.byKey(const Key('legal-error')), findsNothing);

      final texte = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join('\n');
      // Weder Platzhalter noch Markdown-Zeichen duerfen sichtbar werden.
      expect(
        texte,
        isNot(contains('{{')),
        reason: '${doc.titel} zeigt einen nicht ersetzten Platzhalter',
      );
      expect(
        texte,
        isNot(contains('**')),
        reason: '${doc.titel} zeigt Sternchen aus dem Quelltext',
      );
      expect(
        texte,
        contains('Marvin B'),
        reason: '${doc.titel} nennt den Anbieter nicht',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('zeigt eine Meldung, wenn ein Text fehlt', (tester) async {
    await pumpLegal(tester, repository: _KaputtesRepo());
    await tester.tap(find.byKey(const Key('legal-impressum')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('legal-error')), findsOneWidget);
  });

  test('jeder Text nennt seinen Kernsatz', () async {
    const pflicht = {
      LegalDoc.impressum: 'DDG',
      LegalDoc.datenschutz: 'nur auf deinem Gerät',
      LegalDoc.agb: 'Sterne',
      LegalDoc.widerruf: 'vierzehn Tagen',
    };

    final repo = VorlagenRepo(angaben: ausgefuellterBetreiber);
    for (final eintrag in pflicht.entries) {
      expect(
        await repo.text(eintrag.key),
        contains(eintrag.value),
        reason: '${eintrag.key.titel} fehlt der Kernsatz',
      );
    }
  });

  test('die Vorlagen kennen nur Platzhalter, die eingesetzt werden', () {
    final bekannt = ausgefuellterBetreiber.platzhalter.keys.toSet();

    for (final doc in LegalDoc.values) {
      final roh = VorlagenRepo.lies(doc.datei);
      for (final treffer in RegExp(r'\{\{(\w+)\}\}').allMatches(roh)) {
        expect(
          bekannt,
          contains(treffer.group(1)),
          reason:
              '${doc.titel} nutzt einen unbekannten Platzhalter '
              '${treffer.group(0)}',
        );
      }
    }
  });
}

/// Ein Speicher, bei dem das Laden schiefgeht.
class _KaputtesRepo implements LegalRepository {
  @override
  Future<Betreiber> betreiber() async => ausgefuellterBetreiber;

  @override
  Future<String> text(LegalDoc doc) async => throw StateError('kein Anhang');
}
