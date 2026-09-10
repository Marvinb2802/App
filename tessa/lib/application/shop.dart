import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/purchases.dart';
import 'game_mode.dart';
import 'providers.dart';

/// Was der Shop anbietet.
///
/// HARTE GRENZE (siehe Fairness-Garantie in CLAUDE.md): Nichts hier darf die
/// Steinfolge beruehren. Es gibt keine besseren Teile, kein Weiterspielen nach
/// dem Ende und keine Vorteile im Tagesraetsel — nur Aussehen und ein paar
/// zusaetzliche Hinweise ausserhalb des Tagesraetsels.
enum ShopKind { hints, palette }

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

  /// Farbsets bleiben nach dem Kauf dauerhaft; Hinweise werden verbraucht.
  bool get isPermanent => kind == ShopKind.palette;
}

const List<ShopItem> shopItems = [
  ShopItem(
    id: 'hints3',
    name: 'Drei Hinweise',
    description: 'Für die laufende Runde. Im Tagesrätsel nicht verfügbar — '
        'dort hat jede und jeder dieselben drei.',
    price: 10,
    kind: ShopKind.hints,
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
  });

  final int stars;
  final Set<String> owned;
  final String palette;

  bool canAfford(ShopItem item) => stars >= item.price;

  bool ownsItem(String id) => owned.contains(id);

  ShopState copyWith({int? stars, Set<String>? owned, String? palette}) =>
      ShopState(
        stars: stars ?? this.stars,
        owned: owned ?? this.owned,
        palette: palette ?? this.palette,
      );

  String toJson() =>
      jsonEncode({'stars': stars, 'owned': owned.toList(), 'palette': palette});

  static ShopState fromJson(String? raw) {
    if (raw == null) return const ShopState();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ShopState(
        stars: data['stars'] as int? ?? 0,
        owned: (data['owned'] as List? ?? []).cast<String>().toSet(),
        palette: data['palette'] as String? ?? 'standard',
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

    if (item.kind == ShopKind.hints) {
      // Im Tagesraetsel bleibt es bei drei Hinweisen fuer alle — sonst waeren
      // die Ergebnisse des Tages nicht mehr vergleichbar.
      if (ref.read(gameModeProvider) == GameMode.daily) return false;
      ref.read(hintProvider.notifier).add(3);
    }

    state = state.copyWith(
      stars: state.stars - item.price,
      owned: {...state.owned, if (item.isPermanent) item.id},
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
    if (antwort.granted.isNotEmpty) {
      state = state.copyWith(owned: {...state.owned, ...antwort.granted});
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
