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
        raw.contains('Huna ruhusa') ||
        raw.contains('hayuko kwenye maeneo') ||
        raw.contains('Eneo hilo hukupangiwa');
  }

  /// A short Swahili line for [raw], which may be an API message or an
  /// exception's toString.
  static String of(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Kuna hitilafu. Jaribu tena.';
    }

    final lower = raw.toLowerCase();

    // Transport
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection closed')) {
      return 'Hakuna mtandao. Angalia intaneti kisha ujaribu tena.';
    }
    if (lower.contains('timeoutexception') || lower.contains('future not completed')) {
      return 'Mtandao ni wa polepole. Jaribu tena.';
    }
    if (lower.contains('handshakeexception') || lower.contains('certificate')) {
      return 'Imeshindikana kuunganisha kwa usalama. Jaribu tena.';
    }

    // The server answered, but not with JSON — almost always a PHP error page
    // or a session redirect reaching an endpoint that expects a token.
    if (lower.contains('failed to parse response') ||
        lower.contains('formatexception') ||
        lower.contains('<!doctype')) {
      return 'Seva imejibu vibaya. Mjulishe msimamizi.';
    }

    // Server-side messages worth translating rather than dropping.
    if (raw.contains('outside your assigned stock locations')) {
      return 'Huyu mteja hayuko kwenye maeneo uliyopangiwa.';
    }
    if (raw.contains('stock location is not assigned to you')) {
      return 'Eneo hilo hukupangiwa.';
    }
    if (raw.startsWith('You do not have permission')) {
      return 'Huna ruhusa ya kufanya hili.';
    }
    if (raw.contains('already has a credit limit request awaiting approval')) {
      return 'Mteja huyu tayari ana ombi linalosubiri idhini.';
    }
    if (raw.contains('already exists for this customer')) {
      return 'Tayari kuna ombi la bidhaa hii kwa mteja huyu leo.';
    }
    if (raw.contains('Could not create the discount request')) {
      return 'Imeshindikana. Huenda tayari kuna ombi la bidhaa hii kwa mteja huyu leo.';
    }
    if (raw.contains('no longer open')) {
      return 'Ombi hili limeshashughulikiwa na mtu mwingine.';
    }
    if (raw.contains('role cannot act on the current step')) {
      return 'Hatua hii inasubiri mtu mwingine, si wewe.';
    }

    // Anything else the server said in its own words is likely useful, but a
    // Dart exception is not. Distinguish by the tell-tale prefix.
    if (lower.startsWith('connection error:')) {
      return 'Imeshindikana kuunganisha. Jaribu tena.';
    }

    return raw;
  }
}
