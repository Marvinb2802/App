import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/model/hand.dart';
import '../theme/tessa_theme.dart';
import 'board_view.dart';
import 'piece_view.dart';

/// Die drei Teile in der Hand. Nachschub kommt erst, wenn alle drei liegen.
class PieceTray extends ConsumerWidget {
  const PieceTray({super.key, required this.boardCellSize});

  /// Die Kantenlaenge eines Bretts-Feldes; das gezogene Teil wird in dieser
  /// Groesse dargestellt, damit die Vorschau zum Ziel passt.
  final double boardCellSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hand = ref.watch(gameControllerProvider).hand;
    final trayCellSize = boardCellSize * 0.6;
    return SizedBox(
      height: trayCellSize * 5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var slot = 0; slot < Hand.slotCount; slot++)
            Expanded(
              child: Center(
                child: _slot(context, ref, hand, slot, trayCellSize),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slot(
    BuildContext context,
    WidgetRef ref,
    Hand hand,
    int slot,
    double trayCellSize,
  ) {
    final piece = hand.pieceAt(slot);
    if (piece == null) {
      return SizedBox(
        key: Key('tray-empty-$slot'),
        width: trayCellSize * 2,
        height: trayCellSize * 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cellRadius(trayCellSize)),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      );
    }

    final drag = ref.read(dragControllerProvider.notifier);
    return Draggable<int>(
      key: Key('tray-$slot'),
      data: slot,
      dragAnchorStrategy: (_, _, _) => pieceDragAnchor(piece, boardCellSize),
      feedback: PieceView(piece: piece, cellSize: boardCellSize),
      childWhenDragging:
          PieceView(piece: piece, cellSize: trayCellSize, opacity: 0.25),
      onDragStarted: () => drag.start(slot),
      onDragEnd: (details) {
        if (!details.wasAccepted) drag.cancel();
      },
      onDraggableCanceled: (_, _) => drag.cancel(),
      child: PieceView(piece: piece, cellSize: trayCellSize),
    );
  }
}
