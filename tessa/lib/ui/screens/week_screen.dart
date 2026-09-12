import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/daily.dart';
import '../../application/game_mode.dart';
import '../../application/providers.dart';
import '../format.dart';
import '../theme/tessa_theme.dart';
import 'game_screen.dart';

const List<String> _wochentage = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

/// Die sieben Tagesrätsel dieser Woche und ihre Gesamtpunktzahl.
class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final woche = ref.watch(weekStatusProvider).value ?? WeekStatus.unknown;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Wochenrätsel')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    zahl(woche.total),
                    key: const Key('week-total'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: tessaAccent,
                    ),
                  ),
                  Text('Punkte diese Woche',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${woche.played} von 7 Tagen gespielt',
                    key: const Key('week-played'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < woche.days.length; i++)
            _TagZeile(name: _wochentage[i], tag: woche.days[i]),
          const SizedBox(height: 16),
          Text(
            'Jeder Tag hat seinen eigenen Spielcode. Vergangene Tage kannst du '
            'nachspielen — gewertet für die Woche wird aber nur der Versuch '
            'am Tag selbst.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagZeile extends ConsumerWidget {
  const _TagZeile({required this.name, required this.tag});

  final String name;
  final WeekDay tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gespielt = tag.score != null;

    return ListTile(
      key: Key('week-day-${tag.code}'),
      enabled: !tag.isFuture,
      leading: Icon(
        gespielt
            ? Icons.check_circle_rounded
            : tag.isFuture
                ? Icons.lock_clock_outlined
                : Icons.circle_outlined,
        color: gespielt
            ? const Color(0xFF3DD6A0)
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: tag.isToday ? FontWeight.w800 : FontWeight.w500,
          color: tag.isToday ? tessaAccent : null,
        ),
      ),
      subtitle: Text('Spielcode ${tag.code}'),
      trailing: gespielt
          ? Text(
              zahl(tag.score!),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            )
          : tag.isFuture
              ? const Text('kommt noch')
              : const Icon(Icons.play_arrow_rounded),
      onTap: tag.isFuture
          ? null
          : () {
              // Heute zaehlt als Tagesraetsel, ein vergangener Tag nicht.
              ref
                  .read(gameModeProvider.notifier)
                  .set(tag.isToday ? GameMode.daily : GameMode.normal);
              ref
                  .read(gameControllerProvider.notifier)
                  .restart(seed: tag.code);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GameScreen()),
              );
            },
    );
  }
}
