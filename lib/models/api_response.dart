import 'package:flutter/foundation.dart';

import '../utils/friendly_error.dart';

class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String message;
  final int? statusCode;

  /// Set only when [data] is a saved copy replayed from the on-device read
  /// cache because the server could not be reached — it is the moment that
  /// copy was taken, not the moment it was served.
  ///
  /// A successful response with this set is NOT live. Any screen that renders
  /// such data owes the user a visible marker saying so; see CachedDataBanner.
  /// Left null by every response that actually came off the network.
  final DateTime? servedFromCacheAt;

  /// Shorthand for "these rows are from the cache, not the server".
  bool get isFromCache => servedFromCacheAt != null;

  /// The raw, untranslated text behind [message] — an exception's toString,
  /// a server's own wording, an HTML error page's title.
  ///
  /// NEVER render this. It exists so a real outage is still diagnosable after
  /// [message] has been made fit to read: "No connection. Check your internet
  /// and try again." is the right thing to show a seller and the wrong thing
  /// to hand a developer at 2am.
  ///
  /// Null when nothing was lost in translation.
  final String? detail;

  /// The technical text if there is one, otherwise the user-facing message.
  /// Use this for any code that has to MATCH on what went wrong, rather than
  /// display it — matching on [message] breaks the moment the wording changes.
  String get diagnostic => detail ?? message;

  ApiResponse({
    required this.isSuccess,
    this.data,
    required this.message,
    this.statusCode,
    this.servedFromCacheAt,
    this.detail,
  });

  factory ApiResponse.success({
    T? data,
    String message = 'Success',
    DateTime? servedFromCacheAt,
  }) {
    return ApiResponse(
      isSuccess: true,
      data: data,
      message: message,
      statusCode: 200,
      servedFromCacheAt: servedFromCacheAt,
    );
  }

  /// The single place a failure message is made fit for a user to read.
  ///
  /// ApiService builds this from a catch block in 158 places, all of the shape
  /// `ApiResponse.error(message: 'Connection error: $e')`. Translating at each
  /// of those call sites was never going to hold — one missed catch and a
  /// seller sees
  ///
  ///     Connection error: ClientException with SocketException: Failed host
  ///     lookup: 'leruma.co.tz' (OS Error: nodename nor servname provided...)
  ///
  /// in English, at 12px, in a Swahili-speaking shop. Doing it HERE means no
  /// construction site can leak it, however the screen chooses to render.
  ///
  /// [FriendlyError.of] passes a server's own wording through untouched, so a
  /// meaningful refusal ("That customer is outside your assigned stock
  /// locations") still reaches the user intact; only transport noise is
  /// replaced. The raw text is kept on [detail] so nothing is lost.
  ///
  /// [statusCode] is passed through UNCHANGED and deliberately so: a null
  /// status code is how the whole offline machinery recognises "nobody
  /// answered" — SyncService's reachability probe, LocationProvider's cache
  /// fallback, AuthProvider's offline login and the read cache all key on it.
  factory ApiResponse.error({
    required String message,
    int? statusCode,
    String? detail,
  }) {
    final friendly = FriendlyError.of(message);
    final raw = detail ?? message;
    if (friendly != raw) {
      // Not shown, but findable: a real outage still has to be diagnosable.
      debugPrint('ApiResponse.error: $raw');
    }
    return ApiResponse(
      isSuccess: false,
      message: friendly,
      statusCode: statusCode,
      detail: friendly == raw ? null : raw,
    );
  }
}
