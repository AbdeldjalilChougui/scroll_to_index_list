# scroll_to_index_list

A Flutter list that can jump or animate to any item index and report which
items are visible. It is a maintained replacement for
`scrollable_positioned_list` with the same API, so migrating is a rename.

[![pub package](https://img.shields.io/pub/v/scroll_to_index_list.svg)](https://pub.dev/packages/scroll_to_index_list)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- **`ScrollToIndexList.builder`** and **`.separated`** take the same
  parameters as `ScrollablePositionedList`.
- **`ItemScrollController`** provides `jumpTo(index, alignment)`,
  `scrollTo(index, alignment, duration, curve)` and `isAttached`.
- **`ItemPositionsListener`** exposes `itemPositions`, a
  `ValueListenable<Iterable<ItemPosition>>` of the visible items. Each
  position has `index`, `itemLeadingEdge` and `itemTrailingEdge`.
- **`ScrollOffsetController.animateScroll`** scrolls by a number of pixels,
  and **`ScrollOffsetListener.changes`** streams the scroll deltas.
- **One viewport and no crossfade.** The list is a single `CustomScrollView`
  whose scroll offset 0 sits on an *anchor* item, set through
  `CustomScrollView.center`. A jump moves the anchor, so jumping to item
  750,000 builds only the items on screen. It never needs the extents of the
  items before the target.
- **Smooth far scrolling.** A near target is animated through the real
  content. The target position is re-estimated on every frame and the rest
  of the path is rescaled, so the motion stays continuous and ends exactly on
  time. For a far target, the list follows a path estimated from the average
  item extent. It re-anchors along that path, then lands exactly on the
  target.
- **Clamped at both ends.** Scrolling to the last items, at any alignment,
  never overshoots, bounces or leaves blank space after the end of the list.
  Scrolling to the first items never leaves blank space before item 0.
- **Supports** `reverse` (for chats), RTL, the horizontal axis, `physics`,
  `padding`, `shrinkWrap`, `semanticChildCount`, `addAutomaticKeepAlives`,
  `addRepaintBoundaries`, `addSemanticIndexes`, `minCacheExtent`,
  `initialScrollIndex` and `initialAlignment`.

### Fixed long-standing issues of the old package

Each fix below is covered by a widget test in `test/`.

- Scrolling or jumping to the last items clamps to the maximum extent with any
  alignment. It does not overshoot or leave blank space.
- Controllers survive widget rebuilds, a controller swap, a key change and
  hot reload. A controller that is attached to a new list before the old list
  is disposed no longer triggers the `_scrollableListState == null` assertion.
  It drives the newest list.
- Item positions stay correct when `itemCount` grows, shrinks, or drops below
  the current index.
- Calling `scrollTo` during a running `scrollTo` continues from the current
  position and completes the first future. A `jumpTo` or a user drag also
  stops the running animation.
- Each list owns a private scroll controller and never claims the
  `PrimaryScrollController`. The "ScrollController attached to multiple scroll
  views" error cannot happen, even when two lists share the same controllers.
- Out-of-range and negative indices are clamped, and the item builder is never
  called with an invalid index.

## Install

```yaml
dependencies:
  scroll_to_index_list: ^0.1.0
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:scroll_to_index_list/scroll_to_index_list.dart';

class Messages extends StatefulWidget {
  const Messages({super.key, required this.messages});

  final List<String> messages;

  @override
  State<Messages> createState() => _MessagesState();
}

class _MessagesState extends State<Messages> {
  final itemScrollController = ItemScrollController();
  final itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    itemPositionsListener.itemPositions.addListener(() {
      final visible = itemPositionsListener.itemPositions.value
          .map((p) => p.index)
          .toList();
      debugPrint('visible: $visible');
    });
  }

  void showMessage(int index) {
    itemScrollController.scrollTo(
      index: index,
      alignment: 0.5, // centre the leading edge of the item
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollToIndexList.builder(
      reverse: true, // newest message (index 0) at the bottom
      itemCount: widget.messages.length,
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      itemBuilder: (context, index) => ListTile(
        title: Text(widget.messages[index]),
        onTap: () => showMessage(index + 20),
      ),
    );
  }
}
```

Use `itemScrollController.jumpTo(index: 150)` to move without animation.

`alignment` is a fraction of the viewport that gives the position of the
item's **leading edge**: 0 is the leading edge of the viewport, 0.5 the middle
and 1 the trailing edge. In a reversed list the leading edge is the bottom. In
a right-to-left horizontal list it is the right side. Near either end of the
list the result is clamped to the content.

The `example/` app is a chat demo and a 100,000-item demo. Both have jump and
scroll controls and a live list of the visible items.

## Migrating from scrollable_positioned_list

1. In `pubspec.yaml`, replace `scrollable_positioned_list` with
   `scroll_to_index_list`.
2. Change the import:

   ```dart
   // Before
   import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
   // After
   import 'package:scroll_to_index_list/scroll_to_index_list.dart';
   ```

3. Rename `ScrollablePositionedList` to `ScrollToIndexList`. The named
   constructors `.builder` and `.separated` and all their parameters are
   unchanged.

| scrollable_positioned_list | scroll_to_index_list |
| --- | --- |
| `ScrollablePositionedList.builder(...)` | `ScrollToIndexList.builder(...)` |
| `ScrollablePositionedList.separated(...)` | `ScrollToIndexList.separated(...)` |
| `ItemScrollController()` | unchanged |
| `ItemPositionsListener.create()` | unchanged |
| `ScrollOffsetController()` | unchanged |
| `ScrollOffsetListener.create(...)` | unchanged |
| `ItemPosition(index, itemLeadingEdge, itemTrailingEdge)` | unchanged |

Behaviour differences:

- `scrollTo(opacityAnimationWeights: ...)` is still accepted but deprecated
  and ignored, because nothing crossfades.
- Scrolling or jumping to one of the last items clamps so that the last item
  ends on the trailing edge. The old package could leave blank space there.
- Calling `jumpTo` or `scrollTo` on a detached controller throws a
  `StateError` with a clear message instead of a null-check error. Check
  `isAttached` first.
- `padding` accepts any `EdgeInsetsGeometry`, so `EdgeInsetsDirectional`
  works too.

## Limitations

- **`shrinkWrap: true`**: a shrink-wrapping viewport cannot anchor on an item.
  A shrink-wrapped list therefore lays out the items before the target when it
  jumps. It reaches the target after a few frames of estimate-and-correct, and
  `initialScrollIndex` is applied after the first frame. Use it only for short
  lists.
- A far `scrollTo` follows a path estimated from the average item extent. With
  very uneven item extents, items can shift slightly while the list moves fast
  through them. The animation always lands exactly on the target.
- Re-anchoring moves items between the two internal slivers. An item that
  crosses the anchor during a jump or a far scroll is rebuilt, and its state
  is lost unless it uses keep-alive.
- `itemPositions` is updated after every frame in which the list scrolled,
  was rebuilt or changed its content extent. If an item changes size without
  any of these, the positions update on the next scroll.
- Like the old package, only the item index identifies an item. If you insert
  items before the visible ones, as in a chat that loads history, the content
  shifts unless you also call `jumpTo` to compensate.
- It is a standalone scroll view. It cannot be placed as a sliver inside
  another `CustomScrollView` or `NestedScrollView`.

## License

MIT. See [LICENSE](LICENSE).

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
