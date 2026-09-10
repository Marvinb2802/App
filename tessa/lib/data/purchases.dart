import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Ein Angebot, das mit echtem Geld gekauft werden kann.
///
/// HARTE GRENZE (Fairness-Garantie, siehe CLAUDE.md): Hier darf ausschliesslich
/// Kosmetik stehen. Nichts, was mit Geld gekauft wird, darf die Steinfolge,
/// den Spielverlauf oder die Vergleichbarkeit von Ergebnissen beruehren.
class PaidItem {
  const PaidItem({
    required this.productId,
    required this.name,
    required this.description,
    required this.grants,
  });

  /// Die Kennung im App Store und bei Google Play.
  final String productId;

  final String name;
  final String description;

  /// Welche Dinge der Kauf freischaltet — dieselben Kennungen wie im
  /// Sterne-Shop, damit beide Wege zum selben Ergebnis führen.
  final Set<String> grants;
}

const List<PaidItem> paidItems = [
  PaidItem(
    productId: 'tessa.palettes.all',
    name: 'Alle Farbsets',
    description: 'Neon, Pastell und Ein Ton auf einmal — dauerhaft.',
    grants: {'palette.neon', 'palette.pastell', 'palette.mono'},
  ),
  PaidItem(
    productId: 'tessa.palette.neon',
    name: 'Farbset „Neon"',
    description: 'Kräftige Leuchtfarben für die Teile.',
    grants: {'palette.neon'},
  ),
  PaidItem(
    productId: 'tessa.palette.pastell',
    name: 'Farbset „Pastell"',
    description: 'Weiche, ruhige Töne.',
    grants: {'palette.pastell'},
  ),
];

/// Wie ein Kauf ausgegangen ist.
enum PurchaseResult { bought, restored, canceled, unavailable, failed }

/// Ein Angebot mit dem Preis, den der Store dafuer nennt.
class PricedItem {
  const PricedItem({required this.item, required this.price});

  final PaidItem item;

  /// Der Preis in der Waehrung des Nutzers, vom Store geliefert.
  final String price;
}

/// Kaeufe mit echtem Geld. In Tests und im Browser wird das ersetzt.
abstract class Purchases {
  /// Ob auf diesem Geraet ueberhaupt gekauft werden kann.
  Future<bool> available();

  /// Die Angebote samt Preisen, wie der Store sie nennt.
  Future<List<PricedItem>> load();

  /// Kauft [item]. Liefert die freigeschalteten Kennungen mit.
  Future<({PurchaseResult result, Set<String> granted})> buy(PaidItem item);

  /// Stellt frueher gekaufte Dinge wieder her — bei Apple Pflicht.
  Future<Set<String>> restore();

  Future<void> dispose();
}

/// Kaeufe sind hier nicht moeglich — etwa im Browser.
class UnavailablePurchases implements Purchases {
  const UnavailablePurchases();

  @override
  Future<bool> available() async => false;

  @override
  Future<List<PricedItem>> load() async => const [];

  @override
  Future<({PurchaseResult result, Set<String> granted})> buy(PaidItem item) async =>
      (result: PurchaseResult.unavailable, granted: <String>{});

  @override
  Future<Set<String>> restore() async => {};

  @override
  Future<void> dispose() async {}
}

/// Kaeufe ueber den App Store beziehungsweise Google Play.
///
/// Digitale Gueter muessen dort ueber das Bezahlsystem der Plattform laufen —
/// ein eigener Bezahlweg waere nicht zulaessig.
class StorePurchases implements Purchases {
  StorePurchases([InAppPurchase? store])
      : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Map<String, ProductDetails> _products = {};

  /// Laeuft ein Kauf, wartet hier auf sein Ergebnis.
  Completer<({PurchaseResult result, Set<String> granted})>? _laufend;
  final Set<String> _wiederhergestellt = {};
  Completer<void>? _restoreFertig;

  @override
  Future<bool> available() => _store.isAvailable();

  @override
  Future<List<PricedItem>> load() async {
    if (!await _store.isAvailable()) return const [];
    _listen();

    final antwort = await _store.queryProductDetails(
      {for (final item in paidItems) item.productId},
    );
    for (final produkt in antwort.productDetails) {
      _products[produkt.id] = produkt;
    }

    return [
      for (final item in paidItems)
        if (_products.containsKey(item.productId))
          PricedItem(item: item, price: _products[item.productId]!.price),
    ];
  }

  @override
  Future<({PurchaseResult result, Set<String> granted})> buy(
      PaidItem item) async {
    final produkt = _products[item.productId];
    if (produkt == null) {
      return (result: PurchaseResult.unavailable, granted: <String>{});
    }

    _listen();
    _laufend = Completer<({PurchaseResult result, Set<String> granted})>();
    // Farbsets sind dauerhaft, also kein Verbrauchsgut.
    await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: produkt),
    );
    return _laufend!.future;
  }

  @override
  Future<Set<String>> restore() async {
    _listen();
    _wiederhergestellt.clear();
    _restoreFertig = Completer<void>();
    await _store.restorePurchases();
    // Der Store meldet die Kaeufe ueber denselben Strom; kurz darauf warten.
    await Future.any([
      _restoreFertig!.future,
      Future<void>.delayed(const Duration(seconds: 5)),
    ]);
    return Set<String>.from(_wiederhergestellt);
  }

  void _listen() {
    _subscription ??= _store.purchaseStream.listen(_onUpdate);
  }

  Future<void> _onUpdate(List<PurchaseDetails> kaeufe) async {
    for (final kauf in kaeufe) {
      final item = paidItems
          .where((i) => i.productId == kauf.productID)
          .firstOrNull;

      switch (kauf.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (item != null) {
            _wiederhergestellt.addAll(item.grants);
            _laufend?.complete((
              result: kauf.status == PurchaseStatus.restored
                  ? PurchaseResult.restored
                  : PurchaseResult.bought,
              granted: item.grants,
            ));
            _laufend = null;
          }
        case PurchaseStatus.canceled:
          _laufend?.complete(
              (result: PurchaseResult.canceled, granted: <String>{}));
          _laufend = null;
        case PurchaseStatus.error:
          _laufend?.complete(
              (result: PurchaseResult.failed, granted: <String>{}));
          _laufend = null;
        case PurchaseStatus.pending:
          break;
      }

      // Jeder Kauf muss abgeschlossen werden, sonst meldet ihn der Store
      // immer wieder.
      if (kauf.pendingCompletePurchase) {
        await _store.completePurchase(kauf);
      }
    }
    if (!(_restoreFertig?.isCompleted ?? true)) _restoreFertig!.complete();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
