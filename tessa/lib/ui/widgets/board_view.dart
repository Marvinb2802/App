import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/rules/placement.dart';
import '../../domain/model/board.dart';
import '../../domain/model/cell.dart';
import '../../domain/model/game_state.dart';
import '../../domain/model/piece.dart';
import 'cell_tile.dart';

/// Wo der Finger relativ zur linken oberen Ecke des gezogenen Teils liegt.
///
/// Das Teil schwebt ueber dem Finger, damit die Hand es nicht verdeckt.
Offset pieceDragAnchor(Piece piece, double cellSize) => Offset(
      piece.width * cellSize / 2,
      piece.height * cellSize + cellSize * 0.6,
    );

/// Verschiebt den Punkt, an dem Flutter das Abwurfziel sucht, vom Finger in
/// die Mitte des gezogenen Teils.
///
/// Flutter sucht das Ziel an der Fingerposition. Da das Teil ueber dem Finger
/// schwebt, laege dieser Punkt beim Ablegen am unteren Rand ausserhalb des
/// Bretts — die unterste Reihe waere mit keinem Teil erreichbar.
Offset pieceHitOffset(Piece piece, double cellSize) =>
    Offset(0, -(piece.height * cellSize / 2 + cellSize * 0.6));

/// Das Spielbrett samt Vorschau und Abwurfziel.
class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key, required this.cellSize});

  final double cellSize;

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView>
    with TickerProviderStateMixin {
  final GlobalKey _boardKey = GlobalKey();

  /// Wie lange eine gefallene Linie nachleuchtet. Kurz genug, um beim
  /// schnellen Spielen nicht im Weg zu stehen.
  static const Duration flashDuration = Duration(milliseconds: 420);

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: flashDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _flashedMove = null);
      }
    });

  /// Wie lange ein frisch gelegtes Teil aufspringt.
  static const Duration popDuration = Duration(milliseconds: 220);

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: popDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _poppingCells = const {});
      }
    });

  /// Der Zug, dessen Linien gerade nachleuchten.
  MoveOutcome? _flashedMove;

  /// Die Zellen, die gerade aufspringen.
  Set<Cell> _poppingCells = const {};

  @override
  void dispose() {
    _flash.dispose();
    _pop.dispose();
    super.dispose();
  }

  /// Setzt die Bewegung eines neuen Zuges in Gang: das gelegte Teil springt
  /// auf, gefallene Linien leuchten nach.
  ///
  /// Nur bei einem *neuen* Zug. Ein Undo stellt einen aelteren Zug wieder her
  /// und senkt die Punktzahl; dabei soll sich nichts ruehren.
  void _onStateChanged(GameState? previous, GameState next) {
    if (previous == null) return;
    final move = next.lastMove;
    if (move == null) return;
    if (next.score <= previous.score) return;
    if (identical(move, previous.lastMove)) return;

    // Zellen, die im selben Zug wieder gefallen sind, springen nicht auf —
    // sie gehoeren zum Nachleuchten.
    final gelegt = move.placedCells
        .where((cell) => next.board.isFilled(cell.x, cell.y))
        .toSet();

    setState(() {
      _poppingCells = gelegt;
      if (move.didClear) _flashedMove = move;
    });
    if (gelegt.isNotEmpty) _pop.forward(from: 0);
    if (move.didClear) _flash.forward(from: 0);
  }

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
    ref.listen(gameControllerProvider, _onStateChanged);
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
        child: Stack(
          children: [
            _grid(context),
            _clearFlash(context),
            ..._hint(context),
            ..._preview(context),
          ],
        ),
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
              child: _maybePop(
                Cell(x, y),
                CellTile(
                  key: Key('cell-$x-$y'),
                  size: widget.cellSize,
                  color: board.isFilled(x, y)
                      ? scheme.primary
                      : scheme.surfaceContainerHighest,
                ),
              ),
            ),
      ],
    );
  }

  /// Laesst eine frisch belegte Zelle aufspringen: klein anfangen, kurz
  /// ueber die volle Groesse hinausschiessen, einrasten.
  Widget _maybePop(Cell cell, Widget tile) {
    if (!_poppingCells.contains(cell)) return tile;
    return AnimatedBuilder(
      animation: _pop,
      child: tile,
      builder: (context, child) => Transform.scale(
        key: Key('pop-${cell.x}-${cell.y}'),
        scale: 0.55 + 0.45 * Curves.easeOutBack.transform(_pop.value),
        child: child,
      ),
    );
  }

  /// Laesst die eben gefallenen Linien verblassen: aufleuchten, leicht
  /// aufblaehen, verschwinden.
  Widget _clearFlash(BuildContext context) {
    final move = _flashedMove;
    if (move == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final cells = <Cell>{
      for (final y in move.clearedRows)
        for (var x = 0; x < Board.size; x++) Cell(x, y),
      for (final x in move.clearedColumns)
        for (var y = 0; y < Board.size; y++) Cell(x, y),
    };

    return AnimatedBuilder(
      animation: _flash,
      builder: (context, _) {
        final fortschritt = _flash.value;
        return IgnorePointer(
          child: Opacity(
            opacity: 1 - fortschritt,
            child: Stack(
              key: const Key('clear-flash'),
              clipBehavior: Clip.none,
              children: [
                for (final cell in cells)
                  Positioned(
                    left: cell.x * widget.cellSize,
                    top: cell.y * widget.cellSize,
                    child: Transform.scale(
                      scale: 1 + 0.3 * fortschritt,
                      child: CellTile(
                        size: widget.cellSize,
                        color: Color.lerp(
                          scheme.onPrimaryContainer,
                          scheme.primary,
                          fortschritt,
                        )!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Zeigt den Vorschlag des Hinweis-Knopfes als Umriss auf dem Brett.
  List<Widget> _hint(BuildContext context) {
    final hint = ref.watch(hintProvider).shown;
    if (hint == null) return const [];
    final piece = ref.watch(gameControllerProvider).hand.pieceAt(hint.slot);
    if (piece == null) return const [];
    final scheme = Theme.of(context).colorScheme;

    return [
      for (final cell in cellsAt(piece, hint.at.x, hint.at.y))
        if (Board.isInside(cell.x, cell.y))
          Positioned(
            key: Key('hint-${cell.x}-${cell.y}'),
            left: cell.x * widget.cellSize,
            top: cell.y * widget.cellSize,
            child: IgnorePointer(
              child: CellTile(
                size: widget.cellSize,
                color: scheme.tertiary.withValues(alpha: 0.22),
                border: scheme.tertiary,
              ),
            ),
          ),
    ];
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
