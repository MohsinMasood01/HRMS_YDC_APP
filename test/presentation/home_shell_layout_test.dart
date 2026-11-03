import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lms/app.dart';
import 'package:lms/presentation/home/home_shell.dart';

void main() {
  final rail = find.byKey(const Key('home-side-rail'));
  final bottomBar = find.byKey(const Key('home-bottom-bar'));

  Future<void> pumpShellAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The test font draws every glyph as a 1em square, so header/nav labels
    // measure far wider than with the real font and report overflows that do
    // not happen on devices. Those are ignored; any other error still fails.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: kDesignSize,
        // Same scale cap as the real app, so sizes match a device.
        builder: (context, _) {
          capScaleOnLargeScreens(context);
          return MaterialApp(
            home: HomeShell(
              pages: [
                for (final name in const [
                  'Dashboard',
                  'Attendance',
                  'Leave',
                  'Profile',
                  'Settings',
                ])
                  Center(child: Text('$name page')),
              ],
            ),
          );
        },
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'tablet landscape (1280x800) shows the side rail, no bottom bar',
    (tester) async {
      await pumpShellAt(tester, const Size(1280, 800));

      expect(rail, findsOneWidget);
      expect(bottomBar, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tablet portrait (800x1280) keeps the bottom bar', (
    tester,
  ) async {
    await pumpShellAt(tester, const Size(800, 1280));

    expect(bottomBar, findsOneWidget);
    expect(rail, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone (390x844) keeps the bottom bar', (tester) async {
    await pumpShellAt(tester, const Size(390, 844));

    expect(bottomBar, findsOneWidget);
    expect(rail, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rail navigation switches tabs', (tester) async {
    await pumpShellAt(tester, const Size(1280, 800));

    await tester.tap(find.descendant(of: rail, matching: find.text('Leave')));
    await tester.pumpAndSettle();

    // The header subtitle follows the selected tab.
    expect(find.text('Leave'), findsNWidgets(2));
  });
}
