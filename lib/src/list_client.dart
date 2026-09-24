import 'package:flutter/animation.dart';

/// What the controllers need from a mounted list. Not exported.
abstract interface class ScrollToIndexClient {
  /// Jumps so item [index]'s leading edge sits at [alignment].
  void jumpToIndex(int index, double alignment);

  /// Animates so item [index]'s leading edge ends at [alignment].
  Future<void> scrollToIndex(
    int index,
    double alignment,
    Duration duration,
    Curve curve,
  );

  /// Animates the scroll position by [offset] logical pixels.
  Future<void> animateScrollBy(double offset, Duration duration, Curve curve);
}

/// Keeps the clients a controller is attached to, newest last.
///
/// A controller can briefly be attached to two lists, for example while a
/// route transition or a key change builds the new list before the old one is
/// disposed. The newest list wins, and detaching an old list never detaches
/// the new one.
class ClientStack {
  final List<ScrollToIndexClient> _clients = <ScrollToIndexClient>[];

  /// Whether any client is attached.
  bool get isNotEmpty => _clients.isNotEmpty;

  /// The most recently attached client.
  ScrollToIndexClient? get current => _clients.isEmpty ? null : _clients.last;

  /// Attaches [client], moving it to the top if it was already attached.
  void attach(ScrollToIndexClient client) {
    _clients
      ..remove(client)
      ..add(client);
  }

  /// Detaches [client] if it is attached.
  void detach(ScrollToIndexClient client) => _clients.remove(client);
}
