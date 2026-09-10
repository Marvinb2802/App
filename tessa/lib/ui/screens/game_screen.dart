import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/model/board.dart';
import '../widgets/board_view.dart';
import '../widgets/piece_tray.dart';
import '../widgets/score_bar.dart';
import 'scores_screen.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOver = ref.watch(gameControllerProvider).isOver;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Das Brett bekommt die Breite, muss aber der Hand Platz lassen.
            final side = math.min(
              constraints.maxWidth - 24,
              constraints.maxHeight * 0.62,
            );
            final cellSize = side / Board.size;
            return Stack(
              children: [
                Column(
                  children: [
                    const ScoreBar(),
                    Expanded(
                      child: Center(child: BoardView(cellSize: cellSize)),
                    ),
                    PieceTray(boardCellSize: cellSize),
                    const SizedBox(height: 8),
                  ],
                ),
                if (isOver) const _GameOverOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GameOverOverlay extends ConsumerWidget {
  const _GameOverOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final theme = Theme.of(context);

    return Positioned.fill(
      key: const Key('game-over'),
      child: ColoredBox(
        color: theme.colorScheme.scrim.withValues(alpha: 0.6),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Runde vorbei', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    '${state.score} Punkte',
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    'Seed ${state.seed}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('new-round'),
                    onPressed: controller.restart,
                    child: const Text('Neue Runde'),
                  ),
                  TextButton(
                    key: const Key('replay'),
                    onPressed: controller.replay,
                    child: const Text('Dieselbe Runde noch einmal'),
                  ),
                  TextButton(
                    key: const Key('scores-from-game-over'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ScoresScreen(),
                      ),
                    ),
                    child: const Text('Bestenliste'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
