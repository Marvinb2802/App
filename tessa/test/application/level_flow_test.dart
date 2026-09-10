import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/application/level_controller.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/shop.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/data/prefs_store.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/level.dart';
import 'package:tessa/domain/rules/placement.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PrefsStore> speicher() async {
    SharedPreferences.setMockInitialValues({});
    return PrefsStore.open();
  }

  ProviderContainer aufbau([PrefsStore? store]) {
    final container = ProviderContainer.test(
      overrides: [
        soundOutputProvider.overrideWithValue(RecordingOutput()),
        seedSourceProvider.overrideWithValue(() => 1),
        storeProvider.overrideWithValue(store),
      ],
    );
    container.read(gameModeProvider.notifier).set(GameMode.level);
    return container;
  }

  /// Ein Level, das mit dem ersten Zug geschafft ist.
  Level leichtesLevel() => Level(
        number: 1,
        seed: 4242,
        goal: const LevelGoal(LevelGoalKind.score, 1),
        start: Board.empty(),
        moveLimit: 5,
        blockedCells: 0,
      );

  /// Ein Level, das sich nicht schaffen laesst: unerreichbares Ziel, zwei Zuege.
  Level schweresLevel() => Level(
        number: 9,
        seed: 4242,
        goal: const LevelGoal(LevelGoalKind.score, 99999),
        start: Board.empty(),
        moveLimit: 2,
        blockedCells: 0,
      );

  void spieleZug(ProviderContainer c) {
    final state = c.read(gameControllerProvider);
    final slot = state.hand.slots.indexWhere((piece) => piece != null);
    final spot = placementsFor(state.board, state.hand.slots[slot]!).first;
    c.read(gameControllerProvider.notifier).place(slot: slot, x: spot.x, y: spot.y);
  }

  test('startLevel setzt Spielcode, Brett und Sitzung', () {
    final c = aufbau();
    final level = levelFor(30);
    c.read(gameControllerProvider.notifier).startLevel(level);

    final state = c.read(gameControllerProvider);
    expect(state.seed, level.seed);
    expect(state.board, equals(level.start));
    expect(state.board.filledCount, level.blockedCells);
    expect(state.score, 0);

    final session = c.read(levelProvider);
    expect(session.level!.number, 30);
    expect(session.outcome, LevelOutcome.playing);
    expect(session.isRunning, isTrue);
  });

  test('das Ziel erreichen gewinnt das Level', () async {
    final store = await speicher();
    final c = aufbau(store);
    c.read(gameControllerProvider.notifier).startLevel(leichtesLevel());

    spieleZug(c);

    expect(c.read(levelProvider).outcome, LevelOutcome.won);
    expect(c.read(shopProvider).stars, greaterThan(0), reason: 'Sterne dafuer');

    // Der Fortschritt wird gesichert.
    for (var i = 0; i < 50 && await store.readSetting('levels.done') == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await store.readSetting('levels.done'), '1');
  });

  test('aufgebrauchte Zuege verlieren das Level', () {
    final c = aufbau();
    c.read(gameControllerProvider.notifier).startLevel(schweresLevel());

    spieleZug(c);
    expect(c.read(levelProvider).outcome, LevelOutcome.playing);

    spieleZug(c);
    expect(c.read(levelProvider).outcome, LevelOutcome.lost,
        reason: 'nach zwei von zwei Zuegen');
  });

  test('ein geschafftes Level bleibt geschafft', () {
    final c = aufbau();
    c.read(gameControllerProvider.notifier).startLevel(leichtesLevel());
    spieleZug(c);
    expect(c.read(levelProvider).outcome, LevelOutcome.won);

    // Weitere Zuege aendern daran nichts.
    spieleZug(c);
    expect(c.read(levelProvider).outcome, LevelOutcome.won);
  });

  test('ein neues Level setzt die Sitzung zurueck', () {
    final c = aufbau();
    c.read(gameControllerProvider.notifier).startLevel(leichtesLevel());
    spieleZug(c);
    expect(c.read(levelProvider).outcome, LevelOutcome.won);

    c.read(gameControllerProvider.notifier).startLevel(levelFor(2));
    expect(c.read(levelProvider).outcome, LevelOutcome.playing);
    expect(c.read(levelProvider).level!.number, 2);
    expect(c.read(roundLogProvider).moveCount, 0);
  });

  test('Level-Runden landen nicht in der Bestenliste', () async {
    final store = await speicher();
    final c = aufbau(store);
    c.read(gameControllerProvider.notifier).startLevel(leichtesLevel());

    spieleZug(c);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(await store.topScores(), isEmpty);
    expect(await store.loadGame(), isNull,
        reason: 'ein Level ist keine offene Partie');
  });

  test('der Fortschritt geht nicht zurueck', () async {
    SharedPreferences.setMockInitialValues({'tessa.setting.levels.done': '7'});
    final store = await PrefsStore.open();
    final c = aufbau(store);

    c.read(gameControllerProvider.notifier).startLevel(leichtesLevel());
    spieleZug(c);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(await store.readSetting('levels.done'), '7',
        reason: 'Level 1 nach Level 7 zaehlt nicht zurueck');
  });
}
