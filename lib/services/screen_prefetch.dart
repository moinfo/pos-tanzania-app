import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_response.dart';
import 'api_service.dart';
import 'read_cache.dart';

/// Pulls the screens people open on a route into the read cache, before they
/// open them.
///
/// The cache underneath is opportunistic: a screen is saved only when somebody
/// visits it while there is signal. That is what forced "connect once to set up
/// this device" -- a screen nobody happened to open in town is blank in the
/// field, and the seller has no way to know which ones those are.
///
/// Two passes, for two different problems.
///
/// **Replay** is the reliable one. The cache knows every key it has ever
/// written, and a key was written by the screen itself -- so re-requesting it
/// lands in the same entry by construction. Anything a person has opened once
/// stays warm from then on, with no list to maintain.
///
/// **Bootstrap** covers the gap replay cannot: a screen never opened has no key
/// to replay. It calls a fixed set of loaders with the arguments their screens
/// use by default, which means those arguments have to MATCH -- limit and
/// locationId included. A bootstrap call that asks differently writes a key no
/// screen ever reads and reports success while the screen stays empty. That was
/// wrong three times before replay was added, which is why replay carries the
/// weight and bootstrap is only the first-run fallback.
class ScreenPrefetch {
  ScreenPrefetch._();

  /// How often a background warm is worth the data it costs.
  ///
  /// Bundles are bought by the megabyte here, and the point is to have
  /// SOMETHING on the phone before the signal goes, not to be current to the
  /// minute. A seller who leaves town at eight has a copy taken at seven.
  static const Duration interval = Duration(hours: 3);

  static const String _lastRunKey = 'screen_prefetch_last_run';
  static const String _lastReportKey = 'screen_prefetch_last_report';

  /// How many previously-seen keys one replay pass will refresh.
  ///
  /// A cap, not a target: a device in daily use accumulates keys for every date
  /// range anyone ever picked, and refreshing all of them would spend a bundle
  /// on report ranges nobody will open again. Newest first, so what is actually
  /// in use wins.
  static const int replayLimit = 60;

  static bool _running = false;

  static Future<DateTime?> lastRun() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastRunKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// What the last warm actually fetched, for the Settings sheet.
  static Future<PrefetchReport?> lastReport() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastReportKey);
    if (raw == null) return null;
    try {
      return PrefetchReport.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isDue() async {
    final last = await lastRun();
    if (last == null) return true;
    return DateTime.now().difference(last) >= interval;
  }

  /// Warm the cache.
  ///
  /// Never throws: a warm is a convenience, and one endpoint being down is not
  /// a reason to abandon the rest or to surface an error to somebody who did
  /// not ask for this.
  static Future<PrefetchReport> run({
    required ApiService api,
    required List<int> allowedLocationIds,
    int? selectedLocationId,
    bool force = false,
    void Function(int done, int total, String label)? onProgress,
  }) async {
    if (_running) return PrefetchReport.skipped('already running');
    if (!force && !await isDue()) return PrefetchReport.skipped('not due');

    _running = true;
    final entries = <PrefetchEntry>[];
    try {
      // MIRRORS the screens: Leruma pins to the chosen store, every other
      // client sends every store the user is granted even when one is selected.
      final isLeruma = ApiService.currentClient?.id == 'leruma';
      final ids = (isLeruma && selectedLocationId != null)
          ? <int>[selectedLocationId]
          : allowedLocationIds;
      final one = selectedLocationId ??
          (allowedLocationIds.isNotEmpty ? allowedLocationIds.first : null);

      // Leruma never asks unfiltered -- that would return every supervisor in
      // the company. Without a store there is nothing to warm, and the screens
      // say so themselves.
      if (isLeruma && ids.isEmpty) {
        return PrefetchReport.skipped('no store assigned yet');
      }

      final today = _isoDate(DateTime.now());
      final now = DateTime.now();
      final scoped = ids.isEmpty ? null : ids;

      // Built as a list BEFORE anything runs, so the progress bar has a real
      // denominator from the first tick. A bar whose total grows while it fills
      // reads as if it is going backwards.
      final tasks = <_Task>[];

      // ---- pass one: everything already known, by its own key -------------
      // A key was written by the screen itself, so re-requesting it lands in
      // the same entry by construction. Newest first, so a screen in daily use
      // is refreshed before a report range somebody opened once in March.
      final known = await ReadCache.instance.knownKeys(limit: replayLimit);
      for (final key in known) {
        tasks.add(_Task(_describeKey(key), () async {
          final ok = await api.refreshCachedKey(key);
          return ok ? null : 'not refreshed';
        }));
      }

      // ---- pass two: first-run bootstrap ----------------------------------
      // Only while the cache is still thin -- once replay carries real traffic
      // these are duplicates of keys just refreshed.
      if (known.length < 8 || force) {
        void add(String label, Future<ApiResponse<dynamic>> Function() call) {
          tasks.add(_Task(label, () async {
            final r = await call();
            return r.isSuccess ? null : r.message;
          }));
        }

        add('Products', () => api.getItems(limit: 100, locationId: one));
        add('Customers', () => api.getCustomers(limit: 100, locationId: one));
        add('Suppliers', () => api.getSuppliers());
        add('Expense categories', () => api.getExpenseCategories());
        add('Supervisors', () => api.getSupervisors(locationId: one));

        add('Credits', () => api.getSupervisorCredits(locationIds: scoped));
        if (one != null) {
          // The actual "Suspended" bottom-nav tab. getSuspendedSummary below
          // is a DIFFERENT screen (a report), reached from Payment -- the two
          // were conflated once already and one of them shipped uncached.
          add('Suspended sales', () => api.getSuspendedSales(locationId: one));
          add('Suspended summary', () => api.getSuspendedSummary(locationId: one));
          add('Payment summary',
              () => api.getPaymentSummary(locationId: one, date: today));
          add('Route map', () => api.getMapRoute(locationId: one));
          add('Main store',
              () => api.getMainStore(locationId: one, date: today));
        }
        add("Today's summary",
            () => api.getCashSubmitTodaySummary(date: today, locationId: one));

        add('Approvals waiting', () => api.getPendingApprovals());
        add('My requests', () => api.getMySubmittedRequests());
        add('Credit limit requests',
            () => api.getCreditLimitRequests(limit: 40));
        // NOT getDiscountRequests: /discount_requests 404s server-side --
        // a pre-existing backend gap, not an offline-mode one. Warming a
        // route that does not exist would report "missing" on every run.

        // Drawer items reached often enough to be worth warming up front;
        // everything else opened once is covered by replay from here on.
        add('Stock locations', () => api.getAllowedStockLocations());
        add('Stock tracking locations', () => api.getStockTrackingLocations());

        add('Expenses',
            () => api.getExpenses(
                startDate: today, endDate: today, locationId: one));
        add('Sales',
            () => api.getSales(
                startDate: today, endDate: today, limit: 20, locationId: one));
        add('Banking',
            () => api.getBankingList(
                startDate: today,
                endDate: today,
                locationId: one,
                limit: 100));
        add('Receivings', () => api.getReceivings(limit: 20));
        add('Seller report',
            () => api.getSellersReport(startDate: today, endDate: today));

        // Debt collection has two defaults: pinned to today without the date
        // permission, the whole current month with it. The range is part of the
        // key, so warming one leaves the other half of the staff empty-handed.
        add('Debt collection (today)',
            () => api.getDailyDebtReport(
                startDate: today, endDate: today, locationIds: scoped));
        add('Debt collection (this month)',
            () => api.getDailyDebtReport(
                startDate: _isoDate(DateTime(now.year, now.month, 1)),
                endDate: _isoDate(DateTime(now.year, now.month + 1, 0)),
                locationIds: scoped));

        add('Supplier credits',
            () => api.getSupplierCreditors(locationIds: scoped));
        add('Wallet cards', () => api.getAllCustomerCards(locationId: one));
        add('Wallet confirmations', () => api.getNfcConfirmations());
      }

      final total = tasks.length;
      if (total == 0) return PrefetchReport.skipped('nothing to fetch');

      var done = 0;
      var replayed = 0;
      for (final task in tasks) {
        // Announced BEFORE the call, so the label names what is being fetched
        // now rather than what finished a moment ago.
        onProgress?.call(done, total, task.label);
        String? failure;
        try {
          failure = await task.run();
        } catch (e) {
          failure = '$e';
        }
        final ok = failure == null;
        if (ok && done < known.length) replayed++;
        entries.add(PrefetchEntry(task.label, ok));
        if (!ok) {
          debugPrint('ScreenPrefetch: ${task.label} did not load - $failure');
        }
        done++;
        onProgress?.call(done, total, task.label);
      }

      // Replay produces one entry per cache key, and several keys collapse to
      // the same human name -- sixteen saved Customers views, nine Items. A
      // list repeating "Customers" sixteen times tells a reader nothing, so
      // equal names are folded together and counted.
      final report = PrefetchReport(
        entries: _group(entries),
        replayed: replayed,
        ranAt: DateTime.now(),
      );
      debugPrint('ScreenPrefetch: ${report.loaded} ready, ${report.failed} '
          'missing, $replayed replayed, ${tasks.length} calls');

      // Only stamp a warm that actually landed something. A pass where
      // everything failed means the server was unreachable throughout, and
      // stamping it would lock the next attempt out for three hours -- exactly
      // when the signal came back and a retry is worth most.
      if (report.loaded > 0) await _save(report);
      return report;
    } finally {
      _running = false;
    }
  }

  static Future<void> _save(PrefetchReport report) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastRunKey, report.ranAt!.toIso8601String());
    await prefs.setString(_lastReportKey, jsonEncode(report.toJson()));
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Fold entries that share a name into one, keeping the counts.
  ///
  /// An entry that partly failed is reported as failed: "3 of 5" hides that
  /// two screens will be blank, and blank is what the reader cares about.
  static List<PrefetchEntry> _group(List<PrefetchEntry> raw) {
    final order = <String>[];
    final ok = <String, int>{};
    final total = <String, int>{};
    for (final e in raw) {
      if (!total.containsKey(e.label)) order.add(e.label);
      total[e.label] = (total[e.label] ?? 0) + 1;
      if (e.ok) ok[e.label] = (ok[e.label] ?? 0) + 1;
    }
    return order.map((label) {
      final good = ok[label] ?? 0;
      final all = total[label]!;
      return PrefetchEntry(
        all == 1 ? label : '$label ($good of $all views)',
        good == all,
      );
    }).toList();
  }

  /// A cache key turned into something a person recognises.
  ///
  /// Replay works on keys like "/items?limit=100&location_id=3". Showing that
  /// in Settings would be worse than showing nothing, so the path's last
  /// meaningful segment is used instead.
  static String _describeKey(String key) {
    final path = key.split('?').first;
    // Numbers are record ids, not names: /credits/statement/4821 is a
    // statement, not a "4821".
    final named = path
        .split('/')
        .where((p) => p.isNotEmpty && int.tryParse(p) == null)
        .toList();
    if (named.isEmpty) return key;

    // Words that describe the request rather than the thing. Keeping them
    // produced rows reading just "All" and "Get", which name nothing -- the
    // resource before them is what a reader recognises.
    const filler = {'all', 'list', 'index', 'get', 'view', 'search'};
    final meaningful = named.where((p) => !filler.contains(p)).toList();
    final parts = (meaningful.isEmpty ? [named.first] : meaningful)
        .take(2)
        .map((p) => p.replaceAll('_', ' '))
        .toList();

    final label = parts.join(' ');
    return label.isEmpty
        ? key
        : '${label[0].toUpperCase()}${label.substring(1)}';
  }


  @visibleForTesting
  static Future<void> resetForTest() async {
    _running = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastRunKey);
    await prefs.remove(_lastReportKey);
  }
}

/// One unit of work in a warm: what to call it, and how to run it.
///
/// Returns null on success, or the reason it failed.
class _Task {
  _Task(this.label, this.run);

  final String label;
  final Future<String?> Function() run;
}

/// One thing a warm tried to fetch, and whether it arrived.
class PrefetchEntry {
  const PrefetchEntry(this.label, this.ok);

  factory PrefetchEntry.fromJson(Map<String, dynamic> j) =>
      PrefetchEntry(j['label'] as String, j['ok'] as bool);

  final String label;
  final bool ok;

  Map<String, dynamic> toJson() => {'label': label, 'ok': ok};
}

/// What one warm did -- shown in Settings, so it names things a person
/// recognises rather than endpoints.
class PrefetchReport {
  const PrefetchReport({
    required this.entries,
    this.replayed = 0,
    this.ranAt,
    this.skippedBecause,
  });

  factory PrefetchReport.skipped(String why) =>
      PrefetchReport(entries: const [], skippedBecause: why);

  factory PrefetchReport.fromJson(Map<String, dynamic> j) => PrefetchReport(
        entries: (j['entries'] as List)
            .map((e) => PrefetchEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        replayed: (j['replayed'] as num?)?.toInt() ?? 0,
        ranAt: DateTime.tryParse(j['ranAt'] as String? ?? ''),
      );

  final List<PrefetchEntry> entries;
  final int replayed;
  final DateTime? ranAt;
  final String? skippedBecause;

  bool get didRun => skippedBecause == null;
  int get loaded => entries.where((e) => e.ok).length;
  int get failed => entries.where((e) => !e.ok).length;

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'replayed': replayed,
        'ranAt': ranAt?.toIso8601String(),
      };
}
