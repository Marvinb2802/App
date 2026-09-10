import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/application/hint_controller.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/domain/rules/placement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container({int seed = 2024}) => ProviderContainer.test(
        overrides: [seedSourceProvider.overrideWithValue(() => seed)],
      );

  test('drei Hinweise je Runde', () {
    final c = container();
    final hints = c.read(hintProvider.notifier);

    expect(c.read(hintProvider).left, HintState.perRound);
    expect(hints.request(), isTrue);
    expect(c.read(hintProvider).left, 2);
    expect(c.read(hintProvider).shown, isNotNull);

    expect(hints.request(), isTrue);
    expect(hints.request(), isTrue);
    expect(c.read(hintProvider).left, 0);
    expect(hints.request(), isFalse, reason: 'aufgebraucht');
  });

  test('der Vorschlag passt wirklich aufs Brett', () {
    final c = container();
    c.read(hintProvider.notifier).request();

    final hint = c.read(hintProvider).shown!;
    final game = c.read(gameControllerProvider);
    final piece = game.hand.pieceAt(hint.slot)!;
    expect(canPlace(game.board, piece, hint.at.x, hint.at.y), isTrue);
  });

  test('nach einem Zug ist der Vorschlag weg', () {
    final c = container();
    c.read(hintProvider.notifier).request();
    expect(c.read(hintProvider).shown, isNotNull);

    final game = c.read(gameControllerProvider);
    final spot = placementsFor(game.board, game.hand.pieceAt(0)!).first;
    c.read(gameControllerProvider.notifier).place(slot: 0, x: spot.x, y: spot.y);

    expect(c.read(hintProvider).shown, isNull);
    expect(c.read(hintProvider).left, 2, reason: 'verbraucht bleibt verbraucht');
  });

  test('im Tueftel-Modus sind Hinweise unbegrenzt', () {
    final c = container();
    c.read(gameModeProvider.notifier).set(GameMode.practice);
    final hints = c.read(hintProvider.notifier);

    for (var i = 0; i < 10; i++) {
      expect(hints.request(), isTrue, reason: 'Versuch $i');
    }
    expect(c.read(hintProvider).left, HintState.perRound);
  });

  test('eine neue Runde bringt die Hinweise zurueck', () {
    final c = container();
    c.read(hintProvider.notifier).request();
    c.read(hintProvider.notifier).request();
    expect(c.read(hintProvider).left, 1);

    c.read(gameControllerProvider.notifier).restart();
    expect(c.read(hintProvider).left, HintState.perRound);
    expect(c.read(hintProvider).shown, isNull);
  });
}
