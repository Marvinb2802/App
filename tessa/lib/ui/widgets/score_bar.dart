import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../screens/scores_screen.dart';

/// Punkte, Combo, Undo — und der Seed der Runde.
///
/// Der Seed steht bewusst sichtbar da: eine Runde soll nachspielbar und
/// ueberpruefbar sein (siehe Fairness-Garantie in CLAUDE.md).
class ScoreBar extends ConsumerWidget {
  const ScoreBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nachgiebig, damit ein langer Seed die Leiste nicht sprengt.
          Flexible(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${state.score}',
                key: const Key('score'),
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                'Seed ${state.seed}',
                key: const Key('seed'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            ),
          ),
          const Spacer(),
          if (state.combo > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                key: const Key('combo'),
                label: Text('Combo ${state.combo}'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          Badge.count(
            key: const Key('undos-left'),
            count: state.undosLeft,
            child: IconButton(
              key: const Key('undo'),
              onPressed: state.canUndo
                  ? () => ref.read(gameControllerProvider.notifier).undo()
                  : null,
              icon: const Icon(Icons.undo),
              tooltip: 'Zug zurück (${state.undosLeft} übrig)',
            ),
          ),
          IconButton(
            key: const Key('open-scores'),
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Bestenliste',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ScoresScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
