import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/model/cell.dart';
import 'providers.dart';

/// Der laufende Zug: welches Teil haengt am Finger und ueber welchem Feld.
///
/// [anchor] ist die linke obere Ecke des Teils auf dem Brett, nicht die
/// Fingerposition — die Umrechnung von Pixeln auf Felder macht die Oberflaeche.
class DragState {
  const DragState({this.slot, this.anchor});

  static const DragState none = DragState();

  final int? slot;
  final Cell? anchor;

  bool get isActive => slot != null;

  DragState withAnchor(Cell? anchor) => DragState(slot: slot, anchor: anchor);

  @override
  bool operator ==(Object other) =>
      other is DragState && other.slot == slot && other.anchor == anchor;

  @override
  int get hashCode => Object.hash(slot, anchor);

  @override
  String toString() => isActive ? 'Zug: Platz $slot auf $anchor' : 'kein Zug';
}

/// Was die Oberflaeche waehrend des Ziehens anzeigt.
class DragPreview {
  const DragPreview({
    required this.slot,
    required this.cells,
    required this.isValid,
  });

  static const DragPreview none =
      DragPreview(slot: null, cells: <Cell>[], isValid: false);

  final int? slot;

  /// Die Zellen, die das Teil belegen wuerde — auch solche ausserhalb des
  /// Rasters, damit die Oberflaeche einen ungueltigen Zug zeigen kann.
  final List<Cell> cells;

  /// Waere der Zug erlaubt?
  final bool isValid;

  bool get isActive => slot != null;
}

/// Haelt den laufenden Zug und gibt ihn ans Spiel weiter.
class DragController extends Notifier<DragState> {
  @override
  DragState build() => DragState.none;

  /// Beginnt einen Zug mit dem Teil aus [slot].
  void start(int slot) => state = DragState(slot: slot);

  /// Setzt das Ziel auf ([x], [y]) — die linke obere Ecke des Teils.
  void moveTo(int x, int y) {
    if (!state.isActive) return;
    state = state.withAnchor(Cell(x, y));
  }

  /// Der Finger ist ueber keinem gueltigen Feld mehr.
  void leaveBoard() {
    if (!state.isActive) return;
    state = state.withAnchor(null);
  }

  void cancel() => state = DragState.none;

  /// Legt das Teil ab. Gibt false zurueck, wenn daraus kein Zug wurde; der
  /// laufende Zug endet in jedem Fall.
  bool drop() {
    final slot = state.slot;
    final anchor = state.anchor;
    state = DragState.none;
    if (slot == null || anchor == null) return false;
    return ref
        .read(gameControllerProvider.notifier)
        .place(slot: slot, x: anchor.x, y: anchor.y);
  }
}
