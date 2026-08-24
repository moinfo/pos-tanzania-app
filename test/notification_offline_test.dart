import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/api_response.dart';
import 'package:pos_tanzania_mobile/models/app_notification.dart';
import 'package:pos_tanzania_mobile/providers/notification_provider.dart';
import 'package:pos_tanzania_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "No notifications" is a claim about what the server holds. It must never be
/// made from a request that never reached the server.
///
/// On device this was the sharpest instance of the whole class of bug: the app
/// bar badge read 26 -- it is served from a separate counter that survives an
/// outage -- while the feed one tap away said "No notifications. You will see
/// requests and decisions here." The app contradicted itself in the same
/// breath, and the reading a seller takes from that is that their approvals
/// were dealt with.
///
/// Two defects made it happen and both are covered here: the provider recorded
/// the failure in `_error` and nothing ever read it, and `loadNotifications`
/// emptied the list BEFORE the request, so a failed refresh also wiped rows
/// that were already on screen.
class _FakeApi extends ApiService {
  _FakeApi(this.feed);

  ApiResponse<List<AppNotification>> feed;
  int feedCalls = 0;

  @override
  Future<ApiResponse<List<AppNotification>>> getNotifications({
    String? after,
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    feedCalls++;
    return feed;
  }

  // The counts are refreshed at the end of every load. Stubbed so the test
  // never touches a socket; they are not what is under test.
  @override
  Future<ApiResponse<({int unread, String? latestAt})>>
      getUnreadNotificationCount() async =>
          ApiResponse.error(message: 'Connection error: SocketException');

  @override
  Future<ApiResponse<int>> getPendingApprovalsCount() async =>
      ApiResponse.error(message: 'Connection error: SocketException');
}

AppNotification _n(String id) => AppNotification(
      id: id,
      title: 'Approval Required',
      body: 'A new One_time_discount requires your approval.',
      notificationType: 'info',
      createdAt: '2026-08-24 07:54:00',
    );

/// A transport failure as ApiService actually produces one: no status code,
/// and a transport-shaped message. ApiResponse.error runs it through
/// FriendlyError, so `message` comes out readable and the raw text survives on
/// `detail` -- which is exactly what isTransportFailure keys on.
ApiResponse<List<AppNotification>> _offlineFailure() => ApiResponse.error(
      message: 'Connection error: ClientException with SocketException: '
          "Failed host lookup: 'leruma.co.tz'",
    );

void main() {
  // The success path persists a polling cursor through SharedPreferences.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a transport failure is reported as offline, not as an empty feed',
      () async {
    final api = _FakeApi(_offlineFailure());
    final provider = NotificationProvider(apiService: api);

    await provider.loadNotifications();

    expect(provider.isOffline, isTrue,
        reason: 'the screen renders OfflineEmptyView off this flag; without '
            'it the feed falls through to "No notifications"');
    expect(provider.notifications, isEmpty);
  });

  test('a refusal the server actually sent is NOT reported as offline',
      () async {
    // 403 is an answer. Showing "you are offline" for it hides a real problem.
    final api = _FakeApi(
      ApiResponse.error(message: 'Forbidden', statusCode: 403),
    );
    final provider = NotificationProvider(apiService: api);

    await provider.loadNotifications();

    expect(provider.isOffline, isFalse);
  });

  test('a failed refresh keeps the rows that were already on screen', () async {
    final api = _FakeApi(ApiResponse.success(data: [_n('a'), _n('b')]));
    final provider = NotificationProvider(apiService: api);

    await provider.loadNotifications();
    expect(provider.notifications, hasLength(2));
    expect(provider.isOffline, isFalse);
    final firstLoad = provider.loadedAt;
    expect(firstLoad, isNotNull);

    // Now the network goes away and the user pulls to refresh.
    api.feed = _offlineFailure();
    await provider.loadNotifications(refresh: true);

    expect(provider.notifications, hasLength(2),
        reason: 'clearing the list before the request meant a failed refresh '
            'destroyed rows the user could still usefully read');
    expect(provider.isOffline, isTrue);
    expect(provider.loadedAt, firstLoad,
        reason: 'the age shown in the banner must be when the rows were '
            'actually fetched, not when the failed attempt happened');
  });

  test('loadedAt is only stamped by a successful load', () async {
    final api = _FakeApi(_offlineFailure());
    final provider = NotificationProvider(apiService: api);

    await provider.loadNotifications();

    expect(provider.loadedAt, isNull,
        reason: 'nothing was ever fetched, so there is no age to show');
  });

  test('coming back online clears the offline flag', () async {
    final api = _FakeApi(_offlineFailure());
    final provider = NotificationProvider(apiService: api);

    await provider.loadNotifications();
    expect(provider.isOffline, isTrue);

    api.feed = ApiResponse.success(data: [_n('a')]);
    await provider.loadNotifications(refresh: true);

    expect(provider.isOffline, isFalse);
    expect(provider.notifications, hasLength(1));
    expect(provider.loadedAt, isNotNull);
  });
}
