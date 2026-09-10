import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/game_controller.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/rules/placement.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() => ProviderContainer.test(
        overrides: [seedSourceProvider.overrideWithValue(() => 4242)],
      );

  void spieleZug(ProviderContainer c) {
    final controller = c.read(gameControllerProvider.notifier);
    final state = c.read(gameControllerProvider);
    final slot = state.hand.slots.indexWhere((piece) => piece != null);
    final spot = placementsFor(state.board, state.hand.slots[slot]!).first;
    controller.place(slot: slot, x: spot.x, y: spot.y);
  }

  test('im Tueftel-Modus geht es bis zum Anfang zurueck', () {
    final c = container();
    c.read(gameModeProvider.notifier).set(GameMode.practice);
    final controller = c.read(gameControllerProvider.notifier);
    final anfang = c.read(gameControllerProvider);

    for (var i = 0; i < 8; i++) {
      spieleZug(c);
    }
    expect(c.read(gameControllerProvider).score, greaterThan(0));

    var zurueck = 0;
    while (controller.undo()) {
      zurueck += 1;
    }

    expect(zurueck, 8, reason: 'jeder Zug laesst sich zuruecknehmen');
    final jetzt = c.read(gameControllerProvider);
    expect(jetzt.score, anfang.score);
    expect(jetzt.board, equals(anfang.board));
    expect(jetzt.hand, equals(anfang.hand));
    expect(jetzt.handIndex, anfang.handIndex);
  });

  test('im Tueftel-Modus bleiben die Undo-Versuche unangetastet', () {
    final c = container();
    c.read(gameModeProvider.notifier).set(GameMode.practice);
    final controller = c.read(gameControllerProvider.notifier);

    spieleZug(c);
    spieleZug(c);
    controller.undo();
    controller.undo();

    expect(c.read(gameControllerProvider).undosLeft, GameState.undosPerRound);
  });

  test('in der normalen Runde bleibt es bei drei', () {
    final c = container();
    final controller = c.read(gameControllerProvider.notifier);

    for (var i = 0; i < 6; i++) {
      spieleZug(c);
    }
    var zurueck = 0;
    while (controller.undo()) {
      zurueck += 1;
    }

    expect(zurueck, GameState.undosPerRound);
    expect(c.read(gameControllerProvider).undosLeft, 0);
  });

  test('der Modus wechselt nicht von allein', () {
    final c = container();
    expect(c.read(gameModeProvider), GameMode.normal);
    c.read(gameModeProvider.notifier).set(GameMode.daily);
    c.read(gameControllerProvider.notifier).restart(seed: 5);
    expect(c.read(gameModeProvider), GameMode.daily);
  });

  test('GameController ist auch ohne Speicher benutzbar', () {
    final c = container();
    expect(c.read(gameControllerProvider.notifier), isA<GameController>());
    spieleZug(c);
    expect(c.read(gameControllerProvider).score, greaterThan(0));
  });
}
