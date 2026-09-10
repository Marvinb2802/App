import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In welcher Art von Runde wir gerade sind.
enum GameMode {
  /// Gewoehnliche Runde mit zufaelligem Spielcode.
  normal,

  /// Das Raetsel des Tages — fuer alle derselbe Spielcode.
  daily,

  /// Zen: kein Spielende. Geht nichts mehr, kommt die naechste Hand aus der
  /// Steinfolge; notfalls wird die vollste Reihe geraeumt.
  zen,

  /// Tuefteln: derselbe Spielcode, aber unbegrenzt zurueck. Zum Ausreizen
  /// einer Runde, die ja durch ihren Code vollstaendig feststeht.
  practice,
}

class GameModeController extends Notifier<GameMode> {
  @override
  GameMode build() => GameMode.normal;

  void set(GameMode mode) => state = mode;
}

final gameModeProvider =
    NotifierProvider<GameModeController, GameMode>(GameModeController.new);
