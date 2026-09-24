import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_list/scroll_to_index_list.dart';

/// Viewport main-axis extent used by every test.
const double kViewport = 600;

/// Cross-axis extent used by every test.
const double kCross = 400;

/// Fixed item extent used by the uniform-list tests.
const double kItem = 50;

/// Wraps [child] in the minimal environment a scroll view needs, sized to
/// [kViewport] along [axis].
Widget harness(
  Widget child, {
  Axis axis = Axis.vertical,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: textDirection,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: axis == Axis.vertical ? kCross : kViewport,
          height: axis == Axis.vertical ? kViewport : kCross,
          child: child,
        ),
      ),
    ),
  );
}

/// A plain item of [extent] along [axis], labelled `item $index`.
Widget item(int index, {double extent = kItem, Axis axis = Axis.vertical}) {
  return SizedBox(
    key: ValueKey<String>('item-$index'),
    height: axis == Axis.vertical ? extent : null,
    width: axis == Axis.horizontal ? extent : null,
    child: Text('item $index', textDirection: TextDirection.ltr),
  );
}

/// Finder for the item with [index].
Finder findItem(int index) => find.byKey(ValueKey<String>('item-$index'));

/// Rect of item [index] in global coordinates (the list sits at 0,0).
Rect rectOf(WidgetTester tester, int index) => tester.getRect(findItem(index));

/// Visible positions sorted by index.
List<ItemPosition> sortedPositions(ItemPositionsListener listener) {
  final list = listener.itemPositions.value.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return list;
}

/// Position of [index] or null when it is not reported.
ItemPosition? positionOf(ItemPositionsListener listener, int index) {
  for (final p in listener.itemPositions.value) {
    if (p.index == index) return p;
  }
  return null;
}

/// Deterministic variable extent for item [i]: between 20 and 139 px.
double variableExtent(int i) => 20.0 + (i * 37) % 120;

/// Checks every reported position against the real rendered rect of the item,
/// along a vertical, non-reversed axis.
void expectPositionsMatchLayout(
  WidgetTester tester,
  ItemPositionsListener listener,
) {
  final positions = listener.itemPositions.value.toList();
  expect(positions, isNotEmpty);
  for (final p in positions) {
    final rect = rectOf(tester, p.index);
    expect(p.itemLeadingEdge, moreOrLessEquals(rect.top / kViewport),
        reason: 'leading edge of ${p.index}');
    expect(p.itemTrailingEdge, moreOrLessEquals(rect.bottom / kViewport),
        reason: 'trailing edge of ${p.index}');
    expect(p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1, isTrue,
        reason: '${p.index} is reported but not visible');
  }
}
