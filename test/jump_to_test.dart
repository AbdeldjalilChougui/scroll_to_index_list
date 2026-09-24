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
    int initialScrollIndex = 0,
    double initialAlignment = 0,
  }) async {
    await tester.pumpWidget(harness(ScrollToIndexList.builder(
      itemCount: itemCount,
      itemScrollController: controller,
      itemPositionsListener: listener,
      initialScrollIndex: initialScrollIndex,
      initialAlignment: initialAlignment,
      itemBuilder: (context, index) => item(index),
    )));
  }

  group('jumpTo', () {
    // Expected top of the target item for (index, alignment). The last items
    // must clamp so the list never shows blank space after its end, and the
    // first items must clamp so nothing shows before item 0.
    final cases = <(int, double, double)>[
      (0, 0, 0),
      (0, 0.5, 0), // cannot move item 0 down: clamps to the start
      (0, 1, 0),
      (3, 0.5, 150), // only 150 px of content above item 3
      (50, 0, 0),
      (50, 0.5, 300),
      (50, 1, 600), // leading edge on the trailing edge of the viewport
      (95, 0, 350), // 5 items below: clamps so item 99 ends at 600
      (99, 0, 550),
      (99, 0.5, 550),
      (99, 1, 600), // just after the viewport; item 98 ends at 600
    ];

    for (final (index, alignment, expectedTop) in cases) {
      testWidgets('index $index alignment $alignment puts top at $expectedTop',
          (tester) async {
        await pumpList(tester);
        controller.jumpTo(index: index, alignment: alignment);
        await tester.pumpAndSettle();

        if (expectedTop < kViewport) {
          expect(rectOf(tester, index).top, moreOrLessEquals(expectedTop));
          expectPositionsMatchLayout(tester, listener);
        } else {
          // The item sits just after the viewport; the one before ends there.
          expect(rectOf(tester, index - 1).bottom, moreOrLessEquals(kViewport));
          expect(positionOf(listener, index), isNull);
        }
        // Never blank space after the end of the list.
        final last = sortedPositions(listener).last;
        expect(last.itemTrailingEdge, greaterThanOrEqualTo(1 - 1e-9));
      });
    }

    testWidgets('does not need the extents of earlier items', (tester) async {
      final built = <int>{};
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 1000000,
        itemScrollController: controller,
        itemBuilder: (context, index) {
          built.add(index);
          return item(index);
        },
      )));
      built.clear();
      controller.jumpTo(index: 750000, alignment: 0.5);
      await tester.pump();
      expect(rectOf(tester, 750000).top, moreOrLessEquals(300));
      // Only a viewport plus cache extent worth of items was built.
      expect(built.length, lessThan(40));
      expect(built.every((i) => i > 749900 && i < 750100), isTrue);
    });

    testWidgets('out-of-range indices are clamped', (tester) async {
      await pumpList(tester, itemCount: 20);
      controller.jumpTo(index: 500);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 19).bottom, moreOrLessEquals(kViewport));
      controller.jumpTo(index: -3);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 0).top, moreOrLessEquals(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('list shorter than the viewport stays at the start',
        (tester) async {
      await pumpList(tester, itemCount: 5);
      controller.jumpTo(index: 4, alignment: 0.2);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 0).top, moreOrLessEquals(0));
      expect(rectOf(tester, 4).top, moreOrLessEquals(200));
    });

    testWidgets('user can scroll back above the jump target', (tester) async {
      await pumpList(tester);
      controller.jumpTo(index: 50);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ScrollToIndexList), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 50).top, moreOrLessEquals(120));
      expect(rectOf(tester, 48).top, moreOrLessEquals(20));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('user can scroll all the way back to item 0', (tester) async {
      await pumpList(tester);
      controller.jumpTo(index: 30);
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(ScrollToIndexList), const Offset(0, 400));
        await tester.pumpAndSettle();
      }
      expect(rectOf(tester, 0).top, moreOrLessEquals(0));
    });
  });

  group('initialScrollIndex', () {
    testWidgets('shows the item at the initial alignment on the first frame',
        (tester) async {
      await pumpList(tester, initialScrollIndex: 40, initialAlignment: 0.25);
      expect(rectOf(tester, 40).top, moreOrLessEquals(150));
      expect(positionOf(listener, 40)!.itemLeadingEdge, moreOrLessEquals(0.25));
    });

    testWidgets('initial index at the end clamps without blank space',
        (tester) async {
      await pumpList(tester, initialScrollIndex: 99);
      expect(rectOf(tester, 99).bottom, moreOrLessEquals(kViewport));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 99).bottom, moreOrLessEquals(kViewport));
    });

    testWidgets('initial index beyond itemCount is clamped', (tester) async {
      await pumpList(tester, itemCount: 30, initialScrollIndex: 1000);
      expect(rectOf(tester, 29).bottom, moreOrLessEquals(kViewport));
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list builds nothing and does not throw', (tester) async {
      await pumpList(tester, itemCount: 0, initialScrollIndex: 5);
      expect(listener.itemPositions.value, isEmpty);
      controller.jumpTo(index: 3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
