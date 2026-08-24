import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pos_tanzania_mobile/models/pending_upload.dart';
import 'package:pos_tanzania_mobile/providers/connectivity_provider.dart';
import 'package:pos_tanzania_mobile/providers/offline_provider.dart';
import 'package:pos_tanzania_mobile/screens/pending_uploads_screen.dart';
import 'package:pos_tanzania_mobile/services/api_service.dart';
import 'package:pos_tanzania_mobile/services/database_service.dart';
import 'package:pos_tanzania_mobile/services/sync_service.dart';
import 'package:pos_tanzania_mobile/utils/app_theme.dart';

/// The screen a person opens to find out what has not gone up.
///
/// Two things are being defended. First, that the three states are legible AS
/// three states -- a refusal shown with the same words and the same colour as
/// a record that is merely waiting is a refusal that will be walked past.
/// Second, that the rows survive a narrow phone: this app has shipped
/// RenderFlex overflows before, and a row that overflows is a row whose reason
/// text is cut off, which on a rejected record is the only thing that says
/// what to fix.
class _FakeConnectivity extends ConnectivityProvider {
  _FakeConnectivity({required this.online});

  final bool online;

  @override
  bool get isOnline => online;

  // The base class derives this from a private field, so overriding isOnline
  // alone leaves the two disagreeing.
  @override
  bool get isOffline => !online;
}

class _FakeOffline extends OfflineProvider {
  _FakeOffline({
    required super.connectivityProvider,
    required this.items,
    this.reachable = true,
    this.report = const SyncRunReport(),
  }) : super(apiService: ApiService());

  final List<PendingUpload> items;
  final bool reachable;
  final SyncRunReport report;

  int syncCalls = 0;

  @override
  bool get serverReachable => reachable;

  @override
  bool get isSyncing => false;

  @override
  Future<List<PendingUpload>> loadPendingUploads() async => items;

  @override
  Future<SyncRunReport> triggerSync() async {
    syncCalls++;
    return report;
  }
}

PendingUpload _waiting() => PendingUpload(
      entityType: DatabaseService.pendingActionEntity,
      localId: 1,
      kind: 'Expense',
      detail: 'Fuel for the delivery run',
      amount: 25000,
      createdAt: DateTime(2026, 8, 24, 9, 15),
      state: UploadState.waiting,
    );

PendingUpload _trying() => PendingUpload(
      entityType: DatabaseService.saleEntity,
      localId: 2,
      kind: 'Sale',
      amount: 148500,
      createdAt: DateTime(2026, 8, 24, 10, 2),
      state: UploadState.trying,
      attempts: 3,
      reason: 'Server error (500)',
    );

PendingUpload _rejected() => PendingUpload(
      entityType: DatabaseService.pendingActionEntity,
      localId: 3,
      kind: 'Expense',
      detail: 'Generator repair, paid in cash to the workshop on the corner',
      amount: 460000,
      createdAt: DateTime(2026, 8, 24, 11, 40),
      state: UploadState.rejected,
      reason: 'Invalid category ID',
      requestId: 'a3f1-9c22',
    );

Widget _host({
  required List<PendingUpload> items,
  bool online = true,
  bool reachable = true,
  Brightness brightness = Brightness.light,
  _FakeOffline? offline,
}) {
  final connectivity = _FakeConnectivity(online: online);
  final provider = offline ??
      _FakeOffline(
        connectivityProvider: connectivity,
        items: items,
        reachable: reachable,
      );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivity),
      ChangeNotifierProvider<OfflineProvider>.value(value: provider),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      home: const PendingUploadsScreen(),
    ),
  );
}

final Finder _syncButton =
    find.byWidgetPredicate((w) => w is ElevatedButton);

void main() {
  // A narrow phone. Width is what produces a RenderFlex overflow, and 360dp
  // is the narrowest screen this app ships on; the height is generous so
  // every row is laid out rather than left below the fold unbuilt.
  Future<void> narrow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('the three states are named separately on the same screen',
      (tester) async {
    await narrow(tester);
    await tester.pumpWidget(_host(
      items: [_waiting(), _trying(), _rejected()],
    ));
    await tester.pumpAndSettle();

    // Each state is a word on screen, not a shade of one word.
    expect(find.text('Waiting'), findsWidgets);
    expect(find.text('Trying'), findsWidgets);
    expect(find.text('Rejected'), findsWidgets);

    // The refused one is hoisted under its own heading and says outright that
    // waiting will not fix it.
    expect(
      find.text('1 record will never upload on their own'),
      findsNothing,
    );
    expect(find.text('1 record will never upload on its own'), findsOneWidget);

    // The server's own words, on the row, not hidden behind a tap.
    expect(find.text('Invalid category ID'), findsOneWidget);

    // A record that is merely being retried says how many times, and does NOT
    // borrow the language of a refusal.
    expect(find.textContaining('Server error (500)'), findsOneWidget);
    expect(find.textContaining('3 attempts'), findsOneWidget);
  });

  testWidgets('a rejected record renders the same way in dark mode',
      (tester) async {
    await narrow(tester);
    await tester.pumpWidget(_host(
      items: [_rejected()],
      brightness: Brightness.dark,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Rejected'), findsWidgets);
    expect(find.text('Invalid category ID'), findsOneWidget);
  });

  testWidgets('long descriptions and big amounts do not overflow a narrow row',
      (tester) async {
    await narrow(tester);
    await tester.pumpWidget(_host(items: [
      _rejected(),
      PendingUpload(
        entityType: DatabaseService.pendingActionEntity,
        localId: 9,
        kind: 'One-time discount request',
        detail:
            'Wholesale customer asking for the full carton price on a mixed '
            'pallet, approved verbally by the branch manager last Thursday',
        amount: 999999999,
        createdAt: DateTime(2026, 8, 24, 12),
        state: UploadState.trying,
        attempts: 4,
        reason:
            'The server is busy and could not take this right now, try later',
      ),
    ]));
    await tester.pumpAndSettle();

    // pumpAndSettle would already have thrown on a RenderFlex overflow; this
    // says so explicitly rather than relying on a silent absence.
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sync now is disabled and explained when there is no connection',
      (tester) async {
    await narrow(tester);
    final connectivity = _FakeConnectivity(online: false);
    final offline = _FakeOffline(
      connectivityProvider: connectivity,
      items: [_waiting()],
    );

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivity),
        ChangeNotifierProvider<OfflineProvider>.value(value: offline),
      ],
      child: const MaterialApp(home: PendingUploadsScreen()),
    ));
    await tester.pumpAndSettle();

    // ElevatedButton.icon returns a SUBCLASS of ElevatedButton, which
    // find.byType would miss entirely.
    final button = tester.widget<ElevatedButton>(_syncButton);
    expect(button.onPressed, isNull);

    // A dead button with no explanation is what makes people tap it ten times.
    expect(
      find.textContaining('There is no connection, so there is nothing to '
          'press'),
      findsOneWidget,
    );

    await tester.tap(_syncButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(offline.syncCalls, 0);
  });

  testWidgets('Sync now reports what happened, refusals included',
      (tester) async {
    await narrow(tester);
    final connectivity = _FakeConnectivity(online: true);
    final offline = _FakeOffline(
      connectivityProvider: connectivity,
      items: [_rejected()],
      report: const SyncRunReport(
        uploaded: 3,
        rejected: 1,
        stillWaiting: 0,
        rejectedTotal: 1,
      ),
    );

    await tester.pumpWidget(_host(items: const [], offline: offline));
    await tester.pumpAndSettle();

    await tester.tap(_syncButton);
    await tester.pumpAndSettle();

    expect(offline.syncCalls, 1);
    // Not "Success". The refusal is in the sentence a person actually reads.
    expect(find.text('3 uploaded, 1 refused.'), findsOneWidget);
  });

  testWidgets('a second tap while a run is going does not start a second run',
      (tester) async {
    await narrow(tester);
    final connectivity = _FakeConnectivity(online: true);
    final offline = _SlowOffline(connectivityProvider: connectivity);

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectivityProvider>.value(value: connectivity),
        ChangeNotifierProvider<OfflineProvider>.value(value: offline),
      ],
      child: const MaterialApp(home: PendingUploadsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(_syncButton);
    await tester.pump();

    // Mid-run: the button now says what it is doing and refuses a second tap.
    expect(find.text('Uploading...'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(_syncButton).onPressed, isNull);

    offline.finish();
    await tester.pumpAndSettle();
    expect(offline.syncCalls, 1);
  });
}

/// A provider whose sync does not finish until the test says so, so the
/// mid-run state can be inspected.
class _SlowOffline extends OfflineProvider {
  _SlowOffline({required super.connectivityProvider})
      : super(apiService: ApiService());

  final _gate = Completer<SyncRunReport>();
  int syncCalls = 0;

  @override
  bool get serverReachable => true;

  @override
  bool get isSyncing => false;

  @override
  Future<List<PendingUpload>> loadPendingUploads() async => const [];

  @override
  Future<SyncRunReport> triggerSync() {
    syncCalls++;
    return _gate.future;
  }

  void finish() => _gate.complete(const SyncRunReport(uploaded: 1));
}
