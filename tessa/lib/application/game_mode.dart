import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In welcher Art von Runde wir gerade sind.
enum GameMode {
  /// Gewoehnliche Runde mit zufaelligem Spielcode.
  normal,

  /// Das Raetsel des Tages — fuer alle derselbe Spielcode.
  daily,

  /// Ein Level aus der Levelliste: fester Spielcode, Ziel und Zugbegrenzung.
  level,

  /// Teile duerfen vor dem Legen gedreht werden — die eine Ausnahme von der
  /// Regel "nicht rotieren".
  rotation,

  /// Zen: kein Spielende. Geht nichts mehr, kommt die naechste Hand aus der
  /// Steinfolge; notfalls wird die vollste Reihe geraeumt.
  zen,

  /// Tuefteln: derselbe Spielcode, aber unbegrenzt zurueck. Zum Ausreizen
  /// einer Runde, die ja durch ihren Code vollstaendig feststeht.
  practice,

  /// Hardcore: kein Hinweis, kein Zurueck, kein Weiterspielen. Dazu sperrigere
  /// Teile und Geroell, das alle drei Zuege faellt.
  hardcore,
}

/// In Hardcore-Runden gibt es keine Hilfe — auch keine gekaufte.
///
/// Steht hier und nicht verstreut in den Controllern, damit es genau eine
/// Stelle gibt, an der diese Zusage haengt (siehe `hardcore_test.dart`).
bool allowsHelp(GameMode mode) => mode != GameMode.hardcore;

class GameModeController extends Notifier<GameMode> {
  @override
  GameMode build() => GameMode.normal;

  void set(GameMode mode) => state = mode;
}

final gameModeProvider =
    NotifierProvider<GameModeController, GameMode>(GameModeController.new);
