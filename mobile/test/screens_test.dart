import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psp_phone_pad_app/app.dart';
import 'package:psp_phone_pad_app/src/app_state.dart';
import 'package:psp_phone_pad_app/src/layout.dart';
import 'package:psp_phone_pad_app/src/screens/pad_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setSurface(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  AppState buildApp({String host = '127.0.0.1'}) {
    return AppState(
      settings: AppSettings(host: host, port: 18081),
      layout: PadLayout.defaults(),
    );
  }

  testWidgets('pad renders at phone landscape size', (
    WidgetTester tester,
  ) async {
    await setSurface(tester, const Size(844, 390));
    final AppState app = buildApp();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PadScreen(app: app, onOpenConnection: () {}),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(PadScreen), findsOneWidget);
  });

  testWidgets('pad renders in edit mode', (WidgetTester tester) async {
    await setSurface(tester, const Size(844, 390));
    final AppState app = buildApp();
    addTearDown(app.dispose);
    app.setEditing(true);
    await tester.pumpWidget(
      MaterialApp(
        home: PadScreen(app: app, onOpenConnection: () {}),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings dialog opens', (WidgetTester tester) async {
    await setSurface(tester, const Size(844, 390));
    final AppState app = buildApp();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PadScreen(app: app, onOpenConnection: () {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Controls'), findsOneWidget);
  });

  testWidgets('connect screen renders at phone landscape size', (
    WidgetTester tester,
  ) async {
    await setSurface(tester, const Size(844, 390));
    final AppState app = buildApp(host: '');
    addTearDown(app.dispose);
    await tester.pumpWidget(PadApp(app: app));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('CONNECT'), findsWidgets);
  });

  testWidgets('pad renders at small landscape size', (
    WidgetTester tester,
  ) async {
    await setSurface(tester, const Size(667, 375));
    final AppState app = buildApp();
    addTearDown(app.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PadScreen(app: app, onOpenConnection: () {}),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
