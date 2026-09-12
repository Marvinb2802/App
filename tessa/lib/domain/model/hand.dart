import 'piece.dart';

/// Die drei Teile in der Hand. Ein bereits platzierter Platz ist null.
///
/// Nachschub kommt erst, wenn alle drei Teile platziert sind — die Hand selbst
/// fuellt sich nicht nach, das entscheidet der Zug (siehe rules/move.dart).
class Hand {
  Hand(List<Piece?> slots) : slots = List<Piece?>.unmodifiable(slots) {
    if (slots.length != slotCount) {
      throw ArgumentError('Eine Hand hat genau $slotCount Plaetze, hat ${slots.length}');
    }
  }

  static const int slotCount = 3;

  final List<Piece?> slots;

  factory Hand.of(List<Piece> pieces) => Hand(List<Piece?>.of(pieces));

  Piece? pieceAt(int slot) => slots[slot];

  Iterable<Piece> get remainingPieces => slots.whereType<Piece>();

  /// True, wenn alle drei Teile platziert sind — dann kommt eine neue Hand.
  bool get isEmpty => remainingPieces.isEmpty;

  int get remainingCount => remainingPieces.length;

  Hand withoutSlot(int slot) {
    if (slots[slot] == null) {
      throw ArgumentError('Platz $slot ist bereits leer');
    }
    final next = List<Piece?>.of(slots);
    next[slot] = null;
    return Hand(next);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Hand) return false;
    for (var i = 0; i < slotCount; i++) {
      if (slots[i] != other.slots[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(slots);

  @override
  String toString() =>
      slots.map((piece) => piece?.id ?? '-').join(', ');
}
