import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hnuhole_mobile/src/design_system/feedback.dart';

Widget _host({bool navigate = false}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Column(
        children: [
          FilledButton(
            onPressed: () => showHhFeedback(context, '统一提示'),
            child: const Text('show'),
          ),
          if (navigate)
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('next')),
                ),
              ),
              child: const Text('next'),
            ),
        ],
      ),
    ),
  ),
);

Future<void> _show(WidgetTester tester) async {
  await tester.tap(find.text('show'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('统一反馈两秒自动关闭且带明显叉号', (tester) async {
    await tester.pumpWidget(_host());
    await _show(tester);
    expect(find.byKey(const ValueKey('hh-feedback')), findsOneWidget);
    expect(find.byKey(const ValueKey('hh-feedback-close')), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hh-feedback')), findsNothing);
  });

  testWidgets('叉号快速关闭且连续触发只保留最新一条', (tester) async {
    await tester.pumpWidget(_host());
    await _show(tester);
    await tester.tap(find.byKey(const ValueKey('hh-feedback-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hh-feedback')), findsNothing);

    await _show(tester);
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hh-feedback')), findsOneWidget);
    expect(find.text('统一提示'), findsOneWidget);
  });

  for (final dx in [-200.0, 200.0]) {
    testWidgets('左右滑动移除统一反馈 $dx', (tester) async {
      await tester.pumpWidget(_host());
      await _show(tester);
      await tester.drag(
        find.byKey(const ValueKey('hh-feedback-swipe')),
        Offset(dx, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hh-feedback')), findsNothing);
    });
  }

  testWidgets('提示显示期间切换页面仍可关闭', (tester) async {
    await tester.pumpWidget(_host(navigate: true));
    await _show(tester);
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hh-feedback')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hh-feedback-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hh-feedback')), findsNothing);
  });
}
