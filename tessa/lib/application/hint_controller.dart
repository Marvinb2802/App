import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/rules/hint.dart';
import 'game_mode.dart';
import 'providers.dart';

/// Stand der Hinweise in dieser Runde.
class HintState {
  const HintState({required this.left, this.shown});

  /// Hinweise je Runde. Im Tueftel-Modus unbegrenzt.
  static const int perRound = 3;

  static const HintState fresh = HintState(left: perRound);

  final int left;

  /// Der gerade angezeigte Vorschlag.
  final Hint? shown;

  bool get canAsk => left > 0;
}

class HintController extends Notifier<HintState> {
  @override
  HintState build() => HintState.fresh;

  /// Sucht einen Zug und zeigt ihn an. False, wenn keiner mehr uebrig ist
  /// oder nichts mehr passt.
  bool request() {
    final unbegrenzt = ref.read(gameModeProvider) == GameMode.practice;
    if (!unbegrenzt && !state.canAsk) return false;

    final game = ref.read(gameControllerProvider);
    if (game.isOver) return false;

    final hint = findHint(game.board, game.hand);
    if (hint == null) return false;

    state = HintState(
      left: unbegrenzt ? state.left : state.left - 1,
      shown: hint,
    );
    return true;
  }

  /// Legt Hinweise nach — etwa aus dem Shop.
  void add(int count) => state = HintState(left: state.left + count, shown: state.shown);

  /// Blendet den Vorschlag aus, ohne einen Hinweis zurueckzugeben.
  void hide() => state = HintState(left: state.left);

  void reset() => state = HintState.fresh;
}
