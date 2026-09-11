import '../generation/seeded_random.dart';
import '../model/board.dart';
import '../model/cell.dart';
import '../model/game_state.dart';
import 'clearing.dart';
import 'game_over.dart';

/// Die Regeln, die nur im Hardcore-Modus gelten.
///
/// Zwei Dinge machen ihn hart. Das eine sind die Teile: Hardcore zieht aus
/// [PieceSet.hardcore], wo der Punkt und die kurzen Balken selten sind und
/// sperrige Formen haeufig. Das andere steht hier — das Geroell.
///
/// WICHTIG fuer die Fairness-Garantie (CLAUDE.md): Die *Steinfolge* bleibt
/// unberuehrt. Sie kommt weiterhin allein aus Spielcode und Handindex; diese
/// Datei fasst nur das Brett an und liegt deshalb auch nicht in
/// `domain/generation/`. Wo das Geroell landet, haengt vom Spielcode, von der
/// Zugnummer und davon ab, welche Felder frei sind — bei gleichem Code und
/// gleichen Zuegen also immer gleich. Eine Runde bleibt damit nachspielbar.
class Hardcore {
  Hardcore._();

  /// Nach jedem so vielten Zug faellt ein Stein.
  static const int rubbleEveryMoves = 3;

  /// Wie viele Zuege am Anfang verschont bleiben.
  ///
  /// Ohne diese Schonfrist faellt schon in der ersten Hand Geroell, bevor
  /// ueberhaupt etwas aufzuloesen war.
  static const int gracePeriod = 6;
}

/// Laesst nach jedem dritten Zug einen Stein auf ein freies Feld fallen.
///
/// [moveNumber] ist die laufende Nummer des gerade gespielten Zuges (der erste
/// Zug einer Runde ist 1). Faellt bei diesem Zug nichts, kommt der Spielstand
/// unveraendert zurueck.
///
/// Schliesst das Geroell zufaellig eine Linie, loest sie sich auf wie immer —
/// Punkte gibt es dafuer keine, denn gelegt hat den Stein niemand.
GameState dropRubble(GameState state, {required int moveNumber}) {
  if (state.isOver) return state;
  if (moveNumber <= Hardcore.gracePeriod) return state;
  if (moveNumber % Hardcore.rubbleEveryMoves != 0) return state;

  final frei = <Cell>[
    for (var y = 0; y < Board.size; y++)
      for (var x = 0; x < Board.size; x++)
        if (state.board.isFree(x, y)) Cell(x, y),
  ];
  if (frei.isEmpty) return state;

  // Der Spielcode allein wuerde bei jedem Zug dasselbe Feld liefern; die
  // Zugnummer macht daraus eine Folge. Beides sind kleine Zahlen — der
  // Generator maskiert auf 32 Bit, die Folge ist also im Web dieselbe.
  final random = SeededRandom(state.seed + moveNumber * 7919);
  final ziel = frei[random.nextIntBelow(frei.length)];

  final board = resolveLines(state.board.fill([ziel])).board;
  return state.copyWith(
    board: board,
    isOver: isGameOver(board, state.hand),
  );
}
