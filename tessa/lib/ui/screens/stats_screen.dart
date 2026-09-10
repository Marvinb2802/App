import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';

/// Zahlen zur eigenen Spielweise, dazu die Einstellungen.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalsProvider).value ?? (rounds: 0, points: 0);
    final best = ref.watch(bestScoreProvider).value ?? 0;
    final daily = ref.watch(dailyStatusProvider).value;
    final haptics = ref.watch(hapticsProvider);
    final schnitt =
        totals.rounds == 0 ? 0 : (totals.points / totals.rounds).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Zeile(
            key: const Key('stat-rounds'),
            label: 'Gespielte Runden',
            value: '${totals.rounds}',
          ),
          _Zeile(
            key: const Key('stat-best'),
            label: 'Beste Runde',
            value: '$best',
          ),
          _Zeile(
            key: const Key('stat-average'),
            label: 'Durchschnitt',
            value: '$schnitt',
          ),
          _Zeile(
            key: const Key('stat-streak'),
            label: 'Tagesrätsel in Folge',
            value: '${daily?.streak ?? 0}',
          ),
          const Divider(height: 40),
          SwitchListTile(
            key: const Key('haptics-switch'),
            title: const Text('Vibration'),
            subtitle: const Text('Kurzes Rütteln beim Legen und Auflösen'),
            value: haptics,
            onChanged: (_) => ref.read(hapticsProvider.notifier).toggle(),
          ),
          if (totals.rounds == 0)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'Sobald du eine Runde zu Ende gespielt hast, stehen hier '
                'deine Zahlen.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
