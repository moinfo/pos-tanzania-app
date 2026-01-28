# Curved Bottom Navigation Implementation

This document explains the architecture and implementation of the animated curved bottom navigation bar used throughout the POS Tanzania app.

## Overview

The navigation features:
- **Curved notch** in the center that holds the selected item
- **Smooth animation** when switching between tabs
- **Circular reordering** - items rotate around rather than slide
- **Dark/Light theme support**
- **Permission-based menu items**

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AppBottomNavigation                       │
│         (Wrapper: permissions, navigation routing)           │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                  CurvedBottomNavigation                      │
│              (Main widget: animation, layout)                │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                    _CurvedNavPainter                         │
│            (CustomPainter: curve geometry)                   │
└─────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/widgets/curved_bottom_navigation.dart` | Main navigation widget with animation and custom painter |
| `lib/widgets/app_bottom_navigation.dart` | Wrapper handling permissions and navigation routing |
| `lib/screens/main_navigation.dart` | Central navigation container for main screens |

## Implementation Details

### 1. Data Model

```dart
class CurvedNavItem {
  final IconData icon;
  final String label;

  const CurvedNavItem({
    required this.icon,
    required this.label,
  });
}
```

### 2. Animation System

The animation uses Flutter's `AnimationController` with a **circular reordering** approach:

```dart
_animationController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 300),
);

_rotationAnimation = Tween<double>(begin: 0, end: 0).animate(
  CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
);
```

**How circular reordering works:**

Instead of moving items left/right directly, we calculate an offset that makes items wrap around:

```dart
void _animateToIndex(int index) {
  final itemCount = widget.items.length;
  final centerIndex = (itemCount - 1) / 2.0;  // Find center position
  final targetOffset = centerIndex - index;    // Calculate rotation needed

  _rotationAnimation = Tween<double>(
    begin: _currentRotationOffset,
    end: targetOffset,
  ).animate(CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeOutCubic,
  ));

  _animationController.forward(from: 0);
}
```

**Position calculation with wrapping:**

```dart
double displayPosition = index + rotationOffset;

// Wrap around to keep all items in valid slots
while (displayPosition < 0) displayPosition += itemCount;
while (displayPosition >= itemCount) displayPosition -= itemCount;

final xPos = displayPosition * itemWidth;
```

### 3. Custom Painter - The Curved Shape

The `_CurvedNavPainter` draws the navigation bar with a notch:

```dart
class _CurvedNavPainter extends CustomPainter {
  final double curvePosition;  // 0.0 = left, 0.5 = center, 1.0 = right
  final Color color;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const curveRadius = 35.0;  // Size of the circular notch
    const curveDepth = 20.0;   // How deep the notch goes

    final curveX = size.width * curvePosition;  // X position of curve center

    final path = Path();

    // Start bottom-left, go up to curve depth
    path.moveTo(0, size.height);
    path.lineTo(0, curveDepth);

    // Approach the curve
    path.lineTo(curveX - curveRadius - 15, curveDepth);

    // Smooth entry into curve (quadratic bezier)
    path.quadraticBezierTo(
      curveX - curveRadius,
      curveDepth,
      curveX - curveRadius,
      0,
    );

    // The circular arc (the notch)
    path.arcToPoint(
      Offset(curveX + curveRadius, 0),
      radius: const Radius.circular(curveRadius),
      clockwise: false,
    );

    // Smooth exit from curve
    path.quadraticBezierTo(
      curveX + curveRadius,
      curveDepth,
      curveX + curveRadius + 15,
      curveDepth,
    );

    // Complete the path
    path.lineTo(size.width, curveDepth);
    path.lineTo(size.width, size.height);
    path.close();

    // Draw fill and border
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(topBorderPath, borderPaint);
  }
}
```

**Visual representation of the curve:**

```
                    ╭───────╮
                   ╱         ╲
──────────────────╯           ╰──────────────────
│                                               │
│                                               │
└───────────────────────────────────────────────┘
```

### 4. Selected Item Styling

The selected item gets special treatment:

```dart
if (isSelected) {
  return Transform.translate(
    offset: const Offset(0, -8),  // Move up into the notch
    child: Icon(
      item.icon,
      color: selectedColor,
      size: 38,  // Larger icon
    ),
  );
} else {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(item.icon, color: unselectedColor, size: 22),
      const SizedBox(height: 4),
      Text(item.label, style: TextStyle(fontSize: 10)),
    ],
  );
}
```

## Usage

### Basic Usage (in a screen)

```dart
Scaffold(
  body: YourScreenContent(),
  bottomNavigationBar: const AppBottomNavigation(currentIndex: 0),
)
```

### In Main Navigation Container

```dart
CurvedBottomNavigation(
  items: const [
    CurvedNavItem(icon: Icons.home, label: 'Home'),
    CurvedNavItem(icon: Icons.inventory, label: 'Items'),
    CurvedNavItem(icon: Icons.receipt, label: 'Sales'),
    CurvedNavItem(icon: Icons.person, label: 'Clients'),
    CurvedNavItem(icon: Icons.more_horiz, label: 'More'),
  ],
  currentIndex: _selectedIndex,
  onTap: (index) => setState(() => _selectedIndex = index),
  backgroundColor: Theme.of(context).cardColor,
  selectedItemColor: AppColors.primaryRed,
  unselectedItemColor: Colors.grey,
)
```

## Permission-Based Menu Items

The `AppBottomNavigation` wrapper filters items based on user permissions:

```dart
List<CurvedNavItem> _buildNavItems() {
  final items = <CurvedNavItem>[];

  if (hasPermission('home')) {
    items.add(CurvedNavItem(icon: Icons.home, label: 'Home'));
  }
  if (hasPermission('items')) {
    items.add(CurvedNavItem(icon: Icons.inventory, label: 'Items'));
  }
  // ... more items

  return items;
}
```

## Theme Support

Colors automatically adapt to light/dark mode:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final backgroundColor = isDark ? AppColors.darkCard : Colors.white;
final borderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
```

## Design Decisions

### Why Circular Reordering?

Traditional slide animations can feel mechanical. The circular reorder approach:
- Creates a more organic, rotating carousel feel
- Selected item always appears in center
- Items wrap smoothly around the edges
- More visually interesting than linear movement

### Why 300ms Duration?

- Fast enough to feel responsive
- Slow enough to be perceivable
- Uses `easeOutCubic` for natural deceleration

### Why Custom Painter?

Using `CustomPainter` instead of images:
- Scales perfectly on all screen sizes
- Easy to adjust curve parameters
- Smaller app size (no image assets)
- Supports dynamic theming

## File Structure

```
lib/
├── widgets/
│   ├── curved_bottom_navigation.dart   # Core navigation widget
│   └── app_bottom_navigation.dart      # Permission wrapper
├── screens/
│   └── main_navigation.dart            # Main navigation container
└── utils/
    └── constants.dart                  # Colors and theme values
```

## Customization

### Adjust Curve Size

In `_CurvedNavPainter`:

```dart
const curveRadius = 35.0;  // Make larger/smaller
const curveDepth = 20.0;   // Adjust notch depth
```

### Change Animation Speed

In `CurvedBottomNavigation`:

```dart
_animationController = AnimationController(
  duration: const Duration(milliseconds: 400),  // Slower
  // or
  duration: const Duration(milliseconds: 200),  // Faster
);
```

### Change Animation Curve

```dart
CurvedAnimation(
  parent: _animationController,
  curve: Curves.bounceOut,  // Different feel
  // or
  curve: Curves.elasticOut,  // Springy effect
)
```