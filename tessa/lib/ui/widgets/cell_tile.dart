import 'package:flutter/material.dart';

import '../theme/tessa_theme.dart';

/// Ein einzelnes Feld — auf dem Brett wie in der Hand.
class CellTile extends StatelessWidget {
  const CellTile({
    super.key,
    required this.size,
    required this.color,
    this.border,
  });

  final double size;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(cellInset(size)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(cellRadius(size)),
          border: border == null ? null : Border.all(color: border!, width: 1.5),
        ),
      ),
    );
  }
}
