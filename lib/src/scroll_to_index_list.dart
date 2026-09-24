import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'index_scroll_animation.dart';
import 'index_scroll_position.dart';
import 'item_position.dart';
import 'item_registry.dart';
import 'item_scroll_controller.dart';
import 'list_client.dart';
import 'scroll_offset.dart';

/// A scrollable list that can jump or animate to any item index and report
/// which items are visible.
///
/// It has the same constructor parameters as `ScrollablePositionedList`, so
/// migrating is a rename. Internally it is a single [CustomScrollView] whose
/// scroll offset 0 is anchored on an item (see [CustomScrollView.center]):
/// items after the anchor grow towards the end and items before it grow
/// towards the start. Jumping to any index therefore needs no extents of the
/// items before it, and scrolling never crossfades between two lists.
class ScrollToIndexList extends StatefulWidget {
  /// Creates a list whose items are built on demand by [itemBuilder].
  const ScrollToIndexList.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemScrollController,
    this.shrinkWrap = false,
    this.itemPositionsListener,
    this.scrollOffsetController,
    this.scrollOffsetListener,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
  })  : assert(itemCount >= 0),
        separatorBuilder = null;

  /// Creates a list with a separator, built by [separatorBuilder], between
  /// each pair of consecutive items.
  ///
  /// Separator `i` sits between item `i` and item `i + 1`. Separators are not
  /// reported by [itemPositionsListener] and cannot be scrolled to.
  const ScrollToIndexList.separated({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required IndexedWidgetBuilder this.separatorBuilder,
    this.itemScrollController,
    this.shrinkWrap = false,
    this.itemPositionsListener,
    this.scrollOffsetController,
    this.scrollOffsetListener,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
  }) : assert(itemCount >= 0);

  /// Number of items.
  final int itemCount;

  /// Builds item `index`, for `0 <= index < itemCount`.
  final IndexedWidgetBuilder itemBuilder;

  /// Builds the separator after item `index`, or null for [builder] lists.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Jumps or animates to an index.
  final ItemScrollController? itemScrollController;

  /// Scrolls by a number of pixels.
  final ScrollOffsetController? scrollOffsetController;

  /// Receives the positions of the visible items.
  final ItemPositionsListener? itemPositionsListener;

  /// Receives scroll deltas.
  final ScrollOffsetListener? scrollOffsetListener;

  /// Item shown first, placed at [initialAlignment]. Clamped to the valid
  /// range.
  final int initialScrollIndex;

  /// Where the leading edge of [initialScrollIndex] is placed, as a fraction
  /// of the viewport (0 = leading edge, 1 = trailing edge).
  final double initialAlignment;

  /// Scroll axis.
  final Axis scrollDirection;

  /// Whether item 0 sits at the bottom (or at the right in left-to-right
  /// horizontal lists), as in a chat.
  final bool reverse;

  /// Scroll physics.
  final ScrollPhysics? physics;

  /// Whether the list sizes itself to its content along the scroll axis.
  ///
  /// A shrink-wrapped viewport cannot anchor on an item, so a shrink-wrapped
  /// list lays out the items before the target when it jumps. Use it only for
  /// short lists.
  final bool shrinkWrap;

  /// Number of semantic children; defaults to [itemCount].
  final int? semanticChildCount;

  /// Space around the items: the leading side before item 0, the trailing
  /// side after the last item, and the cross-axis sides around every item.
  final EdgeInsetsGeometry? padding;

  /// Whether items are wrapped in [IndexedSemantics] with their item index.
  final bool addSemanticIndexes;

  /// Whether items are wrapped in [AutomaticKeepAlive].
  final bool addAutomaticKeepAlives;

  /// Whether items are wrapped in [RepaintBoundary].
  final bool addRepaintBoundaries;

  /// Minimum cache extent in pixels, laid out before and after the viewport.
  /// The default cache extent is used when this is smaller.
  final double? minCacheExtent;

  @override
  State<ScrollToIndexList> createState() => _ScrollToIndexListState();
}

@immutable
class _ChildKey extends LocalKey {
  const _ChildKey(this.index, {required this.separator});

  final int index;
  final bool separator;

  @override
  bool operator ==(Object other) =>
      other is _ChildKey &&
      other.index == index &&
      other.separator == separator;

  @override
  int get hashCode => Object.hash(index, separator);
}

class _ScrollToIndexListState extends State<ScrollToIndexList>
    implements ScrollToIndexClient, IndexAnimationHost {
  final GlobalKey _centerKey =
      GlobalKey(debugLabel: 'ScrollToIndexList.center');
  final ItemRegistry _registry = ItemRegistry();
  late final IndexScrollController _scrollController;
  late int _anchor;
  bool _positionsScheduled = false;
  double _leadingPadding = 0;
  int _programmaticDepth = 0;

  @override
  void initState() {
    super.initState();
    final count = widget.itemCount;
    final initial = _clampIndex(widget.initialScrollIndex, count);
    _anchor = widget.shrinkWrap ? 0 : initial;
    _scrollController = IndexScrollController(
      trailingExtent: _trailingExtent,
      initialOffset: widget.shrinkWrap
          ? null
          : _anchorOffset(initial, widget.initialAlignment),
    )..addListener(_schedulePositions);
    _attach(widget);
    if (widget.shrinkWrap &&
        count > 0 &&
        (initial != 0 || widget.initialAlignment != 0)) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _shrinkWrapJump(initial, widget.initialAlignment, 0),
      );
    }
  }

  @override
  void didUpdateWidget(ScrollToIndexList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemScrollController != widget.itemScrollController ||
        oldWidget.scrollOffsetController != widget.scrollOffsetController) {
      _detach(oldWidget);
      _attach(widget);
    }
    final count = widget.itemCount;
    final hasPosition = _scrollController.hasClients;
    if (widget.shrinkWrap != oldWidget.shrinkWrap) {
      if (widget.shrinkWrap && _anchor != 0) {
        _anchor = 0;
        if (hasPosition) _position.reanchor(0);
      }
    } else if (!widget.shrinkWrap && count != oldWidget.itemCount) {
      if (count == 0 && _anchor != 0) {
        _anchor = 0;
        if (hasPosition) _position.reanchor(0);
      } else if (count > 0 && _anchor >= count) {
        // The anchor item is gone. Anchor on the new last item; clamping
        // during layout then shows the end of the list.
        _anchor = count - 1;
        if (hasPosition) _position.reanchor(0);
      }
    }
  }

  @override
  void dispose() {
    _detach(widget);
    _scrollController.dispose();
    super.dispose();
  }

  void _attach(ScrollToIndexList w) {
    final items = w.itemScrollController;
    if (items != null) attachItemScrollController(items, this);
    final offsets = w.scrollOffsetController;
    if (offsets != null) attachScrollOffsetController(offsets, this);
  }

  void _detach(ScrollToIndexList w) {
    final items = w.itemScrollController;
    if (items != null) detachItemScrollController(items, this);
    final offsets = w.scrollOffsetController;
    if (offsets != null) detachScrollOffsetController(offsets, this);
  }

  static int _clampIndex(int index, int count) =>
      count == 0 ? 0 : index.clamp(0, count - 1);

  IndexScrollPosition get _position => _scrollController.indexPosition;

  double? _trailingExtent() {
    if (widget.shrinkWrap) return null;
    final sliver = _centerKey.currentContext?.findRenderObject();
    if (sliver is RenderSliver) return sliver.geometry?.scrollExtent;
    return null;
  }

  // ---------------------------------------------------------------------
  // Controller API.

  @override
  void jumpToIndex(int index, double alignment) {
    final count = widget.itemCount;
    if (count == 0 || !_scrollController.hasClients) return;
    final target = _clampIndex(index, count);
    if (widget.shrinkWrap) {
      _shrinkWrapJump(target, alignment, 0);
      return;
    }
    setState(() => _anchor = target);
    _position.alignAnchor(_anchorOffset(target, alignment));
  }

  /// Offset that puts the anchor [index] at [alignment]. Item 0 also reveals
  /// the leading padding, like the start of a [ListView].
  PendingOffset _anchorOffset(int index, double alignment) {
    return (extent) =>
        -alignment * extent - (index == 0 ? _leadingPadding : 0.0);
  }

  @override
  Future<void> scrollToIndex(
    int index,
    double alignment,
    Duration duration,
    Curve curve,
  ) async {
    final count = widget.itemCount;
    if (count == 0 || !_scrollController.hasClients) return;
    final target = _clampIndex(index, count);
    if (duration <= Duration.zero) {
      jumpToIndex(target, alignment);
      return;
    }
    _programmaticDepth++;
    try {
      await IndexScrollAnimation(
        host: this,
        index: target,
        alignment: alignment,
        duration: duration,
        curve: curve,
      ).start();
    } finally {
      _programmaticDepth--;
    }
  }

  @override
  Future<void> animateScrollBy(
    double offset,
    Duration duration,
    Curve curve,
  ) async {
    if (!_scrollController.hasClients) return;
    final position = _position;
    final to = position.pixels + offset;
    _programmaticDepth++;
    try {
      if (duration <= Duration.zero) {
        position.jumpTo(to);
      } else {
        await position.animateTo(to, duration: duration, curve: curve);
      }
    } finally {
      _programmaticDepth--;
    }
  }

  void _shrinkWrapJump(int index, double alignment, int attempt) {
    if (!mounted || !_scrollController.hasClients) return;
    final target = this.target(index, alignment);
    final position = _position;
    final settled = target != null &&
        target.exact &&
        (target.value - position.pixels).abs() < 0.5;
    if (settled) return;
    if (target != null) position.jumpTo(target.value);
    if (attempt < 30) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _shrinkWrapJump(index, alignment, attempt + 1),
      );
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  // ---------------------------------------------------------------------
  // IndexAnimationHost.

  @override
  IndexScrollPosition get position => _position;

  @override
  int get itemCount => widget.itemCount;

  @override
  bool get canReanchor => !widget.shrinkWrap;

  @override
  List<MeasuredItem> measure() => _registry.measure(widget.scrollDirection);

  @override
  ScrollTarget? target(int index, double alignment) {
    if (!_scrollController.hasClients) return null;
    final position = _position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return null;
    }
    final items = measure();
    if (items.isEmpty) return null;
    MeasuredItem? hit;
    for (final item in items) {
      if (item.index == index) {
        hit = item;
        break;
      }
    }
    final double leading;
    if (hit != null) {
      leading = hit.leading;
    } else {
      final avg = averageExtent(items);
      leading = index > items.last.index
          ? items.last.leading + (index - items.last.index) * avg
          : items.first.leading - (items.first.index - index) * avg;
    }
    final value = clampDouble(
      leading -
          alignment * position.viewportDimension -
          (index == 0 ? _leadingPadding : 0.0),
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    return (value: value, exact: hit != null);
  }

  @override
  void setAnchor(int anchor, double pixels) {
    if (!mounted) return;
    setState(() => _anchor = anchor);
    _position.reanchor(pixels);
  }

  @override
  void reportVirtualDelta(double delta) {
    final listener = widget.scrollOffsetListener;
    if (listener is ScrollOffsetNotifier) {
      listener.report(delta, programmatic: true);
    }
  }

  @override
  void jumpExact(int index, double alignment) => jumpToIndex(index, alignment);

  // ---------------------------------------------------------------------
  // Item positions.

  void _schedulePositions() {
    if (_positionsScheduled) return;
    _positionsScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _updatePositions(),
      debugLabel: 'ScrollToIndexList.positions',
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _updatePositions() {
    _positionsScheduled = false;
    if (!mounted || !_scrollController.hasClients) return;
    final notifier = widget.itemPositionsListener;
    if (notifier is! ItemPositionsNotifier) return;
    final position = _position;
    if (!position.hasPixels || !position.hasViewportDimension) return;
    final extent = position.viewportDimension;
    if (extent <= 0) return;
    final pixels = position.pixels;
    final positions = <ItemPosition>[];
    for (final item in measure()) {
      final leading = (item.leading - pixels) / extent;
      final trailing = (item.leading + item.extent - pixels) / extent;
      if (trailing > 0 && leading < 1) {
        positions.add(ItemPosition(
          index: item.index,
          itemLeadingEdge: leading,
          itemTrailingEdge: trailing,
        ));
      }
    }
    notifier.update(positions);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _schedulePositions();
    final listener = widget.scrollOffsetListener;
    if (notification is ScrollUpdateNotification &&
        listener is ScrollOffsetNotifier) {
      final activity = _position.currentActivity;
      final byUser = notification.dragDetails != null ||
          (_programmaticDepth == 0 && activity is BallisticScrollActivity);
      listener.report(notification.scrollDelta ?? 0, programmatic: !byUser);
    }
    return false;
  }

  bool _onMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) _schedulePositions();
    return false;
  }

  // ---------------------------------------------------------------------
  // Build.

  Widget _buildItem(BuildContext context, int index) {
    return ItemMarker(
      key: _ChildKey(index, separator: false),
      index: index,
      registry: _registry,
      child: widget.itemBuilder(context, index),
    );
  }

  Widget _buildSeparator(BuildContext context, int index) {
    return KeyedSubtree(
      key: _ChildKey(index, separator: true),
      child: widget.separatorBuilder!(context, index),
    );
  }

  static int? _semanticIndex(Widget child, int localIndex) {
    final key = child.key;
    if (key is _ChildKey && !key.separator) return key.index;
    return null;
  }

  /// Items `start ..< itemCount`, growing away from the anchor.
  SliverChildDelegate _forwardDelegate(int start) {
    final count = widget.itemCount;
    final separated = widget.separatorBuilder != null;
    final n = math.max(0, count - start);
    return SliverChildBuilderDelegate(
      (context, local) {
        if (!separated) return _buildItem(context, start + local);
        final i = start + local ~/ 2;
        return local.isEven
            ? _buildItem(context, i)
            : _buildSeparator(context, i);
      },
      childCount: separated ? math.max(0, 2 * n - 1) : n,
      findChildIndexCallback: (key) {
        if (key is! _ChildKey || key.index < start || key.index >= count) {
          return null;
        }
        final offset = key.index - start;
        if (!separated) return key.separator ? null : offset;
        if (key.separator && key.index >= count - 1) return null;
        return key.separator ? 2 * offset + 1 : 2 * offset;
      },
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
      semanticIndexCallback: _semanticIndex,
    );
  }

  /// Items `anchor - 1` down to 0, growing away from the anchor.
  SliverChildDelegate _backwardDelegate(int anchor) {
    final separated = widget.separatorBuilder != null;
    return SliverChildBuilderDelegate(
      (context, local) {
        if (!separated) return _buildItem(context, anchor - 1 - local);
        final i = anchor - 1 - local ~/ 2;
        // Local 0 is the separator between item anchor - 1 and the anchor.
        return local.isEven
            ? _buildSeparator(context, i)
            : _buildItem(context, i);
      },
      childCount: separated ? 2 * anchor : anchor,
      findChildIndexCallback: (key) {
        if (key is! _ChildKey || key.index < 0 || key.index >= anchor) {
          return null;
        }
        final offset = anchor - 1 - key.index;
        if (!separated) return key.separator ? null : offset;
        return key.separator ? 2 * offset : 2 * offset + 1;
      },
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addSemanticIndexes: widget.addSemanticIndexes,
      semanticIndexCallback: _semanticIndex,
    );
  }

  static EdgeInsets _withoutSide(EdgeInsets padding, AxisDirection side) {
    return switch (side) {
      AxisDirection.down => padding.copyWith(top: 0),
      AxisDirection.up => padding.copyWith(bottom: 0),
      AxisDirection.right => padding.copyWith(left: 0),
      AxisDirection.left => padding.copyWith(right: 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    _schedulePositions();
    final count = widget.itemCount;
    final anchor = widget.shrinkWrap ? 0 : _clampIndex(_anchor, count);
    final direction = getAxisDirectionFromAxisReverseAndDirectionality(
      context,
      widget.scrollDirection,
      widget.reverse,
    );
    final padding = widget.padding?.resolve(Directionality.maybeOf(context)) ??
        EdgeInsets.zero;
    _leadingPadding = switch (direction) {
      AxisDirection.down => padding.top,
      AxisDirection.up => padding.bottom,
      AxisDirection.right => padding.left,
      AxisDirection.left => padding.right,
    };

    final List<Widget> slivers;
    if (widget.shrinkWrap) {
      slivers = <Widget>[
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: _forwardDelegate(0)),
        ),
      ];
    } else {
      slivers = <Widget>[
        // Items before the anchor: keep the leading padding (far from the
        // anchor), drop the trailing one.
        SliverPadding(
          padding: _withoutSide(padding, flipAxisDirection(direction)),
          sliver: SliverList(delegate: _backwardDelegate(anchor)),
        ),
        SliverPadding(
          key: _centerKey,
          padding: _withoutSide(padding, direction),
          sliver: SliverList(delegate: _forwardDelegate(anchor)),
        ),
      ];
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          controller: _scrollController,
          primary: false,
          scrollDirection: widget.scrollDirection,
          reverse: widget.reverse,
          physics: widget.physics,
          shrinkWrap: widget.shrinkWrap,
          center: widget.shrinkWrap ? null : _centerKey,
          cacheExtent: math.max(
            widget.minCacheExtent ?? 0,
            RenderAbstractViewport.defaultCacheExtent,
          ),
          semanticChildCount: widget.semanticChildCount ?? count,
          slivers: slivers,
        ),
      ),
    );
  }
}
