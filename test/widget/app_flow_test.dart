import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subako/app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  for (final width in [360.0, 390.0, 768.0]) {
    testWidgets('demo login and primary navigation at ${width.toInt()} px', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const ProviderScope(child: SubakoApp()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();
      final account = find.widgetWithText(ActionChip, 'Pekaseh');
      await tester.ensureVisible(account);
      await tester.tap(account);
      await tester.pump();
      final login = find.widgetWithText(FilledButton, 'Masuk');
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.textContaining('MODE SIMULASI'), findsWidgets);
      expect(tester.takeException(), isNull);
      for (final destination in [
        'Monitoring',
        'Operasional',
        'Catatan Air',
        'Profil',
        'Beranda',
      ]) {
        await tester.tap(
          find.widgetWithText(NavigationDestination, destination),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$destination at $width',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
