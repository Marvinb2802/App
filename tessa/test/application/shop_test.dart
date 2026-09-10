import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tessa/application/game_mode.dart';
import 'package:tessa/application/hint_controller.dart';
import 'package:tessa/application/providers.dart';
import 'package:tessa/application/shop.dart';
import 'package:tessa/application/sound.dart';

import '../support/fake_sound.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ShopItem item(String id) => shopItems.firstWhere((i) => i.id == id);

  ProviderContainer container({int stars = 0, Set<String> owned = const {}}) =>
      ProviderContainer.test(
        overrides: [
          soundOutputProvider.overrideWithValue(RecordingOutput()),
          seedSourceProvider.overrideWithValue(() => 7),
          initialShopProvider
              .overrideWithValue(ShopState(stars: stars, owned: owned)),
        ],
      );

  test('Sterne gibt es fuers Spielen, nicht fuer Geld', () {
    expect(starsForScore(0), 0);
    expect(starsForScore(249), 0);
    expect(starsForScore(250), 1);
    expect(starsForScore(3000), 12);
  });

  test('verdiente Sterne landen auf dem Konto', () {
    final c = container();
    c.read(shopProvider.notifier).earn(7);
    expect(c.read(shopProvider).stars, 7);

    c.read(shopProvider.notifier).earn(0);
    expect(c.read(shopProvider).stars, 7, reason: 'nichts zu holen');
  });

  test('ein Farbset kostet Sterne und bleibt dann dauerhaft', () {
    final c = container(stars: 100);
    final neon = item('palette.neon');

    expect(c.read(shopProvider.notifier).buy(neon), isTrue);
    expect(c.read(shopProvider).stars, 100 - neon.price);
    expect(c.read(shopProvider).ownsItem('palette.neon'), isTrue);

    expect(c.read(shopProvider.notifier).buy(neon), isFalse,
        reason: 'zweimal kaufen ergibt keinen Sinn');
    expect(c.read(shopProvider).stars, 100 - neon.price);
  });

  test('ohne genug Sterne gibt es nichts', () {
    final c = container(stars: 5);
    expect(c.read(shopProvider.notifier).buy(item('palette.mono')), isFalse);
    expect(c.read(shopProvider).stars, 5);
    expect(c.read(shopProvider).owned, isEmpty);
  });

  test('Hinweise werden verbraucht, nicht besessen', () {
    final c = container(stars: 50);
    final hinweise = item('hints3');

    expect(c.read(hintProvider).left, HintState.perRound);
    expect(c.read(shopProvider.notifier).buy(hinweise), isTrue);

    expect(c.read(hintProvider).left, HintState.perRound + 3);
    expect(c.read(shopProvider).ownsItem('hints3'), isFalse);
    expect(c.read(shopProvider).stars, 50 - hinweise.price);

    // Nachkaufen bleibt moeglich.
    expect(c.read(shopProvider.notifier).buy(hinweise), isTrue);
    expect(c.read(hintProvider).left, HintState.perRound + 6);
  });

  test('gekaufte Hinweise gelten auch im Tagesraetsel', () {
    // Geaendert auf Wunsch des Auftraggebers: Kaeufe duerfen Vorteile bringen,
    // auch im Raetsel des Tages.
    final c = container(stars: 100);
    c.read(gameModeProvider.notifier).set(GameMode.daily);

    expect(c.read(shopProvider.notifier).buy(item('hints3')), isTrue);
    expect(c.read(hintProvider).left, HintState.perRound + 3);
  });

  test('Zurueck-Zuege lassen sich nachkaufen', () {
    final c = container(stars: 100);
    final vorher = c.read(gameControllerProvider).undosLeft;

    expect(c.read(shopProvider.notifier).buy(item('undo3')), isTrue);
    expect(c.read(gameControllerProvider).undosLeft, vorher + 3);
  });

  test('Weiterspielen wandert in den Vorrat', () {
    final c = container(stars: 100);
    expect(c.read(shopProvider).revives, 0);

    expect(c.read(shopProvider.notifier).buy(item('revive1')), isTrue);
    expect(c.read(shopProvider).revives, 1);

    expect(c.read(shopProvider.notifier).consumeRevive(), isTrue);
    expect(c.read(shopProvider).revives, 0);
    expect(c.read(shopProvider.notifier).consumeRevive(), isFalse,
        reason: 'leerer Vorrat');
  });

  test('ein Farbset laesst sich erst nach dem Kauf waehlen', () {
    final c = container(stars: 100);

    expect(c.read(shopProvider.notifier).selectPalette('neon'), isFalse);
    expect(c.read(shopProvider).palette, 'standard');

    c.read(shopProvider.notifier).buy(item('palette.neon'));
    expect(c.read(shopProvider.notifier).selectPalette('neon'), isTrue);
    expect(c.read(shopProvider).palette, 'neon');

    expect(c.read(shopProvider.notifier).selectPalette('standard'), isTrue,
        reason: 'das Standardset gehoert allen');
  });

  test('der Stand ueberlebt als Text und zurueck', () {
    const stand = ShopState(
      stars: 42,
      owned: {'palette.neon'},
      palette: 'neon',
    );
    final zurueck = ShopState.fromJson(stand.toJson());

    expect(zurueck.stars, 42);
    expect(zurueck.owned, {'palette.neon'});
    expect(zurueck.palette, 'neon');
  });

  test('beschaedigter Stand faellt auf den Anfang zurueck', () {
    final zurueck = ShopState.fromJson('kaputt');
    expect(zurueck.stars, 0);
    expect(zurueck.owned, isEmpty);
    expect(zurueck.palette, 'standard');
  });

  test('kein Angebot beruehrt die Steinfolge', () {
    // Waechter zur Fairness-Garantie in ihrer heutigen Fassung: Vorteile im
    // Verlauf sind erlaubt (Hinweise, Zurueck-Zuege, Weiterspielen), Aussehen
    // ohnehin. Kaeme je ein Angebot dazu, das andere Teile oder eine andere
    // Reihenfolge verspricht, muesste dieser Test scheitern -- damit waeren
    // Tagesraetsel, Bestwert je Spielcode und Nachspielen hinfaellig.
    for (final angebot in shopItems) {
      expect(
        angebot.kind,
        anyOf(
          ShopKind.hints,
          ShopKind.undos,
          ShopKind.revive,
          ShopKind.palette,
        ),
        reason: '${angebot.id} ist von anderer Art',
      );
    }
  });
}
