# scroll_to_index_list example

Two demos:

- **Chat (reverse)**: 5,000 placeholder messages of varying length, newest at
  the bottom (`reverse: true`). Type an index, pick an alignment, then
  **Jump** or **Scroll**. **Oldest** / **Newest** animate to either end and
  **Send** inserts a message and scrolls to it.
- **Long list**: 100,000 separated rows of varying extent, with a switch for
  the horizontal axis.

The bar at the top lists the visible items and their leading and trailing
edges, from `ItemPositionsListener`.

Run it with `flutter run` from this directory.
