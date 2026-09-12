import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/purchases.dart';
import 'providers.dart';

/// Was der Shop anbietet.
///
/// GRENZE (siehe Fairness-Garantie in CLAUDE.md): Nichts hier darf die
/// Steinfolge beruehren — sonst verlieren Tagesraetsel, Bestwert je Spielcode
/// und das Nachspielen ihre Grundlage. Vorteile im Spielverlauf sind dagegen
/// ausdruecklich erlaubt: Hinweise, zusaetzliche Zurueck-Zuege und
/// Weiterspielen nach dem Ende.
enum ShopKind { hints, undos, revive, palette }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.kind,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final ShopKind kind;

  /// Farbsets bleiben nach dem Kauf dauerhaft; alles andere wird verbraucht.
  bool get isPermanent => kind == ShopKind.palette;
}

const List<ShopItem> shopItems = [
  ShopItem(
    id: 'hints3',
    name: 'Drei Hinweise',
    description: 'Für die laufende Runde.',
    price: 10,
    kind: ShopKind.hints,
  ),
  ShopItem(
    id: 'undo3',
    name: 'Drei Zurück-Züge',
    description: 'Drei zusätzliche Undos für die laufende Runde.',
    price: 15,
    kind: ShopKind.undos,
  ),
  ShopItem(
    id: 'revive1',
    name: 'Einmal weiterspielen',
    description: 'Nach dem Ende geht es weiter: Platz wird geschaffen, die '
        'Runde läuft mit deiner Punktzahl weiter.',
    price: 25,
    kind: ShopKind.revive,
  ),
  ShopItem(
    id: 'palette.neon',
    name: 'Farbset „Neon"',
    description: 'Kräftige Leuchtfarben für die Teile.',
    price: 40,
    kind: ShopKind.palette,
  ),
  ShopItem(
    id: 'palette.pastell',
    name: 'Farbset „Pastell"',
    description: 'Weiche, ruhige Töne.',
    price: 40,
    kind: ShopKind.palette,
  ),
  ShopItem(
    id: 'palette.mono',
    name: 'Farbset „Ein Ton"',
    description: 'Alle Teile in Blautönen — schlicht und streng.',
    price: 60,
    kind: ShopKind.palette,
  ),
];

/// Sterne, gekaufte Dinge und das gewählte Farbset.
class ShopState {
  const ShopState({
    this.stars = 0,
    this.owned = const {},
    this.palette = 'standard',
    this.revives = 0,
  });

  final int stars;
  final Set<String> owned;
  final String palette;

  /// Wie oft noch weitergespielt werden kann.
  final int revives;

  bool canAfford(ShopItem item) => stars >= item.price;

  bool ownsItem(String id) => owned.contains(id);

  ShopState copyWith({
    int? stars,
    Set<String>? owned,
    String? palette,
    int? revives,
  }) =>
      ShopState(
        stars: stars ?? this.stars,
        owned: owned ?? this.owned,
        palette: palette ?? this.palette,
        revives: revives ?? this.revives,
      );

  String toJson() => jsonEncode({
        'stars': stars,
        'owned': owned.toList(),
        'palette': palette,
        'revives': revives,
      });

  static ShopState fromJson(String? raw) {
    if (raw == null) return const ShopState();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ShopState(
        stars: data['stars'] as int? ?? 0,
        owned: (data['owned'] as List? ?? []).cast<String>().toSet(),
        palette: data['palette'] as String? ?? 'standard',
        revives: data['revives'] as int? ?? 0,
      );
    } catch (_) {
      return const ShopState();
    }
  }
}

/// Wie viele Sterne eine Runde einbringt.
///
/// Bewusst am Ergebnis bemessen und nicht an Geld: Sterne gibt es nur fuers
/// Spielen.
int starsForScore(int score) => score ~/ 250;

/// Bonus fuer das geschaffte Tagesziel.
const int starsForDailyGoal = 5;

final initialShopProvider = Provider<ShopState>((ref) => const ShopState());

class ShopController extends Notifier<ShopState> {
  @override
  ShopState build() => ref.read(initialShopProvider);

  void earn(int stars) {
    if (stars <= 0) return;
    state = state.copyWith(stars: state.stars + stars);
    unawaited(_save());
  }

  /// Kauft [item]. False, wenn die Sterne nicht reichen, es schon gekauft ist
  /// oder der Kauf gerade nicht erlaubt ist.
  bool buy(ShopItem item) {
    if (!state.canAfford(item)) return false;
    if (item.isPermanent && state.ownsItem(item.id)) return false;

    switch (item.kind) {
      case ShopKind.hints:
        ref.read(hintProvider.notifier).add(3);
      case ShopKind.undos:
        ref.read(gameControllerProvider.notifier).addUndos(3);
      case ShopKind.revive:
        break; // wird unten dem Vorrat gutgeschrieben
      case ShopKind.palette:
        break;
    }

    state = state.copyWith(
      stars: state.stars - item.price,
      owned: {...state.owned, if (item.isPermanent) item.id},
      revives: state.revives + (item.kind == ShopKind.revive ? 1 : 0),
    );
    unawaited(_save());
    return true;
  }

  /// Waehlt ein gekauftes Farbset aus.
  bool selectPalette(String id) {
    if (id != 'standard' && !state.ownsItem('palette.$id')) return false;
    state = state.copyWith(palette: id);
    unawaited(_save());
    return true;
  }

  /// Kauft [item] mit echtem Geld ueber den Store.
  ///
  /// Freigeschaltet wird dasselbe wie im Sterne-Shop — nur Aussehen. Sterne
  /// werden dabei weder verlangt noch gutgeschrieben.
  Future<PurchaseResult> buyWithMoney(PaidItem item) async {
    final antwort = await ref.read(purchasesProvider).buy(item);
    final erfolgreich = antwort.result == PurchaseResult.bought ||
        antwort.result == PurchaseResult.restored;
    if (erfolgreich) {
      if (item.hints > 0) ref.read(hintProvider.notifier).add(item.hints);
      if (item.undos > 0) {
        ref.read(gameControllerProvider.notifier).addUndos(item.undos);
      }
      state = state.copyWith(
        owned: {...state.owned, ...antwort.granted},
        revives: state.revives + item.revives,
      );
      await _save();
    }
    return antwort.result;
  }

  /// Holt frueher gekaufte Dinge zurueck — etwa auf einem neuen Geraet.
  /// Gibt zurueck, wie viele Dinge dazugekommen sind.
  Future<int> restorePurchases() async {
    final zurueck = await ref.read(purchasesProvider).restore();
    final neu = zurueck.difference(state.owned);
    if (neu.isNotEmpty) {
      state = state.copyWith(owned: {...state.owned, ...neu});
      await _save();
    }
    return neu.length;
  }

  /// Verbraucht ein Weiterspielen. False, wenn keines mehr da ist.
  bool consumeRevive() {
    if (state.revives <= 0) return false;
    state = state.copyWith(revives: state.revives - 1);
    unawaited(_save());
    return true;
  }

  Future<void> _save() async {
    try {
      await ref.read(storeProvider)?.writeSetting('shop', state.toJson());
    } catch (_) {
      // Ein misslungenes Speichern darf das Spiel nicht stoppen.
    }
  }
}

final shopProvider =
    NotifierProvider<ShopController, ShopState>(ShopController.new);
