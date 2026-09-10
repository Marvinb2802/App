import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/model/board.dart';
import '../../domain/model/piece.dart';
import 'cell_tile.dart';

/// Wo der Finger relativ zur linken oberen Ecke des gezogenen Teils liegt.
///
/// Das Teil schwebt ueber dem Finger, damit die Hand es nicht verdeckt.
Offset pieceDragAnchor(Piece piece, double cellSize) => Offset(
      piece.width * cellSize / 2,
      piece.height * cellSize + cellSize * 0.6,
    );

/// Das Spielbrett samt Vorschau und Abwurfziel.
class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key, required this.cellSize});

  final double cellSize;

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> {
  final GlobalKey _boardKey = GlobalKey();

  /// Rechnet die linke obere Ecke des gezogenen Teils in ein Feld um.
  void _aimAt(Offset globalTopLeft) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalTopLeft);
    ref.read(dragControllerProvider.notifier).moveTo(
          (local.dx / widget.cellSize).round(),
          (local.dy / widget.cellSize).round(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.cellSize * Board.size;
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) => _aimAt(details.offset),
      onLeave: (_) => ref.read(dragControllerProvider.notifier).leaveBoard(),
      onAcceptWithDetails: (details) {
        _aimAt(details.offset);
        ref.read(dragControllerProvider.notifier).drop();
      },
      builder: (context, _, _) => SizedBox(
        key: _boardKey,
        width: side,
        height: side,
        child: Stack(children: [_grid(context), ..._preview(context)]),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final board = ref.watch(gameControllerProvider).board;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        for (var y = 0; y < Board.size; y++)
          for (var x = 0; x < Board.size; x++)
            Positioned(
              left: x * widget.cellSize,
              top: y * widget.cellSize,
              child: CellTile(
                size: widget.cellSize,
                color: board.isFilled(x, y)
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
              ),
            ),
      ],
    );
  }

  /// Zeigt, wo das Teil landen wuerde — und faerbt einen unerlaubten Zug ein,
  /// statt ihn einfach nicht anzuzeigen.
  List<Widget> _preview(BuildContext context) {
    final preview = ref.watch(dragPreviewProvider);
    if (!preview.isActive) return const [];
    final scheme = Theme.of(context).colorScheme;
    final color = preview.isValid
        ? scheme.primary.withValues(alpha: 0.55)
        : scheme.error.withValues(alpha: 0.45);
    return [
      for (final cell in preview.cells)
        if (Board.isInside(cell.x, cell.y))
          Positioned(
            left: cell.x * widget.cellSize,
            top: cell.y * widget.cellSize,
            child: CellTile(
              size: widget.cellSize,
              color: color,
              border: scheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
    ];
  }
}
