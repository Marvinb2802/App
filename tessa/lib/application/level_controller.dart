import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/model/level.dart';

/// Wie eine Level-Runde gerade steht.
enum LevelOutcome { playing, won, lost }

class LevelSession {
  const LevelSession({this.level, this.outcome = LevelOutcome.playing});

  static const LevelSession none = LevelSession();

  final Level? level;
  final LevelOutcome outcome;

  bool get isRunning => level != null && outcome == LevelOutcome.playing;
}

class LevelController extends Notifier<LevelSession> {
  @override
  LevelSession build() => LevelSession.none;

  void start(Level level) => state = LevelSession(level: level);

  void settle(LevelOutcome outcome) {
    if (state.level == null) return;
    state = LevelSession(level: state.level, outcome: outcome);
  }

  void clear() => state = LevelSession.none;
}

final levelProvider =
    NotifierProvider<LevelController, LevelSession>(LevelController.new);
