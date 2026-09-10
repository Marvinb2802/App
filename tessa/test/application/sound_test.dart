import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dot = PieceCatalog.byId('dot');

  /// Ein Brett, auf dem ein Punkt bei (7,7) die letzte Reihe schliesst.
  GameState kurzVorLinie({int combo = 1}) => GameState(
        seed: 1,
        handIndex: 0,
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
        score: 0,
        combo: combo,
        undosLeft: 3,
        isOver: false,
      );

  ({ProviderContainer container, RecordingOutput sound}) aufbau({
    GameState? state,
    bool tonAn = true,
  }) {
    final sound = RecordingOutput();
    final container = ProviderContainer.test(
      overrides: [
        soundOutputProvider.overrideWithValue(sound),
        seedSourceProvider.overrideWithValue(() => 7),
        initialSoundProvider.overrideWithValue(tonAn),
        if (state != null) restoredGameProvider.overrideWithValue(state),
      ],
    );
    return (container: container, sound: sound);
  }

  test('ein gewoehnlicher Zug klingt anders als eine Aufloesung', () {
    final a = aufbau(state: kurzVorLinie());
    a.container.read(gameControllerProvider.notifier).place(slot: 0, x: 0, y: 0);
    expect(a.sound.played, [Sounds.place]);

    final b = aufbau(state: kurzVorLinie());
    b.container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
    expect(b.sound.played, [Sounds.clear(1)]);
  });

  test('die Tonhoehe steigt mit der Combo', () {
    final a = aufbau(state: kurzVorLinie(combo: 4));
    a.container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);

    expect(a.sound.played, [Sounds.clear(4)]);
    expect(Sounds.clear(4), isNot(Sounds.clear(1)));
  });

  test('ueber Combo 9 hinaus bleibt es beim hoechsten Ton', () {
    expect(Sounds.clear(12), Sounds.clear(9));
    expect(Sounds.clear(0), Sounds.clear(1));
  });

  test('am Ende der Runde erklingt der Schlussklang', () {
    // Ein Brett, auf dem nach dem Punkt nichts mehr passt.
    final state = GameState(
      seed: 1,
      handIndex: 0,
      board: Board.fromRows(const [
        '.###.###',
        '#.###.##',
        '##.###.#',
        '###.###.',
        '.###.###',
        '#.###.##',
        '##.###.#',
        '###.###.',
      ]),
      hand: Hand.of([
        dot,
        PieceCatalog.byId('square2'),
        PieceCatalog.byId('square2'),
      ]),
      score: 0,
      combo: 1,
      undosLeft: 3,
      isOver: false,
    );
    final a = aufbau(state: state);
    a.container.read(gameControllerProvider.notifier).place(slot: 0, x: 0, y: 0);

    expect(a.container.read(gameControllerProvider).isOver, isTrue);
    expect(a.sound.played, [Sounds.gameOver]);
  });

  test('abgeschaltet bleibt es still', () {
    final a = aufbau(state: kurzVorLinie(), tonAn: false);
    a.container.read(gameControllerProvider.notifier).place(slot: 0, x: 7, y: 7);
    expect(a.sound.played, isEmpty);
  });

  test('der Schalter wirkt sofort', () async {
    final a = aufbau(state: kurzVorLinie());
    await a.container.read(soundProvider.notifier).toggle();

    a.container.read(gameControllerProvider.notifier).place(slot: 0, x: 0, y: 0);
    expect(a.sound.played, isEmpty);
    expect(a.container.read(soundProvider), isFalse);
  });
}
