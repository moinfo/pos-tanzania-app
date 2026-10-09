// Session-cookie auth for backend features that have no JWT API yet
// (Industry module). Everything else in the app uses ApiService's
// Bearer-token auth; this is a deliberately separate, narrow auth path only
// for those web-only endpoints.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class WebSessionExpiredException implements Exception {
  final String message;
  WebSessionExpiredException([this.message = 'Web session expired']);
  @override
  String toString() => message;
}

/// Thrown when a write endpoint responds with {success: false, ...} - a real
/// (not session-expiry) failure from the server, e.g. validation errors.
class WebActionFailedException implements Exception {
  final String message;
  WebActionFailedException(this.message);
  @override
  String toString() => message;
}

class WebSessionService {
  static const _cookieKey = 'web_session_cookie';
  static const _csrfCookieKey = 'web_session_csrf_cookie';
  static const _cookieClientKey = 'web_session_cookie_client_id';
  static const _usernameKey = 'web_session_username';
  static const _passwordKey = 'web_session_password';
  static const _credentialsClientKey = 'web_session_credentials_client_id';

  // Matches application/config/config.php's csrf_token_name/csrf_cookie_name.
  static const _csrfTokenName = 'csrf_ospos_v3';
  static const _csrfCookieName = 'csrf_cookie_ospos_v3';

  final _storage = const FlutterSecureStorage();
  String? _cookie;
  String? _csrfCookie;

  /// Stores the credentials the user already typed at the app's normal
  /// login screen, so the Industry module can (re)establish its own
  /// session-cookie login silently, without ever prompting a second time.
  /// User explicitly approved storing this (2026-09-29) - same encrypted
  /// secure storage tier the app already uses for offline-login credentials
  /// (see AuthProvider._cacheOfflineCredentials).
  Future<void> rememberCredentials(String username, String password) async {
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(
      key: _credentialsClientKey,
      value: ApiService.currentClient?.id ?? '',
    );
  }

  Future<void> forgetCredentials() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _credentialsClientKey);
  }

  /// Establishes the session using the credentials remembered at app login,
  /// with no user-visible prompt. Returns false if none are stored (e.g. the
  /// user logged in before this module existed - they'll pick up remembered
  /// credentials on their next normal login) or if login fails.
  Future<bool> loginWithRememberedCredentials() async {
    final storedClientId = await _storage.read(key: _credentialsClientKey);
    if (storedClientId != ApiService.currentClient?.id) return false;

    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (username == null || password == null) return false;

    return login(username, password);
  }

  /// Base URL for the staff web dashboard (prodApiUrl/devApiUrl with the
  /// trailing "/api" stripped), derived from the same client config ApiService uses.
  Future<String> get webBaseUrl async {
    await ApiService.getCurrentClient();
    final apiUrl = ApiService.baseUrlSync;
    return apiUrl.endsWith('/api')
        ? apiUrl.substring(0, apiUrl.length - '/api'.length)
        : apiUrl;
  }

  Future<String?> getCookie() async {
    if (_cookie != null) return _cookie;

    final storedCookie = await _storage.read(key: _cookieKey);
    final storedCsrf = await _storage.read(key: _csrfCookieKey);
    final storedClientId = await _storage.read(key: _cookieClientKey);
    final currentClientId = ApiService.currentClient?.id;

    if (storedCookie != null && storedClientId == currentClientId) {
      _cookie = storedCookie;
      _csrfCookie = storedCsrf;
    }
    return _cookie;
  }

  Future<void> _saveCookies({String? session, String? csrf}) async {
    if (session != null) {
      _cookie = session;
      await _storage.write(key: _cookieKey, value: session);
    }
    if (csrf != null) {
      _csrfCookie = csrf;
      await _storage.write(key: _csrfCookieKey, value: csrf);
    }
    await _storage.write(
      key: _cookieClientKey,
      value: ApiService.currentClient?.id ?? '',
    );
  }

  Future<void> clearCookie() async {
    _cookie = null;
    _csrfCookie = null;
    await _storage.delete(key: _cookieKey);
    await _storage.delete(key: _csrfCookieKey);
    await _storage.delete(key: _cookieClientKey);
  }

  /// Logs into the staff web dashboard and stores the session + CSRF cookies.
  ///
  /// The login form (application/views/login.php) posts straight to the
  /// 'login' route (Login::index()) - 'login_check' is only a form_validation
  /// callback method name, never itself a POST target. That route's exact
  /// URI ("login") is what csrf_exclude_uris matches (the exclude check is
  /// an anchored `^login$` regex), so this plain POST needs no CSRF token.
  ///
  /// On success Login::index() calls redirect('home') -> a 302 with a fresh
  /// session cookie. On bad credentials it re-renders the same login page
  /// (200, no redirect). Redirects must NOT be auto-followed here, or the
  /// login response's Set-Cookie header would be lost to the httpClient's
  /// internal redirect-following before we ever see it.
  Future<bool> login(String username, String password) async {
    final base = await webBaseUrl;
    final uri = Uri.parse('$base/login');

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..bodyFields = {'username': username, 'password': password};

      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      // CI redirects with 303 (See Other) after this POST, not the classic
      // 302 - accept any redirect status pointing at home.
      final isRedirectToHome = response.statusCode >= 300 &&
          response.statusCode < 400 &&
          (response.headers['location']?.contains('home') ?? false);

      if (!isRedirectToHome) {
        return false;
      }

      final setCookie = response.headers['set-cookie'];
      final sessionCookie = _extractCookieValue(setCookie, 'ospos_session');
      if (sessionCookie == null) {
        return false;
      }
      final csrfCookie = _extractCookieValue(setCookie, _csrfCookieName);

      await _saveCookies(session: sessionCookie, csrf: csrfCookie);
      return true;
    } finally {
      client.close();
    }
  }

  /// Extracts just the value part of a named cookie from a (possibly
  /// multi-cookie, comma-joined) Set-Cookie header.
  String? _extractCookieValue(String? setCookieHeader, String name) {
    if (setCookieHeader == null) return null;
    final match = RegExp('$name=([^;,]+)').firstMatch(setCookieHeader);
    return match?.group(1);
  }

  /// Picks up any rotated csrf cookie from a response (CI issues a fresh one
  /// after every POST since csrf_regenerate=TRUE) so the next write uses it.
  Future<void> _captureRotatedCsrf(http.Response response) async {
    final rotated = _extractCookieValue(response.headers['set-cookie'], _csrfCookieName);
    if (rotated != null && rotated != _csrfCookie) {
      await _saveCookies(csrf: rotated);
    }
  }

  /// Ensures a valid session cookie exists, silently (re)logging in with the
  /// remembered credentials if needed. No user-visible prompt - if this
  /// fails there are no working credentials, and the caller's request will
  /// simply come back as a session-expired error for the UI to surface.
  Future<Map<String, String>> getHeaders() async {
    var cookie = await getCookie();
    if (cookie == null) {
      await loginWithRememberedCredentials();
      cookie = await getCookie();
    }
    if (cookie == null) {
      throw WebSessionExpiredException('Not logged into web dashboard');
    }
    // cookie/_csrfCookie are stored as bare values (see _extractCookieValue) -
    // the actual Cookie header needs the "name=value" pairs the server set.
    final cookieHeader = _csrfCookie != null
        ? 'ospos_session=$cookie; $_csrfCookieName=$_csrfCookie'
        : 'ospos_session=$cookie';
    return {'Cookie': cookieHeader, 'Accept': 'application/json'};
  }

  bool isLoggedIn() => _cookie != null;

  /// GET helper for endpoints wrapped in a JSON object. Retries once via
  /// [loginWithRememberedCredentials] if the response isn't JSON (redirected
  /// to the HTML login page - session expired), before giving up and
  /// throwing [WebSessionExpiredException].
  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final decoded = await _getDecoded(uri);
    return decoded as Map<String, dynamic>;
  }

  /// Same retry behaviour as [getJson], for endpoints (e.g. get_roster) that
  /// return a bare JSON array instead of an object.
  Future<List<dynamic>> getJsonList(Uri uri) async {
    final decoded = await _getDecoded(uri);
    return decoded is List ? decoded : <dynamic>[];
  }

  /// Raw HTML GET, for the one case (Settings tab) where the only source of
  /// current values is the same server-rendered page the web dashboard
  /// itself reads them from - there is no JSON endpoint for these fields.
  Future<String> getHtml(Uri uri) async {
    final headers = await getHeaders();
    final response = await http.get(uri, headers: headers);
    await _captureRotatedCsrf(response);

    if (_looksLikeHtmlLoginPage(response.body)) {
      final reLoggedIn = await loginWithRememberedCredentials();
      if (!reLoggedIn) throw WebSessionExpiredException();
      final retry = await http.get(uri, headers: await getHeaders());
      await _captureRotatedCsrf(retry);
      if (_looksLikeHtmlLoginPage(retry.body)) throw WebSessionExpiredException();
      return retry.body;
    }
    return response.body;
  }

  bool _looksLikeHtmlLoginPage(String body) =>
      body.contains('id="username"') && body.contains('id="password"');

  /// POST helper for CSRF-protected write endpoints. Attaches the current
  /// CSRF token as both the request cookie (handled by getHeaders()) and the
  /// matching form field CI's Security library checks against
  /// (hash_equals($_POST[token_name], $_COOKIE[cookie_name])), retries once
  /// on session expiry, and throws [WebActionFailedException] if the server
  /// responds with {success: false}.
  Future<Map<String, dynamic>> postForm(Uri uri, Map<String, String> fields) async {
    final result = await _postFormRaw(uri, fields);

    if (result['success'] == false) {
      throw WebActionFailedException(result['message']?.toString() ?? 'Action failed');
    }
    return result;
  }

  Future<Map<String, dynamic>> _postFormRaw(Uri uri, Map<String, String> fields) async {
    final headers = await getHeaders();
    final body = {...fields, _csrfTokenName: _csrfCookie ?? ''};

    final response = await http.post(uri, headers: headers, body: body);
    await _captureRotatedCsrf(response);

    if (_looksLikeJson(response)) {
      return json.decode(response.body) as Map<String, dynamic>;
    }

    await clearCookie();
    final reLoggedIn = await loginWithRememberedCredentials();
    if (!reLoggedIn) {
      throw WebSessionExpiredException();
    }

    final retryHeaders = await getHeaders();
    final retryBody = {...fields, _csrfTokenName: _csrfCookie ?? ''};
    final retryResponse = await http.post(uri, headers: retryHeaders, body: retryBody);
    await _captureRotatedCsrf(retryResponse);

    if (!_looksLikeJson(retryResponse)) {
      throw WebSessionExpiredException();
    }
    return json.decode(retryResponse.body) as Map<String, dynamic>;
  }

  Future<dynamic> _getDecoded(Uri uri) async {
    final headers = await getHeaders();
    final response = await http.get(uri, headers: headers);
    await _captureRotatedCsrf(response);

    if (_looksLikeJson(response)) {
      return json.decode(response.body);
    }

    await clearCookie();
    final reLoggedIn = await loginWithRememberedCredentials();
    if (!reLoggedIn) {
      throw WebSessionExpiredException();
    }

    final retryResponse = await http.get(uri, headers: await getHeaders());
    await _captureRotatedCsrf(retryResponse);
    if (!_looksLikeJson(retryResponse)) {
      throw WebSessionExpiredException();
    }
    return json.decode(retryResponse.body);
  }

  /// The backend's `echo json_encode(...)` endpoints don't set a JSON
  /// Content-Type header (CI defaults to text/html), so detection has to
  /// look at the actual body rather than trust that header.
  bool _looksLikeJson(http.Response response) {
    final body = response.body.trimLeft();
    return body.startsWith('{') || body.startsWith('[');
  }
}
