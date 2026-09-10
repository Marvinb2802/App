import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/level.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/clearing.dart';
import 'package:tessa/domain/rules/game_over.dart';
import 'package:tessa/domain/rules/move.dart';
import 'package:tessa/domain/rules/placement.dart';

/// Wie eine Runde ausgegangen ist, wenn ein Automat sie spielt.
class Ergebnis {
  Ergebnis({
    required this.geschafft,
    required this.zuege,
    required this.punkte,
    required this.linien,
    required this.bestesRaeumen,
    required this.besteCombo,
    required this.festgefahren,
  });

  final bool geschafft;
  final int zuege;
  final int punkte;
  final int linien;
  final int bestesRaeumen;
  final int besteCombo;
  final bool festgefahren;
}

final _square = PieceCatalog.byId('square2');

/// Wie viel Luft ein Brett noch hat: freie Felder plus Platz fuer ein 2x2-Teil.
int _luft(Board board) =>
    (Board.cellCount - board.filledCount) +
    placementsFor(board, _square).length * 3;

/// Spielt ein Level durch: nimmt den Zug, der die meisten Linien raeumt, und
/// haelt bei Gleichstand das Brett so offen wie moeglich.
///
/// Das ist keine perfekte Spielweise, sondern eine untere Schranke — was der
/// Automat schafft, schafft ein Mensch erst recht. Umgekehrt gilt das nicht:
/// vorausschauende Ziele wie „zwei Linien in einem Zug" plant der Automat nie,
/// weil er sofort raeumt, statt aufzubauen.
Ergebnis spieleDurch(Level level) {
  var state = startGame(level.seed).copyWith(board: level.start);
  var linien = 0;
  var bestesRaeumen = 0;
  var besteCombo = 0;
  var zuege = 0;

  for (var zug = 0; zug < level.moveLimit; zug++) {
    ({int slot, int x, int y})? bester;
    var bestesErgebnis = -1 << 30;
    for (var slot = 0; slot < Hand.slotCount; slot++) {
      final piece = state.hand.pieceAt(slot);
      if (piece == null) continue;
      for (final at in placementsFor(state.board, piece)) {
        final nachher = resolveLines(place(state.board, piece, at.x, at.y));
        final wert = nachher.lineCount * 1000 + _luft(nachher.board);
        if (wert > bestesErgebnis) {
          bestesErgebnis = wert;
          bester = (slot: slot, x: at.x, y: at.y);
        }
      }
    }
    if (bester == null) break;

    state = applyMove(state, slot: bester.slot, x: bester.x, y: bester.y);
    final move = state.lastMove!;
    linien += move.clearedLines;
    if (move.clearedLines > bestesRaeumen) bestesRaeumen = move.clearedLines;
    if (move.appliedCombo > besteCombo) besteCombo = move.appliedCombo;
    zuege = zug + 1;

    if (level.goal.reached(
      score: state.score,
      totalLines: linien,
      bestClear: bestesRaeumen,
      bestCombo: besteCombo,
    )) {
      return Ergebnis(
        geschafft: true,
        zuege: zuege,
        punkte: state.score,
        linien: linien,
        bestesRaeumen: bestesRaeumen,
        besteCombo: besteCombo,
        festgefahren: false,
      );
    }
    if (state.isOver) break;
  }

  return Ergebnis(
    geschafft: false,
    zuege: zuege,
    punkte: state.score,
    linien: linien,
    bestesRaeumen: bestesRaeumen,
    besteCombo: besteCombo,
    festgefahren: state.isOver,
  );
}

void main() {
  group('Aufbau', () {
    test('dieselbe Nummer ergibt immer dasselbe Level', () {
      for (final nummer in [1, 7, 42, 300]) {
        final a = levelFor(nummer);
        final b = levelFor(nummer);
        expect(a.seed, b.seed);
        expect(a.goal.kind, b.goal.kind);
        expect(a.goal.target, b.goal.target);
        expect(a.start, equals(b.start));
        expect(a.moveLimit, b.moveLimit);
      }
    });

    test('jedes Level hat seinen eigenen Spielcode', () {
      final codes = {for (var n = 1; n <= 200; n++) levelFor(n).seed};
      expect(codes.length, 200);
    });

    test('Level beginnen bei 1', () {
      expect(() => levelFor(0), throwsArgumentError);
      expect(() => levelFor(-3), throwsArgumentError);
    });

    test('es gibt beliebig viele Level', () {
      final spaet = levelFor(5000);
      expect(spaet.number, 5000);
      expect(spaet.moveLimit, LevelTuning.minMoves);
      expect(spaet.blockedCells, LevelTuning.maxBlocks);
    });
  });

  group('Schwierigkeit steigt', () {
    test('die Vorbelegung nimmt zu und die Zuege nehmen ab', () {
      var vorherBlocks = -1;
      var vorherZuege = 999;
      for (var n = 1; n <= 300; n++) {
        final level = levelFor(n);
        expect(level.blockedCells, greaterThanOrEqualTo(vorherBlocks),
            reason: 'Level $n hat weniger Vorbelegung als $n-1');
        expect(level.moveLimit, lessThanOrEqualTo(vorherZuege),
            reason: 'Level $n hat mehr Zuege als $n-1');
        vorherBlocks = level.blockedCells;
        vorherZuege = level.moveLimit;
      }
    });

    test('die ersten Level sind frei und grosszuegig', () {
      expect(levelFor(1).blockedCells, 0);
      expect(levelFor(1).start.isEmpty, isTrue);
      expect(levelFor(1).moveLimit, LevelTuning.startMoves);
    });

    test('spaete Level sind eng', () {
      expect(levelFor(120).blockedCells, LevelTuning.maxBlocks);
      expect(levelFor(120).moveLimit, LevelTuning.minMoves);
    });

    test('die Ziele wechseln durch alle Arten', () {
      final arten = {for (var n = 1; n <= 8; n++) levelFor(n).goal.kind};
      expect(arten.length, LevelGoalKind.values.length);
    });
  });

  group('Jedes Level beginnt spielbar', () {
    test('keine Vorbelegung schliesst eine Linie', () {
      for (var n = 1; n <= 300; n++) {
        final start = levelFor(n).start;
        for (var i = 0; i < Board.size; i++) {
          expect(start.isRowFull(i), isFalse, reason: 'Level $n, Reihe $i');
          expect(start.isColumnFull(i), isFalse, reason: 'Level $n, Spalte $i');
        }
      }
    });

    test('die erste Hand passt immer irgendwohin', () {
      for (var n = 1; n <= 300; n++) {
        final level = levelFor(n);
        final state = startGame(level.seed).copyWith(board: level.start);
        expect(isGameOver(state.board, state.hand), isFalse,
            reason: 'Level $n beginnt festgefahren');
      }
    });
  });

  group('Die Kurve ist spielbar', () {
    /// Ein Level gilt als „frueh am Ende", wenn der Automat nicht einmal 60
    /// Prozent seiner Zuege spielen kann, ohne das Ziel erreicht zu haben.
    List<int> frueheAbbrueche(int von, int bis) {
      final treffer = <int>[];
      for (var n = von; n <= bis; n++) {
        final level = levelFor(n);
        final ergebnis = spieleDurch(level);
        if (ergebnis.geschafft) continue;
        if (ergebnis.zuege < (level.moveLimit * 0.6).floor()) treffer.add(n);
      }
      return treffer;
    }

    test('der Anfang ist verlaesslich', () {
      expect(frueheAbbrueche(1, 25), isEmpty,
          reason: 'die ersten Level muessen sich durchspielen lassen');
    });

    test('frueh festgefahrene Level bleiben die Ausnahme', () {
      // Bei gewuerfelten Steinfolgen gibt es vereinzelt unglueckliche Runden;
      // gemessen sind es 3 von 120. Waechst das deutlich, stimmt etwas an der
      // Kurve oder an der Vorbelegung nicht.
      final treffer = frueheAbbrueche(1, 120);
      expect(treffer.length, lessThanOrEqualTo(5),
          reason: 'zu viele Level fahren sich fest: $treffer');
    });

    test('die ersten Level schafft schon ein Automat', () {
      final gescheitert = <int>[];
      for (var n = 1; n <= 12; n++) {
        final level = levelFor(n);
        // „Linien in einem Zug" plant der Automat nicht — dafuer der Test
        // darunter.
        if (level.goal.kind == LevelGoalKind.linesInOneMove) continue;
        if (!spieleDurch(level).geschafft) gescheitert.add(n);
      }
      expect(gescheitert, isEmpty,
          reason: 'zu schwer fuer den Anfang: $gescheitert');
    });

    test('auch die vorausschauenden Ziele sind in Reichweite', () {
      for (var n = 1; n <= 20; n++) {
        final level = levelFor(n);
        if (level.goal.kind != LevelGoalKind.linesInOneMove) continue;
        final ergebnis = spieleDurch(level);
        expect(ergebnis.bestesRaeumen, greaterThanOrEqualTo(level.goal.target - 1),
            reason: 'Level $n verlangt ${level.goal.target} auf einmal, '
                'sofortiges Raeumen kommt nur auf ${ergebnis.bestesRaeumen}');
      }
    });

    test('spaeter wird es auch fuer den Automaten eng', () {
      var geschafft = 0;
      for (var n = 60; n <= 80; n++) {
        if (spieleDurch(levelFor(n)).geschafft) geschafft += 1;
      }
      expect(geschafft, lessThan(21),
          reason: 'wenn der Automat alles schafft, ist es zu leicht');
    });
  });
}
