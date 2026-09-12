import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/model/board.dart';
import '../../domain/model/cell.dart';
import '../../domain/model/game_state.dart';

/// Ein einzelner Funke einer gefallenen Linie.
///
/// Alles steht in Brettkoordinaten (Pixel, Ursprung oben links) und wird
/// **einmal** beim Zug gewuerfelt — nicht je Bild. Sonst zappelte der Funke,
/// statt zu fliegen.
class Funke {
  const Funke({
    required this.start,
    required this.flug,
    required this.farbe,
    required this.groesse,
    required this.drall,
  });

  /// Wo er losfliegt.
  final Offset start;

  /// Wie weit er bis zum Ende des Fortschritts kommt (ohne Schwerkraft).
  final Offset flug;

  final Color farbe;

  /// Kantenlaenge in Pixeln am Anfang.
  final double groesse;

  /// Umdrehungen bis zum Ende.
  final double drall;

  /// Wo der Funke bei [t] (0..1) steht. Die Schwerkraft zieht ihn nach unten,
  /// damit es nach Truemmern aussieht und nicht nach einem Feuerwerk.
  Offset positionBei(double t, double fall) =>
      start + flug * t + Offset(0, fall * t * t);
}

/// Ob [next] einen *neuen* Zug zeigt — und welchen.
///
/// Die eine Stelle, an der diese Frage beantwortet wird: Brett, Ruettler und
/// Banner haengen alle daran. Ein Undo stellt einen aelteren Zug wieder her und
/// senkt dabei die Punktzahl; dann darf sich nichts ruehren.
MoveOutcome? neuerZug(GameState? previous, GameState next) {
  if (previous == null) return null;
  final move = next.lastMove;
  if (move == null) return null;
  if (next.score <= previous.score) return null;
  if (identical(move, previous.lastMove)) return null;
  return move;
}

/// Wie viele Funken je geraeumter Zelle.
const int funkenJeZelle = 6;

/// Obergrenze. Vier Linien sind 32 Zellen — ohne Deckel waeren das fast 200
/// Funken auf einmal, und das Telefon soll ruhig bleiben.
const int maxFunken = 220;

/// Wie weit die Schwerkraft einen Funken bis zum Ende zieht, in Zellen.
const double funkenFall = 5.5;

/// Die Zellen, die dieser Zug geraeumt hat.
Set<Cell> geraeumteZellen(MoveOutcome move) => {
      for (final y in move.clearedRows)
        for (var x = 0; x < Board.size; x++) Cell(x, y),
      for (final x in move.clearedColumns)
        for (var y = 0; y < Board.size; y++) Cell(x, y),
    };

/// Wuerfelt die Funken eines Zuges.
///
/// [seed] macht das wiederholbar — zwei gleiche Zuege sehen gleich aus, und
/// Tests koennen sich darauf verlassen.
List<Funke> funkenFuer(
  MoveOutcome move, {
  required double cellSize,
  required List<Color> farben,
  required int seed,
}) {
  final zellen = geraeumteZellen(move).toList();
  if (zellen.isEmpty) return const [];

  // Je mehr Zellen, desto weniger Funken je Zelle — die Summe bleibt unter dem
  // Deckel, das Bild bleibt voll.
  final jeZelle = math.max(2, math.min(funkenJeZelle, maxFunken ~/ zellen.length));
  final zufall = math.Random(seed);
  final wucht = 1 + 0.25 * (move.clearedLines - 1);

  return [
    for (final zelle in zellen)
      for (var i = 0; i < jeZelle; i++)
        () {
          final winkel = zufall.nextDouble() * 2 * math.pi;
          final tempo = cellSize * (0.8 + zufall.nextDouble() * 2.4) * wucht;
          return Funke(
            start: Offset(
              (zelle.x + zufall.nextDouble()) * cellSize,
              (zelle.y + zufall.nextDouble()) * cellSize,
            ),
            flug: Offset(math.cos(winkel), math.sin(winkel) * 0.8) * tempo,
            farbe: farben[zufall.nextInt(farben.length)],
            groesse: cellSize * (0.12 + zufall.nextDouble() * 0.22),
            drall: (zufall.nextDouble() - 0.5) * 2.4,
          );
        }(),
  ];
}

/// Das Wort, das bei einer Aufloesung gross aufpoppt.
String raeumWort(int linien) => switch (linien) {
      <= 0 => '',
      1 => 'GUT',
      2 => 'DOPPEL',
      3 => 'DREIFACH',
      4 => 'VIERFACH',
      _ => 'UNFASSBAR',
    };

/// Wie stark das Bild bei so vielen Linien wackeln darf, in Pixeln.
double ruettelWeite(int linien) => switch (linien) {
      <= 0 => 0,
      1 => 3,
      2 => 7,
      3 => 11,
      _ => 15,
    };

/// Alles, was bei einer gefallenen Linie ueber dem Brett passiert: ein
/// Lichtbalken faehrt durch die Linie, Funken fliegen, eine Druckwelle laeuft
/// nach aussen.
class ClearBurst extends StatelessWidget {
  const ClearBurst({
    super.key,
    required this.move,
    required this.funken,
    required this.cellSize,
    required this.animation,
  });

  final MoveOutcome move;
  final List<Funke> funken;
  final double cellSize;
  final Animation<double> animation;

  /// Wie lange der ganze Ausbruch dauert.
  static const Duration duration = Duration(milliseconds: 720);

  @override
  Widget build(BuildContext context) {
    final side = cellSize * Board.size;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          key: const Key('clear-burst'),
          size: Size(side, side),
          painter: _BurstPainter(
            move: move,
            funken: funken,
            cellSize: cellSize,
            animation: animation,
            glanz: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.move,
    required this.funken,
    required this.cellSize,
    required this.animation,
    required this.glanz,
  }) : super(repaint: animation);

  final MoveOutcome move;
  final List<Funke> funken;
  final double cellSize;
  final Animation<double> animation;
  final Color glanz;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t <= 0 || t >= 1) return;

    _blitz(canvas, size, t);
    _lichtbalken(canvas, size, t);
    _druckwelle(canvas, size, t);
    _funken(canvas, t);
  }

  /// Ab drei Linien wird kurz das ganze Brett hell.
  void _blitz(Canvas canvas, Size size, double t) {
    if (move.clearedLines < 3) return;
    final staerke = (1 - t * 5).clamp(0.0, 1.0) * 0.35;
    if (staerke <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: staerke),
    );
  }

  /// Ein heller Balken faehrt einmal durch jede gefallene Linie.
  void _lichtbalken(Canvas canvas, Size size, double t) {
    final lauf = Curves.easeOutCubic.transform((t / 0.45).clamp(0.0, 1.0));
    if (lauf >= 1) return;
    final deckkraft = 1 - lauf;
    final breite = cellSize * 2.6;
    final weg = size.width + breite * 2;

    for (final y in move.clearedRows) {
      final mitte = -breite + lauf * weg;
      _balken(
        canvas,
        Rect.fromLTWH(mitte - breite / 2, y * cellSize, breite, cellSize),
        waagerecht: true,
        deckkraft: deckkraft,
      );
    }
    for (final x in move.clearedColumns) {
      final mitte = -breite + lauf * weg;
      _balken(
        canvas,
        Rect.fromLTWH(x * cellSize, mitte - breite / 2, cellSize, breite),
        waagerecht: false,
        deckkraft: deckkraft,
      );
    }
  }

  void _balken(Canvas canvas, Rect rect,
      {required bool waagerecht, required double deckkraft}) {
    final farben = [
      Colors.white.withValues(alpha: 0),
      Colors.white.withValues(alpha: 0.9 * deckkraft),
      glanz.withValues(alpha: 0.75 * deckkraft),
      Colors.white.withValues(alpha: 0),
    ];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: waagerecht ? Alignment.centerLeft : Alignment.topCenter,
          end: waagerecht ? Alignment.centerRight : Alignment.bottomCenter,
          colors: farben,
          stops: const [0, 0.4, 0.6, 1],
        ).createShader(rect),
    );
  }

  /// Eine Druckwelle vom Kreuzungspunkt der gefallenen Linien nach aussen.
  void _druckwelle(Canvas canvas, Size size, double t) {
    final lauf = Curves.easeOutQuart.transform((t / 0.6).clamp(0.0, 1.0));
    if (lauf >= 1) return;

    final mitte = Offset(
      move.clearedColumns.isEmpty
          ? size.width / 2
          : (move.clearedColumns.reduce((a, b) => a + b) /
                  move.clearedColumns.length +
              0.5) *
              cellSize,
      move.clearedRows.isEmpty
          ? size.height / 2
          : (move.clearedRows.reduce((a, b) => a + b) / move.clearedRows.length +
                  0.5) *
              cellSize,
    );

    canvas.drawCircle(
      mitte,
      lauf * size.width * 0.85,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.5 * (1 - lauf)
        ..color = Colors.white.withValues(alpha: 0.55 * (1 - lauf)),
    );
  }

  void _funken(Canvas canvas, double t) {
    final fall = cellSize * funkenFall;
    final schwund = (1 - t * t).clamp(0.0, 1.0);
    if (schwund <= 0) return;

    for (final funke in funken) {
      final pos = funke.positionBei(t, fall);
      final kante = funke.groesse * (1 - 0.45 * t);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(funke.drall * t * 2 * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: kante, height: kante),
          Radius.circular(kante * 0.3),
        ),
        Paint()..color = funke.farbe.withValues(alpha: schwund),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.move != move || old.funken != funken || old.cellSize != cellSize;
}
