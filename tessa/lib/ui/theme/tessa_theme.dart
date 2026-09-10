import 'package:flutter/material.dart';

import '../../domain/model/piece.dart';

ThemeData tessaTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4C6EF5),
    brightness: brightness,
  );
  return ThemeData(colorScheme: scheme, useMaterial3: true);
}

/// Feste Farben nach Zellenzahl: gleich grosse Teile sehen gleich aus, und die
/// Hand bleibt auf einen Blick unterscheidbar.
const List<Color> _pieceColors = [
  Color(0xFF4C6EF5),
  Color(0xFF12B886),
  Color(0xFFF59F00),
  Color(0xFFE8590C),
  Color(0xFFAE3EC9),
];

Color pieceColor(Piece piece) =>
    _pieceColors[(piece.cellCount - 1) % _pieceColors.length];

/// Radius und Abstand einer Zelle, abhaengig von ihrer Kantenlaenge.
double cellRadius(double cellSize) => cellSize * 0.18;

double cellInset(double cellSize) => cellSize * 0.06;
