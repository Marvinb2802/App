import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_mode.dart';
import '../../application/providers.dart';
import '../format.dart';
import '../theme/tessa_theme.dart';
import 'game_screen.dart';
import 'scores_screen.dart';
import 'stats_screen.dart';

/// Einstieg: Tagesrätsel, laufende Runde, neue Runde, Tüfteln, Spielcode.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final best = ref.watch(bestScoreProvider).value ?? 0;
    final daily = ref.watch(dailyStatusProvider).value;
    final theme = Theme.of(context);

    // Eine Runde laeuft, wenn schon etwas auf dem Brett steht.
    final laeuft = !state.isOver && (!state.board.isEmpty || state.score > 0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tessa',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                    ),
                  ),
                  Text(
                    'Block-Puzzle',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (best > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Bestpunktzahl ${zahl(best)}',
                      key: const Key('best-score'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: tessaAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _DailyCard(
                    code: ref.watch(dailyCodeProvider),
                    playedToday: daily?.playedToday ?? false,
                    streak: daily?.streak ?? 0,
                    lastScore: daily?.lastScore,
                    onPlay: () => _start(context, ref, GameMode.daily,
                        seed: ref.read(dailyCodeProvider)),
                  ),
                  const SizedBox(height: 20),
                  if (laeuft) ...[
                    FilledButton(
                      key: const Key('continue'),
                      onPressed: () => _open(context),
                      child: Text('Weiterspielen (${zahl(state.score)} Punkte)'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  (laeuft ? OutlinedButton.new : FilledButton.new)(
                    key: const Key('new-game'),
                    onPressed: () => _start(context, ref, GameMode.normal),
                    child: const Text('Neue Runde'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    key: const Key('practice'),
                    onPressed: () => _start(context, ref, GameMode.practice),
                    child: const Text('Tüfteln'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                    child: Text(
                      'Unbegrenzt zurück: Weil der Spielcode die ganze '
                      'Steinfolge festlegt, ist jede Runde ein lösbares '
                      'Rätsel — probiere aus, wie viele Punkte drinstecken.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    key: const Key('home-seed'),
                    onPressed: () => _askForCode(context, ref),
                    child: const Text('Mit Spielcode spielen'),
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        key: const Key('home-scores'),
                        icon: const Icon(Icons.emoji_events_outlined),
                        label: const Text('Bestenliste'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ScoresScreen(),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('home-stats'),
                        icon: const Icon(Icons.insights_outlined),
                        label: const Text('Statistik'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const StatsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GameScreen()),
      );

  void _start(BuildContext context, WidgetRef ref, GameMode mode, {int? seed}) {
    ref.read(gameModeProvider.notifier).set(mode);
    ref.read(gameControllerProvider.notifier).restart(seed: seed);
    _open(context);
  }

  /// Eine Runde laesst sich gezielt nachspielen — dafuer steht der Spielcode
  /// ueberall sichtbar (siehe Fairness-Garantie in CLAUDE.md).
  Future<void> _askForCode(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<int>(
      context: context,
      builder: (context) => const _CodeDialog(),
    );
    if (code == null || !context.mounted) return;
    _start(context, ref, GameMode.normal, seed: code);
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.code,
    required this.playedToday,
    required this.streak,
    required this.lastScore,
    required this.onPlay,
  });

  final int code;
  final bool playedToday;
  final int streak;
  final int? lastScore;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('daily-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.today_rounded, color: tessaAccent),
                const SizedBox(width: 8),
                Text(
                  'Tagesrätsel',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (streak > 0)
                  Text(
                    '🔥 $streak',
                    key: const Key('daily-streak'),
                    style: theme.textTheme.titleMedium,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              playedToday
                  ? 'Heute gespielt${lastScore == null ? '' : ': $lastScore Punkte'}. '
                      'Du kannst es erneut versuchen.'
                  : 'Jeden Tag dieselbe Runde für alle. Spielcode $code.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('play-daily'),
              onPressed: onPlay,
              child: Text(playedToday ? 'Noch einmal spielen' : 'Spielen'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eigener Zustand, damit das Textfeld seinen Controller selbst entsorgt —
/// erst wenn der Dialog wirklich weg ist, nicht schon beim Ausblenden.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? text]) =>
      Navigator.of(context).pop(int.tryParse((text ?? _controller.text).trim()));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mit Spielcode spielen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Derselbe Code liefert immer dieselbe Steinfolge. Gib einen Code '
            'ein, um eine Runde nachzuspielen oder dich zu vergleichen.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('seed-field'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Spielcode'),
            onSubmitted: _submit,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('seed-start'),
          onPressed: _submit,
          child: const Text('Spielen'),
        ),
      ],
    );
  }
}
