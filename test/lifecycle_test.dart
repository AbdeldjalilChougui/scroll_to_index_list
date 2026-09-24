import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_list/scroll_to_index_list.dart';

import 'helpers.dart';

void main() {
  late ItemScrollController controller;
  late ItemPositionsListener listener;

  setUp(() {
    controller = ItemScrollController();
    listener = ItemPositionsListener.create();
  });

  Widget list({
    Key? key,
    int itemCount = 100,
    ItemScrollController? itemScrollController,
    ScrollOffsetController? scrollOffsetController,
    ScrollOffsetListener? scrollOffsetListener,
  }) {
    return ScrollToIndexList.builder(
      key: key,
      itemCount: itemCount,
      itemScrollController: itemScrollController ?? controller,
      itemPositionsListener: listener,
      scrollOffsetController: scrollOffsetController,
      scrollOffsetListener: scrollOffsetListener,
      itemBuilder: (context, index) => item(index),
    );
  }

  group('ItemScrollController lifecycle', () {
    testWidgets('isAttached follows mount and unmount', (tester) async {
      expect(controller.isAttached, isFalse);
      await tester.pumpWidget(harness(list()));
      expect(controller.isAttached, isTrue);
      await tester.pumpWidget(harness(const SizedBox()));
      expect(controller.isAttached, isFalse);
    });

    testWidgets('survives parent rebuilds and keeps the scroll position',
        (tester) async {
      await tester.pumpWidget(harness(list()));
      controller.jumpTo(index: 40);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(harness(list()));
      }
      expect(controller.isAttached, isTrue);
      expect(rectOf(tester, 40).top, moreOrLessEquals(0));
      controller.jumpTo(index: 60);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 60).top, moreOrLessEquals(0));
    });

    testWidgets('survives hot reload', (tester) async {
      await tester.pumpWidget(harness(list()));
      controller.jumpTo(index: 25, alignment: 0.5);
      await tester.pumpAndSettle();
      // reassembleApplication completes after the next frame, so pump it.
      final reassembled = tester.binding.reassembleApplication();
      await tester.pump();
      await reassembled;
      await tester.pumpAndSettle();
      expect(controller.isAttached, isTrue);
      expect(rectOf(tester, 25).top, moreOrLessEquals(300));
      controller.jumpTo(index: 70);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 70).top, moreOrLessEquals(0));
    });

    testWidgets('swapping the controller detaches the old one', (tester) async {
      final other = ItemScrollController();
      await tester.pumpWidget(harness(list()));
      await tester.pumpWidget(harness(list(itemScrollController: other)));
      expect(controller.isAttached, isFalse);
      expect(other.isAttached, isTrue);
      other.jumpTo(index: 10);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 10).top, moreOrLessEquals(0));
    });

    testWidgets(
        'new list mounted before the old one is disposed: no assertion, '
        'the controller drives the newest list', (tester) async {
      await tester.pumpWidget(harness(list(key: const ValueKey<int>(1))));
      // Replacing the key creates a new State; both exist during the swap.
      await tester.pumpWidget(harness(list(key: const ValueKey<int>(2))));
      expect(tester.takeException(), isNull);
      expect(controller.isAttached, isTrue);
      controller.jumpTo(index: 33);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 33).top, moreOrLessEquals(0));
    });

    testWidgets(
        'two lists sharing controllers: no "ScrollController attached to '
        'multiple scroll views" error', (tester) async {
      final offsetController = ScrollOffsetController();
      await tester.pumpWidget(harness(Column(children: [
        Expanded(child: list(scrollOffsetController: offsetController)),
        Expanded(child: list(scrollOffsetController: offsetController)),
      ])));
      expect(tester.takeException(), isNull);
      controller.jumpTo(index: 50);
      await tester.pumpAndSettle();
      offsetController.animateScroll(
          offset: 20, duration: const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.drag(
          find.byType(ScrollToIndexList).first, const Offset(0, -100));
      await tester.drag(
          find.byType(ScrollToIndexList).last, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists inside a PrimaryScrollController do not claim it',
        (tester) async {
      final primary = ScrollController();
      addTearDown(primary.dispose);
      await tester.pumpWidget(harness(PrimaryScrollController(
        controller: primary,
        child: Column(children: [
          Expanded(child: list()),
          Expanded(child: list()),
        ]),
      )));
      expect(primary.hasClients, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('calling jumpTo while detached throws a clear StateError',
        (tester) async {
      expect(() => controller.jumpTo(index: 1), throwsStateError);
      expect(
          () => controller.scrollTo(
              index: 1, duration: const Duration(seconds: 1)),
          throwsStateError);
    });
  });

  group('itemCount changes', () {
    testWidgets('shrinking below the current index shows the new end',
        (tester) async {
      await tester.pumpWidget(harness(list()));
      controller.jumpTo(index: 80);
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(list(itemCount: 50)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(rectOf(tester, 49).bottom, moreOrLessEquals(kViewport));
      final positions = sortedPositions(listener);
      expect(positions.last.index, 49);
      expect(positions.every((p) => p.index < 50), isTrue);
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('shrinking to a few items shows them from the start',
        (tester) async {
      await tester.pumpWidget(harness(list()));
      controller.jumpTo(index: 80);
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(list(itemCount: 3)));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 0).top, moreOrLessEquals(0));
      expect(sortedPositions(listener).map((p) => p.index), [0, 1, 2]);
    });

    testWidgets('shrinking to zero and growing back', (tester) async {
      await tester.pumpWidget(harness(list()));
      controller.jumpTo(index: 80);
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(list(itemCount: 0)));
      await tester.pumpAndSettle();
      expect(listener.itemPositions.value, isEmpty);
      await tester.pumpWidget(harness(list(itemCount: 100)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('shrinking at the end while scrolled near it clamps',
        (tester) async {
      await tester.pumpWidget(harness(list()));
      controller.jumpTo(index: 60);
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(list(itemCount: 65)));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 64).bottom, moreOrLessEquals(kViewport));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('growing keeps the visible items where they are',
        (tester) async {
      await tester.pumpWidget(harness(list()));
      controller.jumpTo(index: 40, alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(list(itemCount: 1000)));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 40).top, moreOrLessEquals(180));
      expectPositionsMatchLayout(tester, listener);
    });
  });

  group('item positions', () {
    testWidgets('initial positions are reported after the first frame',
        (tester) async {
      await tester.pumpWidget(harness(list()));
      final indices = sortedPositions(listener).map((p) => p.index).toList();
      expect(indices, List<int>.generate(12, (i) => i));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('stay correct while the user drags and flings', (tester) async {
      await tester.pumpWidget(harness(list()));
      final gesture = await tester
          .startGesture(tester.getCenter(find.byType(ScrollToIndexList)));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -37));
        await tester.pump();
        expectPositionsMatchLayout(tester, listener);
      }
      await gesture.up();
      await tester.pump();
      await tester.fling(
          find.byType(ScrollToIndexList), const Offset(0, -300), 1500);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectPositionsMatchLayout(tester, listener);
      }
      await tester.pumpAndSettle();
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('stay correct during scrollTo, frame by frame', (tester) async {
      await tester.pumpWidget(harness(list(itemCount: 3000)));
      controller.scrollTo(index: 2500, duration: const Duration(seconds: 1));
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectPositionsMatchLayout(tester, listener);
      }
    });

    testWidgets('notify listeners when positions change', (tester) async {
      var calls = 0;
      listener.itemPositions.addListener(() => calls++);
      await tester.pumpWidget(harness(list()));
      final afterMount = calls;
      expect(afterMount, greaterThan(0));
      controller.jumpTo(index: 30);
      await tester.pump();
      expect(calls, greaterThan(afterMount));
    });

    testWidgets('ItemPosition value semantics', (tester) async {
      const a = ItemPosition(index: 1, itemLeadingEdge: 0, itemTrailingEdge: 1);
      const b = ItemPosition(index: 1, itemLeadingEdge: 0, itemTrailingEdge: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('index: 1'));
    });
  });

  group('ScrollOffsetController and ScrollOffsetListener', () {
    testWidgets('animateScroll moves by a relative number of pixels',
        (tester) async {
      final offsetController = ScrollOffsetController();
      await tester
          .pumpWidget(harness(list(scrollOffsetController: offsetController)));
      controller.jumpTo(index: 10);
      await tester.pumpAndSettle();
      final future = offsetController.animateScroll(
          offset: 125, duration: const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await future;
      expect(rectOf(tester, 12).top, moreOrLessEquals(-25));
      expect(rectOf(tester, 13).top, moreOrLessEquals(25));
    });

    testWidgets('listener reports scroll deltas', (tester) async {
      final offsetListener = ScrollOffsetListener.create();
      final deltas = <double>[];
      final sub = offsetListener.changes.listen(deltas.add);
      addTearDown(sub.cancel);
      await tester
          .pumpWidget(harness(list(scrollOffsetListener: offsetListener)));
      await tester.drag(find.byType(ScrollToIndexList), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(deltas.fold<double>(0, (a, b) => a + b), moreOrLessEquals(200));
    });

    testWidgets('far scrollTo reports deltas that add up to the distance',
        (tester) async {
      final offsetListener = ScrollOffsetListener.create();
      final deltas = <double>[];
      final sub = offsetListener.changes.listen(deltas.add);
      addTearDown(sub.cancel);
      await tester.pumpWidget(
          harness(list(itemCount: 1000, scrollOffsetListener: offsetListener)));
      controller.scrollTo(index: 500, duration: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 500).top, moreOrLessEquals(0));
      final total = deltas.fold<double>(0, (a, b) => a + b);
      expect(total, moreOrLessEquals(500 * kItem, epsilon: 1));
    });

    testWidgets('listener can ignore programmatic scrolls', (tester) async {
      final offsetListener =
          ScrollOffsetListener.create(recordProgrammaticScrolls: false);
      final deltas = <double>[];
      final sub = offsetListener.changes.listen(deltas.add);
      addTearDown(sub.cancel);
      await tester
          .pumpWidget(harness(list(scrollOffsetListener: offsetListener)));
      controller.scrollTo(
          index: 5, duration: const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(deltas, isEmpty);
    });
  });
}
