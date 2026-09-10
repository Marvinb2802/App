import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import 'game_screen.dart';
import 'scores_screen.dart';

/// Einstieg: laufende Runde fortsetzen, neu anfangen, Bestenliste, oder eine
/// Runde mit einem bestimmten Seed spielen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final best = ref.watch(bestScoreProvider).value ?? 0;
    final theme = Theme.of(context);

    // Eine Runde laeuft, wenn schon etwas auf dem Brett steht.
    final laeuft = !state.isOver && (!state.board.isEmpty || state.score > 0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tessa', style: theme.textTheme.displaySmall),
                const SizedBox(height: 4),
                Text('Block-Puzzle', style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                if (best > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      'Bestpunktzahl $best',
                      key: const Key('best-score'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                if (laeuft)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                      key: const Key('continue'),
                      onPressed: () => _openGame(context),
                      child: Text('Weiterspielen (${state.score} Punkte)'),
                    ),
                  ),
                (laeuft ? OutlinedButton.new : FilledButton.new)(
                  key: const Key('new-game'),
                  onPressed: () {
                    ref.read(gameControllerProvider.notifier).restart();
                    _openGame(context);
                  },
                  child: const Text('Neue Runde'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('home-scores'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScoresScreen(),
                    ),
                  ),
                  child: const Text('Bestenliste'),
                ),
                TextButton(
                  key: const Key('home-seed'),
                  onPressed: () => _askForSeed(context, ref),
                  child: const Text('Runde mit Seed spielen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openGame(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const GameScreen()),
      );

  /// Eine Runde laesst sich gezielt nachspielen — dafuer steht der Seed
  /// ueberall sichtbar (siehe Fairness-Garantie in CLAUDE.md).
  Future<void> _askForSeed(BuildContext context, WidgetRef ref) async {
    final seed = await showDialog<int>(
      context: context,
      builder: (context) => const _SeedDialog(),
    );
    if (seed == null || !context.mounted) return;
    ref.read(gameControllerProvider.notifier).restart(seed: seed);
    _openGame(context);
  }
}

/// Eigener Zustand, damit das Textfeld seinen Controller selbst entsorgt —
/// erst wenn der Dialog wirklich weg ist, nicht schon beim Ausblenden.
class _SeedDialog extends StatefulWidget {
  const _SeedDialog();

  @override
  State<_SeedDialog> createState() => _SeedDialogState();
}

class _SeedDialogState extends State<_SeedDialog> {
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
      title: const Text('Runde mit Seed spielen'),
      content: TextField(
        key: const Key('seed-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Seed'),
        onSubmitted: _submit,
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
