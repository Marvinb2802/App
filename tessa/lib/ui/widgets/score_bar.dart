import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_mode.dart';
import '../../application/providers.dart';
import '../format.dart';
import '../theme/tessa_theme.dart';

/// Punkte, Combo, Undo, Hinweis — und der Spielcode der Runde.
///
/// Der Code steht bewusst sichtbar da: eine Runde soll nachspielbar und
/// ueberpruefbar sein (siehe Fairness-Garantie in CLAUDE.md).
class ScoreBar extends ConsumerWidget {
  const ScoreBar({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final mode = ref.watch(gameModeProvider);
    final hints = ref.watch(hintProvider);
    final theme = Theme.of(context);
    final unbegrenzt = mode == GameMode.practice;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('back-home'),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Zurück zum Start',
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      zahl(state.score),
                      key: const Key('score'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      _untertitel(mode, state.seed),
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
              IconButton(
                key: const Key('hint'),
                icon: const Icon(Icons.lightbulb_outline_rounded),
                tooltip: unbegrenzt
                    ? 'Hinweis'
                    : 'Hinweis (${hints.left} übrig)',
                onPressed: (unbegrenzt || hints.canAsk) && !state.isOver
                    ? () => ref.read(hintProvider.notifier).request()
                    : null,
              ),
              Badge.count(
                key: const Key('undos-left'),
                count: unbegrenzt ? 99 : state.undosLeft,
                isLabelVisible: !unbegrenzt,
                child: IconButton(
                  key: const Key('undo'),
                  onPressed: (unbegrenzt || state.canUndo)
                      ? () => ref.read(gameControllerProvider.notifier).undo()
                      : null,
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: unbegrenzt
                      ? 'Zug zurück (unbegrenzt)'
                      : 'Zug zurück (${state.undosLeft} übrig)',
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (state.combo > 1) _ComboPill(combo: state.combo),
              _BestPill(seed: state.seed, score: state.score),
            ],
          ),
        ],
      ),
    );
  }

  String _untertitel(GameMode mode, int seed) => switch (mode) {
        GameMode.daily => 'Tagesrätsel · Spielcode $seed',
        GameMode.practice => 'Tüfteln · Spielcode $seed',
        GameMode.normal => 'Spielcode $seed',
      };
}

/// Zeigt die eigene Bestleistung mit genau diesem Spielcode — die Messlatte
/// beim Nachspielen und beim Tuefteln.
class _BestPill extends ConsumerWidget {
  const _BestPill({required this.seed, required this.score});

  final int seed;
  final int score;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best = ref.watch(bestForCodeProvider(seed)).value ?? 0;
    if (best == 0) return const SizedBox.shrink();

    final voraus = score > best;
    final text = voraus
        ? 'Bestwert übertroffen +${zahl(score - best)}'
        : 'Bestwert ${zahl(best)} · noch ${zahl(best - score)}';
    final farbe = voraus ? const Color(0xFF3DD6A0) : Colors.white70;

    return Container(
      key: const Key('best-for-code'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: farbe,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ComboPill extends StatelessWidget {
  const _ComboPill({required this.combo});

  final int combo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('combo'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: tessaAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Combo $combo',
        style: theme.textTheme.labelLarge?.copyWith(
          color: tessaAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
