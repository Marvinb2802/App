import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/sound.dart';
import '../format.dart';

/// Zahlen zur eigenen Spielweise, dazu die Einstellungen.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalsProvider).value ?? (rounds: 0, points: 0);
    final best = ref.watch(bestScoreProvider).value ?? 0;
    final daily = ref.watch(dailyStatusProvider).value;
    final haptics = ref.watch(hapticsProvider);
    final sound = ref.watch(soundProvider);
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
            value: zahl(totals.rounds),
          ),
          _Zeile(
            key: const Key('stat-best'),
            label: 'Beste Runde',
            value: zahl(best),
          ),
          _Zeile(
            key: const Key('stat-average'),
            label: 'Durchschnitt',
            value: zahl(schnitt),
          ),
          _Zeile(
            key: const Key('stat-streak'),
            label: 'Tagesrätsel in Folge',
            value: '${daily?.streak ?? 0}',
          ),
          const Divider(height: 40),
          SwitchListTile(
            key: const Key('sound-switch'),
            title: const Text('Töne'),
            subtitle: const Text('Beim Auflösen steigt die Tonhöhe mit der '
                'Combo'),
            value: sound,
            onChanged: (_) => ref.read(soundProvider.notifier).toggle(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('test-sound'),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Ton testen'),
                onPressed: () {
                  // Erst vorbereiten, dann spielen: im Browser zaehlt genau
                  // dieser Fingerdruck als Freigabe.
                  ref.read(soundProvider.notifier).unlock();
                  ref.read(soundProvider.notifier).play(Sounds.clear(3));
                },
              ),
            ),
          ),
          SwitchListTile(
            key: const Key('haptics-switch'),
            title: const Text('Vibration'),
            subtitle: Text(
              kIsWeb
                  ? 'Im Browser nicht möglich — nur in der App auf dem Handy'
                  : 'Kurzes Rütteln beim Legen und Auflösen',
            ),
            value: haptics,
            onChanged:
                kIsWeb ? null : (_) => ref.read(hapticsProvider.notifier).toggle(),
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
