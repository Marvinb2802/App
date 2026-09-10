import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/ui/screens/game_screen.dart';
import 'package:tessa/ui/theme/tessa_theme.dart';
import 'package:tessa/application/game_controller.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/placement.dart';
import 'package:tessa/ui/widgets/board_view.dart';
import 'package:tessa/ui/widgets/cell_tile.dart';

/// Ein Controller, der mit einem vorgegebenen Spielstand startet — damit sich
/// auch Zustaende zeigen lassen, die man sonst erst erspielen muesste.
class FixedGame extends GameController {
  FixedGame(this.initial);

  final GameState initial;

  @override
  GameState build() => initial;
}

Future<ProviderContainer> pumpGame(
  WidgetTester tester, {
  int seed = 2024,
  GameState? state,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        seedSourceProvider.overrideWithValue(() => seed),
        if (state != null)
          gameControllerProvider.overrideWith(() => FixedGame(state)),
      ],
      // Direkt der Spielbildschirm: der Einstieg der App ist der
      // Startbildschirm, hier geht es aber um das Spiel selbst.
      child: MaterialApp(
        theme: tessaTheme(Brightness.light),
        home: const GameScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(BoardView)));
}

GameState stateWith({
  required Board board,
  required Hand hand,
  int score = 0,
  int combo = 1,
  int undosLeft = GameState.undosPerRound,
  bool isOver = false,
  int seed = 4711,
}) =>
    GameState(
      seed: seed,
      handIndex: 0,
      board: board,
      hand: hand,
      score: score,
      combo: combo,
      undosLeft: undosLeft,
      isOver: isOver,
    );

/// Der tatsaechliche Vergroesserungsfaktor eines Transform.
///
/// Nicht getMaxScaleOnAxis: das nimmt die Z-Achse mit, die bei Transform.scale
/// immer 1 bleibt — Werte unter 1 waeren dann nicht zu sehen.
double scaleOf(Finder finder, WidgetTester tester) =>
    tester.widget<Transform>(finder).transform.entry(0, 0);

void main() {
  final dot = PieceCatalog.byId('dot');
  final square = PieceCatalog.byId('square2');

  testWidgets('zeigt Brett, Hand, Punkte und Seed', (tester) async {
    await pumpGame(tester, seed: 12345);

    // 64 Felder auf dem Brett, dazu die Zellen der drei Teile in der Hand.
    expect(find.byType(CellTile), findsAtLeast(Board.cellCount));
    expect(find.byKey(const Key('score')), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('Seed 12345'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('undo')));
    await tester.pumpAndSettle();

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
    expect(find.text('1234 Punkte'), findsOneWidget);

    await tester.tap(find.byKey(const Key('replay')));
    await tester.pumpAndSettle();

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
    expect(find.byKey(const Key('open-scores')), findsOneWidget);
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
}
