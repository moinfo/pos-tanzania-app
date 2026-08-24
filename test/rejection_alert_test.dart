import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pos_tanzania_mobile/models/pending_upload.dart';
import 'package:pos_tanzania_mobile/providers/connectivity_provider.dart';
import 'package:pos_tanzania_mobile/providers/offline_provider.dart';
import 'package:pos_tanzania_mobile/services/api_service.dart';
import 'package:pos_tanzania_mobile/services/database_service.dart';
import 'package:pos_tanzania_mobile/widgets/rejection_alert.dart';

/// The warning that a record will never upload.
///
/// A rejected record is where data dies quietly, so the test that matters is
/// not "does it show" but "can it be got rid of without anybody reading it".
/// A tap on the barrier, a back gesture, or a phone in a pocket must NOT be
/// enough -- only one of the two named buttons.
class _Offline extends OfflineProvider {
  _Offline({required super.connectivityProvider})
      : super(apiService: ApiService());

  int count = 0;
  List<PendingUpload> items = const [];

  @override
  int get unreadRejectionCount => count;

  @override
  Future<List<PendingUpload>> loadPendingUploads() async => items;

  void set(int newCount, List<PendingUpload> newItems) {
    count = newCount;
    items = newItems;
    notifyListeners();
  }
}

PendingUpload _rejected(int id, String detail) => PendingUpload(
      entityType: DatabaseService.pendingActionEntity,
      localId: id,
      kind: 'Expense',
      detail: detail,
      amount: 5000,
      createdAt: DateTime(2026, 8, 24, 9),
      state: UploadState.rejected,
      reason: 'Invalid category ID',
    );

void main() {
  late GlobalKey<NavigatorState> navKey;
  late _Offline offline;

  Widget host() {
    navKey = GlobalKey<NavigatorState>();
    final connectivity = ConnectivityProvider();
    offline = _Offline(connectivityProvider: connectivity);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivity),
        ChangeNotifierProvider<OfflineProvider>.value(value: offline),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        builder: (context, child) => RejectionAlertHost(
          navigatorKey: navKey,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: Center(child: Text('Some other screen'))),
      ),
    );
  }

  testWidgets('nothing is shown while there is nothing refused',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a refusal raises a warning over whatever screen is up',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    offline.set(2, [_rejected(1, 'Fuel'), _rejected(2, 'Rent')]);
    await tester.pumpAndSettle();

    expect(find.text('2 records were refused'), findsOneWidget);
    // Named, not counted: "2 records" sends somebody hunting.
    expect(find.textContaining('Fuel'), findsOneWidget);
    expect(find.textContaining('Rent'), findsOneWidget);
    // And it is over the screen that was already there.
    expect(find.text('Some other screen'), findsOneWidget);
  });

  testWidgets('it cannot be dismissed by tapping outside or going back',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    offline.set(1, [_rejected(1, 'Fuel')]);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    // The dark area around the dialog. This is the accidental dismissal.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // The back gesture / Android back button.
    await navKey.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'a back press must not clear an unread refusal');
  });

  testWidgets('"Later" quiets it, and a new refusal brings it back',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    offline.set(1, [_rejected(1, 'Fuel')]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // Still unread -- but not nagged about again for this run of the app.
    offline.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // A SECOND record is refused. That is new news, and it is told.
    offline.set(2, [_rejected(1, 'Fuel'), _rejected(2, 'Rent')]);
    await tester.pumpAndSettle();
    expect(find.text('2 records were refused'), findsOneWidget);
  });

  testWidgets('"Show me" opens the list', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    offline.set(1, [_rejected(1, 'Fuel')]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show me'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Not yet uploaded'), findsOneWidget);
  });
}
