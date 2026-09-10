import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_mode.dart';
import '../../application/shop.dart';
import '../format.dart';
import '../theme/tessa_theme.dart';

/// Sterne ausgeben — für Aussehen und ein paar Hinweise.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider);
    final imTagesraetsel = ref.watch(gameModeProvider) == GameMode.daily;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFFC44D), size: 32),
                  const SizedBox(width: 12),
                  Text(
                    zahl(shop.stars),
                    key: const Key('star-count'),
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Text('Sterne', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              'Sterne bekommst du fürs Spielen: einen je 250 Punkte, dazu '
              '$starsForDailyGoal fürs Tagesziel. Nichts hier ist mit Geld zu '
              'kaufen, und nichts verändert die Steinfolge — es gibt keine '
              'besseren Teile und kein Weiterspielen nach dem Ende.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final item in shopItems)
            _ItemTile(
              item: item,
              shop: shop,
              gesperrt: item.kind == ShopKind.hints && imTagesraetsel,
            ),
          const Divider(height: 40),
          Text('Farbset wählen', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: shop.palette,
            onChanged: (wert) =>
                ref.read(shopProvider.notifier).selectPalette(wert!),
            child: Column(
              children: [
          for (final id in piecePalettes.keys)
            RadioListTile<String>(
              key: Key('palette-$id'),
              value: id,
              title: Text(_paletteName(id)),
              subtitle: id == 'standard' || shop.ownsItem('palette.$id')
                  ? null
                  : const Text('noch nicht gekauft'),
              secondary: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final farbe in piecePalettes[id]!.take(4))
                    Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        color: farbe,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _paletteName(String id) => switch (id) {
        'neon' => 'Neon',
        'pastell' => 'Pastell',
        'mono' => 'Ein Ton',
        _ => 'Standard',
      };
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.item,
    required this.shop,
    required this.gesperrt,
  });

  final ShopItem item;
  final ShopState shop;
  final bool gesperrt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gekauft = item.isPermanent && shop.ownsItem(item.id);
    final kannKaufen = !gekauft && !gesperrt && shop.canAfford(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    gesperrt
                        ? 'Im Tagesrätsel gesperrt — dort hat jede und jeder '
                            'dieselben drei Hinweise.'
                        : item.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            gekauft
                ? const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF3DD6A0))
                : FilledButton(
                    key: Key('buy-${item.id}'),
                    onPressed: kannKaufen
                        ? () {
                            final erfolg =
                                ref.read(shopProvider.notifier).buy(item);
                            if (erfolg && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${item.name} gekauft')),
                              );
                            }
                          }
                        : null,
                    child: Text('${item.price} ★'),
                  ),
          ],
        ),
      ),
    );
  }
}
