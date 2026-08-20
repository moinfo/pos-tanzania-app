/// Turn an API failure into something a seller can act on.
///
/// The request endpoints report failures verbatim, which means a shop with one
/// bar of signal shows the user roughly 180 characters of this:
///
///   Connection error: ClientException with SocketException: Failed host
///   lookup: 'leruma.co.tz' (OS Error: nodename nor servname provided, or not
///   known, errno = 8), uri=https://...
///
/// in English, at 12px, in an otherwise Swahili app. The server's own messages
/// ("That customer is outside your assigned stock locations") are meaningful
/// and are passed through translated; only the transport-level noise is
/// replaced.
class FriendlyError {
  const FriendlyError._();

  /// True when retrying cannot possibly help.
  ///
  /// A permission or scope refusal will answer the same way every time, so
  /// offering "Jaribu tena" on one is a button that can only ever fail.
  static bool isPermanent(String? raw) {
    if (raw == null) return false;
    return raw.startsWith('You do not have permission') ||
        raw.contains('outside your assigned stock locations') ||
        raw.contains('stock location is not assigned to you') ||
        raw.contains('do not have permission to do this') ||
        raw.contains('not in the stock locations assigned to you');
  }

  /// A short Swahili line for [raw], which may be an API message or an
  /// exception's toString.
  static String of(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Something went wrong. Try again.';
    }

    final lower = raw.toLowerCase();

    // Transport
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection closed')) {
      return 'No connection. Check your internet and try again.';
    }
    if (lower.contains('timeoutexception') || lower.contains('future not completed')) {
      return 'The connection is too slow. Try again.';
    }
    if (lower.contains('handshakeexception') || lower.contains('certificate')) {
      return 'Could not connect securely. Try again.';
    }

    // The server answered, but not with JSON — almost always a PHP error page
    // or a session redirect reaching an endpoint that expects a token.
    if (lower.contains('failed to parse response') ||
        lower.contains('formatexception') ||
        lower.contains('<!doctype')) {
      return 'The server sent back something unexpected. Tell your supervisor.';
    }

    // Server-side messages worth translating rather than dropping.
    if (raw.contains('outside your assigned stock locations')) {
      return 'That customer is not in the stock locations assigned to you.';
    }
    if (raw.contains('stock location is not assigned to you')) {
      return 'That stock location is not assigned to you.';
    }
    if (raw.startsWith('You do not have permission')) {
      return 'You do not have permission to do this.';
    }
    if (raw.contains('already has a credit limit request awaiting approval')) {
      return 'This customer already has a request awaiting approval.';
    }
    if (raw.contains('already exists for this customer')) {
      return 'There is already a request for this item and customer today.';
    }
    if (raw.contains('Could not create the discount request')) {
      return 'Could not send. There may already be a request for this item and customer today.';
    }
    if (raw.contains('no longer open')) {
      return 'Someone else has already dealt with this request.';
    }
    if (raw.contains('role cannot act on the current step')) {
      return 'This step is waiting on someone else, not you.';
    }

    // Anything else the server said in its own words is likely useful, but a
    // Dart exception is not. Distinguish by the tell-tale prefix.
    if (lower.startsWith('connection error:')) {
      return 'Could not connect. Try again.';
    }

    return raw;
  }
}
