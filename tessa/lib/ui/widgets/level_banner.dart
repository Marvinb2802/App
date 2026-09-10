import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/level_controller.dart';
import '../../application/providers.dart';
import '../theme/tessa_theme.dart';

/// Zeigt im Level, was verlangt wird und wie viele Züge noch bleiben.
class LevelBanner extends ConsumerWidget {
  const LevelBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(levelProvider).level;
    if (level == null) return const SizedBox.shrink();

    final gespielt = ref.watch(roundLogProvider).moveCount;
    final uebrig = level.moveLimit - gespielt;
    final knapp = uebrig <= 3;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              'Level ${level.number} · ${level.goal.shortText}',
              key: const Key('level-goal'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: tessaAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'noch $uebrig ${uebrig == 1 ? 'Zug' : 'Züge'}',
            key: const Key('level-moves'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: knapp
                  ? const Color(0xFFFF7A59)
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: knapp ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
