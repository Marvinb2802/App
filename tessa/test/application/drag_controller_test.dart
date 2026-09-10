import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/cell.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/rules/placement.dart';

ProviderContainer containerWithSeed(int seed) => ProviderContainer.test(
      overrides: [seedSourceProvider.overrideWithValue(() => seed)],
    );

void main() {
  group('DragController', () {
    test('beginnt ohne laufenden Zug', () {
      final container = containerWithSeed(1);
      expect(container.read(dragControllerProvider).isActive, isFalse);
      expect(container.read(dragPreviewProvider).isActive, isFalse);
    });

    test('merkt sich Teil und Zielfeld', () {
      final container = containerWithSeed(1);
      final drag = container.read(dragControllerProvider.notifier);

      drag.start(1);
      expect(container.read(dragControllerProvider).slot, 1);

      drag.moveTo(2, 3);
      expect(container.read(dragControllerProvider).anchor, const Cell(2, 3));

      drag.leaveBoard();
      expect(container.read(dragControllerProvider).anchor, isNull);
      expect(container.read(dragControllerProvider).isActive, isTrue);

      drag.cancel();
      expect(container.read(dragControllerProvider).isActive, isFalse);
    });

    test('ohne begonnenen Zug bewirkt moveTo nichts', () {
      final container = containerWithSeed(1);
      container.read(dragControllerProvider.notifier).moveTo(4, 4);
      expect(container.read(dragControllerProvider).isActive, isFalse);
    });

    test('die Vorschau zeigt die Zellen und ob der Zug erlaubt ist', () {
      final container = containerWithSeed(12345);
      final drag = container.read(dragControllerProvider.notifier);
      final game = container.read(gameControllerProvider);
      final piece = game.hand.pieceAt(0)!;
      final spot = placementsFor(game.board, piece).first;

      drag.start(0);
      drag.moveTo(spot.x, spot.y);

      final preview = container.read(dragPreviewProvider);
      expect(preview.isActive, isTrue);
      expect(preview.isValid, isTrue);
      expect(preview.cells.length, piece.cellCount);
      expect(preview.cells, contains(Cell(spot.x, spot.y)));
    });

    test('die Vorschau meldet ein Ziel ausserhalb des Rasters als ungueltig', () {
      final container = containerWithSeed(12345);
      final drag = container.read(dragControllerProvider.notifier);

      drag.start(0);
      drag.moveTo(7, 7);

      final preview = container.read(dragPreviewProvider);
      expect(preview.isActive, isTrue);
      expect(preview.isValid, isFalse);
      expect(preview.cells, isNotEmpty,
          reason: 'die Oberflaeche zeigt auch den ungueltigen Zug an');
    });

    test('ein Abwurf auf einem gueltigen Feld fuehrt den Zug aus', () {
      final container = containerWithSeed(2024);
      final drag = container.read(dragControllerProvider.notifier);
      final before = container.read(gameControllerProvider);
      final spot = placementsFor(before.board, before.hand.pieceAt(0)!).first;

      drag.start(0);
      drag.moveTo(spot.x, spot.y);
      expect(drag.drop(), isTrue);

      final after = container.read(gameControllerProvider);
      expect(after.hand.pieceAt(0), isNull);
      expect(after.score, greaterThan(0));
      expect(container.read(dragControllerProvider).isActive, isFalse,
          reason: 'der Zug ist beendet');
    });

    test('ein Abwurf neben dem Brett endet ohne Zug', () {
      final container = containerWithSeed(2024);
      final drag = container.read(dragControllerProvider.notifier);
      final before = container.read(gameControllerProvider);

      drag.start(0);
      drag.leaveBoard();
      expect(drag.drop(), isFalse);

      expect(container.read(gameControllerProvider), same(before));
      expect(container.read(dragControllerProvider).isActive, isFalse);
    });

    test('ein Abwurf auf einem belegten Feld endet ohne Zug', () {
      final container = containerWithSeed(2024);
      final drag = container.read(dragControllerProvider.notifier);
      final game = container.read(gameControllerProvider.notifier);
      final start = container.read(gameControllerProvider);
      final spot = placementsFor(start.board, start.hand.pieceAt(0)!).first;

      game.place(slot: 0, x: spot.x, y: spot.y);
      final occupied = container.read(gameControllerProvider);

      // Ein Handplatz mit einem Ankerpunkt, an dem das Teil ueberlappt.
      // Nicht jede Form erreicht jedes belegte Feld: ein Teil ohne Zelle in
      // der linken oberen Ecke kaeme dafuer nur von ausserhalb des Rasters.
      int? blockedSlot;
      Cell? blocked;
      for (var slot = 1; slot < Hand.slotCount && blocked == null; slot++) {
        final piece = occupied.hand.pieceAt(slot)!;
        for (var y = 0; y <= Board.size - piece.height && blocked == null; y++) {
          for (var x = 0; x <= Board.size - piece.width; x++) {
            if (!canPlace(occupied.board, piece, x, y)) {
              blockedSlot = slot;
              blocked = Cell(x, y);
              break;
            }
          }
        }
      }
      expect(blocked, isNotNull, reason: 'kein ueberlappender Ankerpunkt gefunden');

      drag.start(blockedSlot!);
      drag.moveTo(blocked!.x, blocked.y);
      expect(container.read(dragPreviewProvider).isValid, isFalse);
      expect(drag.drop(), isFalse);
      expect(container.read(gameControllerProvider), same(occupied));
      expect(container.read(dragControllerProvider).isActive, isFalse);
    });
  });
}
