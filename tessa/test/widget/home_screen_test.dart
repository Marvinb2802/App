import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/app.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/data/database.dart';
import 'package:tessa/data/store.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/ui/screens/game_screen.dart';
import 'package:tessa/ui/screens/home_screen.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/ui/screens/scores_screen.dart';
import 'package:tessa/ui/screens/stats_screen.dart';

/// Tippt auf ein Bedienelement und scrollt es vorher ins Bild — die Seiten
/// sind laenger geworden, nicht jedes Element ist von Anfang an sichtbar.
Future<void> tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(sqfliteFfiInit);

  Future<TessaDatabase> openMemory() => TessaDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    int seed = 2024,
    GameState? restored,
    TessaDatabase? database,
    DateTime? today,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seedSourceProvider.overrideWithValue(() => seed),
          restoredGameProvider.overrideWithValue(restored),
          storeProvider.overrideWithValue(database == null ? null : SqfliteStore(database)),
          if (today != null) todayProvider.overrideWithValue(today),
        ],
        child: const TessaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  GameState laufendePartie() => GameState(
        seed: 99,
        handIndex: 2,
        board: Board.fromRows(const [
          '###.....',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
          '........',
        ]),
        hand: Hand.of([
          PieceCatalog.byId('dot'),
          PieceCatalog.byId('line2h'),
          PieceCatalog.byId('square2'),
        ]),
        score: 640,
        combo: 2,
        undosLeft: 1,
        isOver: false,
      );

  testWidgets('die App startet auf dem Startbildschirm', (tester) async {
    await pumpHome(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Tessa'), findsOneWidget);
    expect(find.byKey(const Key('new-game')), findsOneWidget);
    expect(find.byKey(const Key('continue')), findsNothing,
        reason: 'ohne angefangene Runde gibt es nichts fortzusetzen');
  });

  testWidgets('eine angefangene Runde laesst sich fortsetzen', (tester) async {
    final container = await pumpHome(tester, restored: laufendePartie());

    expect(find.text('Weiterspielen (640 Punkte)'), findsOneWidget);

    await tapKey(tester, Key('continue'));

    expect(find.byType(GameScreen), findsOneWidget);
    final state = container.read(gameControllerProvider);
    expect(state.seed, 99, reason: 'dieselbe Runde, nicht eine neue');
    expect(state.score, 640);
  });

  testWidgets('eine neue Runde faengt bei null an', (tester) async {
    final container = await pumpHome(tester, restored: laufendePartie());

    await tapKey(tester, Key('new-game'));

    expect(find.byType(GameScreen), findsOneWidget);
    final state = container.read(gameControllerProvider);
    expect(state.seed, 2024, reason: 'ein frischer Seed aus der Quelle');
    expect(state.score, 0);
    expect(state.board.isEmpty, isTrue);
    expect(state.undosLeft, 3);
  });

  testWidgets('die Bestpunktzahl steht nur da, wenn es eine gibt',
      (tester) async {
    final leer = await openMemory();
    addTearDown(leer.close);
    await pumpHome(tester, database: leer);
    expect(find.byKey(const Key('best-score')), findsNothing);

    final gefuellt = await openMemory();
    addTearDown(gefuellt.close);
    await gefuellt.scores.add(score: 8400, seed: 5);
    await pumpHome(tester, database: gefuellt);
    expect(find.text('Bestpunktzahl 8400'), findsOneWidget);
  });

  testWidgets('die Bestenliste ist vom Start aus erreichbar', (tester) async {
    await pumpHome(tester);

    await tapKey(tester, Key('home-scores'));

    expect(find.byType(ScoresScreen), findsOneWidget);
  });

  testWidgets('eine Runde laesst sich mit einem Seed starten', (tester) async {
    final container = await pumpHome(tester);

    await tapKey(tester, Key('home-seed'));

    await tester.enterText(find.byKey(const Key('seed-field')), '123456');
    await tapKey(tester, Key('seed-start'));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(container.read(gameControllerProvider).seed, 123456);
  });

  testWidgets('ein leerer oder unsinniger Seed startet nichts', (tester) async {
    final container = await pumpHome(tester);
    final vorher = container.read(gameControllerProvider).seed;

    await tapKey(tester, Key('home-seed'));
    await tester.enterText(find.byKey(const Key('seed-field')), 'abc');
    await tapKey(tester, Key('seed-start'));

    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(gameControllerProvider).seed, vorher);
  });
  testWidgets('das Tagesraetsel steht oben und nennt seinen Code',
      (tester) async {
    await pumpHome(tester, today: DateTime(2026, 9, 10));

    expect(find.byKey(const Key('daily-card')), findsOneWidget);
    expect(find.text('Tagesrätsel'), findsOneWidget);
    expect(
      find.textContaining('20260910'),
      findsOneWidget,
      reason: 'der Code des Tages kommt aus dem Datum',
    );
  });

  testWidgets('das Tagesraetsel startet die Runde mit dem Code des Tages',
      (tester) async {
    final container = await pumpHome(tester, today: DateTime(2026, 9, 10));

    await tapKey(tester, const Key('play-daily'));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(container.read(gameControllerProvider).seed, 20260910);
    expect(container.read(gameModeProvider), GameMode.daily);
  });

  testWidgets('Tuefteln startet im Tueftel-Modus', (tester) async {
    final container = await pumpHome(tester);

    await tapKey(tester, const Key('practice'));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(container.read(gameModeProvider), GameMode.practice);
  });

  testWidgets('aus dem Spiel geht es mit dem Zurueck-Knopf zum Start',
      (tester) async {
    await pumpHome(tester);
    await tapKey(tester, const Key('new-game'));
    expect(find.byType(GameScreen), findsOneWidget);

    await tapKey(tester, const Key('back-home'));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
  });

  testWidgets('die Statistik ist vom Start aus erreichbar', (tester) async {
    await pumpHome(tester);
    await tapKey(tester, const Key('home-stats'));
    expect(find.byType(StatsScreen), findsOneWidget);
  });
}
