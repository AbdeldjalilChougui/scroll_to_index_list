import 'package:flutter/material.dart';
import 'package:scroll_to_index_list/scroll_to_index_list.dart';

void main() => runApp(const DemoApp());

/// Demo app with two pages: a reversed chat and a long list.
class DemoApp extends StatelessWidget {
  /// Creates the app.
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'scroll_to_index_list demo',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: TabBar(
            tabs: [Tab(text: 'Chat (reverse)'), Tab(text: 'Long list')],
          ),
          body: SafeArea(
            child: TabBarView(
              physics: NeverScrollableScrollPhysics(),
              children: [ChatDemo(), LongListDemo()],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat demo: newest message at the bottom (index 0), reverse: true.

/// A chat-style list: 5,000 generated placeholder messages of varying length,
/// newest at the bottom, with jump/scroll controls and a live list of the
/// visible items.
class ChatDemo extends StatefulWidget {
  /// Creates the chat demo.
  const ChatDemo({super.key});

  @override
  State<ChatDemo> createState() => _ChatDemoState();
}

class _ChatDemoState extends State<ChatDemo> {
  final itemScrollController = ItemScrollController();
  final itemPositionsListener = ItemPositionsListener.create();
  // Newest first: messages[0] is shown at the bottom.
  final List<String> messages =
      List<String>.generate(5000, (i) => _placeholderText(5000 - i));
  int _sent = 0;

  static String _placeholderText(int n) {
    const words = ['lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur'];
    final length = 2 + (n * 7) % 24;
    final body = List<String>.generate(length, (i) => words[(n + i) % 6]);
    return 'Message #$n: ${body.join(' ')}';
  }

  void _send() {
    setState(() {
      _sent++;
      messages.insert(0, 'New message $_sent');
    });
    itemScrollController.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VisibleItemsBar(listener: itemPositionsListener),
        Expanded(
          child: ScrollToIndexList.builder(
            reverse: true,
            itemCount: messages.length,
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) => _Bubble(
              text: messages[index],
              index: index,
              mine: index.isEven,
            ),
          ),
        ),
        JumpControls(controller: itemScrollController, max: messages.length),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => itemScrollController.scrollTo(
                  index: messages.length - 1,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOutCubic,
                ),
                child: const Text('Oldest'),
              ),
              OutlinedButton(
                onPressed: () => itemScrollController.scrollTo(
                  index: 0,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOutCubic,
                ),
                child: const Text('Newest'),
              ),
              FilledButton.icon(
                onPressed: _send,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.index, required this.mine});

  final String text;
  final int index;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text('[$index] $text'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Long list demo: 100,000 rows of varying extent, optional horizontal axis.

/// A 100,000-item list with variable row extents, separators and an axis
/// switch.
class LongListDemo extends StatefulWidget {
  /// Creates the long-list demo.
  const LongListDemo({super.key});

  @override
  State<LongListDemo> createState() => _LongListDemoState();
}

class _LongListDemoState extends State<LongListDemo> {
  final itemScrollController = ItemScrollController();
  final itemPositionsListener = ItemPositionsListener.create();
  static const int count = 100000;
  bool horizontal = false;

  @override
  Widget build(BuildContext context) {
    final axis = horizontal ? Axis.horizontal : Axis.vertical;
    return Column(
      children: [
        VisibleItemsBar(listener: itemPositionsListener),
        SwitchListTile(
          dense: true,
          title: const Text('Horizontal'),
          value: horizontal,
          onChanged: (value) => setState(() => horizontal = value),
        ),
        Expanded(
          child: ScrollToIndexList.separated(
            key: ValueKey<Axis>(axis),
            itemCount: count,
            scrollDirection: axis,
            itemScrollController: itemScrollController,
            itemPositionsListener: itemPositionsListener,
            separatorBuilder: (context, index) => horizontal
                ? const VerticalDivider(width: 1)
                : const Divider(height: 1),
            itemBuilder: (context, index) {
              final extent = 40.0 + (index * 37) % 90;
              final color = Colors.primaries[index % Colors.primaries.length];
              return Container(
                height: horizontal ? null : extent,
                width: horizontal ? extent + 40 : null,
                color: color.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Text('Item $index'),
              );
            },
          ),
        ),
        JumpControls(controller: itemScrollController, max: count),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets.

/// Shows the visible item indices and their edges, live.
class VisibleItemsBar extends StatelessWidget {
  /// Creates the bar for [listener].
  const VisibleItemsBar({super.key, required this.listener});

  /// Source of positions.
  final ItemPositionsListener listener;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        height: 48,
        child: ValueListenableBuilder<Iterable<ItemPosition>>(
          valueListenable: listener.itemPositions,
          builder: (context, positions, _) {
            final sorted = positions.toList()
              ..sort((a, b) => a.index.compareTo(b.index));
            if (sorted.isEmpty) return const Center(child: Text('No items'));
            return ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                Center(
                  child: Text(
                    'Visible ${sorted.first.index}-${sorted.last.index}  ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final p in sorted)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${p.index}: '
                        '${p.itemLeadingEdge.toStringAsFixed(2)}..'
                        '${p.itemTrailingEdge.toStringAsFixed(2)}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Index field, alignment slider, and Jump / Scroll buttons.
class JumpControls extends StatefulWidget {
  /// Creates controls driving [controller] for a list of [max] items.
  const JumpControls({super.key, required this.controller, required this.max});

  /// Controller to drive.
  final ItemScrollController controller;

  /// Item count, for validation.
  final int max;

  @override
  State<JumpControls> createState() => _JumpControlsState();
}

class _JumpControlsState extends State<JumpControls> {
  final _index = TextEditingController(text: '250');
  double _alignment = 0;

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  int get _target => (int.tryParse(_index.text) ?? 0).clamp(0, widget.max - 1);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _index,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Index',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => widget.controller
                    .jumpTo(index: _target, alignment: _alignment),
                child: const Text('Jump'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => widget.controller.scrollTo(
                  index: _target,
                  alignment: _alignment,
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeInOutCubic,
                ),
                child: const Text('Scroll'),
              ),
            ],
          ),
          Row(
            children: [
              Text('Alignment ${_alignment.toStringAsFixed(2)}'),
              Expanded(
                child: Slider(
                  value: _alignment,
                  onChanged: (v) => setState(() => _alignment = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
