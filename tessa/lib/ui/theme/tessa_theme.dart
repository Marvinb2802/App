import 'package:flutter/material.dart';

import '../../domain/model/piece.dart';

/// Dunkel und ruhig: tiefer Hintergrund, klare Flaechen, kraeftige Teile.
const Color tessaBackground = Color(0xFF0E1118);
const Color tessaSurface = Color(0xFF161B26);
const Color tessaSurfaceHigh = Color(0xFF1F2634);
const Color tessaAccent = Color(0xFF6C8BFF);
const Color tessaEmptyCell = Color(0xFF232B3A);

ThemeData tessaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: tessaAccent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: tessaBackground,
    primary: tessaAccent,
    surfaceContainerHighest: tessaEmptyCell,
    surfaceContainer: tessaSurface,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: tessaBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: tessaSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Feste Farben nach Zellenzahl: gleich grosse Teile sehen gleich aus, und die
/// Hand bleibt auf einen Blick unterscheidbar.
///
/// Die Farbsets sind reine Kosmetik — sie aendern nichts am Spiel.
const Map<String, List<Color>> piecePalettes = {
  'standard': [
    Color(0xFF6C8BFF),
    Color(0xFF3DD6A0),
    Color(0xFFFFC44D),
    Color(0xFFFF7A59),
    Color(0xFFC77DFF),
  ],
  'neon': [
    Color(0xFF00E5FF),
    Color(0xFF39FF14),
    Color(0xFFFFF700),
    Color(0xFFFF3D71),
    Color(0xFFB026FF),
  ],
  'pastell': [
    Color(0xFFA3C4F3),
    Color(0xFFB9FBC0),
    Color(0xFFFDE4A6),
    Color(0xFFFFC9C9),
    Color(0xFFD8BBFF),
  ],
  'mono': [
    Color(0xFF3A5BC7),
    Color(0xFF5478E0),
    Color(0xFF6C8BFF),
    Color(0xFF8EA6FF),
    Color(0xFFB3C4FF),
  ],
};

Color pieceColor(Piece piece, [String palette = 'standard']) {
  final farben = piecePalettes[palette] ?? piecePalettes['standard']!;
  return farben[(piece.cellCount - 1) % farben.length];
}

/// Radius und Abstand einer Zelle, abhaengig von ihrer Kantenlaenge.
double cellRadius(double cellSize) => cellSize * 0.22;

double cellInset(double cellSize) => cellSize * 0.07;
