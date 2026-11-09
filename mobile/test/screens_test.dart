import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psp_phone_pad_app/app.dart';
import 'package:psp_phone_pad_app/src/app_state.dart';
import 'package:psp_phone_pad_app/src/layout.dart';
import 'package:psp_phone_pad_app/src/screens/pad_screen.dart';
import 'package:psp_phone_pad_app/src/widgets/action_bar.dart';
import 'package:psp_phone_pad_app/src/widgets/face_pad.dart';

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

  testWidgets('status sits at the top and action bar at the bottom', (
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
    final double statusY = tester.getCenter(find.text('not connected')).dy;
    final double actionsY = tester.getCenter(find.byType(ActionBar)).dy;
    expect(statusY, lessThan(80));
    expect(actionsY, greaterThan(280));
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit panel is centered and face group exposes spacing', (
    WidgetTester tester,
  ) async {
    await setSurface(tester, const Size(844, 390));
    final AppState app = buildApp();
    addTearDown(app.dispose);
    app.setEditing(true);
    app.selectGroup(PadGroup.face);
    await tester.pumpWidget(
      MaterialApp(
        home: PadScreen(app: app, onOpenConnection: () {}),
      ),
    );
    await tester.pump();
    final Offset panel = tester.getCenter(
      find.byKey(const Key('edit-layout-panel')),
    );
    expect(panel.dx, closeTo(422, 24));
    expect(panel.dy, closeTo(195, 24));
    expect(find.text('SPACING'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinching face buttons adjusts their spacing smoothly', (
    WidgetTester tester,
  ) async {
    await setSurface(tester, const Size(844, 390));
    final AppState app = buildApp();
    addTearDown(app.dispose);
    app.setEditing(true);
    app.selectGroup(PadGroup.face);
    await tester.pumpWidget(
      MaterialApp(
        home: PadScreen(app: app, onOpenConnection: () {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('HIDE'));
    await tester.pump();
    final double before = app.layout.groups[PadGroup.face]!.spread;
    final double width = tester.getSize(find.byType(FacePad)).width;
    final Offset center = tester.getCenter(find.byType(FacePad));
    final TestGesture first = await tester.startGesture(
      center + const Offset(-18, 0),
      pointer: 1,
    );
    final TestGesture second = await tester.startGesture(
      center + const Offset(18, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveBy(const Offset(-34, 0));
    await second.moveBy(const Offset(34, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(
      app.layout.groups[PadGroup.face]!.spread,
      closeTo(before + 68 / (width * 2) * 100, 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinching face buttons inward clusters them', (
    WidgetTester tester,
  ) async {
    await setSurface(tester, const Size(844, 390));
    final AppState app = buildApp();
    addTearDown(app.dispose);
    app.setEditing(true);
    app.selectGroup(PadGroup.face);
    await tester.pumpWidget(
      MaterialApp(
        home: PadScreen(app: app, onOpenConnection: () {}),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('HIDE'));
    await tester.pump();
    final double before = app.layout.groups[PadGroup.face]!.spread;
    final double width = tester.getSize(find.byType(FacePad)).width;
    final Offset center = tester.getCenter(find.byType(FacePad));
    final TestGesture first = await tester.startGesture(
      center + const Offset(-40, 0),
      pointer: 1,
    );
    final TestGesture second = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveBy(const Offset(30, 0));
    await second.moveBy(const Offset(-30, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    expect(
      app.layout.groups[PadGroup.face]!.spread,
      closeTo(before - 60 / (width * 2) * 100, 0.5),
    );
    expect(app.layout.groups[PadGroup.face]!.spread, lessThan(before));
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

  testWidgets('settings dialog fits a small landscape screen', (
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
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('BACKGROUND'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
