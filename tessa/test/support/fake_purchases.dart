import 'package:tessa/data/purchases.dart';

/// Ein Store zum Ausprobieren: kauft nichts, merkt sich aber alles.
class FakePurchases implements Purchases {
  FakePurchases({
    this.verfuegbar = true,
    this.ergebnis = PurchaseResult.bought,
    this.wiederherstellbar = const {},
  });

  final bool verfuegbar;
  final PurchaseResult ergebnis;
  final Set<String> wiederherstellbar;

  final List<String> gekauft = [];
  int wiederherstellungen = 0;

  @override
  Future<bool> available() async => verfuegbar;

  @override
  Future<List<PricedItem>> load() async => verfuegbar
      ? [for (final item in paidItems) PricedItem(item: item, price: '1,99 €')]
      : const [];

  @override
  Future<({PurchaseResult result, Set<String> granted})> buy(
      PaidItem item) async {
    gekauft.add(item.productId);
    final erfolgreich = ergebnis == PurchaseResult.bought ||
        ergebnis == PurchaseResult.restored;
    return (
      result: ergebnis,
      granted: erfolgreich ? item.grants : <String>{},
    );
  }

  @override
  Future<Set<String>> restore() async {
    wiederherstellungen += 1;
    return wiederherstellbar;
  }

  @override
  Future<void> dispose() async {}
}
