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

  Future<void> pumpList(
    WidgetTester tester, {
    int itemCount = 100,
    double Function(int)? extent,
    Set<int>? built,
  }) async {
    await tester.pumpWidget(harness(ScrollToIndexList.builder(
      itemCount: itemCount,
      itemScrollController: controller,
      itemPositionsListener: listener,
      itemBuilder: (context, index) {
        built?.add(index);
        return item(index, extent: extent?.call(index) ?? kItem);
      },
    )));
  }

  const duration = Duration(milliseconds: 500);

  group('scrollTo', () {
    testWidgets('near target: completes at the exact position', (tester) async {
      await pumpList(tester);
      var done = false;
      controller
          .scrollTo(index: 8, alignment: 0.5, duration: duration)
          .then((_) => done = true);
      await tester.pump();
      await tester.pump(duration ~/ 2);
      // Mid-animation the list has moved, but not all the way.
      final mid = rectOf(tester, 8).top;
      expect(mid, lessThan(400));
      expect(mid, greaterThan(300));
      expect(done, isFalse);
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(rectOf(tester, 8).top, moreOrLessEquals(300));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('moves continuously: no frame jumps backwards', (tester) async {
      await pumpList(tester, itemCount: 5000);
      controller.scrollTo(index: 3000, duration: duration);
      await tester.pump();
      var previousFirst = 0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final first = sortedPositions(listener).first.index;
        expect(first, greaterThanOrEqualTo(previousFirst));
        previousFirst = first;
      }
      await tester.pumpAndSettle();
      expect(rectOf(tester, 3000).top, moreOrLessEquals(0));
    });

    testWidgets('far target: animates without building every item between',
        (tester) async {
      final built = <int>{};
      await pumpList(tester, itemCount: 100000, built: built);
      built.clear();
      final future = controller.scrollTo(
          index: 90000, alignment: 0.25, duration: duration);
      await tester.pumpAndSettle();
      await future;
      expect(rectOf(tester, 90000).top, moreOrLessEquals(150));
      expect(built.length, lessThan(3000));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('far target backwards lands exactly', (tester) async {
      await pumpList(tester, itemCount: 100000, extent: variableExtent);
      controller.jumpTo(index: 80000);
      await tester.pumpAndSettle();
      controller.scrollTo(index: 12, alignment: 0.1, duration: duration);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 12).top, moreOrLessEquals(60));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('scrolling to the last item does not overshoot or bounce',
        (tester) async {
      await pumpList(tester);
      controller.scrollTo(index: 99, duration: duration);
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        // Never blank space after the last item, on any frame.
        final last = sortedPositions(listener).last;
        if (last.index == 99) {
          expect(last.itemTrailingEdge, greaterThanOrEqualTo(1 - 1e-9));
        }
      }
      await tester.pumpAndSettle();
      expect(rectOf(tester, 99).bottom, moreOrLessEquals(kViewport));
      // Settled: another frame does not move anything.
      await tester.pump(const Duration(seconds: 1));
      expect(rectOf(tester, 99).bottom, moreOrLessEquals(kViewport));
    });

    testWidgets('scrolling to the first item with alignment clamps at start',
        (tester) async {
      await pumpList(tester);
      controller.jumpTo(index: 60);
      await tester.pumpAndSettle();
      controller.scrollTo(index: 0, alignment: 0.5, duration: duration);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 0).top, moreOrLessEquals(0));
    });

    testWidgets('scrollTo during an ongoing scrollTo retargets smoothly',
        (tester) async {
      await pumpList(tester, itemCount: 500);
      var firstDone = false;
      controller
          .scrollTo(index: 200, duration: duration)
          .then((_) => firstDone = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final before = sortedPositions(listener).first.index;
      final second =
          controller.scrollTo(index: 20, alignment: 0.5, duration: duration);
      await tester.pump();
      // The new animation starts from where the old one was.
      expect(
          (sortedPositions(listener).first.index - before).abs(), lessThan(5));
      await tester.pumpAndSettle();
      await second;
      expect(firstDone, isTrue);
      expect(rectOf(tester, 20).top, moreOrLessEquals(300));
    });

    testWidgets('jumpTo during scrollTo cancels the animation', (tester) async {
      await pumpList(tester, itemCount: 500);
      var done = false;
      controller
          .scrollTo(index: 300, duration: duration)
          .then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.jumpTo(index: 40);
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(rectOf(tester, 40).top, moreOrLessEquals(0));
    });

    testWidgets('a user drag interrupts scrollTo and completes its future',
        (tester) async {
      await pumpList(tester, itemCount: 500);
      var done = false;
      controller
          .scrollTo(index: 300, duration: const Duration(seconds: 2))
          .then((_) => done = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.drag(find.byType(ScrollToIndexList), const Offset(0, -50));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(positionOf(listener, 300), isNull);
    });

    testWidgets('variable extents: lands exactly on a far item',
        (tester) async {
      await pumpList(tester, itemCount: 2000, extent: variableExtent);
      controller.scrollTo(index: 1500, alignment: 0.5, duration: duration);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 1500).top, moreOrLessEquals(300));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('zero duration behaves like jumpTo', (tester) async {
      await pumpList(tester);
      await controller.scrollTo(index: 30, duration: Duration.zero);
      await tester.pump();
      expect(rectOf(tester, 30).top, moreOrLessEquals(0));
    });
  });
}
