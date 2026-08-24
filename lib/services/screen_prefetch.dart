import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_response.dart';
import 'api_service.dart';

/// Pulls the screens people open on a route into the read cache, before they
/// open them.
///
/// The cache underneath this is opportunistic: a screen is saved only when
/// somebody visits it while there is signal. That is what forced "connect once
/// to set this device up" -- a screen nobody happened to open in town is blank
/// in the field, and the seller has no way to know which ones those are.
///
/// This closes that gap by calling the same cached loaders in the background
/// while there IS signal, so the saved copies exist whether or not anyone
/// visited. Nothing here has its own storage: every call goes through
/// ApiService._cachedGet, so the answer lands in exactly the entry the screen
/// will later read.
///
/// Which makes the ARGUMENTS the whole game. A prefetch that asks with
/// different arguments than the screen writes a different cache key, and the
/// screen stays empty while the log claims success. Every call below mirrors
/// what its screen asks for by default; where a screen's default depends on the
/// chosen location, that location is passed in rather than guessed.
class ScreenPrefetch {
  ScreenPrefetch._();

  /// How often a background warm is worth the data it costs.
  ///
  /// Three hours, not fifteen minutes: bundles are bought by the megabyte here,
  /// and the point is to have SOMETHING on the phone before the signal goes,
  /// not to be current to the minute. A seller who leaves town at eight has a
  /// copy taken at seven.
  static const Duration interval = Duration(hours: 3);

  static const String _lastRunKey = 'screen_prefetch_last_run';

  static bool _running = false;

  /// When the last warm finished, or null if it never has on this device.
  static Future<DateTime?> lastRun() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastRunKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static Future<bool> isDue() async {
    final last = await lastRun();
    if (last == null) return true;
    return DateTime.now().difference(last) >= interval;
  }

  /// Warm the cache for the working screens.
  ///
  /// [allowedLocationIds] and [selectedLocationId] must be the same values the
  /// screens themselves would send -- see the note on arguments above.
  ///
  /// Never throws: a warm is a convenience, and one endpoint being down is not
  /// a reason to abandon the rest or to surface an error to somebody who did
  /// not ask for this.
  static Future<PrefetchOutcome> run({
    required ApiService api,
    required List<int> allowedLocationIds,
    int? selectedLocationId,
    bool force = false,
  }) async {
    if (_running) return PrefetchOutcome.skipped('already running');
    if (!force && !await isDue()) return PrefetchOutcome.skipped('not due');

    _running = true;
    final today = _isoDate(DateTime.now());
    var ok = 0;
    var failed = 0;

    Future<void> attempt(String label, Future<ApiResponse<dynamic>> Function() call) async {
      try {
        final r = await call();
        if (r.isSuccess) {
          ok++;
        } else {
          failed++;
          debugPrint('ScreenPrefetch: $label did not load - ${r.message}');
        }
      } catch (e) {
        failed++;
        debugPrint('ScreenPrefetch: $label threw - $e');
      }
    }

    try {
      // MIRRORS the screens exactly -- see the note on arguments above. Leruma
      // pins to the chosen store; every other client sends every store the user
      // is granted, even when one is selected. Getting this wrong does not
      // fail loudly: it writes a cache entry under a key no screen ever reads,
      // and the warm reports success while the screen stays empty.
      final isLeruma = ApiService.currentClient?.id == 'leruma';
      final List<int> ids;
      if (isLeruma && selectedLocationId != null) {
        ids = <int>[selectedLocationId];
      } else {
        ids = allowedLocationIds;
      }

      // Screens that take a single location use the chosen one.
      final one = selectedLocationId ??
          (allowedLocationIds.isNotEmpty ? allowedLocationIds.first : null);

      // Leruma never asks unfiltered: an empty filter would return every
      // supervisor in the company. If nothing resolved, there is nothing to
      // warm, and the screen will say so itself.
      if (isLeruma && ids.isEmpty) {
        return PrefetchOutcome.skipped('no location assigned');
      }

      // --- the five tabs in the bottom bar come first ---------------------
      await attempt('credits',
          () => api.getSupervisorCredits(locationIds: ids.isEmpty ? null : ids));

      if (one != null) {
        await attempt('suspended', () => api.getSuspendedSummary(locationId: one));
        await attempt('payment summary',
            () => api.getPaymentSummary(locationId: one, date: today));
      }

      await attempt('today summary',
          () => api.getCashSubmitTodaySummary(date: today, locationId: one));

      // --- the lists a route depends on -----------------------------------
      await attempt('map route',
          () => one == null ? _none() : api.getMapRoute(locationId: one));
      // Two ranges, because this screen has two defaults. Somebody without the
      // date permission is pinned to today; somebody with it opens on the whole
      // current month. Warming only one leaves the other half of the staff with
      // an empty screen, and the range is part of the cache key.
      await attempt('debt collection (today)',
          () => api.getDailyDebtReport(
                startDate: today,
                endDate: today,
                locationIds: ids.isEmpty ? null : ids,
              ));
      final now = DateTime.now();
      await attempt('debt collection (this month)',
          () => api.getDailyDebtReport(
                startDate: _isoDate(DateTime(now.year, now.month, 1)),
                endDate: _isoDate(DateTime(now.year, now.month + 1, 0)),
                locationIds: ids.isEmpty ? null : ids,
              ));
      await attempt('supplier creditors',
          () => api.getSupplierCreditors(locationIds: ids.isEmpty ? null : ids));
      await attempt('expenses',
          () => api.getExpenses(startDate: today, endDate: today));
      await attempt('seller report',
          () => api.getSellersReport(startDate: today, endDate: today));

      // --- wallet and cards ------------------------------------------------
      await attempt('cards', () => api.getAllCustomerCards(locationId: one));
      await attempt('wallet confirmations', () => api.getNfcConfirmations());

      // Only count this as a warm if something actually landed. A run where
      // every call failed means the server was unreachable the whole time, and
      // stamping it would lock the next attempt out for three hours -- exactly
      // when the signal came back and a retry was worth most.
      if (ok > 0) await _stamp();
      return PrefetchOutcome(loaded: ok, failed: failed, ranAt: DateTime.now());
    } finally {
      _running = false;
    }
  }

  static Future<ApiResponse<dynamic>> _none() async =>
      ApiResponse<dynamic>.error(message: 'no location');

  static Future<void> _stamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRunKey, DateTime.now().toIso8601String());
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @visibleForTesting
  static Future<void> resetForTest() async {
    _running = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastRunKey);
  }
}

/// What one warm did, for the Settings sheet.
class PrefetchOutcome {
  const PrefetchOutcome({
    required this.loaded,
    required this.failed,
    this.ranAt,
    this.skippedBecause,
  });

  factory PrefetchOutcome.skipped(String why) =>
      PrefetchOutcome(loaded: 0, failed: 0, skippedBecause: why);

  final int loaded;
  final int failed;
  final DateTime? ranAt;
  final String? skippedBecause;

  bool get didRun => skippedBecause == null;
}
