import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/shop.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final square = PieceCatalog.byId('square2');

  /// Eine beendete Runde mit vollem Brett.
  GameState beendet() => GameState(
        seed: 4242,
        handIndex: 3,
        board: Board.fromRows(List.filled(8, '########')),
        hand: Hand.of([square, square, square]),
        score: 2500,
        combo: 1,
        undosLeft: 0,
        isOver: true,
      );

  ProviderContainer aufbau({int revives = 0}) => ProviderContainer.test(
        overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
          seedSourceProvider.overrideWithValue(() => 4242),
          restoredGameProvider.overrideWithValue(beendet()),
          initialShopProvider.overrideWithValue(ShopState(revives: revives)),
        ],
      );

  test('ohne Vorrat geht es nicht weiter', () {
    final c = aufbau();
    expect(c.read(gameControllerProvider.notifier).revive(), isFalse);
    expect(c.read(gameControllerProvider).isOver, isTrue);
  });

  test('mit Vorrat geht die Runde weiter', () {
    final c = aufbau(revives: 1);
    expect(c.read(gameControllerProvider.notifier).revive(), isTrue);

    final state = c.read(gameControllerProvider);
    expect(state.isOver, isFalse);
    expect(state.score, 2500, reason: 'die Punkte bleiben');
    expect(state.seed, 4242, reason: 'derselbe Spielcode');
    expect(state.board.filledCount, lessThan(Board.cellCount),
        reason: 'es wurde Platz geschaffen');
    expect(c.read(shopProvider).revives, 0, reason: 'verbraucht');
  });

  test('die Steinfolge bleibt die des Spielcodes', () {
    final c = aufbau(revives: 1);
    final vorher = c.read(gameControllerProvider).handIndex;
    c.read(gameControllerProvider.notifier).revive();

    final nachher = c.read(gameControllerProvider);
    expect(nachher.handIndex, greaterThan(vorher),
        reason: 'weitergezogen statt neu gewuerfelt');
    expect(nachher.seed, 4242);
  });

  test('in einer laufenden Runde bewirkt es nichts', () {
    final c = ProviderContainer.test(
      overrides: [
        soundOutputProvider.overrideWithValue(RecordingOutput()),
        seedSourceProvider.overrideWithValue(() => 1),
        initialShopProvider.overrideWithValue(const ShopState(revives: 2)),
      ],
    );

    expect(c.read(gameControllerProvider.notifier).revive(), isFalse);
    expect(c.read(shopProvider).revives, 2, reason: 'nichts verbraucht');
  });
}
