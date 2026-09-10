import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_mode.dart';
import '../../application/level_controller.dart';
import '../../application/providers.dart';
import '../../domain/model/board.dart';
import '../widgets/board_view.dart';
import '../../domain/model/level.dart';
import '../widgets/level_banner.dart';
import '../widgets/move_feedback.dart';
import '../widgets/piece_tray.dart';
import '../../application/round_log.dart';
import '../../application/shop.dart';
import '../format.dart';
import '../widgets/score_bar.dart';
import 'scores_screen.dart';
import 'shop_screen.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOver = ref.watch(gameControllerProvider).isOver;
    final imLevel = ref.watch(gameModeProvider) == GameMode.level;
    final session = ref.watch(levelProvider);

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
                    if (imLevel) const LevelBanner() else const MoveFeedback(),
                    Expanded(
                      child: Center(child: BoardView(cellSize: cellSize)),
                    ),
                    PieceTray(boardCellSize: cellSize),
                    const SizedBox(height: 8),
                  ],
                ),
                if (imLevel && session.outcome != LevelOutcome.playing)
                  _LevelOverlay(session: session)
                else if (isOver && !imLevel)
                  const _GameOverOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Der Abschluss eines Levels — geschafft oder nicht.
class _LevelOverlay extends ConsumerWidget {
  const _LevelOverlay({required this.session});

  final LevelSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = session.level!;
    final gewonnen = session.outcome == LevelOutcome.won;
    final state = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);

    return Positioned.fill(
      key: const Key('level-over'),
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
                      gewonnen
                          ? 'Level ${level.number} geschafft'
                          : 'Ziel nicht erreicht',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      gewonnen
                          ? '${zahl(state.score)} Punkte · '
                              '+${3 + level.number ~/ 10} ★'
                          : level.goal.text,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: gewonnen
                            ? const Color(0xFF3DD6A0)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (gewonnen)
                      FilledButton(
                        key: const Key('next-level'),
                        onPressed: () => ref
                            .read(gameControllerProvider.notifier)
                            .startLevel(levelFor(level.number + 1)),
                        child: const Text('Nächstes Level'),
                      )
                    else
                      FilledButton(
                        key: const Key('retry-level'),
                        onPressed: () => ref
                            .read(gameControllerProvider.notifier)
                            .startLevel(level),
                        child: const Text('Noch einmal'),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('back-to-levels'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Zur Übersicht'),
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

/// Was in der Runde gut lief und was liegen blieb.
///
/// Moeglich wird das nur, weil zu jedem Zug feststeht, was der beste
/// verfuegbare Zug gewesen waere — vergleiche domain/rules/hint.dart.
class _Analyse extends StatelessWidget {
  const _Analyse({required this.log});

  final RoundLog log;

  @override
  Widget build(BuildContext context) {
    if (log.moveCount == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bester = log.bestMove;
    final verpasst = log.biggestMiss;

    return Container(
      key: const Key('analysis'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deine Runde', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _Zeile(text: '${log.moveCount} Züge gelegt'),
          if (bester != null)
            _Zeile(
              text: 'Bester Zug: Nummer ${bester.index}, '
                  '${bester.clearedLines} '
                  '${bester.clearedLines == 1 ? 'Linie' : 'Linien'} '
                  'für ${zahl(bester.points)} Punkte',
            ),
          if (verpasst != null)
            _Zeile(
              key: const Key('analysis-miss'),
              text: 'Größte verpasste Gelegenheit: bei Zug ${verpasst.index} '
                  'wären ${verpasst.bestLines} Linien möglich gewesen',
              warnend: true,
            )
          else
            const _Zeile(
              text: 'Du hast keine große Gelegenheit ausgelassen.',
            ),
        ],
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({super.key, required this.text, this.warnend = false});

  final String text;
  final bool warnend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: warnend
              ? const Color(0xFFFFC44D)
              : theme.colorScheme.onSurfaceVariant,
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
    final vorrat = ref.watch(shopProvider).revives;
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
                    const SizedBox(height: 20),
                    _Analyse(log: ref.watch(roundLogProvider)),
                    const SizedBox(height: 20),
                    if (vorrat > 0)
                      FilledButton.icon(
                        key: const Key('revive'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Weiterspielen ($vorrat übrig)'),
                        onPressed: () =>
                            ref.read(gameControllerProvider.notifier).revive(),
                      )
                    else
                      OutlinedButton.icon(
                        key: const Key('revive-buy'),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Weiterspielen holen'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ShopScreen(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
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
