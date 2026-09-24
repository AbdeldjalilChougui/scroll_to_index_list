import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index_list/scroll_to_index_list.dart';
import 'package:scroll_to_index_list_example/main.dart';

void main() {
  testWidgets('chat demo jumps and scrolls to the typed index', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DemoApp());
    // Positions are published after the first layout.
    await tester.pump();
    expect(find.byType(ScrollToIndexList), findsOneWidget);
    expect(find.textContaining('Visible 0-'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1200');
    await tester.tap(find.text('Jump'));
    await tester.pumpAndSettle();
    expect(find.textContaining('[1200]'), findsOneWidget);

    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Visible 0-'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.textContaining('New message 1'), findsOneWidget);
  });

  testWidgets('long-list demo scrolls far and switches axis', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DemoApp());
    await tester.tap(find.text('Long list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '75000');
    await tester.tap(find.text('Scroll'));
    await tester.pumpAndSettle();
    expect(find.text('Item 75000'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsOneWidget);
  });
}
