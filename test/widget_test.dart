import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cybersentinel_frontend/main.dart';

void main() {
  void configureTestViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> navigateToSection(WidgetTester tester, String route, String label) async {
    if (find.byTooltip('Open navigation menu').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return;
    }

    await tester.tap(find.byKey(Key('sidebar-$route')));
    await tester.pumpAndSettle();
  }

  testWidgets('Dashboard screen renders', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());

    expect(find.text('CyberSentinel Dashboard'), findsOneWidget);
    expect(find.text('Threats Detected'), findsOneWidget);
    expect(find.text('Recent Security Alerts'), findsOneWidget);
  });

  testWidgets('Drawer navigates to Alerts screen', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());
    await navigateToSection(tester, '/alerts', 'Alerts');

    expect(find.text('Alerts Screen'), findsOneWidget);
  });

  testWidgets('Drawer navigates to Monitoring screen', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());
    await navigateToSection(tester, '/monitoring', 'Monitoring');

    expect(find.text('Monitoring Screen'), findsOneWidget);
  });

  testWidgets('Drawer navigates to Reports screen', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());
    await navigateToSection(tester, '/reports', 'Reports');

    expect(find.text('Reports Screen'), findsOneWidget);
  });

  testWidgets('Drawer navigates to Incidents screen', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());
    await navigateToSection(tester, '/incidents', 'Incidents');

    expect(find.text('Incidents Screen'), findsOneWidget);
  });

  testWidgets('Drawer navigates to Settings screen', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());
    await navigateToSection(tester, '/settings', 'Settings');

    expect(find.text('Settings Screen'), findsOneWidget);
  });

  testWidgets('Settings screen toggles dark mode switch', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());
    await navigateToSection(tester, '/settings', 'Settings');

    expect(find.byType(SwitchListTile), findsOneWidget);
    final initialSwitch = tester.widget<SwitchListTile>(find.byType(SwitchListTile));

    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();

    final updatedSwitch = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(updatedSwitch.value, isNot(initialSwitch.value));
  });

  testWidgets('Alerts screen opens alert details', (WidgetTester tester) async {
    configureTestViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CyberSentinelApp());
    await navigateToSection(tester, '/alerts', 'Alerts');

    await tester.tap(find.text('DDoS • 192.168.1.10'));
    await tester.pumpAndSettle();

    expect(find.text('Alert Details'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
  });
}
