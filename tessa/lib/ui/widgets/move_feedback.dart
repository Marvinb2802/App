import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/model/game_state.dart';

/// Zeigt, was der letzte Zug gebracht hat: Punkte, gefallene Linien, Combo.
///
/// Steht bewusst ueber dem Brett und nicht darauf — welche Linien gefallen
/// sind, gehoert spaeter in die Animation.
class MoveFeedback extends ConsumerWidget {
  const MoveFeedback({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final move = state.lastMove;
    final theme = Theme.of(context);

    final zeigen = move != null && move.didClear;
    return SizedBox(
      height: 28,
      child: AnimatedOpacity(
        opacity: zeigen ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: zeigen
            ? Text(
                _text(move),
                key: const Key('move-feedback'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  String _text(MoveOutcome move) {
    final linien = move.clearedLines == 1 ? '1 Linie' : '${move.clearedLines} Linien';
    final combo = move.appliedCombo > 1 ? ' · Combo ${move.appliedCombo}' : '';
    return '+${move.points} · $linien$combo';
  }
}
