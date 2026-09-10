import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/data/game_dao.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/placement.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final line3h = PieceCatalog.byId('line3h');
  final dot = PieceCatalog.byId('dot');

  GameState mitHand() => GameState(
        seed: 1,
        handIndex: 0,
        board: Board.empty(),
        hand: Hand.of([line3h, dot, dot]),
        score: 0,
        combo: 1,
        undosLeft: 3,
        isOver: false,
      );

  ProviderContainer aufbau(GameMode mode) {
    final container = ProviderContainer.test(
      overrides: [
        soundOutputProvider.overrideWithValue(RecordingOutput()),
        seedSourceProvider.overrideWithValue(() => 1),
        restoredGameProvider.overrideWithValue(mitHand()),
      ],
    );
    container.read(gameModeProvider.notifier).set(mode);
    return container;
  }

  test('im Rotations-Modus dreht sich das Teil in der Hand', () {
    final c = aufbau(GameMode.rotation);
    expect(c.read(gameControllerProvider).hand.pieceAt(0)!.width, 3);

    expect(c.read(gameControllerProvider.notifier).rotate(0), isTrue);

    final gedreht = c.read(gameControllerProvider).hand.pieceAt(0)!;
    expect(gedreht.width, 1);
    expect(gedreht.height, 3);
    expect(c.read(gameControllerProvider).hand.pieceAt(1), dot,
        reason: 'die anderen Plaetze bleiben');
  });

  test('in den anderen Modi dreht sich nichts', () {
    for (final mode in [GameMode.normal, GameMode.daily, GameMode.level]) {
      final c = aufbau(mode);
      expect(c.read(gameControllerProvider.notifier).rotate(0), isFalse,
          reason: '$mode');
      expect(c.read(gameControllerProvider).hand.pieceAt(0)!.width, 3);
    }
  });

  test('das gedrehte Teil laesst sich wirklich legen', () {
    final c = aufbau(GameMode.rotation);
    c.read(gameControllerProvider.notifier).rotate(0);

    final state = c.read(gameControllerProvider);
    final piece = state.hand.pieceAt(0)!;
    expect(canPlace(state.board, piece, 0, 5), isTrue,
        reason: 'stehend passt es auch unten hin');

    c.read(gameControllerProvider.notifier).place(slot: 0, x: 0, y: 5);
    final board = c.read(gameControllerProvider).board;
    expect(board.isFilled(0, 5), isTrue);
    expect(board.isFilled(0, 7), isTrue);
    expect(board.isFilled(2, 5), isFalse, reason: 'es liegt nicht mehr quer');
  });

  test('ein leerer Platz laesst sich nicht drehen', () {
    final c = aufbau(GameMode.rotation);
    final ohne = c.read(gameControllerProvider).hand.withoutSlot(0);
    c.read(gameControllerProvider.notifier).state =
        c.read(gameControllerProvider).copyWith(hand: ohne);

    expect(c.read(gameControllerProvider.notifier).rotate(0), isFalse);
  });

  test('ein gedrehtes Teil ueberlebt das Speichern', () {
    final gedreht = line3h.rotated();
    final hand = Hand.of([gedreht, dot, dot]);

    final text = encodeHand(hand);
    expect(text, startsWith('line3h@1'));

    final zurueck = decodeHand(text);
    expect(zurueck.pieceAt(0)!.id, 'line3h@1');
    expect(zurueck.pieceAt(0)!.width, 1);
    expect(zurueck.pieceAt(0)!.height, 3);
    expect(zurueck, equals(hand));
  });
}
