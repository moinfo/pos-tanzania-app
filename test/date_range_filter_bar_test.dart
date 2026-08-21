import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pos_tanzania_mobile/widgets/date_range_filter_bar.dart';

/// The screens this bar sits on were laid out carefully, and the brief was
/// explicit that adding it must not reintroduce a RenderFlex overflow. A
/// widget test fails automatically on an overflow, so pumping the bar across
/// its states at a deliberately cramped width is the proof.
void main() {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Widget host({
    required bool dark,
    required double width,
    required Widget child,
  }) {
    return MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  // A narrow phone (320pt) is the tightest real target; test below it too.
  for (final width in <double>[280, 320, 360]) {
    for (final dark in <bool>[true, false]) {
      testWidgets(
        'bar does not overflow — holder, filtered range, ${width}px, '
        '${dark ? 'dark' : 'light'}',
        (tester) async {
          await tester.pumpWidget(host(
            dark: dark,
            width: width,
            child: DateRangeFilterBar(
              dateFrom: '2026-01-05',
              dateTo: '2026-08-21',
              canFilterDate: true,
              onChange: () {},
              onResetToToday: () {},
              note: 'Showing today only for discount requests — that needs a '
                  'separate permission.',
            ),
          ));
          expect(tester.takeException(), isNull);
          expect(find.byType(DateRangeFilterBar), findsOneWidget);
        },
      );

      testWidgets(
        'bar does not overflow — locked to today, ${width}px, '
        '${dark ? 'dark' : 'light'}',
        (tester) async {
          await tester.pumpWidget(host(
            dark: dark,
            width: width,
            child: DateRangeFilterBar(
              dateFrom: today,
              dateTo: today,
              canFilterDate: false,
              onChange: () {},
              onResetToToday: () {},
            ),
          ));
          expect(tester.takeException(), isNull);
          // A user without the grant is told the view is limited, not shown a
          // dead control.
          expect(find.text('You may only view today'), findsOneWidget);
          expect(find.text('Change'), findsNothing);
        },
      );
    }
  }

  testWidgets('holder sees a working Change control, and Today once filtered',
      (tester) async {
    var changed = 0;
    var reset = 0;
    await tester.pumpWidget(host(
      dark: false,
      width: 360,
      child: DateRangeFilterBar(
        dateFrom: '2026-08-01',
        dateTo: '2026-08-10',
        canFilterDate: true,
        onChange: () => changed++,
        onResetToToday: () => reset++,
      ),
    ));

    await tester.tap(find.text('Change'));
    await tester.tap(find.text('Today'));
    expect(changed, equals(1));
    expect(reset, equals(1));
  });

  group('describe()', () {
    test('a single day that is today reads as Today', () {
      expect(DateRangeFilterBar.describe(today, today), equals('Today'));
    });

    test('a real range reads as a range, not machine dates', () {
      expect(
        DateRangeFilterBar.describe('2026-08-01', '2026-08-21'),
        equals('1 Aug – 21 Aug 2026'),
      );
    });

    test('a cross-year range prints both years', () {
      expect(
        DateRangeFilterBar.describe('2025-12-29', '2026-08-21'),
        equals('29 Dec 2025 – 21 Aug 2026'),
      );
    });
  });
}
