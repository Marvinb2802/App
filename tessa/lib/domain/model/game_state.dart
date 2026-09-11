import 'board.dart';
import 'cell.dart';
import 'hand.dart';
import 'piece_catalog.dart';

/// Was ein einzelner Zug bewirkt hat. Die Oberflaeche braucht das fuer
/// Rueckmeldungen ("+240", Combo-Anzeige, Raeum-Animation).
///
/// [appliedCombo] ist der Faktor, mit dem dieser Zug bewertet wurde — also der
/// Combo-Stand *vor* dem Erhoehen. Der Wert in [GameState.combo] ist danach
/// bereits der Stand fuer den naechsten Zug.
class MoveOutcome {
  const MoveOutcome({
    required this.placedCells,
    required this.clearedRows,
    required this.clearedColumns,
    required this.appliedCombo,
    required this.points,
  });

  /// Die Zellen, die das Teil belegt hat — in Brettkoordinaten, damit die
  /// Oberflaeche sie hervorheben kann. Manche davon sind im selben Zug wieder
  /// gefallen, wenn sie in einer vollen Linie lagen.
  final List<Cell> placedCells;

  final List<int> clearedRows;
  final List<int> clearedColumns;
  final int appliedCombo;
  final int points;

  int get placedCellCount => placedCells.length;

  int get clearedLines => clearedRows.length + clearedColumns.length;

  bool get didClear => clearedLines > 0;

  @override
  String toString() =>
      'Zug: $placedCellCount Zellen, $clearedLines Linien, '
      'Combo $appliedCombo, $points Punkte';
}

/// Der vollstaendige Spielstand einer Runde.
///
/// Enthaelt alles, was ein Undo zuruecknehmen muss — insbesondere [handIndex],
/// die Position in der Steinsequenz. Ein Undo, das die Position stehen liesse,
/// waere ein Leck in der Fairness-Garantie (siehe CLAUDE.md).
class GameState {
  const GameState({
    required this.seed,
    required this.handIndex,
    required this.board,
    required this.hand,
    required this.score,
    required this.combo,
    required this.undosLeft,
    required this.isOver,
    this.pieces = PieceSet.standard,
    this.lastMove,
  });

  /// Undo-Versuche je Runde (eine Partie bis zum Game over).
  static const int undosPerRound = 3;

  final int seed;

  /// Die wievielte Hand der Steinsequenz gerade im Spiel ist.
  final int handIndex;

  final Board board;
  final Hand hand;
  final int score;
  final int combo;
  final int undosLeft;
  final bool isOver;

  /// Aus welchem Satz Gewichte die Steinfolge kommt. Gehoert zur Runde wie der
  /// Seed: Hardcore zieht dieselben Formen, aber anders haeufig.
  final PieceSet pieces;

  final MoveOutcome? lastMove;

  bool get canUndo => undosLeft > 0;

  GameState copyWith({
    int? handIndex,
    Board? board,
    Hand? hand,
    int? score,
    int? combo,
    int? undosLeft,
    bool? isOver,
    PieceSet? pieces,
    MoveOutcome? lastMove,
  }) {
    return GameState(
      seed: seed,
      handIndex: handIndex ?? this.handIndex,
      board: board ?? this.board,
      hand: hand ?? this.hand,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      undosLeft: undosLeft ?? this.undosLeft,
      isOver: isOver ?? this.isOver,
      pieces: pieces ?? this.pieces,
      lastMove: lastMove ?? this.lastMove,
    );
  }
}
