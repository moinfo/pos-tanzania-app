import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/api_response.dart';
import 'package:pos_tanzania_mobile/services/read_cache.dart';
import 'package:pos_tanzania_mobile/utils/friendly_error.dart';
import 'package:pos_tanzania_mobile/widgets/state_views.dart';

/// The offline read states, and the two ways they have historically gone
/// wrong in this app.
///
/// The first is layout: the "showing saved data" banner is an icon, a long
/// sentence and a button in a Row, which is the exact shape that produced the
/// last RenderFlex overflow here. A widget test fails automatically on an
/// overflow, so pumping it at a cramped width in both themes is the proof.
///
/// The second is meaning: a seller who cannot tell "nothing exists" from "I
/// cannot see it right now" chases the wrong problem. So these also assert on
/// the WORDS, because the wording is the feature.
void main() {
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

  group('CachedDataBanner', () {
    // 320pt is the tightest real target; 280 is below anything shipped, and is
    // here so the wrap has headroom rather than only just fitting.
    for (final width in <double>[280, 320, 360]) {
      for (final dark in <bool>[true, false]) {
        testWidgets(
          'does not overflow with a retry button — ${width}px, '
          '${dark ? 'dark' : 'light'}',
          (tester) async {
            await tester.pumpWidget(host(
              dark: dark,
              width: width,
              child: CachedDataBanner(
                fetchedAtLabel: '3 hours ago',
                noun: 'credit limit requests',
                isDark: dark,
                onRetry: () {},
              ),
            ));
            expect(tester.takeException(), isNull);
            expect(find.byType(CachedDataBanner), findsOneWidget);
          },
        );

        testWidgets(
          'does not overflow without a retry button — ${width}px, '
          '${dark ? 'dark' : 'light'}',
          (tester) async {
            await tester.pumpWidget(host(
              dark: dark,
              width: width,
              child: CachedDataBanner(
                // The longest noun any screen passes, with the longest age
                // label, is the worst case the Row has to wrap.
                fetchedAtLabel: '14 minutes ago',
                noun: 'the customer and location choices',
                isDark: dark,
              ),
            ));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('says the data is saved, how old it is, and that it is not live',
        (tester) async {
      await tester.pumpWidget(host(
        dark: false,
        width: 320,
        child: const CachedDataBanner(
          fetchedAtLabel: '3 hours ago',
          noun: 'approvals',
          isDark: false,
        ),
      ));

      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text, contains('Offline'));
      expect(text, contains('saved 3 hours ago'));
      // Without this clause the banner reads as a timestamp rather than a
      // warning, which is how a stale queue gets acted on.
      expect(text, contains('not live'));
    });

    testWidgets('the sentence is Flexible, so a long noun wraps', (tester) async {
      await tester.pumpWidget(host(
        dark: false,
        width: 280,
        child: CachedDataBanner(
          fetchedAtLabel: '2 days ago',
          noun: 'the customer and location choices',
          isDark: false,
          onRetry: () {},
        ),
      ));
      expect(tester.takeException(), isNull);
      // An unflexed Text in a Row is what overflowed last time; assert the
      // guard is actually present rather than relying on it happening to fit.
      expect(
        find.ancestor(of: find.byType(Text).first, matching: find.byType(Expanded)),
        findsOneWidget,
      );
    });
  });

  group('OfflineEmptyView', () {
    for (final width in <double>[280, 320, 360]) {
      for (final dark in <bool>[true, false]) {
        testWidgets(
          'does not overflow — ${width}px, ${dark ? 'dark' : 'light'}',
          (tester) async {
            await tester.pumpWidget(host(
              dark: dark,
              width: width,
              child: OfflineEmptyView(
                noun: 'credit limit requests',
                isDark: dark,
                onRefresh: () async {},
              ),
            ));
            await tester.pump();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('never claims the list is empty, and says what to do',
        (tester) async {
      await tester.pumpWidget(host(
        dark: false,
        width: 320,
        child: const OfflineEmptyView(noun: 'approvals', isDark: false),
      ));

      expect(find.text('Cannot show approvals offline'), findsOneWidget);
      expect(
        find.textContaining('has not loaded approvals yet'),
        findsOneWidget,
      );
      // The instruction is the point: without it the screen is a dead end.
      expect(find.textContaining('Connect to the internet'), findsOneWidget);
    });

    testWidgets('a copy past its horizon reads differently from no copy',
        (tester) async {
      await tester.pumpWidget(host(
        dark: false,
        width: 320,
        child: const OfflineEmptyView(
          noun: 'approvals',
          isDark: false,
          wasStale: true,
        ),
      ));

      expect(find.text('Saved approvals are too old to show'), findsOneWidget);
      expect(find.textContaining('out of date'), findsOneWidget);
    });
  });

  group('CachedBodyWrapper', () {
    testWidgets('draws nothing when the data is live', (tester) async {
      await tester.pumpWidget(host(
        dark: false,
        width: 320,
        child: const CachedBodyWrapper(
          cachedAt: null,
          noun: 'expenses',
          isDark: false,
          child: Text('rows'),
        ),
      ));

      expect(find.byType(CachedDataBanner), findsNothing);
      expect(find.text('rows'), findsOneWidget);
    });

    testWidgets('puts the banner above the list, not inside it', (tester) async {
      await tester.pumpWidget(host(
        dark: false,
        width: 320,
        child: CachedBodyWrapper(
          cachedAt: DateTime.now().subtract(const Duration(hours: 2)),
          noun: 'expenses',
          isDark: false,
          onRetry: () {},
          child: const Text('rows'),
        ),
      ));

      expect(find.byType(CachedDataBanner), findsOneWidget);
      expect(find.text('rows'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Above, not scrolled with the rows: the moment a reader needs to know
      // the list is stale is after they have scrolled to something.
      final bannerY = tester.getTopLeft(find.byType(CachedDataBanner)).dy;
      final rowsY = tester.getTopLeft(find.text('rows')).dy;
      expect(bannerY, lessThan(rowsY));
    });

    for (final dark in <bool>[true, false]) {
      testWidgets(
        'does not overflow at 320px — ${dark ? 'dark' : 'light'}',
        (tester) async {
          await tester.pumpWidget(host(
            dark: dark,
            width: 320,
            child: CachedBodyWrapper(
              cachedAt: DateTime.now().subtract(const Duration(days: 2)),
              noun: 'credit limit requests',
              isDark: dark,
              onRetry: () {},
              child: const SizedBox(height: 40, child: Text('rows')),
            ),
          ));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('describeCacheAge', () {
    test('is coarse, and agrees in number', () {
      final now = DateTime.now();
      expect(describeCacheAge(now), 'just now');
      expect(
        describeCacheAge(now.subtract(const Duration(minutes: 1))),
        '1 minute ago',
      );
      expect(
        describeCacheAge(now.subtract(const Duration(minutes: 14))),
        '14 minutes ago',
      );
      expect(
        describeCacheAge(now.subtract(const Duration(hours: 1))),
        '1 hour ago',
      );
      expect(
        describeCacheAge(now.subtract(const Duration(hours: 5))),
        '5 hours ago',
      );
      expect(
        describeCacheAge(now.subtract(const Duration(days: 1))),
        '1 day ago',
      );
      expect(
        describeCacheAge(now.subtract(const Duration(days: 3))),
        '3 days ago',
      );
    });
  });

  /// The bug that kept offline mode dormant for years: ApiService turns a
  /// transport failure into an error RESPONSE rather than throwing, so every
  /// `catch (e)` offline fallback in the app was unreachable. These pin the
  /// replacement test down, including the cases it must NOT fire on.
  group('isTransportFailure', () {
    test('true for the failures ApiService reports without a status code', () {
      for (final message in [
        'Connection error: ClientException with SocketException: Failed host '
            "lookup: 'leruma.co.tz' (OS Error: nodename nor servname provided, "
            'or not known, errno = 8)',
        'Network error: Unable to connect to server. Please check your '
            'internet connection.',
        'Connection error: TimeoutException after 0:00:30.000000',
        'Connection error: Connection refused',
        'Connection error: HandshakeException: Connection terminated',
      ]) {
        expect(
          isTransportFailure(ApiResponse<void>.error(message: message)),
          isTrue,
          reason: message,
        );
      }
    });

    test('false when the server actually answered', () {
      // A refusal is an answer. Replacing it with yesterday's rows would hide
      // a real problem -- a revoked permission would look like a stale list.
      expect(
        isTransportFailure(ApiResponse<void>.error(
          message: 'You do not have permission to do this',
          statusCode: 403,
        )),
        isFalse,
      );
      expect(
        isTransportFailure(ApiResponse<void>.error(
          message: 'Failed to parse response: unexpected character',
          statusCode: 200,
        )),
        isFalse,
      );
    });

    test('false for a success, cached or live', () {
      expect(isTransportFailure(ApiResponse<int>.success(data: 1)), isFalse);
      expect(
        isTransportFailure(ApiResponse<int>.success(
          data: 1,
          servedFromCacheAt: DateTime.now(),
        )),
        isFalse,
      );
    });

    test('false for a hand-rolled message that omits the status code', () {
      // The second gate. Without the message check, any validation error that
      // forgot to set a status code would be mistaken for the network dying.
      expect(
        isTransportFailure(
          ApiResponse<void>.error(message: 'Choose a customer'),
        ),
        isFalse,
      );
    });
  });

  group('ApiResponse.servedFromCacheAt', () {
    test('is null for anything that came off the network', () {
      expect(ApiResponse<int>.success(data: 1).isFromCache, isFalse);
      expect(
        ApiResponse<int>.error(message: 'nope', statusCode: 500).isFromCache,
        isFalse,
      );
    });

    test('marks a replayed copy, and carries when it was taken', () {
      final taken = DateTime.now().subtract(const Duration(hours: 4));
      final response =
          ApiResponse<int>.success(data: 1, servedFromCacheAt: taken);
      expect(response.isSuccess, isTrue);
      expect(response.isFromCache, isTrue);
      expect(response.servedFromCacheAt, taken);
    });
  });

  /// The user-visible half of the same bug. ApiService builds a failure from a
  /// catch block in 158 places; translating at each was never going to hold.
  /// The factory is the choke point, so these assert on it directly.
  group('ApiResponse.error never leaks a raw exception', () {
    const socketNoise =
        "Connection error: ClientException with SocketException: Failed host "
        "lookup: 'leruma.co.tz' (OS Error: nodename nor servname provided, or "
        'not known, errno = 8)';

    test('the message a screen renders is fit to read', () {
      final response = ApiResponse<void>.error(message: socketNoise);
      expect(response.message, 'No connection. Check your internet and try again.');
      // The exact strings the user reported seeing must be gone from anything
      // a screen can render, however it chooses to render it.
      expect(response.message, isNot(contains('SocketException')));
      expect(response.message, isNot(contains('Failed host lookup')));
      expect(response.message, isNot(contains('ClientException')));
      expect(response.message, isNot(contains('leruma.co.tz')));
    });

    test('the raw text is kept for diagnosis, not thrown away', () {
      final response = ApiResponse<void>.error(message: socketNoise);
      expect(response.detail, socketNoise);
      expect(response.diagnostic, socketNoise);
    });

    test('a meaningful server refusal reaches the user intact', () {
      final response = ApiResponse<void>.error(
        message: 'That stock location is not assigned to you.',
        statusCode: 403,
      );
      expect(response.message, 'That stock location is not assigned to you.');
      // Nothing was translated, so there is no second copy to keep.
      expect(response.detail, isNull);
      expect(response.diagnostic, 'That stock location is not assigned to you.');
    });

    test('statusCode is passed through untouched', () {
      // The whole offline machinery keys on a null status code meaning
      // "nobody answered" -- SyncService's probe, LocationProvider's cache
      // fallback, AuthProvider's offline login. Changing it breaks all three.
      expect(ApiResponse<void>.error(message: socketNoise).statusCode, isNull);
      expect(
        ApiResponse<void>.error(message: 'nope', statusCode: 403).statusCode,
        403,
      );
      expect(
        ApiResponse<void>.error(message: 'nope', statusCode: 500).statusCode,
        500,
      );
    });

    test('classification still works after the message is translated', () {
      // isTransportFailure reads the raw text, so sanitising the user-facing
      // message must not make an outage look like a server refusal.
      expect(
        isTransportFailure(ApiResponse<void>.error(message: socketNoise)),
        isTrue,
      );
    });

    test('isPermanent still recognises a refusal after translation', () {
      final response = ApiResponse<void>.error(
        message: 'You do not have permission to view this',
        statusCode: 403,
      );
      // Screens use this to decide whether a Retry button can ever succeed.
      expect(FriendlyError.isPermanent(response.message), isTrue);
    });

    test('translating twice changes nothing', () {
      // Screens already call FriendlyError.of on the message, so it now runs
      // twice. It has to be idempotent or the wording drifts.
      final once = ApiResponse<void>.error(message: socketNoise).message;
      final twice = FriendlyError.of(once);
      expect(twice, once);
    });
  });

  group('CacheAge horizons', () {
    test('a queue goes stale faster than a reference list', () {
      // The ordering is the judgement, so pin it: acting on a stale approval
      // wastes somebody's trip, while a stale phone number is still correct.
      expect(CacheAge.queue, lessThan(CacheAge.today));
      expect(CacheAge.today, lessThan(CacheAge.reference));
      expect(CacheAge.reference, lessThan(CacheAge.ledger));
    });
  });
}
