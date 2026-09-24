import 'package:flutter/animation.dart';

import 'list_client.dart';

/// Scrolls a `ScrollToIndexList` to an item index.
///
/// Create it once (for example in `State.initState`) and pass it to the
/// list's `itemScrollController`. It survives rebuilds, hot reload and the
/// list being replaced; when it is briefly attached to two lists it drives the
/// one mounted last.
class ItemScrollController {
  /// Creates a controller that is not attached to any list yet.
  ItemScrollController();

  final ClientStack _clients = ClientStack();

  /// Whether a list is currently using this controller.
  bool get isAttached => _clients.isNotEmpty;

  ScrollToIndexClient get _client {
    final client = _clients.current;
    if (client == null) {
      throw StateError(
        'ItemScrollController is not attached to a ScrollToIndexList. '
        'Check isAttached before calling jumpTo or scrollTo.',
      );
    }
    return client;
  }

  /// Immediately shows item [index] with its leading edge at [alignment].
  ///
  /// [alignment] is a fraction of the viewport: 0 puts the item's leading edge
  /// on the viewport's leading edge, 0.5 in the middle and 1 on the trailing
  /// edge. Near the ends of the list the result is clamped, so the list never
  /// shows blank space before its first or after its last item. [index] is
  /// clamped to the valid range.
  ///
  /// Throws a [StateError] when [isAttached] is false.
  void jumpTo({required int index, double alignment = 0}) {
    _client.jumpToIndex(index, alignment);
  }

  /// Animates until item [index] has its leading edge at [alignment].
  ///
  /// The animation scrolls through the real content. For a target that is far
  /// away it estimates the distance from the items it has already measured
  /// and corrects the estimate as the target comes into view, so the list
  /// moves continuously and lands exactly, without a crossfade.
  ///
  /// Calling [scrollTo] or [jumpTo] while an animation runs, or a user drag,
  /// stops the running animation and completes its future.
  ///
  /// [opacityAnimationWeights] is accepted for source compatibility with
  /// `scrollable_positioned_list` and ignored.
  ///
  /// Throws a [StateError] when [isAttached] is false.
  Future<void> scrollTo({
    required int index,
    double alignment = 0,
    required Duration duration,
    Curve curve = Curves.linear,
    @Deprecated('Ignored: ScrollToIndexList never crossfades.')
    List<double> opacityAnimationWeights = const <double>[40, 20, 40],
  }) {
    return _client.scrollToIndex(index, alignment, duration, curve);
  }
}

/// Attaches [client] to [controller]. Not exported.
void attachItemScrollController(
  ItemScrollController controller,
  ScrollToIndexClient client,
) =>
    controller._clients.attach(client);

/// Detaches [client] from [controller]. Not exported.
void detachItemScrollController(
  ItemScrollController controller,
  ScrollToIndexClient client,
) =>
    controller._clients.detach(client);
