import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/daily_goal.dart';
import '../../application/game_mode.dart';
import '../../application/providers.dart';
import '../format.dart';
import '../theme/tessa_theme.dart';
import 'game_screen.dart';
import 'levels_screen.dart';
import 'scores_screen.dart';
import 'shop_screen.dart';
import 'stats_screen.dart';
import 'week_screen.dart';

/// Der Einstieg, in vier Blöcken: laufende Runde, heute, Level, weitere
/// Spielarten. Unten die Übersichten.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final best = ref.watch(bestScoreProvider).value ?? 0;
    final daily = ref.watch(dailyStatusProvider).value;
    final geschaffteLevel = ref.watch(levelProgressProvider).value ?? 0;
    final theme = Theme.of(context);

    // Eine Runde läuft, wenn schon etwas auf dem Brett steht.
    final laeuft = !state.isOver && (!state.board.isEmpty || state.score > 0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            // Bewusst keine ListView: die Seite ist kurz, und so steht alles
            // sofort im Baum — auch fuer Tests und Vorlesefunktionen.
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                _Kopf(best: best),
                if (laeuft) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('continue'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () => _open(context),
                    label: Text('Weiterspielen (${zahl(state.score)} Punkte)'),
                  ),
                ],
                const SizedBox(height: 28),
                const _Abschnitt('Heute'),
                _DailyCard(
                  code: ref.watch(dailyCodeProvider),
                  playedToday: daily?.playedToday ?? false,
                  streak: daily?.streak ?? 0,
                  lastScore: daily?.lastScore,
                  goal: goalForDate(ref.watch(todayProvider)),
                  goalReached: daily?.goalReachedToday ?? false,
                  onPlay: () => _start(context, ref, GameMode.daily,
                      seed: ref.read(dailyCodeProvider)),
                ),
                const SizedBox(height: 24),
                const _Abschnitt('Level'),
                _LevelCard(
                  geschafft: geschaffteLevel,
                  onPlay: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LevelsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _Abschnitt('Weitere Spielarten'),
                Card(
                  child: Column(
                    children: [
                      _Spielart(
                        schluessel: 'new-game',
                        symbol: Icons.casino_outlined,
                        name: 'Neue Runde',
                        erklaerung: 'Zufälliger Spielcode, drei Undo, '
                            'bis nichts mehr passt.',
                        onTap: () => _start(context, ref, GameMode.normal),
                      ),
                      _Spielart(
                        schluessel: 'zen',
                        symbol: Icons.all_inclusive_rounded,
                        name: 'Zen',
                        erklaerung: 'Kein Spielende. Geht nichts mehr, wird '
                            'Platz geschaffen.',
                        onTap: () => _start(context, ref, GameMode.zen),
                      ),
                      _Spielart(
                        schluessel: 'rotation',
                        symbol: Icons.rotate_right_rounded,
                        name: 'Drehen erlaubt',
                        erklaerung: 'Antippen dreht ein Teil, Ziehen legt es.',
                        onTap: () => _start(context, ref, GameMode.rotation),
                      ),
                      _Spielart(
                        schluessel: 'practice',
                        symbol: Icons.undo_rounded,
                        name: 'Tüfteln',
                        erklaerung: 'Unbegrenzt zurück: Weil der Spielcode die '
                            'Steinfolge festlegt, ist jede Runde ein lösbares '
                            'Rätsel — reize sie aus.',
                        onTap: () => _start(context, ref, GameMode.practice),
                      ),
                      _Spielart(
                        schluessel: 'home-seed',
                        symbol: Icons.tag_rounded,
                        name: 'Mit Spielcode',
                        erklaerung: 'Eine bestimmte Runde nachspielen oder '
                            'dich mit anderen vergleichen.',
                        letzte: true,
                        onTap: () => _askForCode(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const _Fusszeile(),
                const SizedBox(height: 8),
                Text(
                  'Bestpunktzahl und Fortschritt bleiben auf diesem Gerät.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                    ),
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

  /// Eine Runde lässt sich gezielt nachspielen — dafür steht der Spielcode
  /// überall sichtbar (siehe Fairness-Garantie in CLAUDE.md).
  Future<void> _askForCode(BuildContext context, WidgetRef ref) async {
    final code = await showDialog<int>(
      context: context,
      builder: (context) => const _CodeDialog(),
    );
    if (code == null || !context.mounted) return;
    _start(context, ref, GameMode.normal, seed: code);
  }
}

class _Kopf extends StatelessWidget {
  const _Kopf({required this.best});

  final int best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Tessa',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        if (best > 0)
          Text(
            'Bestpunktzahl ${zahl(best)}',
            key: const Key('best-score'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: tessaAccent,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Text(
            'Block-Puzzle',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Eine Überschrift über einem Block.
class _Abschnitt extends StatelessWidget {
  const _Abschnitt(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

/// Eine Zeile in der Liste der Spielarten: Name und was sie ausmacht.
class _Spielart extends StatelessWidget {
  const _Spielart({
    required this.schluessel,
    required this.symbol,
    required this.name,
    required this.erklaerung,
    required this.onTap,
    this.letzte = false,
  });

  final String schluessel;
  final IconData symbol;
  final String name;
  final String erklaerung;
  final VoidCallback onTap;
  final bool letzte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          key: Key(schluessel),
          onTap: onTap,
          leading: Icon(symbol, color: tessaAccent),
          title: Text(
            name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            erklaerung,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
        if (!letzte) const Divider(height: 1, indent: 56),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.geschafft, required this.onPlay});

  final int geschafft;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_rounded, color: tessaAccent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    geschafft == 0 ? 'Level' : 'Level ${geschafft + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              geschafft == 0
                  ? 'Jedes Level hat ein eigenes Ziel, begrenzte Züge und ein '
                      'teils vorbelegtes Brett. Es wird Stück für Stück enger.'
                  : 'Geschafft bis Level $geschafft. Weiter geht es mit '
                      '${geschafft + 1}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('levels'),
              onPressed: onPlay,
              child: Text(geschafft == 0 ? 'Level spielen' : 'Weiter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fusszeile extends StatelessWidget {
  const _Fusszeile();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        _FussKnopf(
          schluessel: 'home-scores',
          symbol: Icons.emoji_events_outlined,
          name: 'Bestenliste',
          ziel: const ScoresScreen(),
        ),
        _FussKnopf(
          schluessel: 'home-week',
          symbol: Icons.date_range_outlined,
          name: 'Woche',
          ziel: const WeekScreen(),
        ),
        _FussKnopf(
          schluessel: 'home-shop',
          symbol: Icons.star_outline_rounded,
          name: 'Shop',
          ziel: const ShopScreen(),
        ),
        _FussKnopf(
          schluessel: 'home-stats',
          symbol: Icons.insights_outlined,
          name: 'Statistik',
          ziel: const StatsScreen(),
        ),
      ],
    );
  }
}

class _FussKnopf extends StatelessWidget {
  const _FussKnopf({
    required this.schluessel,
    required this.symbol,
    required this.name,
    required this.ziel,
  });

  final String schluessel;
  final IconData symbol;
  final String name;
  final Widget ziel;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: Key(schluessel),
      icon: Icon(symbol, size: 18),
      label: Text(name),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ziel),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.code,
    required this.playedToday,
    required this.streak,
    required this.lastScore,
    required this.goal,
    required this.goalReached,
    required this.onPlay,
  });

  final int code;
  final bool playedToday;
  final int streak;
  final int? lastScore;
  final DailyGoal goal;
  final bool goalReached;
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
                // Nachgiebig: auf schmalen Geraeten darf die Ueberschrift
                // kuerzen, statt die Zeile zu sprengen.
                Flexible(
                  child: Text(
                    'Tagesrätsel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
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
                  ? 'Heute gespielt${lastScore == null ? '' : ': ${zahl(lastScore!)} Punkte'}. '
                      'Du kannst es erneut versuchen.'
                  : 'Jeden Tag dieselbe Runde für alle. Spielcode $code.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              key: const Key('daily-goal'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (goalReached ? const Color(0xFF3DD6A0) : tessaAccent)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    goalReached
                        ? Icons.check_circle_rounded
                        : Icons.flag_outlined,
                    size: 18,
                    color: goalReached ? const Color(0xFF3DD6A0) : tessaAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ziel: ${goal.text}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: goalReached
                            ? const Color(0xFF3DD6A0)
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
