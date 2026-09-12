import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_mode.dart';
import '../../application/providers.dart';
import '../../domain/model/level.dart';
import '../theme/tessa_theme.dart';
import 'game_screen.dart';

/// Die Levelliste. Es gibt beliebig viele — nachgeladen wird beim Blättern.
class LevelsScreen extends ConsumerStatefulWidget {
  const LevelsScreen({super.key});

  @override
  ConsumerState<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends ConsumerState<LevelsScreen> {
  static const int _schritt = 60;
  int _sichtbar = _schritt;

  @override
  Widget build(BuildContext context) {
    final geschafft = ref.watch(levelProgressProvider).value ?? 0;
    // Immer mindestens bis kurz hinter den eigenen Stand.
    final bis = _sichtbar > geschafft + 20 ? _sichtbar : geschafft + 20;

    return Scaffold(
      appBar: AppBar(title: const Text('Level')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Text(
              geschafft == 0
                  ? 'Jedes Level hat ein eigenes Ziel, ein vorbelegtes Brett '
                      'und begrenzte Züge. Es wird Stück für Stück enger.'
                  : 'Geschafft: Level $geschafft',
              key: const Key('level-progress'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 92,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: bis + 1,
              itemBuilder: (context, index) {
                if (index == bis) {
                  return TextButton(
                    key: const Key('more-levels'),
                    onPressed: () => setState(() => _sichtbar = bis + _schritt),
                    child: const Text('mehr'),
                  );
                }
                final nummer = index + 1;
                return _LevelTile(
                  nummer: nummer,
                  geschafft: nummer <= geschafft,
                  offen: nummer <= geschafft + 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends ConsumerWidget {
  const _LevelTile({
    required this.nummer,
    required this.geschafft,
    required this.offen,
  });

  final int nummer;
  final bool geschafft;
  final bool offen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final level = levelFor(nummer);

    return Material(
      color: geschafft
          ? tessaAccent.withValues(alpha: 0.22)
          : offen
              ? tessaSurfaceHigh
              : tessaSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('level-$nummer'),
        borderRadius: BorderRadius.circular(16),
        onTap: offen
            ? () {
                ref.read(gameModeProvider.notifier).set(GameMode.level);
                ref.read(gameControllerProvider.notifier).startLevel(level);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GameScreen()),
                );
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$nummer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: offen
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 2),
              if (offen)
                Text(
                  level.goal.shortText,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
