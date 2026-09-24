import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

import 'index_scroll_position.dart';
import 'item_registry.dart';

/// Where a target item should end up, in scroll-offset pixels, clamped to the
/// scroll range. [exact] is false when the value is extrapolated from the
/// measured items because the target is not laid out yet.
typedef ScrollTarget = ({double value, bool exact});

/// What an [IndexScrollAnimation] needs from the list. Not exported.
abstract interface class IndexAnimationHost {
  /// The list's scroll position.
  IndexScrollPosition get position;

  /// Number of items.
  int get itemCount;

  /// Whether the list may move its anchor (false for shrink-wrapped lists).
  bool get canReanchor;

  /// Measured, laid-out items sorted by index.
  List<MeasuredItem> measure();

  /// Scroll offset that puts [index]'s leading edge at [alignment].
  ScrollTarget? target(int index, double alignment);

  /// Moves the anchor to [anchor] and the scroll offset to [pixels], in one
  /// frame, without reporting a scroll delta.
  void setAnchor(int anchor, double pixels);

  /// Reports a programmatic scroll delta that no notification carries.
  void reportVirtualDelta(double delta);

  /// Places [index] exactly at [alignment] without animation.
  void jumpExact(int index, double alignment);
}

/// Animates a list to an item index.
///
/// Two phases:
///
/// * **Near** (the target is laid out or estimated to be within a few
///   viewports): the scroll offset follows [curve] towards a target that is
///   re-evaluated every frame. When the estimate improves, the remaining path
///   is rescaled so the motion stays continuous and still ends on time.
/// * **Far**: laying out every item between here and the target would be
///   slow, so the animation follows a virtual path computed from the average
///   measured item extent. Each frame it re-anchors the list on the item the
///   path reaches, which builds only the items on screen. When the target is
///   close enough it anchors on the target itself and finishes with the near
///   phase, which lands exactly.
class IndexScrollAnimation {
  /// Creates an animation to [index] at [alignment].
  IndexScrollAnimation({
    required this.host,
    required this.index,
    required this.alignment,
    required this.duration,
    required this.curve,
  });

  /// Use the far phase when the target is estimated more than this many
  /// viewports away.
  static const double farThreshold = 3;

  /// Leave the far phase when the target is this many viewports away.
  static const double nearThreshold = 2;

  /// The list being animated.
  final IndexAnimationHost host;

  /// Target item.
  final int index;

  /// Target alignment.
  final double alignment;

  /// Total duration.
  final Duration duration;

  /// Easing curve.
  final Curve curve;

  final Completer<void> _completer = Completer<void>();
  Ticker? _ticker;
  IndexScrollActivity? _activity;
  bool _ended = false;

  // Near phase state.
  double _lastCurve = 0;
  double _lastPixels = 0;
  Duration _lastElapsed = Duration.zero;

  // Far phase state.
  bool _far = false;
  int _refIndex = 0;
  double _refLeading = 0;
  double _avgExtent = 1;
  double _startPixels = 0;
  double _distance = 0;
  double _lastVirtual = 0;

  /// Starts the animation; the future completes when it ends or is
  /// interrupted.
  Future<void> start() {
    final position = host.position;
    final target = host.target(index, alignment);
    if (target == null) {
      host.jumpExact(index, alignment);
      _completer.complete();
      return _completer.future;
    }
    _lastPixels = position.pixels;
    final viewport = position.viewportDimension;
    final estimate = target.value - position.pixels;
    final items = host.measure();
    if (!target.exact &&
        host.canReanchor &&
        items.isNotEmpty &&
        estimate.abs() > farThreshold * viewport) {
      _setUpFarPhase(items, position.pixels, viewport);
    }
    final activity = IndexScrollActivity(position, onEnd: _onActivityEnd);
    _activity = activity;
    position.beginActivity(activity);
    _ticker = position.context.vsync.createTicker(_tick)..start();
    return _completer.future;
  }

  void _setUpFarPhase(List<MeasuredItem> items, double pixels, double vp) {
    var ref = items.first;
    for (final item in items) {
      if (item.leading + item.extent > pixels) {
        ref = item;
        break;
      }
    }
    _refIndex = ref.index;
    _refLeading = ref.leading;
    _avgExtent = averageExtent(items);
    _startPixels = pixels;
    final targetLeading = _modelLeading(index);
    _distance = targetLeading - alignment * vp - pixels;
    _far = true;
  }

  double _modelLeading(int i) => _refLeading + (i - _refIndex) * _avgExtent;

  void _tick(Duration elapsed) {
    if (_ended) return;
    final position = host.position;
    final t = duration.inMicroseconds == 0
        ? 1.0
        : math.min(1.0, elapsed.inMicroseconds / duration.inMicroseconds);
    final c = curve.transform(t);
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;

    if (_far) {
      final vp = position.viewportDimension;
      final s = c * _distance;
      host.reportVirtualDelta(s - _lastVirtual);
      if (dt > 0) _activity?.currentVelocity = (s - _lastVirtual) / dt;
      _lastVirtual = s;
      final virtualPixels = _startPixels + s;
      final remaining = _distance - s;
      if (remaining.abs() <= nearThreshold * vp || t >= 1) {
        // Hand over to the near phase, anchored on the target itself.
        final pixels = virtualPixels - _modelLeading(index);
        _far = false;
        _lastCurve = t >= 1 ? math.min(c, 0.999) : c;
        _lastPixels = pixels;
        host.setAnchor(index, pixels);
        return;
      }
      final k =
          (_refIndex + ((virtualPixels - _refLeading) / _avgExtent).floor())
              .clamp(0, host.itemCount - 1);
      host.setAnchor(k, virtualPixels - _modelLeading(k));
      return;
    }

    final target = host.target(index, alignment);
    if (target == null) {
      _finish(null);
      return;
    }
    if (t >= 1) {
      _finish(target);
      return;
    }
    final f = target.value;
    final double next;
    if ((1 - _lastCurve).abs() < 1e-9) {
      next = f;
    } else {
      next = f - (f - _lastPixels) * (1 - c) / (1 - _lastCurve);
    }
    if (dt > 0) _activity?.currentVelocity = (next - position.pixels) / dt;
    position.setPixels(next);
    _lastCurve = c;
    _lastPixels = position.pixels;
  }

  void _finish(ScrollTarget? target) {
    final position = host.position;
    if (target != null && target.exact) {
      if ((target.value - position.pixels).abs() > 0.01) {
        position.setPixels(target.value);
      }
      position.goIdle();
    } else {
      host.jumpExact(index, alignment);
      position.goIdle();
    }
  }

  void _onActivityEnd() {
    if (_ended) return;
    _ended = true;
    final ticker = _ticker;
    if (ticker != null) {
      ticker.stop();
      scheduleMicrotask(ticker.dispose);
    }
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// Average main-axis extent per item (including any separator) of [items],
/// which must be sorted by index and not empty. Never below 1 pixel.
double averageExtent(List<MeasuredItem> items) {
  final first = items.first;
  final last = items.last;
  final avg = last.index > first.index
      ? (last.leading - first.leading) / (last.index - first.index)
      : first.extent;
  return math.max(avg, 1.0);
}
