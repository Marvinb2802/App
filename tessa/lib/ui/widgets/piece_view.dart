import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/shop.dart';
import '../../domain/model/piece.dart';
import '../theme/tessa_theme.dart';
import 'cell_tile.dart';

/// Stellt ein Teil in seiner eigenen Groesse dar.
class PieceView extends ConsumerWidget {
  const PieceView({
    super.key,
    required this.piece,
    required this.cellSize,
    this.opacity = 1,
  });

  final Piece piece;
  final double cellSize;
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = pieceColor(piece, ref.watch(shopProvider).palette);
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: piece.width * cellSize,
        height: piece.height * cellSize,
        child: Stack(
          children: [
            // Fasst die ganze Flaeche des Teils an, nicht nur die Kacheln:
            // sonst greift ein Finger in der Luecke dazwischen ins Leere.
            const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
            for (final cell in piece.cells)
              Positioned(
                left: cell.x * cellSize,
                top: cell.y * cellSize,
                child: CellTile(size: cellSize, color: color),
              ),
          ],
        ),
      ),
    );
  }
}
