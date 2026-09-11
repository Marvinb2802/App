import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/cell.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/ui/theme/tessa_theme.dart';
import 'package:tessa/ui/widgets/clear_effects.dart';

import '../support/spiel_harness.dart';

final _dot = PieceCatalog.byId('dot');
final _line2v = PieceCatalog.byId('line2v');

MoveOutcome _zug({
  List<int> reihen = const [],
  List<int> spalten = const [],
  int combo = 1,
  int punkte = 100,
}) =>
    MoveOutcome(
      placedCells: const [Cell(7, 7)],
      clearedRows: reihen,
      clearedColumns: spalten,
      appliedCombo: combo,
      points: punkte,
    );

List<Funke> _funken(MoveOutcome move, {int seed = 1}) => funkenFuer(
      move,
      cellSize: 40,
      farben: piecePalettes['standard']!,
      seed: seed,
    );

/// Brett, bei dem in den beiden untersten Reihen je ein Feld fehlt — beide
/// Luecken liegen in derselben Spalte.
Board _zweiReihenFast() => Board.fromRows(const [
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '#######.',
      '#######.',
    ]);

Board _eineReiheFast() => Board.fromRows(const [
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '#######.',
    ]);

/// Der groesste Ausschlag des Ruettlers waehrend [dauer].
Future<double> _maxAusschlag(WidgetTester tester, Duration dauer) async {
  var groesster = 0.0;
  for (var ms = 0; ms < dauer.inMilliseconds; ms += 20) {
    await tester.pump(const Duration(milliseconds: 20));
    final transform =
        tester.widget<Transform>(find.byKey(const Key('screen-shake')));
    final verschiebung = transform.transform.getTranslation();
    groesster = math.max(
      groesster,
      math.sqrt(verschiebung.x * verschiebung.x +
          verschiebung.y * verschiebung.y),
    );
  }
  return groesster;
}

void main() {
  group('Das Wort zur Aufloesung', () {
    test('waechst mit der Zahl der Linien', () {
      expect(raeumWort(0), '');
      expect(raeumWort(1), 'GUT');
      expect(raeumWort(2), 'DOPPEL');
      expect(raeumWort(3), 'DREIFACH');
      expect(raeumWort(4), 'VIERFACH');
      expect(raeumWort(7), 'UNFASSBAR');
    });
  });

  group('Wie stark es ruettelt', () {
    test('nimmt mit jeder Linie zu und bleibt im Rahmen', () {
      expect(ruettelWeite(0), 0);
      var vorher = 0.0;
      for (var linien = 1; linien <= 4; linien++) {
        final jetzt = ruettelWeite(linien);
        expect(jetzt, greaterThan(vorher), reason: '$linien Linien');
        vorher = jetzt;
      }
      expect(ruettelWeite(8), lessThanOrEqualTo(20),
          reason: 'ein Schlag, kein Erdbeben');
    });
  });

  group('Funken', () {
    test('fliegen nur, wenn wirklich etwas gefallen ist', () {
      expect(_funken(_zug()), isEmpty);
    });

    test('werden mehr, je mehr Linien fallen', () {
      final eine = _funken(_zug(reihen: [7])).length;
      final zwei = _funken(_zug(reihen: [6, 7])).length;
      expect(eine, greaterThan(0));
      expect(zwei, greaterThan(eine));
    });

    test('bleiben auch bei vier Linien unter dem Deckel', () {
      final viele = _funken(_zug(reihen: [0, 7], spalten: [0, 7]));
      expect(viele.length, lessThanOrEqualTo(maxFunken));
      expect(viele.length, greaterThan(50), reason: 'aber es soll knallen');
    });

    test('starten auf dem Brett', () {
      const seite = 40.0 * Board.size;
      for (final funke in _funken(_zug(reihen: [3]))) {
        expect(funke.start.dx, inInclusiveRange(0, seite));
        expect(funke.start.dy, inInclusiveRange(0, seite));
      }
    });

    test('sehen bei gleichem Spielcode gleich aus', () {
      final a = _funken(_zug(reihen: [7]), seed: 12);
      final b = _funken(_zug(reihen: [7]), seed: 12);
      final c = _funken(_zug(reihen: [7]), seed: 13);
      expect(a.map((f) => f.start), equals(b.map((f) => f.start)));
      expect(a.map((f) => f.start), isNot(equals(c.map((f) => f.start))));
    });

    test('fallen im Flug nach unten', () {
      final funke = _funken(_zug(reihen: [3])).first;
      expect(funke.positionBei(0, 200), funke.start);
      final frueh = funke.positionBei(0.3, 200);
      final spaet = funke.positionBei(0.9, 200);
      expect(spaet.dy - frueh.dy, greaterThan(0),
          reason: 'die Schwerkraft zieht sie nach unten');
    });
  });

  group('Was als neuer Zug gilt', () {
    // Die eine Regel, an der Brett, Ruettler und Banner haengen.
    final stand = stateWith(board: Board.empty(), hand: Hand.of([_dot, _dot, _dot]));

    test('ohne Vorzustand passiert nichts', () {
      expect(neuerZug(null, stand), isNull);
    });

    test('ein Zug ohne Punktgewinn zaehlt nicht', () {
      final gleich = stand.copyWith(lastMove: _zug());
      expect(neuerZug(gleich, gleich), isNull);
    });

    test('ein Undo zaehlt nicht — es senkt die Punktzahl', () {
      final vorher = stand.copyWith(score: 500, lastMove: _zug());
      final zurueck = stand.copyWith(score: 300, lastMove: _zug());
      expect(neuerZug(vorher, zurueck), isNull);
    });

    test('ein neuer Zug mit mehr Punkten zaehlt', () {
      final vorher = stand.copyWith(score: 300);
      final move = _zug(reihen: [7]);
      final nachher = stand.copyWith(score: 500, lastMove: move);
      expect(neuerZug(vorher, nachher), same(move));
    });
  });

  group('Auf dem Bildschirm', () {
    testWidgets('eine gefallene Linie laesst es knallen und wackeln',
        (tester) async {
      final container = await pumpGame(
        tester,
        state: stateWith(
          board: _eineReiheFast(),
          hand: Hand.of([_dot, _dot, _dot]),
        ),
      );
      expect(find.byKey(const Key('clear-burst')), findsNothing);
      expect(find.byKey(const Key('clear-banner')), findsNothing);

      container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
      await tester.pump();

      expect(find.byKey(const Key('clear-burst')), findsOneWidget);
      expect(find.byKey(const Key('clear-banner')), findsOneWidget);
      expect(find.text('GUT'), findsOneWidget);

      // Es wackelt wirklich — und kommt danach zur Ruhe.
      expect(await _maxAusschlag(tester, ScreenShakeDauer.kurz), greaterThan(0));
      await tester.pumpAndSettle();
      final ruhe = tester
          .widget<Transform>(find.byKey(const Key('screen-shake')))
          .transform
          .getTranslation();
      expect(ruhe.x, 0);
      expect(ruhe.y, 0);

      // Und alles raeumt sich von selbst wieder weg.
      expect(find.byKey(const Key('clear-burst')), findsNothing);
      expect(find.byKey(const Key('clear-banner')), findsNothing);
    });

    testWidgets('zwei Linien wackeln staerker als eine', (tester) async {
      Future<double> ausschlagFuer(Board board, int slot, int x, int y,
          Hand hand) async {
        // Jede Messung braucht einen frischen Baum: sonst haengt der Ruettler
        // noch am Spielstand der Messung davor.
        await tester.pumpWidget(const SizedBox.shrink());
        final container =
            await pumpGame(tester, state: stateWith(board: board, hand: hand));
        final vorher = container.read(gameControllerProvider).score;
        container.read(gameControllerProvider.notifier)
            .place(slot: slot, x: x, y: y);
        expect(container.read(gameControllerProvider).score,
            greaterThan(vorher),
            reason: 'der Zug muss wirklich stattgefunden haben');
        expect(container.read(gameControllerProvider).lastMove!.clearedLines,
            greaterThan(0));
        await tester.pump();
        final wert = await _maxAusschlag(tester, ScreenShakeDauer.kurz);
        await tester.pumpAndSettle();
        return wert;
      }

      final eine = await ausschlagFuer(
          _eineReiheFast(), 0, 7, 7, Hand.of([_dot, _dot, _dot]));
      final zwei = await ausschlagFuer(
          _zweiReihenFast(), 0, 7, 6, Hand.of([_line2v, _dot, _dot]));

      expect(zwei, greaterThan(eine));
    });

    testWidgets('zwei Linien heissen DOPPEL', (tester) async {
      final container = await pumpGame(
        tester,
        state: stateWith(
          board: _zweiReihenFast(),
          hand: Hand.of([_line2v, _dot, _dot]),
        ),
      );

      container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 6);
      await tester.pump();

      expect(find.text('DOPPEL'), findsOneWidget);
      expect(find.textContaining('+'), findsWidgets);
    });

    testWidgets('die Punktzahl springt kurz an, wenn Punkte dazukommen',
        (tester) async {
      final container = await pumpGame(
        tester,
        state: stateWith(
          board: _eineReiheFast(),
          hand: Hand.of([_dot, _dot, _dot]),
        ),
      );
      double groesse() => scaleOf(
            find.ancestor(
              of: find.byKey(const Key('score')),
              matching: find.byType(Transform),
            ).first,
            tester,
          );
      expect(groesse(), closeTo(1, 0.001));

      container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(groesse(), greaterThan(1.05));

      await tester.pumpAndSettle();
      expect(groesse(), closeTo(1, 0.001), reason: 'und kommt zurueck');
    });

    testWidgets('ein Zug ohne Aufloesung laesst alles ruhig', (tester) async {
      final container = await pumpGame(
        tester,
        state: stateWith(
          board: Board.empty(),
          hand: Hand.of([_dot, _dot, _dot]),
        ),
      );

      container.read(gameControllerProvider.notifier).place(slot: 0, x: 3, y: 3);
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byKey(const Key('clear-burst')), findsNothing);
      expect(find.byKey(const Key('clear-banner')), findsNothing);
      final ruhe = tester
          .widget<Transform>(find.byKey(const Key('screen-shake')))
          .transform
          .getTranslation();
      expect(ruhe.x, 0);
      expect(ruhe.y, 0);
    });

    testWidgets('ein Undo laesst nichts erneut knallen', (tester) async {
      final container = await pumpGame(
        tester,
        state: stateWith(
          board: _eineReiheFast(),
          hand: Hand.of([_dot, _dot, _dot]),
        ),
      );
      final controller = container.read(gameControllerProvider.notifier);
      controller.place(slot: 0, x: 7, y: 7);
      await tester.pumpAndSettle();

      controller.undo();
      await tester.pump();

      expect(find.byKey(const Key('clear-burst')), findsNothing);
      expect(find.byKey(const Key('clear-banner')), findsNothing);
    });
  });
}

/// Wie lange der Ruettler laeuft — als Zahl im Test, damit er nicht laenger
/// pumpt als noetig.
class ScreenShakeDauer {
  static const Duration kurz = Duration(milliseconds: 400);
}
