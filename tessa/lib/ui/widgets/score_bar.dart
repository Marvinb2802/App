import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';

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
          Column(
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
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
          IconButton(
            key: const Key('undo'),
            onPressed: state.canUndo
                ? () => ref.read(gameControllerProvider.notifier).undo()
                : null,
            icon: const Icon(Icons.undo),
            tooltip: 'Zug zurueck (${state.undosLeft} uebrig)',
          ),
          Text(
            '${state.undosLeft}',
            key: const Key('undos-left'),
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
