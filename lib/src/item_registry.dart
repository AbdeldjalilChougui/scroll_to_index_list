import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Layout of one item, measured in scroll-offset space: [leading] is the
/// scroll offset at which the item's leading edge would sit on the viewport's
/// leading edge.
@immutable
class MeasuredItem {
  /// Creates a measurement.
  const MeasuredItem(this.index, this.leading, this.extent);

  /// Item index.
  final int index;

  /// Scroll offset of the item's leading edge.
  final double leading;

  /// Main-axis extent of the item.
  final double extent;
}

/// Tracks the item widgets that are currently mounted in a list.
class ItemRegistry {
  final Set<ItemMarkerState> _markers = <ItemMarkerState>{};

  /// Measures every mounted item that has a valid layout in the viewport,
  /// sorted by index. Kept-alive items that are out of the laid-out range are
  /// skipped because their stored offsets are stale.
  List<MeasuredItem> measure(Axis axis) {
    final result = <MeasuredItem>[];
    for (final marker in _markers) {
      final box = marker.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (!_isLaidOutInSliver(box)) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      final leading = viewport.getOffsetToReveal(box, 0).offset;
      final extent = axis == Axis.vertical ? box.size.height : box.size.width;
      result.add(MeasuredItem(marker.widget.index, leading, extent));
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  static bool _isLaidOutInSliver(RenderBox box) {
    RenderObject child = box;
    var parent = child.parent;
    while (parent != null && parent is! RenderSliverMultiBoxAdaptor) {
      child = parent;
      parent = child.parent;
    }
    if (parent is! RenderSliverMultiBoxAdaptor || child is! RenderBox) {
      return false;
    }
    return parent.paintsChild(child);
  }
}

/// Registers its subtree as item [index] in [registry] while mounted.
class ItemMarker extends StatefulWidget {
  /// Creates a marker.
  const ItemMarker({
    super.key,
    required this.index,
    required this.registry,
    required this.child,
  });

  /// Item index.
  final int index;

  /// Registry to join.
  final ItemRegistry registry;

  /// The item.
  final Widget child;

  @override
  State<ItemMarker> createState() => ItemMarkerState();
}

/// State of [ItemMarker].
class ItemMarkerState extends State<ItemMarker> {
  @override
  void initState() {
    super.initState();
    widget.registry._markers.add(this);
  }

  @override
  void didUpdateWidget(ItemMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registry != widget.registry) {
      oldWidget.registry._markers.remove(this);
      widget.registry._markers.add(this);
    }
  }

  @override
  void dispose() {
    widget.registry._markers.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
