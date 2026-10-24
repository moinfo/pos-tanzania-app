import 'package:flutter/material.dart';

/// Shows the author credit after [_taps] quick taps anywhere in the app.
///
/// Mounted in MaterialApp.builder, above the Navigator, so it sees every
/// screen. It uses a Listener, which watches raw pointer events without
/// entering the gesture arena, so it never steals a tap from the screen below.
///
/// The text is kept XOR-encoded rather than as a string literal, so it cannot be
/// found by searching the source or the compiled binary for the sentence.
class CreditGate extends StatefulWidget {
  const CreditGate({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<CreditGate> createState() => _CreditGateState();
}

class _CreditGateState extends State<CreditGate> {
  static const int _taps = 10;
  static const Duration _gap = Duration(milliseconds: 700);

  static const List<int> _k = [0x5a, 0x1d, 0xc3, 0x7e, 0x29, 0xb4, 0x91];
  static const List<int> _d = [
    0x0e, 0x75, 0xaa, 0x0d, 0x09, 0xd5, 0xe1, 0x2a, 0x3d, 0xaa, 0x0d, 0x09,
    0xc4, 0xe3, 0x35, 0x7a, 0xb1, 0x1f, 0x44, 0xd9, 0xf4, 0x3e, 0x3d, 0xa1,
    0x07, 0x09, 0xf1, 0xff, 0x3d, 0x33, 0xe3, 0x34, 0x46, 0xc7, 0xf4, 0x2a,
    0x75, 0xe3, 0x33, 0x5a, 0xd1, 0xfc, 0x38, 0x78, 0xef, 0x5e, 0x43, 0xd9,
    0xe2, 0x3f, 0x70, 0xa1, 0x1b, 0x69, 0xd3, 0xfc, 0x3b, 0x74, 0xaf, 0x50,
    0x4a, 0xdb, 0xfc, 0x7a, 0x7f, 0xb6, 0x0a, 0x09, 0xc4, 0xfe, 0x2d, 0x78,
    0xb1, 0x1b, 0x4d, 0x94, 0xf3, 0x23, 0x3d, 0x8e, 0x11, 0x40, 0xda, 0xf7,
    0x35, 0x69, 0xa6, 0x1d, 0x41,
  ];

  int _count = 0;
  DateTime? _last;

  String _decode() => String.fromCharCodes(
        [for (var i = 0; i < _d.length; i++) _d[i] ^ _k[i % _k.length]],
      );

  void _onDown(PointerDownEvent _) {
    final now = DateTime.now();
    final last = _last;
    _count = (last != null && now.difference(last) <= _gap) ? _count + 1 : 1;
    _last = now;
    if (_count < _taps) return;
    _count = 0;
    _last = null;

    final overlay = widget.navigatorKey.currentState?.overlay;
    final ctx = widget.navigatorKey.currentContext;
    if (overlay == null || ctx == null) return;

    // One toast at a time; a fresh burst of taps replaces the old one.
    _toast?.remove();
    final accent = Theme.of(ctx).colorScheme.primary;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CreditToast(
        text: _decode(),
        accent: accent,
        onDone: () {
          if (_toast == entry) _toast = null;
          entry.remove();
        },
      ),
    );
    _toast = entry;
    overlay.insert(entry);
  }

  OverlayEntry? _toast;

  @override
  void dispose() {
    _toast?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Listener(onPointerDown: _onDown, child: widget.child);
}

/// The credit as a floating toast card: slides up and fades in, then fades away
/// on its own so the whole thing is over within 0.8 s. There is no button.
class _CreditToast extends StatefulWidget {
  const _CreditToast({
    required this.text,
    required this.accent,
    required this.onDone,
  });

  final String text;
  final Color accent;
  final VoidCallback onDone;

  @override
  State<_CreditToast> createState() => _CreditToastState();
}

class _CreditToastState extends State<_CreditToast>
    with SingleTickerProviderStateMixin {
  // 150 + 500 + 150 ms: gone within 0.8 s of the tenth tap.
  static const Duration _in = Duration(milliseconds: 150);
  static const Duration _hold = Duration(milliseconds: 500);
  static const Duration _out = Duration(milliseconds: 150);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _in, reverseDuration: _out);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _c.forward().then((_) async {
      await Future<void>.delayed(_hold);
      _close();
    });
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Bold + accent colour for the name, email and company; plain for the rest.
  List<InlineSpan> _spans() {
    final hot = RegExp(r'Eng\. Joseph Msembe|[\w.]+@[\w.]+\.com|Moinfotech');
    const base = TextStyle(color: Colors.white70, fontSize: 14, height: 1.45);
    final strong = base.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w800,
    );
    final out = <InlineSpan>[];
    widget.text.splitMapJoin(
      hot,
      onMatch: (m) {
        out.add(TextSpan(text: m[0], style: strong));
        return '';
      },
      onNonMatch: (s) {
        out.add(TextSpan(text: s, style: base));
        return '';
      },
    );
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    final dark = Color.lerp(widget.accent, const Color(0xFF0B1B2B), 0.78)!;
    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.6),
                  end: Offset.zero,
                ).animate(curve),
                child: GestureDetector(
                  onTap: _close,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [dark, widget.accent],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.code_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text.rich(TextSpan(children: _spans())),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
