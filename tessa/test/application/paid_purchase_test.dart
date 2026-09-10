import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/shop.dart';
import 'package:tessa/application/sound.dart';
import 'package:tessa/data/purchases.dart';

import '../support/fake_purchases.dart';
import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PaidItem angebot(String id) =>
      paidItems.firstWhere((item) => item.productId == id);

  ({ProviderContainer container, FakePurchases store}) aufbau({
    PurchaseResult ergebnis = PurchaseResult.bought,
    Set<String> wiederherstellbar = const {},
    int stars = 0,
  }) {
    final store = FakePurchases(
      ergebnis: ergebnis,
      wiederherstellbar: wiederherstellbar,
    );
    return (
      container: ProviderContainer.test(
        overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
          seedSourceProvider.overrideWithValue(() => 7),
          purchasesProvider.overrideWithValue(store),
          initialShopProvider.overrideWithValue(ShopState(stars: stars)),
        ],
      ),
      store: store,
    );
  }

  test('ein bezahlter Kauf schaltet das Farbset frei', () async {
    final a = aufbau();
    final ergebnis = await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.palette.neon'));

    expect(ergebnis, PurchaseResult.bought);
    expect(a.container.read(shopProvider).ownsItem('palette.neon'), isTrue);
    expect(a.store.gekauft, ['tessa.palette.neon']);
  });

  test('ein Paket schaltet alles darin frei', () async {
    final a = aufbau();
    await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.palettes.all'));

    final shop = a.container.read(shopProvider);
    expect(shop.ownsItem('palette.neon'), isTrue);
    expect(shop.ownsItem('palette.pastell'), isTrue);
    expect(shop.ownsItem('palette.mono'), isTrue);
  });

  test('ein abgebrochener Kauf aendert nichts', () async {
    final a = aufbau(ergebnis: PurchaseResult.canceled);
    final ergebnis = await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.palette.neon'));

    expect(ergebnis, PurchaseResult.canceled);
    expect(a.container.read(shopProvider).owned, isEmpty);
  });

  test('ein fehlgeschlagener Kauf schaltet nichts frei', () async {
    final a = aufbau(ergebnis: PurchaseResult.failed);
    await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.palette.neon'));
    expect(a.container.read(shopProvider).owned, isEmpty);
  });

  test('Geld kostet keine Sterne und bringt keine', () async {
    final a = aufbau(stars: 30);
    await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.palette.neon'));

    expect(a.container.read(shopProvider).stars, 30);
  });

  test('Wiederherstellen holt frueher Gekauftes zurueck', () async {
    final a = aufbau(wiederherstellbar: {'palette.neon', 'palette.mono'});
    final anzahl =
        await a.container.read(shopProvider.notifier).restorePurchases();

    expect(anzahl, 2);
    expect(a.container.read(shopProvider).ownsItem('palette.neon'), isTrue);
    expect(a.container.read(shopProvider).ownsItem('palette.mono'), isTrue);

    // Beim zweiten Mal gibt es nichts Neues.
    expect(await a.container.read(shopProvider.notifier).restorePurchases(), 0);
    expect(a.store.wiederherstellungen, 2);
  });

  test('ohne Store passiert nichts', () async {
    final container = ProviderContainer.test(
      overrides: [
        soundOutputProvider.overrideWithValue(RecordingOutput()),
        seedSourceProvider.overrideWithValue(() => 7),
      ],
    );

    final ergebnis = await container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.palette.neon'));

    expect(ergebnis, PurchaseResult.unavailable);
    expect(container.read(shopProvider).owned, isEmpty);
    expect(await container.read(shopProvider.notifier).restorePurchases(), 0);
  });

  test('fuer Geld gibt es ausschliesslich Aussehen', () {
    // Waechter zur Fairness-Garantie: kaeme je ein bezahltes Angebot dazu,
    // das etwas anderes freischaltet als ein Farbset, schlaegt dieser Test an.
    for (final item in paidItems) {
      expect(item.grants, isNotEmpty, reason: item.productId);
      for (final freigabe in item.grants) {
        expect(
          freigabe.startsWith('palette.'),
          isTrue,
          reason: '${item.productId} schaltet "$freigabe" frei — '
              'fuer Geld darf es nur Aussehen geben',
        );
      }
    }
  });
}
