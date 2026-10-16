import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/public_product.dart';
import 'package:pos_tanzania_mobile/screens/landing/widgets/product_grid_card.dart';

/// The landing grid sizes each card from the screen width and the text scale
/// (see landing_screen.dart). The card must never report a RenderFlex overflow
/// at that size, on narrow phones or with a large system font.
double _extent(double width, double textScale) =>
    (width - 36) / 2 + 78 + 84 * textScale;

void main() {
  for (final width in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.15, 1.3]) {
      testWidgets('no overflow at width $width, text scale $scale',
          (tester) async {
        final product = PublicProduct(
          itemId: 1,
          name: 'HP ELITEBOOK DRAGONFLY G4 X360 CONVERTIBLE LAPTOP',
          category: 'COMPUTER ACCESSORIES',
          description: '',
          retailPrice: 1100000,
          wholesalePrice: 850000,
          likesCount: 0,
          isLiked: false,
        );

        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 900),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: (width - 36) / 2,
                    height: _extent(width, scale),
                    child: ProductGridCard(
                      product: product,
                      onTap: () {},
                      onLike: () {},
                      onAddToCart: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
