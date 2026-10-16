import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/public_product.dart';
import '../../../services/api_service.dart';
import '../../../services/public_api_service.dart';
import '../../../widgets/tr_text.dart';
import '../landing_screen.dart';
import 'orbit_border.dart';

/// Shop-window product tile for the landing grid: square photo, rounded card,
/// price in the brand colour, a heart, a "New" / "Out of stock" tag and the
/// add-to-cart / WhatsApp / share buttons (same trio as the web shop). Tapping the card opens the full product page.
class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onLike,
    required this.onAddToCart,
    this.isDarkMode = false,
    this.showStockIndicator = false,
    this.currencySymbol = 'TZS',
    this.orbit,
    this.orbitPhase = 0,
  });

  final PublicProduct product;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onAddToCart;
  final bool isDarkMode;
  final bool showStockIndicator;
  final String currencySymbol;

  /// Shared 0..1 ticker that drives the bulb travelling round the card's
  /// border; null (or reduced motion) leaves the border still.
  final Animation<double>? orbit;

  /// This card's offset along the lap, so neighbours are not in step.
  final double orbitPhase;

  /// Newest portfolio photo first (that is what the full card shows), then the
  /// main product image.
  String? get _imageUrl {
    final portfolio = List.of(product.portfolio)
      ..sort((a, b) {
        if (a.createdAt == null && b.createdAt == null) return 0;
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
    for (final p in portfolio) {
      final url = PublicApiService.getPortfolioImageUrl(p.filename);
      if (url.isNotEmpty) return url;
    }
    final main = PublicApiService.getProductImageUrl(product.displayImage);
    return main.isNotEmpty ? main : null;
  }

  bool get _isNew {
    final at = product.latestMediaAt;
    return at != null && DateTime.now().difference(at).inDays <= 7;
  }

  // No "Out of stock" tag: like the live web shop, items with zero stock can
  // still be ordered, so they are shown like any other product.
  bool get _outOfStock => false;

  String _price(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}K';
    return price.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final brand = LandingColors.primaryRed;
    final deep = LandingColors.deep;
    final surface = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final ink = isDarkMode ? Colors.white : const Color(0xFF14213D);
    final muted = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final placeholder =
        isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F3F5);
    final url = _imageUrl;

    final card = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        // Thin brand outline; the orbiting bulb rides on it.
        border: Border.all(color: brand.withValues(alpha: 0.55), width: 1.4),
        // Layered lift: a brand-tinted glow underneath plus a tight dark
        // contact shadow.
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: isDarkMode ? 0.20 : 0.20),
            blurRadius: 26,
            spreadRadius: -2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.45 : 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                url == null
                    ? _placeholder(placeholder, muted)
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: placeholder,
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: brand),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) =>
                            _placeholder(placeholder, muted),
                      ),
                // Soft fade so the tags stay legible on bright photos.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                if (_isNew && !_outOfStock)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _tag('New', brand, Colors.white),
                  ),
                if (_outOfStock)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _tag(
                        'Out of stock', const Color(0xFFD93A3A), Colors.white),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: onLike,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        product.isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 18,
                        color: product.isLiked
                            ? const Color(0xFFE53935)
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                if (_outOfStock)
                  Positioned.fill(
                    child:
                        ColoredBox(color: Colors.white.withValues(alpha: 0.2)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.category.isNotEmpty)
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: brand,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: ink,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$currencySymbol ${_price(product.retailPrice)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode ? Colors.white : deep,
                        ),
                      ),
                      if (product.hasWholesalePrice)
                        Text(
                          'Wholesale: $currencySymbol ${_price(product.wholesalePrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: muted),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _action(
                            onTap: onAddToCart,
                            color: brand,
                            gradientTo: deep,
                            child: const Icon(Icons.add_shopping_cart_rounded,
                                size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          _action(
                            onTap: () => _openWhatsApp(context),
                            color: const Color(0xFF25D366),
                            breathe: true,
                            child: const FaIcon(FontAwesomeIcons.whatsapp,
                                size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 6),
                          _action(
                            onTap: _share,
                            color: isDarkMode ? const Color(0xFF3A3A3A) : deep,
                            child: const Icon(Icons.share_rounded,
                                size: 17, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final bulb = orbit;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (bulb != null && !MediaQuery.disableAnimationsOf(context))
            Positioned.fill(
              child: IgnorePointer(
                child: OrbitBorder(
                  animation: bulb,
                  color: brand,
                  phase: orbitPhase,
                  radius: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _action({
    required VoidCallback onTap,
    required Color color,
    Color? gradientTo,
    bool breathe = false,
    required Widget child,
  }) =>
      // Flexible so the trio shrinks on narrow phones instead of overflowing
      // the card; capped at 36 so it does not stretch on wide ones.
      Flexible(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 36),
          child: GestureDetector(
            onTap: onTap,
            child: _Breathe(
              enabled: breathe,
              color: color,
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gradientTo == null ? color : null,
                  gradient: gradientTo == null
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [color, gradientTo],
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      );

  String get _shopUrl {
    final api = ApiService.baseUrlSync;
    return api.endsWith('/api') ? api.substring(0, api.length - 4) : api;
  }

  String get _summary {
    final b = StringBuffer(product.name.trim());
    if (product.category.isNotEmpty) b.write(' (${product.category})');
    b.write('\nPrice: $currencySymbol ${_price(product.retailPrice)}');
    if (product.hasWholesalePrice) {
      b.write('\nWholesale: $currencySymbol ${_price(product.wholesalePrice)}');
    }
    return b.toString();
  }

  Future<void> _share() =>
      Share.share('$_summary\n$_shopUrl', subject: product.name);

  Future<void> _openWhatsApp(BuildContext context) async {
    const number = '255713727566';
    final text = Uri.encodeComponent(
      "Hi! I'm interested in:\n\n*${product.name.trim()}*\n"
      '${_summary.substring(product.name.trim().length)}\n\n'
      'Can you tell me more about this product?',
    );
    try {
      await launchUrl(Uri.parse('https://wa.me/$number?text=$text'),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  Widget _tag(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: fg,
            letterSpacing: 0.2,
          ),
        ),
      );

  Widget _placeholder(Color bg, Color fg) => Container(
        color: bg,
        child: Center(
          child: Icon(Icons.image_outlined,
              size: 40, color: fg.withValues(alpha: 0.6)),
        ),
      );
}

/// Slow "breathing" pulse for an attention button: the button swells a touch
/// while a soft glow around it grows and fades, then settles back, forever.
/// Does nothing when the system asks for reduced motion.
class _Breathe extends StatefulWidget {
  const _Breathe({
    required this.enabled,
    required this.color,
    required this.child,
  });

  final bool enabled;
  final Color color;
  final Widget child;

  @override
  State<_Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<_Breathe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Breathe old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) {
        final t = curve.value;
        return Transform.scale(
          scale: 1 + 0.08 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.18 + 0.50 * t),
                  blurRadius: 5 + 13 * t,
                  spreadRadius: 3 * t,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }
}
