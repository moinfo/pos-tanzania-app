import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A protected image widget that prevents long-press saving and context menus
class ProtectedImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const ProtectedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Absorb long press to prevent context menu
      onLongPress: () {
        // Show a message that saving is disabled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.shield, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Image saving is disabled'),
              ],
            ),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: AbsorbPointer(
        absorbing: false,
        child: IgnorePointer(
          ignoring: false,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: fit,
            width: width,
            height: height,
            placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
            errorWidget: (context, url, error) => errorWidget ?? _defaultError(),
            // Disable image caching to file system for extra protection
            // (Note: This affects offline functionality, so we keep caching enabled)
          ),
        ),
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}

/// A protected network image that uses Stack with an invisible overlay
/// to prevent browser/system context menus from appearing
class ProtectedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const ProtectedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The actual image
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: fit,
          width: width,
          height: height,
          placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
          errorWidget: (context, url, error) => errorWidget ?? _defaultError(),
        ),
        // Invisible overlay to intercept touch events
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: () {
                // Intercept long press - show protection message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.shield, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Image is protected'),
                      ],
                    ),
                    backgroundColor: Colors.grey[800],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
