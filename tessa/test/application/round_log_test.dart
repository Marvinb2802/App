import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/round_log.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dot = PieceCatalog.byId('dot');
  final square = PieceCatalog.byId('square2');

  MoveRecord zug(int index, {int lines = 0, int best = 0, int punkte = 5}) =>
      MoveRecord(
        index: index,
        clearedLines: lines,
        bestLines: best,
        points: punkte,
        combo: 1,
      );

  group('RoundLog', () {
    test('findet den besten eigenen Zug', () {
      final log = RoundLog([
        zug(1, lines: 1, best: 1, punkte: 11),
        zug(2, lines: 2, best: 2, punkte: 44),
        zug(3),
      ]);
      expect(log.bestMove!.index, 2);
      expect(log.bestClear, 2);
    });

    test('findet die groesste verpasste Gelegenheit', () {
      final log = RoundLog([
        zug(1, lines: 0, best: 1),
        zug(2, lines: 1, best: 3),
        zug(3, lines: 0, best: 2),
      ]);
      expect(log.biggestMiss!.index, 2, reason: 'zwei Linien liegen geblieben');
      expect(log.biggestMiss!.missedLines, 2);
    });

    test('ohne verpasste Gelegenheit gibt es nichts zu melden', () {
      final log = RoundLog([zug(1, lines: 2, best: 2), zug(2)]);
      expect(log.biggestMiss, isNull);
    });

    test('ein Undo nimmt den letzten Eintrag mit', () {
      final container = ProviderContainer.test();
      final controller = container.read(roundLogProvider.notifier);

      controller.record(zug(1));
      controller.record(zug(2));
      expect(container.read(roundLogProvider).moveCount, 2);

      controller.undoLast();
      expect(container.read(roundLogProvider).moveCount, 1);

      controller.undoLast();
      controller.undoLast();
      expect(container.read(roundLogProvider).moveCount, 0,
          reason: 'ins Minus geht es nicht');
    });
  });

  group('Aufzeichnung im Spiel', () {
    /// Ein Brett, auf dem ein Punkt bei (7,7) eine Linie schliesst — das
    /// 2x2-Teil kann das nicht.
    GameState kurzVorLinie() => GameState(
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
          hand: Hand.of([square, dot, dot]),
          score: 0,
          combo: 1,
          undosLeft: 3,
          isOver: false,
        );

    ProviderContainer aufbau(GameState state) => ProviderContainer.test(
          overrides: [
            soundOutputProvider.overrideWithValue(RecordingOutput()),
            seedSourceProvider.overrideWithValue(() => 1),
            restoredGameProvider.overrideWithValue(state),
          ],
        );

    test('haelt fest, was moeglich gewesen waere', () {
      final c = aufbau(kurzVorLinie());
      // Das 2x2-Teil irgendwo hinlegen, statt die Linie zu schliessen.
      c.read(gameControllerProvider.notifier).place(slot: 0, x: 0, y: 0);

      final log = c.read(roundLogProvider);
      expect(log.moveCount, 1);
      expect(log.moves.first.clearedLines, 0);
      expect(log.moves.first.bestLines, 1,
          reason: 'der Punkt haette die Reihe geschlossen');
      expect(log.biggestMiss!.index, 1);
    });

    test('zaehlt die Zuege durch', () {
      final c = aufbau(kurzVorLinie());
      final controller = c.read(gameControllerProvider.notifier);
      controller.place(slot: 0, x: 0, y: 0);
      controller.place(slot: 1, x: 7, y: 7);

      final log = c.read(roundLogProvider);
      expect(log.moves.map((m) => m.index), [1, 2]);
      expect(log.moves.last.clearedLines, 1);
      expect(log.bestClear, 1);
    });

    test('eine neue Runde faengt mit leerem Verlauf an', () {
      final c = aufbau(kurzVorLinie());
      c.read(gameControllerProvider.notifier).place(slot: 0, x: 0, y: 0);
      expect(c.read(roundLogProvider).moveCount, 1);

      c.read(gameControllerProvider.notifier).restart();
      expect(c.read(roundLogProvider).moveCount, 0);
    });
  });
}
