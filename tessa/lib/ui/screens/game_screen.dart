import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_mode.dart';
import '../../application/providers.dart';
import '../../domain/model/board.dart';
import '../widgets/board_view.dart';
import '../widgets/move_feedback.dart';
import '../widgets/piece_tray.dart';
import '../format.dart';
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
              constraints.maxHeight * 0.58,
            );
            final cellSize = side / Board.size;
            return Stack(
              children: [
                Column(
                  children: [
                    const ScoreBar(),
                    const MoveFeedback(),
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

/// Der Text, den der Teilen-Knopf in die Zwischenablage legt.
String shareText({
  required GameMode mode,
  required int score,
  required int seed,
  required int streak,
}) {
  final kopf = mode == GameMode.daily ? 'Tessa Tagesrätsel' : 'Tessa';
  final serie = mode == GameMode.daily && streak > 1 ? ' · Serie $streak Tage' : '';
  return '$kopf\n$score Punkte$serie\nSpielcode $seed\n'
      'Spiel denselben Code und vergleiche.';
}

class _GameOverOverlay extends ConsumerWidget {
  const _GameOverOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final mode = ref.watch(gameModeProvider);
    final streak = ref.watch(dailyStatusProvider).value?.streak ?? 0;
    final best = ref.watch(bestScoreProvider).value ?? 0;
    final codeBest = ref.watch(bestForCodeProvider(state.seed)).value ?? 0;
    final controller = ref.read(gameControllerProvider.notifier);
    final theme = Theme.of(context);
    final rekord = state.score >= best && state.score > 0;

    return Positioned.fill(
      key: const Key('game-over'),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      rekord ? 'Neuer Rekord!' : 'Runde vorbei',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      zahl(state.score),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text('Punkte',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Spielcode ${state.seed}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (codeBest > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.score >= codeBest
                            ? 'Neuer Bestwert für diesen Spielcode'
                            : 'Dein Bestwert mit diesem Code: ${zahl(codeBest)}',
                        key: const Key('code-best'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: state.score >= codeBest
                              ? const Color(0xFF3DD6A0)
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (mode == GameMode.daily && streak > 0) ...[
                      const SizedBox(height: 8),
                      Text('Serie: $streak Tage',
                          key: const Key('streak'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('share'),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Ergebnis kopieren'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                          text: shareText(
                            mode: mode,
                            score: state.score,
                            seed: state.seed,
                            streak: streak,
                          ),
                        ));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ergebnis kopiert — jetzt einfügen '
                                'und verschicken.'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('new-round'),
                      onPressed: () {
                        ref.read(gameModeProvider.notifier).set(GameMode.normal);
                        controller.restart();
                      },
                      child: const Text('Neue Runde'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('replay'),
                      onPressed: controller.replay,
                      child: const Text('Denselben Code noch einmal'),
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
      ),
    );
  }
}
