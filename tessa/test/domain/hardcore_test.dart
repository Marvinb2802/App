import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/domain/generation/piece_sequence.dart';
import 'package:tessa/domain/model/board.dart';
import 'package:tessa/domain/model/cell.dart';
import 'package:tessa/domain/model/game_state.dart';
import 'package:tessa/domain/model/hand.dart';
import 'package:tessa/domain/model/piece_catalog.dart';
import 'package:tessa/domain/rules/clearing.dart';
import 'package:tessa/domain/rules/hardcore.dart';
import 'package:tessa/domain/rules/move.dart';
import 'package:tessa/domain/rules/placement.dart';

final _square = PieceCatalog.byId('square2');

/// Wie viel Luft ein Brett noch hat — dieselbe Messgroesse wie in
/// `level_test.dart`, damit beide Automaten vergleichbar spielen.
int _luft(Board board) =>
    (Board.cellCount - board.filledCount) +
    placementsFor(board, _square).length * 3;

/// Spielt eine Runde mit dem Automaten: nimmt den Zug, der die meisten Linien
/// raeumt, und haelt bei Gleichstand das Brett offen.
///
/// Untere Schranke, kein perfektes Spiel — aber dieselbe Schranke fuer beide
/// Saetze, und genau darum geht es hier.
({int zuege, int punkte}) _spiele(
  int seed, {
  required PieceSet set,
  required bool geroell,
  int maxZuege = 250,
}) {
  var state = startGame(seed, pieces: set);
  var zuege = 0;

  while (!state.isOver && zuege < maxZuege) {
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
    zuege += 1;
    if (geroell) state = dropRubble(state, moveNumber: zuege);
  }
  return (zuege: zuege, punkte: state.score);
}

int _median(List<int> werte) {
  final sortiert = [...werte]..sort();
  return sortiert[sortiert.length ~/ 2];
}

/// Sucht einen Spielcode, bei dem das Geroell auf [ziel] faellt.
///
/// Wo es landet, haengt vom Code ab; welcher das ist, ist fuer die Regel egal.
int _seedMitTreffer(Board board, Cell ziel) {
  for (var seed = 1; seed < 2000; seed++) {
    final danach = dropRubble(_stand(board: board, seed: seed), moveNumber: 9);
    if (danach.board.isFilled(ziel.x, ziel.y) ||
        danach.board.filledCount < board.filledCount) {
      return seed;
    }
  }
  fail('kein Spielcode gefunden, bei dem das Geroell auf $ziel faellt');
}

GameState _stand({required Board board, int seed = 4242}) => GameState(
      seed: seed,
      handIndex: 1,
      board: board,
      hand: Hand.of([_square, _square, _square]),
      score: 100,
      combo: 1,
      undosLeft: 0,
      isOver: false,
      pieces: PieceSet.hardcore,
    );

void main() {
  group('Der harte Teilesatz', () {
    test('kennt dieselben Formen wie das Grundspiel', () {
      final standard =
          PieceCatalog.entries.map((e) => e.piece.id).toSet();
      final hart =
          PieceCatalog.hardcoreEntries.map((e) => e.piece.id).toSet();
      expect(hart, equals(standard),
          reason: 'Hardcore aendert nur die Haeufigkeit, nicht die Formen');
    });

    test('vergibt fuer jede Form ein positives Gewicht', () {
      for (final eintrag in PieceCatalog.hardcoreEntries) {
        expect(eintrag.weight, greaterThan(0), reason: eintrag.piece.id);
      }
      expect(PieceCatalog.totalWeightFor(PieceSet.hardcore),
          PieceCatalog.hardcoreEntries.fold(0, (s, e) => s + e.weight));
    });

    test('macht den Punkt selten und die Teile groesser', () {
      double schnitt(PieceSet set) {
        final eintraege = PieceCatalog.entriesFor(set);
        final zellen = eintraege.fold<int>(
            0, (s, e) => s + e.piece.cellCount * e.weight);
        return zellen / PieceCatalog.totalWeightFor(set);
      }

      double anteilPunkt(PieceSet set) {
        final punkt = PieceCatalog.entriesFor(set)
            .firstWhere((e) => e.piece.id == 'dot')
            .weight;
        return punkt / PieceCatalog.totalWeightFor(set);
      }

      expect(schnitt(PieceSet.hardcore),
          greaterThan(schnitt(PieceSet.standard) + 0.8),
          reason: 'im Schnitt deutlich groessere Teile');
      expect(anteilPunkt(PieceSet.hardcore),
          lessThan(anteilPunkt(PieceSet.standard) / 2),
          reason: 'der Punkt ist der Notnagel — er wird selten');
    });
  });

  group('Die Steinfolge im harten Satz', () {
    test('ist wie immer allein vom Spielcode bestimmt', () {
      const a = PieceSequence(777, set: PieceSet.hardcore);
      const b = PieceSequence(777, set: PieceSet.hardcore);
      for (var index = 0; index < 5; index++) {
        expect(a.handAt(index), equals(b.handAt(index)));
      }
    });

    test('ist eine andere als im Grundspiel', () {
      const hart = PieceSequence(777, set: PieceSet.hardcore);
      const weich = PieceSequence(777);
      final unterschiede = [
        for (var index = 0; index < 10; index++)
          if (hart.handAt(index) != weich.handAt(index)) index,
      ];
      expect(unterschiede, isNotEmpty,
          reason: 'derselbe Code, aber ein anderer Satz Gewichte');
    });

    test('wird von startGame an die Runde weitergereicht', () {
      final runde = startGame(777, pieces: PieceSet.hardcore);
      expect(runde.pieces, PieceSet.hardcore);
      expect(runde.hand,
          equals(const PieceSequence(777, set: PieceSet.hardcore).handAt(0)));
    });

    test('bleibt ueber den Nachschub hinweg der harte Satz', () {
      var state = startGame(777, pieces: PieceSet.hardcore);
      // Alle drei Teile legen, damit eine neue Hand kommt.
      for (var slot = 0; slot < Hand.slotCount; slot++) {
        final piece = state.hand.pieceAt(slot)!;
        final platz = placementsFor(state.board, piece).first;
        state = applyMove(state, slot: slot, x: platz.x, y: platz.y);
      }
      expect(state.handIndex, 1);
      expect(state.pieces, PieceSet.hardcore);
      expect(state.hand,
          equals(const PieceSequence(777, set: PieceSet.hardcore).handAt(1)));
    });
  });

  group('Geroell', () {
    test('faellt in den ersten Zuegen nicht', () {
      final start = _stand(board: Board.empty());
      for (var zug = 1; zug <= Hardcore.gracePeriod; zug++) {
        expect(dropRubble(start, moveNumber: zug).board.filledCount, 0,
            reason: 'Zug $zug liegt in der Schonfrist');
      }
    });

    test('faellt danach nur jeden dritten Zug', () {
      final start = _stand(board: Board.empty());
      for (var zug = Hardcore.gracePeriod + 1;
          zug <= Hardcore.gracePeriod + 9;
          zug++) {
        final danach = dropRubble(start, moveNumber: zug).board.filledCount;
        expect(danach, zug % Hardcore.rubbleEveryMoves == 0 ? 1 : 0,
            reason: 'Zug $zug');
      }
    });

    test('landet auf einem freien Feld und gibt keine Punkte', () {
      final start = _stand(board: Board.empty());
      final danach = dropRubble(start, moveNumber: 9);
      expect(danach.board.filledCount, 1);
      expect(danach.score, start.score, reason: 'gelegt hat den Stein niemand');
      expect(danach.handIndex, start.handIndex,
          reason: 'die Steinfolge rueckt nicht weiter');
      expect(danach.hand, equals(start.hand));
    });

    test('faellt bei gleichem Code und gleichem Zug immer gleich', () {
      final start = _stand(board: Board.empty());
      final einmal = dropRubble(start, moveNumber: 9).board;
      final nochmal = dropRubble(start, moveNumber: 9).board;
      expect(nochmal, equals(einmal));
    });

    test('liegt bei anderem Spielcode woanders', () {
      final felder = {
        for (final seed in [1, 2, 3, 4, 5, 6, 7, 8])
          dropRubble(_stand(board: Board.empty(), seed: seed), moveNumber: 9)
              .board
              .toString()
      };
      expect(felder.length, greaterThan(1),
          reason: 'der Spielcode bestimmt mit, wo es faellt');
    });

    test('raeumt eine Linie, die es zufaellig schliesst', () {
      // In Reihe 7 fehlt genau ein Stein. Bei welchem Spielcode das Geroell
      // ausgerechnet dorthin faellt, sucht der Test sich — gemeint ist der
      // Fall, nicht der Code.
      final fastVoll = Board.empty().fill([
        for (var x = 0; x < Board.size - 1; x++) Cell(x, 7),
      ]);
      final treffer = _seedMitTreffer(fastVoll, const Cell(7, 7));
      final danach =
          dropRubble(_stand(board: fastVoll, seed: treffer), moveNumber: 9);

      expect(danach.board.filledCount, 0, reason: 'die Reihe ist gefallen');
      expect(danach.score, 100, reason: 'dafuer gibt es keine Punkte');
    });

    test('beendet die Runde, wenn danach nichts mehr passt', () {
      // Auf diesem Brett passt das 2x2-Teil nur noch in die Ecke oben links.
      final eng = Board.fromRows(const [
        '..######',
        '..######',
        '##.#####',
        '###.####',
        '####.###',
        '#####.##',
        '######.#',
        '#######.',
      ]);
      final start = _stand(board: eng);
      expect(start.isOver, isFalse);

      final treffer = _seedMitTreffer(eng, const Cell(0, 0));
      final danach =
          dropRubble(_stand(board: eng, seed: treffer), moveNumber: 9);

      expect(danach.isOver, isTrue,
          reason: 'der letzte Platz fuer das 2x2-Teil ist zu');
    });

    test('faellt nicht mehr, wenn die Runde vorbei ist', () {
      final voll = Board.fromRows(List.filled(8, '########'));
      final ende = _stand(board: voll).copyWith(isOver: true);
      expect(dropRubble(ende, moveNumber: 9), same(ende));
    });
  });

  group('Wie hart es wirklich ist — gemessen', () {
    // Gemessen statt geschaetzt, wie bei den Leveln: derselbe Automat spielt
    // beide Saetze. Bei der Eichung kam heraus (30 Spielcodes):
    // Standard 139 Zuege / 1260 Punkte, Hardcore mit Geroell 28 / 284.
    final seeds = [for (var i = 0; i < 12; i++) 1000 + i * 7919];

    test('eine Hardcore-Runde ist um ein Vielfaches kuerzer', () {
      final weich = [
        for (final seed in seeds)
          _spiele(seed, set: PieceSet.standard, geroell: false).zuege
      ];
      final hart = [
        for (final seed in seeds)
          _spiele(seed, set: PieceSet.hardcore, geroell: true).zuege
      ];

      expect(_median(hart) * 3, lessThan(_median(weich)),
          reason: 'Hardcore muss deutlich kuerzer sein als das Grundspiel — '
              'sonst ist es kein Hardcore (weich ${_median(weich)}, '
              'hart ${_median(hart)})');
    });

    test('bleibt aber spielbar: der Automat kommt ueber zehn Zuege', () {
      for (final seed in seeds) {
        final ergebnis = _spiele(seed, set: PieceSet.hardcore, geroell: true);
        expect(ergebnis.zuege, greaterThan(10),
            reason: 'Spielcode $seed endet nach ${ergebnis.zuege} Zuegen — '
                'schwer ist gewollt, aussichtslos nicht');
        expect(ergebnis.punkte, greaterThan(0));
      }
    });

    test('das Geroell verkuerzt die Runde zusaetzlich', () {
      final ohne = [
        for (final seed in seeds)
          _spiele(seed, set: PieceSet.hardcore, geroell: false).zuege
      ];
      final mit = [
        for (final seed in seeds)
          _spiele(seed, set: PieceSet.hardcore, geroell: true).zuege
      ];
      expect(_median(mit), lessThan(_median(ohne)));
    });
  });
}
