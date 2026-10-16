import 'package:flutter/material.dart' hide Text;
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'tr_text.dart';

/// Tinted gradient card surface that "breathes": it lifts and swells on the
/// inhale while its accent-coloured shadow widens and brightens, then settles
/// back. Each card starts at its own point in the loop ([phaseKey]) so a grid
/// ripples instead of pulsing in lockstep. [builder] receives the eased breath
/// value (0..1) so contents, like an icon glow, can follow it.
class BreathingSurface extends StatefulWidget {
  final Color color;
  final bool isDark;
  final String phaseKey;
  final double radius;
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, double t) builder;

  const BreathingSurface({
    super.key,
    required this.color,
    required this.isDark,
    required this.phaseKey,
    required this.builder,
    this.radius = 20,
    this.onTap,
  });

  @override
  State<BreathingSurface> createState() => _BreathingSurfaceState();
}

class _BreathingSurfaceState extends State<BreathingSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the system "remove animations" setting.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _c.stop();
      _started = false;
    } else if (!_started) {
      _started = true;
      final phase = (widget.phaseKey.hashCode.abs() % 100) / 100.0;
      _c.repeat(reverse: true);
      _c.value = phase;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final dark = widget.isDark;
    final radius = BorderRadius.circular(widget.radius);
    final surfaceTop = dark ? AppColors.darkCard : Colors.white;
    final surfaceBottom = dark
        ? Color.alphaBlend(color.withValues(alpha: 0.10), AppColors.darkCard)
        : Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          // Lifts as it inhales; the shadow falls further away while raised.
          return Transform.translate(
            offset: Offset(0, -9 * t),
            child: Transform.scale(
              scale: 1.0 + 0.03 * t,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [surfaceTop, surfaceBottom],
                  ),
                  border: Border.all(
                    color: color.withValues(alpha: dark ? 0.28 : 0.14),
                  ),
                  boxShadow: [
                    // Soft accent glow that breathes.
                    BoxShadow(
                      color: color.withValues(
                          alpha: (dark ? 0.22 : 0.16) + 0.26 * t),
                      blurRadius: 12 + 20 * t,
                      spreadRadius: -2 + 4 * t,
                      offset: Offset(0, 6 + 12 * t),
                    ),
                    // Tight contact shadow for depth.
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.35 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: radius,
                    onTap: widget.onTap,
                    child: widget.builder(context, t),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The gradient icon tile used on the cards, its glow following the breath.
class BreathingIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double t;
  final double size;
  final double iconSize;

  const BreathingIconTile({
    super.key,
    required this.icon,
    required this.color,
    required this.t,
    this.size = 48,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.75), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28 + 0.2 * t),
            blurRadius: 8 + 6 * t,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

/// Dashboard KPI card: icon tile, label and amount on a [BreathingSurface].
class BreathingStatCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isDark;

  /// Smaller icon and type, for the dense twelve-card transactions grid.
  final bool compact;

  const BreathingStatCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
    required this.isDark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return BreathingSurface(
      color: color,
      isDark: isDark,
      phaseKey: title,
      builder: (context, t) => Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BreathingIconTile(
              icon: icon,
              color: color,
              t: t,
              size: compact ? 40 : 48,
              iconSize: compact ? 20 : 24,
            ),
            SizedBox(height: compact ? 12 : 16),
            Text(
              title,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                color: isDark ? AppColors.darkTextLight : AppColors.textLight,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              Formatters.formatCurrency(amount),
              style: TextStyle(
                fontSize: compact ? 16 : 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
