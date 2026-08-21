import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_version_info.dart';
import 'api_service.dart';

/// What the last check concluded.
enum UpdateState {
  /// No check has completed yet this session.
  unknown,

  /// The server answered and the installed build is at or ahead of it — or the
  /// deployment has published nothing, which is treated the same way: there is
  /// nothing to announce.
  upToDate,

  /// The server published a build number higher than the installed one.
  updateAvailable,

  /// The check could not complete (offline, server down, not signed in).
  /// Deliberately NOT the same as [upToDate]: the update screen says so
  /// instead of claiming the app is current when it does not know.
  checkFailed,
}

/// Decides whether a newer release exists, and opens the store listing.
///
/// WHY A SERVER CHECK AND NOT THE PLAY IN-APP UPDATE API
/// -----------------------------------------------------
/// Android's In-App Updates API (the `in_app_update` package) is the obvious
/// candidate and its *flexible* flow is genuinely the non-forced behaviour we
/// want. It was not chosen, for four reasons:
///
///  1. It is Android-only. There is no iOS equivalent, so iOS would need a
///     version comparison and a store link anyway — this file, built twice,
///     with two different notions of "up to date" for the settings screen to
///     reconcile.
///  2. Five flavors, five Play listings, five independent version streams.
///     A server check resolves per-client for free: each flavor already points
///     at its own deployment via ClientConfig.prodApiUrl, so leruma.co.tz
///     answers for leruma and saichi.co.tz answers for saichi. No flavor
///     branching anywhere in this file.
///  3. Non-forced by construction. Play's flexible flow is one enum value
///     (AppUpdateType.IMMEDIATE) away from being a gate nobody can dismiss.
///     A check that can only ever open a store listing cannot become one by
///     accident.
///  4. No new dependency and no Play Core in a five-flavor Gradle build:
///     url_launcher, package_info_plus and shared_preferences are already
///     here.
///
/// The cost is real and worth naming: Play is authoritative about whether a
/// release has actually reached a given device, and this is not. If the
/// app_config row is bumped before a staged rollout reaches 100%, some users
/// are told about a build Play will not yet hand them — they tap Update and
/// see "Open". That is a mild confusion, not a broken app, and the fix is
/// operational (bump the row when the rollout completes). If that ever proves
/// to be a problem in the field, the native API can be layered in on Android
/// as a second opinion without any of the UI here changing.
class UpdateService {
  UpdateService({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  /// Epoch millis until which the prompt stays quiet.
  static const _snoozeUntilKey = 'app_update_snoozed_until_ms';

  /// The build number the snooze was taken against. A release NEWER than this
  /// escapes the snooze immediately — saying "Later" to 37 must not also
  /// silence the hotfix in 38.
  static const _snoozeBuildKey = 'app_update_snoozed_build';

  /// How long "Later" lasts.
  ///
  /// Three days. These are work phones a seller opens dozens of times a shift,
  /// so anything keyed to launches — or even a single day — is the nagging the
  /// brief rules out. A week is too slow when the release carries a fix people
  /// are waiting on. Three days lands roughly two reminders across the week a
  /// staged rollout typically takes, and it always yields to a newer build via
  /// [_snoozeBuildKey].
  static const snoozeDuration = Duration(days: 3);

  /// Reads the installed marketing version and build number from the running
  /// binary — not from pubspec, which is a build-time file the shipped app
  /// cannot see, and not from a constant someone has to remember to bump.
  Future<({String versionName, int versionCode, String packageName})>
      installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (
      versionName: info.version,
      versionCode: int.tryParse(info.buildNumber) ?? 0,
      packageName: info.packageName,
    );
  }

  /// The platform key the server stores versions under.
  String get platformKey => Platform.isIOS ? 'ios' : 'android';

  /// Ask this client's deployment what it has published.
  ///
  /// Goes direct rather than through ApiService: that file is 7k lines and
  /// this needs one GET. It borrows ApiService's keep-alive client and token
  /// so it behaves identically on the wire.
  Future<AppVersionInfo?> fetchPublishedVersion() async {
    final uri = Uri.parse('${ApiService.baseUrlSync}/app_version')
        .replace(queryParameters: {'platform': platformKey});

    final token = await _api.getToken();
    if (token == null) return null;

    final response = await ApiService.sharedHttpClient.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('Update check failed: HTTP ${response.statusCode}');
      return null;
    }

    final body = json.decode(response.body);
    final data = body is Map ? body['data'] : null;
    if (data is! Map) return null;

    return AppVersionInfo.fromJson(Map<String, dynamic>.from(data));
  }

  /// Where to send the user.
  ///
  /// The server may supply an explicit listing URL, and on iOS it must: a
  /// bundle id gives you nothing you can build an App Store URL from. On
  /// Android the listing URL is fully derivable from the installed package
  /// name, which is why five flavors need no per-flavor configuration —
  /// co.tz.leruma.pos and co.tz.saichi.pos each produce their own listing.
  Future<Uri?> storeUri(AppVersionInfo? latest) async {
    final fromServer = latest?.storeUrl;
    if (fromServer != null) return Uri.tryParse(fromServer);

    if (Platform.isAndroid) {
      final installed = await installedVersion();
      return Uri.parse(
        'https://play.google.com/store/apps/details?id=${installed.packageName}',
      );
    }

    return null;
  }

  /// Open the store listing. Returns false when there is nowhere to go, so
  /// the caller can say so rather than leaving a button that does nothing.
  Future<bool> openStore(AppVersionInfo? latest) async {
    final uri = await storeUri(latest);
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open store listing: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // "Later"
  // ---------------------------------------------------------------------

  /// Whether the prompt is currently silenced for [versionCode].
  Future<bool> isSnoozed(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_snoozeUntilKey);
    final build = prefs.getInt(_snoozeBuildKey);
    if (until == null || build == null) return false;

    // A newer release than the one that was deferred is a new announcement.
    if (versionCode > build) return false;

    return DateTime.now().millisecondsSinceEpoch < until;
  }

  /// Silence the prompt for [snoozeDuration], against this build.
  ///
  /// Called for every way out of the prompt, not just the Later button —
  /// dismissing by tapping outside, dragging down or pressing back is the same
  /// answer, and re-asking on the next launch because the user swiped instead
  /// of tapping is exactly the nagging this is meant to avoid.
  Future<void> snooze(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _snoozeUntilKey,
      DateTime.now().add(snoozeDuration).millisecondsSinceEpoch,
    );
    await prefs.setInt(_snoozeBuildKey, versionCode);
  }

  /// When the current snooze runs out, or null if none is active.
  Future<DateTime?> snoozedUntil(int versionCode) async {
    if (!await isSnoozed(versionCode)) return null;
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_snoozeUntilKey);
    return until == null ? null : DateTime.fromMillisecondsSinceEpoch(until);
  }
}
