/// The release the server says is currently published on the store.
///
/// One row per platform per client. The client dimension is not carried in
/// this object because it does not need to be: every flavor points at its own
/// deployment (`ClientConfig.prodApiUrl`), so leruma.co.tz answers for leruma
/// and saichi.co.tz answers for saichi. Nothing in the app has to branch on
/// the flavor to ask the right server.
class AppVersionInfo {
  const AppVersionInfo({
    required this.platform,
    required this.versionName,
    required this.versionCode,
    this.storeUrl,
    this.releaseNotes,
    this.configured = true,
    this.offlineEnabled = true,
  });

  /// 'android' or 'ios'.
  final String platform;

  /// The marketing version, e.g. '1.0.1'. Shown to the user, never compared --
  /// see [versionCode].
  final String versionName;

  /// The build number, e.g. 37. This is the ONLY field compared against the
  /// installed app.
  ///
  /// versionName is a human label that can repeat, go sideways or be typed
  /// wrong ('1.0.10' sorts below '1.0.9' as a string); the build number is the
  /// integer Play and App Store Connect actually order releases by, and it is
  /// the same integer `PackageInfo.buildNumber` reports.
  final int versionCode;

  /// Where to send the user. Optional: on Android it can be derived from the
  /// installed package name, which is why five flavors do not need five rows
  /// of configuration. On iOS there is nothing to derive a listing URL from,
  /// so it has to be supplied here.
  final String? storeUrl;

  /// Short "what's new" note, shown on the update screen and in the prompt.
  final String? releaseNotes;

  /// False when the deployment has not published a version yet, i.e. the
  /// app_config keys are still empty.
  ///
  /// Deliberately distinct from "up to date": an unconfigured server must
  /// announce nothing rather than compare against a zero and tell every user
  /// they are ahead of the store.
  final bool configured;

  /// Whether the deployment still lets the app keep new work on the device
  /// when it cannot reach the server. See [OfflineFeature].
  ///
  /// Absent on a server that predates the setting, which must read as ON: the
  /// app keeps the behaviour it already had rather than losing offline selling
  /// because a field was missing.
  final bool offlineEnabled;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      offlineEnabled: json['offline_enabled'] != false,
      platform: (json['platform'] ?? '').toString(),
      versionName: (json['version_name'] ?? '').toString(),
      versionCode: _asInt(json['version_code']),
      storeUrl: _asNonEmpty(json['store_url']),
      releaseNotes: _asNonEmpty(json['release_notes']),
      configured: json['configured'] == true && _asInt(json['version_code']) > 0,
    );
  }

  /// The server hands numbers back as strings often enough that parsing
  /// defensively here is cheaper than a null build number reading as "no
  /// update" and silently disabling the whole feature.
  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _asNonEmpty(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
