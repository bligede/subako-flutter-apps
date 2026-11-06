import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subako/features/authentication/login_screen.dart';
import 'package:subako/services/demo_repository.dart';

void main() {
  testWidgets('validasi email dan sandi tampil saat form kosong', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await tester.tap(find.text('Masuk'));
    await tester.pump();

    expect(find.text('Masukkan email yang valid.'), findsOneWidget);
    expect(find.text('Kata sandi minimal 6 karakter.'), findsOneWidget);
  });

  testWidgets('chip akun demo mengisi email dan sandi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Akun demo (build simulasi)'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Pekaseh'));
    await tester.pump();

    expect(find.text('pekaseh@subako.demo'), findsOneWidget);
    expect(find.text(kDemoPassword), findsOneWidget);
  });
}
