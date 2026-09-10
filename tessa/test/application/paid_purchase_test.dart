import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/hint_controller.dart';
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

  test('bezahlte Hinweise und Zurueck-Zuege wirken sofort', () async {
    final a = aufbau();
    final vorherUndos = a.container.read(gameControllerProvider).undosLeft;

    await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.hints.10'));
    await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.undos.10'));
    await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.revive.3'));

    expect(a.container.read(hintProvider).left, HintState.perRound + 10);
    expect(a.container.read(gameControllerProvider).undosLeft,
        vorherUndos + 10);
    expect(a.container.read(shopProvider).revives, 3);
  });

  test('ein abgebrochener Kauf bringt auch keine Hinweise', () async {
    final a = aufbau(ergebnis: PurchaseResult.canceled);
    await a.container
        .read(shopProvider.notifier)
        .buyWithMoney(angebot('tessa.hints.10'));

    expect(a.container.read(hintProvider).left, HintState.perRound);
    expect(a.container.read(shopProvider).revives, 0);
  });

  test('kein bezahltes Angebot beruehrt die Steinfolge', () {
    // Waechter zur Fairness-Garantie in ihrer heutigen Fassung: Vorteile im
    // Verlauf duerfen verkauft werden. Dauerhaft freischalten darf ein Kauf
    // aber nur Aussehen — kaeme je ein Angebot dazu, das andere Teile oder
    // eine andere Reihenfolge verspricht, schlaegt dieser Test an.
    for (final item in paidItems) {
      final wirktIrgendwie = item.grants.isNotEmpty ||
          item.hints > 0 ||
          item.undos > 0 ||
          item.revives > 0;
      expect(wirktIrgendwie, isTrue, reason: '${item.productId} tut nichts');

      for (final freigabe in item.grants) {
        expect(
          freigabe.startsWith('palette.'),
          isTrue,
          reason: '${item.productId} schaltet "$freigabe" dauerhaft frei — '
              'dauerhaft darf nur Aussehen sein',
        );
      }
    }
  });
}
