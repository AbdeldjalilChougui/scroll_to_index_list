import 'package:flutter/foundation.dart';

/// Position of one item in the viewport of a `ScrollToIndexList`.
///
/// Edges are fractions of the viewport's main-axis extent, measured from the
/// viewport's leading edge in the scroll direction: the top for a vertical
/// list, the bottom for a reversed vertical list, the left for a horizontal
/// left-to-right list and the right for a horizontal right-to-left list.
@immutable
class ItemPosition {
  /// Creates an [ItemPosition].
  const ItemPosition({
    required this.index,
    required this.itemLeadingEdge,
    required this.itemTrailingEdge,
  });

  /// Index of the item.
  final int index;

  /// Distance from the viewport's leading edge to the item's leading edge,
  /// as a fraction of the viewport extent.
  ///
  /// Negative when the item is partly scrolled out before the viewport.
  final double itemLeadingEdge;

  /// Distance from the viewport's leading edge to the item's trailing edge,
  /// as a fraction of the viewport extent.
  ///
  /// Greater than 1 when the item is partly scrolled out after the viewport.
  final double itemTrailingEdge;

  @override
  bool operator ==(Object other) =>
      other is ItemPosition &&
      other.index == index &&
      other.itemLeadingEdge == itemLeadingEdge &&
      other.itemTrailingEdge == itemTrailingEdge;

  @override
  int get hashCode => Object.hash(index, itemLeadingEdge, itemTrailingEdge);

  @override
  String toString() => 'ItemPosition(index: $index, '
      'itemLeadingEdge: $itemLeadingEdge, itemTrailingEdge: $itemTrailingEdge)';
}

/// Reports which items of a `ScrollToIndexList` are visible.
///
/// Create one with [ItemPositionsListener.create] and pass it to the list's
/// `itemPositionsListener` parameter.
abstract class ItemPositionsListener {
  /// Creates a listener that a `ScrollToIndexList` can report to.
  factory ItemPositionsListener.create() = ItemPositionsNotifier;

  /// Positions of the items that are at least partly visible.
  ///
  /// Updated after every frame in which the visible items moved. The order of
  /// the iterable is not specified.
  ValueListenable<Iterable<ItemPosition>> get itemPositions;
}

/// Internal implementation of [ItemPositionsListener]; not exported.
class ItemPositionsNotifier implements ItemPositionsListener {
  /// Creates a notifier with no positions.
  ItemPositionsNotifier();

  @override
  final ValueNotifier<Iterable<ItemPosition>> itemPositions =
      ValueNotifier<Iterable<ItemPosition>>(const <ItemPosition>[]);

  /// Publishes [positions] when they differ from the current value.
  void update(List<ItemPosition> positions) {
    final current = itemPositions.value;
    if (current is List<ItemPosition> && listEquals(current, positions)) {
      return;
    }
    itemPositions.value = List<ItemPosition>.unmodifiable(positions);
  }
}
