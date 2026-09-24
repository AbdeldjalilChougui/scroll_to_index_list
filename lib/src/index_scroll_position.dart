import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Returns the scroll extent of everything after the anchor item, once the
/// last item has been laid out, or null when that is not known or not
/// relevant (shrink-wrapped lists).
typedef TrailingExtentGetter = double? Function();

/// Computes a scroll offset from the viewport extent once it is known.
typedef PendingOffset = double Function(double viewportExtent);

/// Scroll controller whose positions are [IndexScrollPosition]s.
///
/// The list owns one of these privately, so it is never shared between two
/// scroll views.
class IndexScrollController extends ScrollController {
  /// Creates a controller that reads the trailing content extent from
  /// [trailingExtent].
  IndexScrollController({
    required this.trailingExtent,
    PendingOffset? initialOffset,
  })  : _initialOffset = initialOffset,
        super(keepScrollOffset: false);

  /// See [TrailingExtentGetter].
  final TrailingExtentGetter trailingExtent;

  PendingOffset? _initialOffset;

  /// The attached position.
  IndexScrollPosition get indexPosition => position as IndexScrollPosition;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    final position = IndexScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      trailingExtent: trailingExtent,
    );
    final initial = _initialOffset;
    if (initial != null && oldPosition == null) {
      position._pendingOffset = initial;
    }
    _initialOffset = null;
    return position;
  }
}

/// A scroll position whose offset 0 is the leading edge of the anchor item.
///
/// It adds three things to [ScrollPositionWithSingleContext]:
///
/// * a pending alignment, turned into pixels once the viewport extent is
///   known, so a jump needs no item extents;
/// * a maximum scroll extent that can be negative, so that the viewport never
///   shows blank space after the last item when the anchor is near the end;
/// * clamping into range during layout when no user gesture is in progress,
///   so jumps, programmatic animations and item count changes land inside the
///   content without a ballistic bounce.
class IndexScrollPosition extends ScrollPositionWithSingleContext {
  /// Creates a position starting at pixel 0.
  IndexScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.trailingExtent,
  }) : super(initialPixels: 0, keepScrollOffset: false);

  /// See [TrailingExtentGetter].
  final TrailingExtentGetter trailingExtent;

  PendingOffset? _pendingOffset;
  bool _clampOnLayout = true;
  bool _notifyScheduled = false;

  /// Sets the scroll offset to [offset] of the viewport extent on the next
  /// layout, for example to place the anchor at an alignment.
  void alignAnchor(PendingOffset offset) {
    goIdle();
    _pendingOffset = offset;
    _clampOnLayout = true;
    notifyListeners();
  }

  /// Silently sets [value] after the anchor changed, without reporting a
  /// scroll delta, and clamps it into range on the next layout.
  void reanchor(double value) {
    _pendingOffset = null;
    correctPixels(value);
    _clampOnLayout = true;
    notifyListeners();
  }

  /// The current activity; exposed so the list can tell who drives it.
  ScrollActivity? get currentActivity => activity;

  @override
  bool applyViewportDimension(double viewportDimension) {
    final result = super.applyViewportDimension(viewportDimension);
    final offset = _pendingOffset;
    if (offset != null) {
      _pendingOffset = null;
      correctPixels(offset(viewportDimension));
      _scheduleNotify();
    }
    return result;
  }

  bool get _shouldClamp {
    if (_clampOnLayout) return true;
    final a = activity;
    return a is IdleScrollActivity || a is IndexScrollActivity;
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    var max = maxScrollExtent;
    final trailing = trailingExtent();
    if (trailing != null && hasViewportDimension) {
      max = math.min(
        maxScrollExtent,
        math.max(minScrollExtent, trailing - viewportDimension),
      );
    }
    if (_shouldClamp && hasPixels) {
      final clamped = clampDouble(pixels, minScrollExtent, max);
      if ((clamped - pixels).abs() > precisionErrorTolerance) {
        correctPixels(clamped);
        _scheduleNotify();
        return false;
      }
    }
    if (!super.applyContentDimensions(minScrollExtent, max)) return false;
    _clampOnLayout = false;
    return true;
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    }, debugLabel: 'IndexScrollPosition.notify');
  }
}

/// Activity used while the list animates to an index.
///
/// [onEnd] runs when anything replaces it: the animation finishing, a new
/// animation, a jump or a user gesture.
class IndexScrollActivity extends ScrollActivity {
  /// Creates the activity.
  IndexScrollActivity(super.delegate, {required this.onEnd});

  /// Called once when the activity is disposed.
  final VoidCallback onEnd;

  double _velocity = 0;

  /// Updates the reported velocity in pixels per second.
  set currentVelocity(double value) => _velocity = value;

  @override
  bool get shouldIgnorePointer => true;

  @override
  bool get isScrolling => true;

  @override
  double get velocity => _velocity;

  @override
  void dispose() {
    onEnd();
    super.dispose();
  }
}
