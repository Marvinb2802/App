import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/shop.dart';
import '../../data/purchases.dart';
import '../format.dart';
import '../theme/tessa_theme.dart';

/// Sterne ausgeben — für Aussehen und ein paar Hinweise.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider);
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
                  const Spacer(),
                  if (shop.revives > 0)
                    Text(
                      '${shop.revives}× weiterspielen',
                      key: const Key('revive-stock'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              'Sterne bekommst du fürs Spielen: einen je 250 Punkte, dazu '
              '$starsForDailyGoal fürs Tagesziel. Kein Angebot verändert die '
              'Steinfolge — dieselbe Runde bleibt für alle dieselbe, sonst '
              'wären Tagesrätsel und Bestwerte nichts wert.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final item in shopItems)
            _ItemTile(item: item, shop: shop),
          const Divider(height: 40),
          const _PaidSection(),
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

/// Angebote, die mit echtem Geld gekauft werden — ausschliesslich Aussehen.
class _PaidSection extends ConsumerWidget {
  const _PaidSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final angebote = ref.watch(paidOffersProvider);
    final shop = ref.watch(shopProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mit Geld kaufen', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Die Zahlung läuft über den App Store deines Geräts. Auch hier gilt: '
          'kein Angebot verändert die Steinfolge.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        angebote.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (fehler, _) => Text(
            'Die Angebote ließen sich nicht laden.',
            key: const Key('paid-error'),
            style: theme.textTheme.bodyMedium,
          ),
          data: (liste) => liste.isEmpty
              ? Text(
                  'Hier nicht verfügbar. Käufe gibt es nur in der App aus dem '
                  'App Store, nicht im Browser.',
                  key: const Key('paid-unavailable'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final angebot in liste)
                      _PaidTile(
                        angebot: angebot,
                        gekauft: angebot.item.grants
                            .every((id) => shop.ownsItem(id)),
                      ),
                    TextButton(
                      key: const Key('restore-purchases'),
                      onPressed: () async {
                        final anzahl = await ref
                            .read(shopProvider.notifier)
                            .restorePurchases();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(anzahl == 0
                              ? 'Nichts wiederherzustellen.'
                              : '$anzahl wiederhergestellt.'),
                        ));
                      },
                      child: const Text('Käufe wiederherstellen'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PaidTile extends ConsumerWidget {
  const _PaidTile({required this.angebot, required this.gekauft});

  final PricedItem angebot;
  final bool gekauft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
                  Text(angebot.item.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    angebot.item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
                    key: Key('pay-${angebot.item.productId}'),
                    onPressed: () async {
                      final ergebnis = await ref
                          .read(shopProvider.notifier)
                          .buyWithMoney(angebot.item);
                      if (!context.mounted) return;
                      final text = switch (ergebnis) {
                        PurchaseResult.bought => 'Gekauft — viel Freude damit.',
                        PurchaseResult.restored => 'Wiederhergestellt.',
                        PurchaseResult.canceled => 'Abgebrochen.',
                        PurchaseResult.unavailable =>
                          'Hier nicht verfügbar.',
                        PurchaseResult.failed =>
                          'Der Kauf hat nicht geklappt.',
                      };
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(text)));
                    },
                    child: Text(angebot.price),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item, required this.shop});

  final ShopItem item;
  final ShopState shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gekauft = item.isPermanent && shop.ownsItem(item.id);
    final kannKaufen = !gekauft && shop.canAfford(item);

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
                    item.description,
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
