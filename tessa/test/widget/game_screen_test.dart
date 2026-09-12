import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/sound.dart';

import '../support/fake_sound.dart';
import '../support/spiel_harness.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/ui/screens/game_screen.dart';
import 'package:tessa/ui/theme/tessa_theme.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/placement.dart';
import 'package:tessa/ui/widgets/board_view.dart';
import 'package:tessa/ui/widgets/cell_tile.dart';

/// Tippt auf ein Bedienelement und scrollt es vorher ins Bild — die Seiten
/// sind laenger geworden, nicht jedes Element ist von Anfang an sichtbar.
Future<void> tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Zieht das Teil aus [slot] per echter Geste auf den Anker ([ax], [ay]).
Future<void> ziehe(
  WidgetTester tester, {
  required int slot,
  required Piece piece,
  required int ax,
  required int ay,
}) async {
  final cell = tester.widget<BoardView>(find.byType(BoardView)).cellSize;
  final boardTopLeft = tester.getTopLeft(find.byType(BoardView));
  final ziel = boardTopLeft +
      Offset(ax * cell, ay * cell) +
      pieceDragAnchor(piece, cell);

  final geste = await tester.startGesture(
    tester.getCenter(find.byKey(Key('tray-$slot'))),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await geste.moveTo(ziel);
  await tester.pump();
  await geste.up();
  await tester.pumpAndSettle();
}

void main() {
  final dot = PieceCatalog.byId('dot');
  final square = PieceCatalog.byId('square2');

  testWidgets('zeigt Brett, Hand, Punkte und Seed', (tester) async {
    await pumpGame(tester, seed: 12345);

    // 64 Felder auf dem Brett, dazu die Zellen der drei Teile in der Hand.
    expect(find.byType(CellTile), findsAtLeast(Board.cellCount));
    expect(find.byKey(const Key('score')), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('Spielcode 12345'), findsOneWidget);
    for (var slot = 0; slot < Hand.slotCount; slot++) {
      expect(find.byKey(Key('tray-$slot')), findsOneWidget);
    }
  });

  testWidgets('bei Combo 1 steht keine Anzeige', (tester) async {
    await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        combo: 1,
      ),
    );
    expect(find.byKey(const Key('combo')), findsNothing);
  });

  testWidgets('ab Combo 2 steht der Stand in der Leiste', (tester) async {
    await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        combo: 4,
      ),
    );
    expect(find.byKey(const Key('combo')), findsOneWidget);
    expect(find.text('Combo 4'), findsOneWidget);
  });

  testWidgets('Undo ist erst nach einem Zug moeglich', (tester) async {
    final container = await pumpGame(tester, seed: 7);

    final undo = find.byKey(const Key('undo'));
    expect(tester.widget<IconButton>(undo).onPressed, isNotNull,
        reason: 'zu Beginn sind noch drei Versuche uebrig');

    // Ohne Zug im Verlauf passiert nichts.
    await tester.tap(undo);
    await tester.pumpAndSettle();
    expect(container.read(gameControllerProvider).undosLeft, 3);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('ein Zug laesst sich ueber die Oberflaeche zuruecknehmen',
      (tester) async {
    final container = await pumpGame(tester, seed: 7);
    final controller = container.read(gameControllerProvider.notifier);
    final before = container.read(gameControllerProvider);
    final spot = placementsFor(before.board, before.hand.pieceAt(0)!).first;

    controller.place(slot: 0, x: spot.x, y: spot.y);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tray-empty-0')), findsOneWidget);

    await tapKey(tester, Key('undo'));

    expect(container.read(gameControllerProvider).board, equals(before.board));
    expect(find.byKey(const Key('tray-0')), findsOneWidget);
    expect(find.text('2'), findsWidgets, reason: 'ein Versuch ist verbraucht');
  });

  testWidgets('am Ende der Runde erscheint die Abschlussanzeige',
      (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.fromRows(List.filled(8, '########')),
        hand: Hand.of([dot, dot, dot]),
        score: 1234,
        isOver: true,
      ),
    );

    expect(find.byKey(const Key('game-over')), findsOneWidget);
    // Die Punktzahl steht in der Leiste und in der Abschlussanzeige.
    expect(
      find.descendant(
        of: find.byKey(const Key('game-over')),
        matching: find.text('1.234'),
      ),
      findsOneWidget,
    );

    await tapKey(tester, Key('replay'));

    final state = container.read(gameControllerProvider);
    expect(state.isOver, isFalse, reason: 'dieselbe Runde beginnt von vorn');
    expect(state.seed, 4711);
    expect(find.byKey(const Key('game-over')), findsNothing);
  });
  testWidgets('ein Teil laesst sich aufs Brett ziehen', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([square, dot, dot]),
      ),
    );

    final cellSize = tester.widget<BoardView>(find.byType(BoardView)).cellSize;
    final boardTopLeft = tester.getTopLeft(find.byType(BoardView));
    // Damit die linke obere Ecke des Teils auf Feld (0,0) liegt, muss der
    // Finger um genau den Greifpunkt versetzt sein.
    final target = boardTopLeft + pieceDragAnchor(square, cellSize);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('tray-0'))),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(target);
    await tester.pump();

    expect(container.read(dragPreviewProvider).isValid, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();

    final state = container.read(gameControllerProvider);
    expect(state.board.isFilled(0, 0), isTrue);
    expect(state.board.isFilled(1, 1), isTrue);
    expect(state.board.filledCount, square.cellCount);
    expect(state.score, square.cellCount);
    expect(state.hand.pieceAt(0), isNull);
    expect(container.read(dragControllerProvider).isActive, isFalse);
  });

  testWidgets('ein Abwurf neben dem Brett aendert nichts', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([square, dot, dot]),
      ),
    );
    final before = container.read(gameControllerProvider);

    final start = tester.getCenter(find.byKey(const Key('tray-0')));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 50));
    // Zur Seite ziehen, aber in der Ablage bleiben.
    await gesture.moveTo(start + const Offset(60, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(gameControllerProvider), same(before));
    expect(find.byKey(const Key('tray-0')), findsOneWidget);
    expect(container.read(dragControllerProvider).isActive, isFalse);
  });
  testWidgets('die Leiste laeuft auf einem schmalen Geraet nicht ueber',
      (tester) async {
    // Kleines Telefon, dazu alles gleichzeitig sichtbar: lange Punktzahl,
    // groesstmoeglicher Seed, Combo-Anzeige, Undo und Bestenliste.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        score: 1234567,
        combo: 9,
        seed: 4294967295,
      ),
    );

    // Ein Ueberlauf meldet sich in Flutter als Fehler und laesst den Test
    // scheitern; hier zaehlt, dass alles gezeichnet wird.
    expect(find.byKey(const Key('score')), findsOneWidget);
    expect(find.byKey(const Key('combo')), findsOneWidget);
    expect(find.byKey(const Key('undo')), findsOneWidget);
    expect(find.byKey(const Key('hint')), findsOneWidget);
    expect(find.byKey(const Key('back-home')), findsOneWidget);
    expect(find.byType(BoardView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('nach einer Aufloesung steht da, was der Zug gebracht hat',
      (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.fromRows(const [
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '#######.',
        ]),
        hand: Hand.of([dot, dot, dot]),
      ),
    );
    expect(find.byKey(const Key('move-feedback')), findsNothing);

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('move-feedback')), findsOneWidget);
    expect(find.text('+11 · 1 Linie'), findsOneWidget);
  });

  testWidgets('ein Zug ohne Aufloesung meldet nichts', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(board: Board.empty(), hand: Hand.of([dot, dot, dot])),
    );

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 3, y: 3);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('move-feedback')), findsNothing);
  });
  testWidgets('gefallene Linien leuchten kurz nach', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.fromRows(const [
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '#######.',
        ]),
        hand: Hand.of([dot, dot, dot]),
      ),
    );
    expect(find.byKey(const Key('clear-flash')), findsNothing);

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
    await tester.pump();
    expect(find.byKey(const Key('clear-flash')), findsOneWidget);

    // Es bewegt sich auch wirklich: das Leuchten wird schwaecher, die Kacheln
    // werden groesser.
    double deckkraft() => tester
        .widget<Opacity>(find.ancestor(
          of: find.byKey(const Key('clear-flash')),
          matching: find.byType(Opacity),
        ))
        .opacity;
    double groesse() => scaleOf(
        find
            .descendant(
              of: find.byKey(const Key('clear-flash')),
              matching: find.byType(Transform),
            )
            .first,
        tester);

    final deckkraftAmAnfang = deckkraft();
    final groesseAmAnfang = groesse();
    expect(deckkraftAmAnfang, closeTo(1, 0.01));

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('clear-flash')), findsOneWidget);
    expect(deckkraft(), lessThan(deckkraftAmAnfang));
    expect(groesse(), greaterThan(groesseAmAnfang));

    // Danach ist es von selbst verschwunden.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clear-flash')), findsNothing);
  });

  testWidgets('ein Zug ohne Aufloesung laesst nichts leuchten', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(board: Board.empty(), hand: Hand.of([dot, dot, dot])),
    );

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 3, y: 3);
    await tester.pump();

    expect(find.byKey(const Key('clear-flash')), findsNothing);
  });

  testWidgets('ein Undo laesst nichts erneut aufleuchten', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.fromRows(const [
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '#######.',
        ]),
        hand: Hand.of([dot, dot, dot]),
      ),
    );

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clear-flash')), findsNothing);

    // Das Undo holt einen aelteren Zug zurueck - das ist kein neuer Treffer.
    container.read(gameControllerProvider.notifier).undo();
    await tester.pump();
    expect(find.byKey(const Key('clear-flash')), findsNothing);
  });
  testWidgets('ein gelegtes Teil springt auf', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(board: Board.empty(), hand: Hand.of([square, dot, dot])),
    );
    expect(find.byKey(const Key('pop-2-2')), findsNothing);

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 2, y: 2);
    await tester.pump();

    // Alle vier Zellen des 2x2-Teils fangen klein an.
    for (final cell in const ['2-2', '3-2', '2-3', '3-3']) {
      final pop = find.byKey(Key('pop-$cell'));
      expect(pop, findsOneWidget, reason: cell);
      expect(scaleOf(pop, tester), lessThan(1), reason: cell);
    }

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pop-2-2')), findsNothing,
        reason: 'danach sitzt die Kachel einfach da');
    expect(find.byKey(const Key('cell-2-2')), findsOneWidget);
  });

  testWidgets('eine sofort wieder gefallene Zelle springt nicht auf',
      (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.fromRows(const [
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '#######.',
        ]),
        hand: Hand.of([dot, dot, dot]),
      ),
    );

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
    await tester.pump();

    expect(find.byKey(const Key('pop-7-7')), findsNothing,
        reason: 'die Zelle ist mit der Linie gefallen, sie leuchtet nur nach');
    expect(find.byKey(const Key('clear-flash')), findsOneWidget);
  });

  testWidgets('ein Undo laesst nichts aufspringen', (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(board: Board.empty(), hand: Hand.of([square, dot, dot])),
    );

    container.read(gameControllerProvider.notifier).place(slot: 0, x: 2, y: 2);
    await tester.pumpAndSettle();

    container.read(gameControllerProvider.notifier).undo();
    await tester.pump();

    expect(find.byKey(const Key('pop-2-2')), findsNothing);
  });
  group('Teilen-Text', () {
    test('nennt beim Tagesraetsel die Serie', () {
      final text = shareText(
        mode: GameMode.daily,
        score: 3210,
        seed: 20260910,
        streak: 4,
      );
      expect(text, contains('Tessa Tagesrätsel'));
      expect(text, contains('3210 Punkte'));
      expect(text, contains('Serie 4 Tage'));
      expect(text, contains('Spielcode 20260910'));
    });

    test('laesst die Serie weg, wenn es keine gibt', () {
      final text = shareText(
        mode: GameMode.normal,
        score: 900,
        seed: 77,
        streak: 0,
      );
      expect(text, contains('900 Punkte'));
      expect(text, isNot(contains('Serie')));
      expect(text, contains('Spielcode 77'));
    });
  });
  testWidgets('ohne frueheren Versuch steht kein Bestwert da', (tester) async {
    await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([dot, dot, dot]),
        seed: 555,
      ),
    );
    expect(find.byKey(const Key('best-for-code')), findsNothing);
  });

  testWidgets('zeigt den Abstand zum eigenen Bestwert dieses Spielcodes',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
          seedSourceProvider.overrideWithValue(() => 555),
          gameControllerProvider.overrideWith(() => FixedGame(stateWith(
                board: Board.empty(),
                hand: Hand.of([dot, dot, dot]),
                seed: 555,
                score: 400,
              ))),
          bestForCodeProvider(555).overrideWith((ref) async => 1000),
        ],
        child: MaterialApp(
          theme: tessaTheme(),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('best-for-code')), findsOneWidget);
    expect(find.textContaining('noch 600'), findsOneWidget);
  });
  testWidgets('ein Teil laesst sich in der untersten Reihe ablegen',
      (tester) async {
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([square, dot, dot]),
      ),
    );

    // Anker (3,6) belegt die Zeilen 6 und 7 — die unterste Reihe.
    await ziehe(tester, slot: 0, piece: square, ax: 3, ay: 6);

    final board = container.read(gameControllerProvider).board;
    expect(board.isFilled(3, 7), isTrue,
        reason: 'die unterste Reihe muss erreichbar sein');
    expect(board.isFilled(4, 7), isTrue);
    expect(board.isFilled(3, 6), isTrue);
  });

  // Je Ecke ein eigener Test: nach einer Ablage ist der Handplatz leer, ein
  // zweiter Zug im selben Baum ginge ins Leere.
  for (final ecke in const [
    [0, 0],
    [7, 0],
    [0, 7],
    [7, 7],
  ]) {
    testWidgets('die Ecke (${ecke[0]},${ecke[1]}) ist erreichbar',
        (tester) async {
      final container = await pumpGame(
        tester,
        state: stateWith(
          board: Board.empty(),
          hand: Hand.of([dot, dot, dot]),
        ),
      );

      await ziehe(tester, slot: 0, piece: dot, ax: ecke[0], ay: ecke[1]);

      expect(
        container.read(gameControllerProvider).board.isFilled(ecke[0], ecke[1]),
        isTrue,
      );
    });
  }

  testWidgets('auch ein hohes Teil kommt bis nach unten', (tester) async {
    final line5v = PieceCatalog.byId('line5v');
    final container = await pumpGame(
      tester,
      state: stateWith(
        board: Board.empty(),
        hand: Hand.of([line5v, dot, dot]),
      ),
    );

    // Hoehe 5, unterste moegliche Ankerzeile ist 3.
    await ziehe(tester, slot: 0, piece: line5v, ax: 2, ay: 3);

    final board = container.read(gameControllerProvider).board;
    expect(board.isFilled(2, 7), isTrue);
    expect(board.isFilled(2, 3), isTrue);
  });
}
