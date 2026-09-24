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

  group('reverse', () {
    Future<void> pumpReversed(WidgetTester tester,
        {int initialScrollIndex = 0}) {
      return tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 100,
        reverse: true,
        initialScrollIndex: initialScrollIndex,
        itemScrollController: controller,
        itemPositionsListener: listener,
        itemBuilder: (context, index) => item(index),
      )));
    }

    testWidgets('item 0 sits at the bottom, like a chat', (tester) async {
      await pumpReversed(tester);
      expect(rectOf(tester, 0).bottom, moreOrLessEquals(kViewport));
      expect(rectOf(tester, 1).bottom, moreOrLessEquals(kViewport - kItem));
      final p0 = positionOf(listener, 0)!;
      expect(p0.itemLeadingEdge, moreOrLessEquals(0));
      expect(p0.itemTrailingEdge, moreOrLessEquals(kItem / kViewport));
    });

    testWidgets('jumpTo aligns from the bottom edge', (tester) async {
      await pumpReversed(tester);
      controller.jumpTo(index: 40, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 40).bottom, moreOrLessEquals(300));
      expect(positionOf(listener, 40)!.itemLeadingEdge, moreOrLessEquals(0.5));
    });

    testWidgets('jumpTo the oldest message leaves no blank space at the top',
        (tester) async {
      await pumpReversed(tester);
      controller.jumpTo(index: 99, alignment: 0);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 99).top, moreOrLessEquals(0));
    });

    testWidgets('initial index in a reversed list', (tester) async {
      await pumpReversed(tester, initialScrollIndex: 10);
      expect(rectOf(tester, 10).bottom, moreOrLessEquals(kViewport));
    });

    testWidgets('scrollTo in a reversed list', (tester) async {
      await pumpReversed(tester);
      controller.scrollTo(
          index: 60, alignment: 0.25, duration: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 60).bottom, moreOrLessEquals(450));
    });
  });

  group('far scrollTo in every layout', () {
    const duration = Duration(milliseconds: 600);

    testWidgets('reverse', (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 20000,
        reverse: true,
        itemScrollController: controller,
        itemPositionsListener: listener,
        itemBuilder: (context, index) =>
            item(index, extent: variableExtent(index)),
      )));
      controller.scrollTo(index: 15000, alignment: 0.5, duration: duration);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 15000).bottom, moreOrLessEquals(300));
      controller.scrollTo(index: 19999, duration: duration);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 19999).top, moreOrLessEquals(0));
    });

    testWidgets('separated', (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.separated(
        itemCount: 20000,
        itemScrollController: controller,
        itemPositionsListener: listener,
        itemBuilder: (context, index) => item(index),
        separatorBuilder: (context, index) => const SizedBox(height: 7),
      )));
      controller.scrollTo(index: 12345, alignment: 0.3, duration: duration);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 12345).top, moreOrLessEquals(180));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('horizontal RTL', (tester) async {
      await tester.pumpWidget(harness(
        ScrollToIndexList.builder(
          itemCount: 20000,
          scrollDirection: Axis.horizontal,
          itemScrollController: controller,
          itemBuilder: (context, index) =>
              item(index, axis: Axis.horizontal, extent: 45),
        ),
        axis: Axis.horizontal,
        textDirection: TextDirection.rtl,
      ));
      controller.scrollTo(index: 9000, alignment: 0.5, duration: duration);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 9000).right, moreOrLessEquals(300));
    });
  });

  group('horizontal', () {
    Future<void> pumpHorizontal(WidgetTester tester, TextDirection dir,
        {bool reverse = false}) {
      return tester.pumpWidget(harness(
        ScrollToIndexList.builder(
          itemCount: 100,
          scrollDirection: Axis.horizontal,
          reverse: reverse,
          itemScrollController: controller,
          itemPositionsListener: listener,
          itemBuilder: (context, index) =>
              item(index, axis: Axis.horizontal, extent: 60),
        ),
        axis: Axis.horizontal,
        textDirection: dir,
      ));
    }

    testWidgets('LTR: jumpTo aligns from the left', (tester) async {
      await pumpHorizontal(tester, TextDirection.ltr);
      expect(rectOf(tester, 0).left, moreOrLessEquals(0));
      controller.jumpTo(index: 30, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 30).left, moreOrLessEquals(300));
      expect(positionOf(listener, 30)!.itemLeadingEdge, moreOrLessEquals(0.5));
      expect(positionOf(listener, 30)!.itemTrailingEdge,
          moreOrLessEquals(360 / kViewport));
    });

    testWidgets('RTL: items start on the right', (tester) async {
      await pumpHorizontal(tester, TextDirection.rtl);
      expect(rectOf(tester, 0).right, moreOrLessEquals(kViewport));
      controller.jumpTo(index: 30, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 30).right, moreOrLessEquals(300));
      expect(positionOf(listener, 30)!.itemLeadingEdge, moreOrLessEquals(0.5));
    });

    testWidgets('RTL reversed: items start on the left', (tester) async {
      await pumpHorizontal(tester, TextDirection.rtl, reverse: true);
      expect(rectOf(tester, 0).left, moreOrLessEquals(0));
      controller.jumpTo(index: 99);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 99).right, moreOrLessEquals(kViewport));
    });

    testWidgets('horizontal scrollTo', (tester) async {
      await pumpHorizontal(tester, TextDirection.ltr);
      controller.scrollTo(
          index: 70, alignment: 0.1, duration: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 70).left, moreOrLessEquals(60));
    });
  });

  group('separated', () {
    Future<void> pumpSeparated(WidgetTester tester) {
      return tester.pumpWidget(harness(ScrollToIndexList.separated(
        itemCount: 100,
        itemScrollController: controller,
        itemPositionsListener: listener,
        itemBuilder: (context, index) => item(index),
        separatorBuilder: (context, index) => SizedBox(
          key: ValueKey<String>('sep-$index'),
          height: 10,
        ),
      )));
    }

    testWidgets('builds a separator between each pair of items',
        (tester) async {
      await pumpSeparated(tester);
      expect(rectOf(tester, 1).top, moreOrLessEquals(60));
      expect(find.byKey(const ValueKey<String>('sep-0')), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey<String>('sep-0'))).top,
          moreOrLessEquals(50));
    });

    testWidgets('positions report items only, never separators',
        (tester) async {
      await pumpSeparated(tester);
      final indices = sortedPositions(listener).map((p) => p.index).toList();
      // 600 px / 60 px per item+separator = 10 visible items.
      expect(indices, List<int>.generate(10, (i) => i));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('jumpTo and scrollTo target items', (tester) async {
      await pumpSeparated(tester);
      controller.jumpTo(index: 50, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 50).top, moreOrLessEquals(300));
      // Separator 49 sits just above item 50.
      expect(
          tester.getRect(find.byKey(const ValueKey<String>('sep-49'))).bottom,
          moreOrLessEquals(300));
      controller.scrollTo(
          index: 10, alignment: 0.2, duration: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 10).top, moreOrLessEquals(120));
      expectPositionsMatchLayout(tester, listener);
    });

    testWidgets('last item clamps with no trailing separator', (tester) async {
      await pumpSeparated(tester);
      controller.jumpTo(index: 99);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 99).bottom, moreOrLessEquals(kViewport));
      expect(find.byKey(const ValueKey<String>('sep-99')), findsNothing);
    });
  });

  group('variable item extents', () {
    testWidgets('jumpTo is exact for any alignment', (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 500,
        itemScrollController: controller,
        itemPositionsListener: listener,
        itemBuilder: (context, index) =>
            item(index, extent: variableExtent(index)),
      )));
      for (final (index, alignment) in [(250, 0.0), (137, 0.5), (400, 0.9)]) {
        controller.jumpTo(index: index, alignment: alignment);
        await tester.pumpAndSettle();
        expect(
            rectOf(tester, index).top, moreOrLessEquals(alignment * kViewport));
        expectPositionsMatchLayout(tester, listener);
      }
    });

    testWidgets('last item clamps with variable extents', (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 500,
        itemScrollController: controller,
        itemBuilder: (context, index) =>
            item(index, extent: variableExtent(index)),
      )));
      controller.jumpTo(index: 497, alignment: 0.3);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 499).bottom, moreOrLessEquals(kViewport));
    });
  });

  group('padding', () {
    testWidgets('leading padding before item 0, trailing after the last',
        (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 100,
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 30),
        itemScrollController: controller,
        itemBuilder: (context, index) => item(index),
      )));
      expect(rectOf(tester, 0).top, moreOrLessEquals(20));
      expect(rectOf(tester, 0).left, moreOrLessEquals(8));
      expect(rectOf(tester, 0).width, moreOrLessEquals(kCross - 16));
      controller.jumpTo(index: 99);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 99).bottom, moreOrLessEquals(kViewport - 30));
      controller.jumpTo(index: 0, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 0).top, moreOrLessEquals(20));
      controller.jumpTo(index: 40, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 40).top, moreOrLessEquals(300));
    });
  });

  group('shrinkWrap', () {
    testWidgets('sizes to its content', (tester) async {
      await tester.pumpWidget(harness(Column(children: [
        ScrollToIndexList.builder(
          itemCount: 3,
          shrinkWrap: true,
          itemBuilder: (context, index) => item(index),
        ),
      ])));
      expect(tester.getSize(find.byType(ScrollToIndexList)).height,
          moreOrLessEquals(150));
    });

    testWidgets('initialScrollIndex, jumpTo and scrollTo work', (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 200,
        shrinkWrap: true,
        initialScrollIndex: 20,
        itemScrollController: controller,
        itemPositionsListener: listener,
        itemBuilder: (context, index) =>
            item(index, extent: variableExtent(index)),
      )));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 20).top, moreOrLessEquals(0));
      controller.jumpTo(index: 150, alignment: 0.5);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 150).top, moreOrLessEquals(300));
      controller.scrollTo(
          index: 60, alignment: 0.25, duration: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 60).top, moreOrLessEquals(150));
      controller.jumpTo(index: 199);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 199).bottom, moreOrLessEquals(kViewport));
      expectPositionsMatchLayout(tester, listener);
    });
  });

  group('pass-through options', () {
    testWidgets('physics is honoured', (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 100,
        physics: const NeverScrollableScrollPhysics(),
        itemScrollController: controller,
        itemBuilder: (context, index) => item(index),
      )));
      await tester.drag(find.byType(ScrollToIndexList), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(rectOf(tester, 0).top, moreOrLessEquals(0));
      // Programmatic moves still work.
      controller.jumpTo(index: 10);
      await tester.pumpAndSettle();
      expect(rectOf(tester, 10).top, moreOrLessEquals(0));
    });

    testWidgets('semanticChildCount defaults to itemCount', (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 42,
        itemBuilder: (context, index) => item(index),
      )));
      final view =
          tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(view.semanticChildCount, 42);
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 42,
        semanticChildCount: 7,
        itemBuilder: (context, index) => item(index),
      )));
      expect(
          tester
              .widget<CustomScrollView>(find.byType(CustomScrollView))
              .semanticChildCount,
          7);
    });

    testWidgets('minCacheExtent is a lower bound for the cache extent',
        (tester) async {
      final built = <int>{};
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 1000,
        minCacheExtent: 2000,
        itemBuilder: (context, index) {
          built.add(index);
          return item(index);
        },
      )));
      // 600 visible + 2000 cache = 52 items.
      expect(built.length, greaterThanOrEqualTo(52));
    });

    testWidgets('addAutomaticKeepAlives keeps item state alive',
        (tester) async {
      await tester.pumpWidget(harness(ScrollToIndexList.builder(
        itemCount: 200,
        itemScrollController: controller,
        itemBuilder: (context, index) =>
            index == 0 ? const _KeepAliveCounter() : item(index),
      )));
      await tester.tap(find.byType(_KeepAliveCounter));
      await tester.pump();
      expect(find.text('taps 1'), findsOneWidget);
      await tester.drag(find.byType(ScrollToIndexList), const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ScrollToIndexList), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(find.text('taps 1'), findsOneWidget);
    });
  });
}

class _KeepAliveCounter extends StatefulWidget {
  const _KeepAliveCounter();

  @override
  State<_KeepAliveCounter> createState() => _KeepAliveCounterState();
}

class _KeepAliveCounterState extends State<_KeepAliveCounter>
    with AutomaticKeepAliveClientMixin {
  int taps = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: () => setState(() => taps++),
      child: SizedBox(
        height: kItem,
        child: Text('taps $taps', textDirection: TextDirection.ltr),
      ),
    );
  }
}
