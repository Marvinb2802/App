import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tessa/app.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/data/database.dart';
import 'package:tessa/ui/screens/scores_screen.dart';
import 'package:tessa/ui/widgets/board_view.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  /// Ohne eigenen Isolate: nur so laufen die Datenbank-Futures in der
  /// kuenstlichen Zeit eines Widget-Tests zu Ende.
  Future<TessaDatabase> openMemory() => TessaDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        path: inMemoryDatabasePath,
      );

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    TessaDatabase? database,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seedSourceProvider.overrideWithValue(() => 2024),
          databaseProvider.overrideWithValue(database),
        ],
        child: const TessaApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(BoardView)));
  }

  testWidgets('ohne gespielte Runde bleibt die Liste leer', (tester) async {
    final database = await openMemory();
    addTearDown(database.close);
    await pumpApp(tester, database: database);

    await tester.tap(find.byKey(const Key('open-scores')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scores-empty')), findsOneWidget);
    expect(find.text('Noch keine Runde gespielt.'), findsOneWidget);
  });

  testWidgets('ohne Datenbank bleibt die Liste ebenfalls leer', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('open-scores')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scores-empty')), findsOneWidget);
  });

  testWidgets('zeigt die besten Runden mit Seed und Datum', (tester) async {
    final database = await openMemory();
    addTearDown(database.close);
    await database.scores
        .add(score: 120, seed: 11, playedAt: DateTime(2026, 3, 7));
    await database.scores
        .add(score: 4300, seed: 22, playedAt: DateTime(2026, 9, 1));

    await pumpApp(tester, database: database);
    await tester.tap(find.byKey(const Key('open-scores')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scores-list')), findsOneWidget);
    expect(find.text('4300 Punkte'), findsOneWidget);
    expect(find.text('Seed 22 · 01.09.2026'), findsOneWidget);
    expect(find.text('120 Punkte'), findsOneWidget);
    expect(find.text('Seed 11 · 07.03.2026'), findsOneWidget);

    // Beste zuerst.
    final erste = tester.getTopLeft(find.text('4300 Punkte'));
    final zweite = tester.getTopLeft(find.text('120 Punkte'));
    expect(erste.dy, lessThan(zweite.dy));
  });

  testWidgets('eine Runde aus der Liste laesst sich noch einmal spielen',
      (tester) async {
    final database = await openMemory();
    addTearDown(database.close);
    final id = await database.scores.add(score: 999, seed: 4711);

    final container = await pumpApp(tester, database: database);
    expect(container.read(gameControllerProvider).seed, 2024);

    await tester.tap(find.byKey(const Key('open-scores')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('replay-$id')));
    await tester.pumpAndSettle();

    expect(find.byType(ScoresScreen), findsNothing, reason: 'zurueck im Spiel');
    final state = container.read(gameControllerProvider);
    expect(state.seed, 4711);
    expect(state.score, 0);
    expect(state.board.isEmpty, isTrue);
  });

  testWidgets('eine beendete Runde taucht danach in der Liste auf',
      (tester) async {
    final database = await openMemory();
    addTearDown(database.close);
    await database.scores.add(score: 50, seed: 1, playedAt: DateTime(2026, 1, 2));

    final container = await pumpApp(tester, database: database);
    await container.read(topScoresProvider.future);

    await database.scores
        .add(score: 7000, seed: 2, playedAt: DateTime(2026, 1, 3));
    container.invalidate(topScoresProvider);

    await tester.tap(find.byKey(const Key('open-scores')));
    await tester.pumpAndSettle();

    expect(find.text('7000 Punkte'), findsOneWidget);
  });
}
