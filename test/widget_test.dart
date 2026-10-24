import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_journal/core/config/app_constants.dart';
import 'package:my_journal/main.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('Welcome fits a small mobile viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: MyJournalApp()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Mulai Ceritakan Harimu.'), findsOneWidget);
  });

  testWidgets('demo user can sign in and navigate the five main tabs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: MyJournalApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang Kembali'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'dania@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Dania123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Dania'), findsOneWidget);
    await tester.tap(find.text('Senang').first);
    await tester.pumpAndSettle();
    expect(find.text('Bagaimana perasaanmu saat ini?'), findsOneWidget);
    expect(find.text('Judul Jurnal'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    for (final tab in const [
      'Beranda',
      'Planner',
      'Journal',
      'Tracker',
      'Insight',
    ]) {
      final item = find.text(tab).last;
      expect(item, findsOneWidget);
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Tracker').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kebiasaan Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Nama Kebiasaan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Tujuan & Rencana'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tujuan Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Nama / Target Tujuan'), findsOneWidget);
    expect(find.text('Tahapan / Milestones'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !AppConstants.isDemoMode);
}
