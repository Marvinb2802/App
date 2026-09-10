import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../data/score_dao.dart';

/// Tag, Monat und Jahr — ohne zusaetzliches Paket.
String formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

/// Die besten Runden. Jede laesst sich mit ihrem Seed noch einmal spielen.
class ScoresScreen extends ConsumerWidget {
  const ScoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(topScoresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bestenliste')),
      body: scores.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          key: const Key('scores-error'),
          child: Text('Die Bestenliste liess sich nicht laden.\n$error',
              textAlign: TextAlign.center),
        ),
        data: (entries) => entries.isEmpty
            ? const Center(
                key: Key('scores-empty'),
                child: Text('Noch keine Runde gespielt.'),
              )
            : ListView.separated(
                key: const Key('scores-list'),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    _ScoreRow(rank: index + 1, entry: entries[index]),
              ),
      ),
    );
  }
}

class _ScoreRow extends ConsumerWidget {
  const _ScoreRow({required this.rank, required this.entry});

  final int rank;
  final ScoreEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(child: Text('$rank')),
      title: Text('${entry.score} Punkte',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text('Seed ${entry.seed} · ${formatDate(entry.playedAt)}'),
      trailing: IconButton(
        key: Key('replay-${entry.id}'),
        icon: const Icon(Icons.replay),
        tooltip: 'Diese Runde noch einmal spielen',
        onPressed: () {
          ref.read(gameControllerProvider.notifier).restart(seed: entry.seed);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
