import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/sound.dart';

import '../support/fake_sound.dart';
import 'package:tessa/application/game_controller.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/domain/generation/piece_sequence.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/rules/placement.dart';

ProviderContainer containerWithSeed(int seed) => ProviderContainer.test(
      overrides: [soundOutputProvider.overrideWithValue(RecordingOutput()), seedSourceProvider.overrideWithValue(() => seed)],
    );

/// Legt das erste noch vorhandene Teil auf den ersten passenden Platz.
bool playFirstFit(GameController controller, GameState state) {
  final slot = state.hand.slots.indexWhere((piece) => piece != null);
  final spot = placementsFor(state.board, state.hand.slots[slot]!).first;
  return controller.place(slot: slot, x: spot.x, y: spot.y);
}

void main() {
  // Die Vibration spricht einen Plattformkanal an; dafuer muss die Bindung
  // stehen, auch in reinen Dart-Tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameController', () {
    test('startet mit dem Seed aus der Quelle', () {
      final container = containerWithSeed(4242);
      final state = container.read(gameControllerProvider);

      expect(state.seed, 4242);
      expect(state.hand, equals(const PieceSequence(4242).handAt(0)));
      expect(state.score, 0);
      expect(state.undosLeft, 3);
    });

    test('fuehrt einen erlaubten Zug aus', () {
      final container = containerWithSeed(1);
      final controller = container.read(gameControllerProvider.notifier);
      final before = container.read(gameControllerProvider);

      expect(playFirstFit(controller, before), isTrue);

      final after = container.read(gameControllerProvider);
      expect(after.score, greaterThan(0));
      expect(after.hand.remainingCount, 2);
      expect(after.board.isEmpty, isFalse);
    });

    test('weist einen unerlaubten Zug zurueck und aendert nichts', () {
      final container = containerWithSeed(1);
      final controller = container.read(gameControllerProvider.notifier);
      final before = container.read(gameControllerProvider);

      // Ausserhalb des Rasters.
      expect(controller.place(slot: 0, x: 7, y: 7), isFalse);
      expect(controller.canPlace(0, 7, 7), isFalse);
      expect(container.read(gameControllerProvider), same(before));
    });

    test('nimmt einen Zug vollstaendig zurueck', () {
      final container = containerWithSeed(99);
      final controller = container.read(gameControllerProvider.notifier);
      final before = container.read(gameControllerProvider);

      playFirstFit(controller, before);
      expect(controller.undo(), isTrue);

      final after = container.read(gameControllerProvider);
      expect(after.score, before.score);
      expect(after.board, equals(before.board));
      expect(after.hand, equals(before.hand));
      expect(after.handIndex, before.handIndex);
      expect(after.undosLeft, 2, reason: 'ein Versuch ist verbraucht');
    });

    test('erlaubt genau drei Undo je Runde', () {
      final container = containerWithSeed(7);
      final controller = container.read(gameControllerProvider.notifier);

      for (var i = 0; i < 6; i++) {
        playFirstFit(controller, container.read(gameControllerProvider));
      }
      expect(controller.undo(), isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.undo(), isTrue);
      expect(controller.undo(), isFalse);
      expect(container.read(gameControllerProvider).undosLeft, 0);
    });

    test('ohne Zug gibt es nichts zurueckzunehmen', () {
      final container = containerWithSeed(5);
      final controller = container.read(gameControllerProvider.notifier);

      expect(controller.undo(), isFalse);
      expect(container.read(gameControllerProvider).undosLeft, 3);
    });

    test('nimmt auch den Nachschub zurueck', () {
      final container = containerWithSeed(2024);
      final controller = container.read(gameControllerProvider.notifier);

      // Alle drei Teile legen, damit eine neue Hand kommt.
      for (var i = 0; i < 3; i++) {
        playFirstFit(controller, container.read(gameControllerProvider));
      }
      expect(container.read(gameControllerProvider).handIndex, 1);

      controller.undo();
      final after = container.read(gameControllerProvider);
      expect(after.handIndex, 0,
          reason: 'sonst liesse sich die naechste Hand abgreifen');
      expect(after.hand.remainingCount, 1);
    });

    test('restart beginnt eine neue Runde und leert den Verlauf', () {
      var seed = 10;
      final container = ProviderContainer.test(
        overrides: [soundOutputProvider.overrideWithValue(RecordingOutput()), seedSourceProvider.overrideWithValue(() => seed)],
      );
      final controller = container.read(gameControllerProvider.notifier);

      playFirstFit(controller, container.read(gameControllerProvider));
      seed = 20;
      controller.restart();

      final state = container.read(gameControllerProvider);
      expect(state.seed, 20);
      expect(state.score, 0);
      expect(state.undosLeft, 3);
      expect(state.board.isEmpty, isTrue);
      expect(controller.undo(), isFalse, reason: 'der Verlauf ist geleert');
    });

    test('replay spielt dieselbe Runde noch einmal', () {
      final container = containerWithSeed(31337);
      final controller = container.read(gameControllerProvider.notifier);
      final first = container.read(gameControllerProvider);

      playFirstFit(controller, first);
      controller.replay();

      final again = container.read(gameControllerProvider);
      expect(again.seed, 31337);
      expect(again.hand, equals(first.hand));
      expect(again.score, 0);
    });
  });
}
