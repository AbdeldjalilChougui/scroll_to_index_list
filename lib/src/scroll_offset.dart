import 'dart:async';

import 'package:flutter/animation.dart';

import 'list_client.dart';

/// Scrolls a `ScrollToIndexList` by a number of pixels.
class ScrollOffsetController {
  /// Creates a controller that is not attached to any list yet.
  ScrollOffsetController();

  final ClientStack _clients = ClientStack();

  /// Whether a list is currently using this controller.
  bool get isAttached => _clients.isNotEmpty;

  /// Animates the list by [offset] logical pixels from where it is now.
  ///
  /// A positive [offset] moves towards the end of the list.
  ///
  /// Throws a [StateError] when [isAttached] is false.
  Future<void> animateScroll({
    required double offset,
    required Duration duration,
    Curve curve = Curves.linear,
  }) {
    final client = _clients.current;
    if (client == null) {
      throw StateError(
        'ScrollOffsetController is not attached to a ScrollToIndexList.',
      );
    }
    return client.animateScrollBy(offset, duration, curve);
  }
}

/// Attaches [client] to [controller]. Not exported.
void attachScrollOffsetController(
  ScrollOffsetController controller,
  ScrollToIndexClient client,
) =>
    controller._clients.attach(client);

/// Detaches [client] from [controller]. Not exported.
void detachScrollOffsetController(
  ScrollOffsetController controller,
  ScrollToIndexClient client,
) =>
    controller._clients.detach(client);

/// Streams scroll offset changes of a `ScrollToIndexList`.
abstract class ScrollOffsetListener {
  /// Creates a listener to pass to the list's `scrollOffsetListener`.
  ///
  /// When [recordProgrammaticScrolls] is false, only scrolling caused by the
  /// user (drags and the flings that follow them) is reported.
  factory ScrollOffsetListener.create(
          {bool recordProgrammaticScrolls = true}) =>
      ScrollOffsetNotifier(
          recordProgrammaticScrolls: recordProgrammaticScrolls);

  /// Stream of scroll deltas in logical pixels. Positive values move towards
  /// the end of the list.
  Stream<double> get changes;
}

/// Internal implementation of [ScrollOffsetListener]; not exported.
class ScrollOffsetNotifier implements ScrollOffsetListener {
  /// Creates a notifier.
  ScrollOffsetNotifier({this.recordProgrammaticScrolls = true});

  /// Whether scrolls started by a controller are reported.
  final bool recordProgrammaticScrolls;

  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  @override
  Stream<double> get changes => _controller.stream;

  /// Reports [delta]; [programmatic] tells whether a controller caused it.
  void report(double delta, {required bool programmatic}) {
    if (delta == 0) return;
    if (programmatic && !recordProgrammaticScrolls) return;
    _controller.add(delta);
  }
}
