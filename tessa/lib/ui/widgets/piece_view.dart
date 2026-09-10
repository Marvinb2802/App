import 'package:flutter/material.dart';

import '../../domain/model/piece.dart';
import '../theme/tessa_theme.dart';
import 'cell_tile.dart';

/// Stellt ein Teil in seiner eigenen Groesse dar.
class PieceView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final color = pieceColor(piece);
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
