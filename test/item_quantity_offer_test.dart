import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/item_quantity_offer.dart';

/// Builds an offer with sensible defaults so each test only states what it cares about.
ItemQuantityOffer buildOffer({
  int itemId = 10,
  double purchaseQuantity = 100,
  double rewardQuantity = 3,
  int useTieredRewards = 0,
  double? maxRewardPerTransaction,
  int rewardType = 0,
  int? rewardItemId,
  String? rewardItemName,
  double? rewardItemUnitPrice,
  int useItemGroup = 0,
  List<OfferTier>? tiers,
}) {
  return ItemQuantityOffer(
    offerId: 1,
    offerName: 'Test Offer',
    itemId: itemId,
    purchaseQuantity: purchaseQuantity,
    rewardQuantity: rewardQuantity,
    useTieredRewards: useTieredRewards,
    maxRewardPerTransaction: maxRewardPerTransaction,
    startDate: '2026-01-01',
    endDate: '2026-12-31',
    priority: 0,
    rewardType: rewardType,
    rewardItemId: rewardItemId,
    rewardItemName: rewardItemName,
    rewardItemUnitPrice: rewardItemUnitPrice,
    useItemGroup: useItemGroup,
    tiers: tiers,
  );
}

void main() {
  _groupOfferTests();
  group('resolveRewardItemId', () {
    test('reward_type 0 gives back the purchased item', () {
      final offer = buildOffer(rewardType: 0);
      expect(offer.resolveRewardItemId(10), 10);
      expect(offer.isCrossItemReward(10), isFalse);
    });

    test('reward_type 1 gives the configured reward item', () {
      final offer = buildOffer(rewardType: 1, rewardItemId: 55);
      expect(offer.resolveRewardItemId(10), 55);
      expect(offer.isCrossItemReward(10), isTrue);
    });

    test('reward_type 1 with no reward item falls back to the purchased item', () {
      // Mirrors the server: `!empty($offer->reward_item_id) ? ... : $offer->item_id`
      final offer = buildOffer(rewardType: 1, rewardItemId: null);
      expect(offer.resolveRewardItemId(10), 10);
    });

    test('reward_type 2 falls back to purchased item on the single-item path', () {
      final offer = buildOffer(rewardType: 2, rewardItemId: 55, useItemGroup: 1);
      expect(offer.resolveRewardItemId(10), 10);
    });
  });

  group('calculateReward - legacy ratio', () {
    test('awards one reward block per completed ratio', () {
      final offer = buildOffer(purchaseQuantity: 100, rewardQuantity: 3);
      expect(offer.calculateReward(99), 0);
      expect(offer.calculateReward(100), 3);
      expect(offer.calculateReward(250), 6); // two complete blocks
    });

    test('respects max_reward_per_transaction', () {
      final offer = buildOffer(
        purchaseQuantity: 100,
        rewardQuantity: 3,
        maxRewardPerTransaction: 5,
      );
      expect(offer.calculateReward(300), 5); // would be 9, capped at 5
    });

    test('returns nothing for non-positive quantities', () {
      final offer = buildOffer();
      expect(offer.calculateReward(0), 0);
      expect(offer.calculateReward(-5), 0);
    });
  });

  group('calculateReward - tiered', () {
    final tiers = [
      OfferTier(tierId: 1, minQuantity: 50, rewardQuantity: 1, tierOrder: 1),
      OfferTier(tierId: 2, minQuantity: 100, rewardQuantity: 3, tierOrder: 2),
      OfferTier(tierId: 3, minQuantity: 200, rewardQuantity: 8, tierOrder: 3),
    ];

    test('selects the highest qualifying tier', () {
      final offer = buildOffer(useTieredRewards: 1, tiers: tiers);
      expect(offer.calculateReward(49), 0);
      expect(offer.calculateReward(50), 1);
      expect(offer.calculateReward(150), 3);
      expect(offer.calculateReward(500), 8);
    });

    test('returns nothing when the offer has no tiers', () {
      final offer = buildOffer(useTieredRewards: 1, tiers: []);
      expect(offer.calculateReward(999), 0);
    });
  });

  group('fromJson', () {
    test('parses reward item fields sent as strings by the PHP API', () {
      // CodeIgniter/MySQL frequently returns numerics as strings
      final offer = ItemQuantityOffer.fromJson({
        'offer_id': '7',
        'offer_name': 'Coke to Fanta',
        'item_id': '10',
        'purchase_quantity': '100',
        'reward_quantity': '3',
        'use_tiered_rewards': '0',
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'priority': '0',
        'reward_type': '1',
        'reward_item_id': '55',
        'reward_item_name': 'Fanta 500ml',
        'reward_item_cost_price': '700.5',
        'reward_item_unit_price': '1000',
        'use_item_group': '0',
      });

      expect(offer.rewardType, 1);
      expect(offer.rewardItemId, 55);
      expect(offer.rewardItemName, 'Fanta 500ml');
      expect(offer.rewardItemCostPrice, 700.5);
      expect(offer.rewardItemUnitPrice, 1000);
      expect(offer.resolveRewardItemId(10), 55);
    });

    test('defaults reward fields when the server omits them', () {
      // An older API build that has not been deployed yet must not crash the app
      final offer = ItemQuantityOffer.fromJson({
        'offer_id': 7,
        'offer_name': 'Legacy',
        'item_id': 10,
        'purchase_quantity': 100,
        'reward_quantity': 3,
        'use_tiered_rewards': 0,
        'start_date': '2026-01-01',
        'end_date': '2026-12-31',
        'priority': 0,
      });

      expect(offer.rewardType, 0);
      expect(offer.rewardItemId, isNull);
      expect(offer.useItemGroup, 0);
      expect(offer.resolveRewardItemId(10), 10);
    });
  });
}

void _groupOfferTests() {
  ItemQuantityOffer buildGroup({
    int itemId = 6113,
    List<int> members = const [6113, 6126, 6127],
    double purchaseQuantity = 50,
    double rewardQuantity = 1,
    int rewardType = 0,
    int? rewardItemId,
  }) {
    return ItemQuantityOffer(
      offerId: 181,
      offerName: 'July offa',
      itemId: itemId,
      purchaseQuantity: purchaseQuantity,
      rewardQuantity: rewardQuantity,
      useTieredRewards: 0,
      startDate: '2026-08-01',
      endDate: '2026-08-31',
      priority: 0,
      useItemGroup: 1,
      groupItemIds: members,
      rewardType: rewardType,
      rewardItemId: rewardItemId,
    );
  }

  group('group offers', () {
    test('combines quantity across member items only', () {
      final offer = buildGroup();
      // 20 BLUE + 20 YELLOW + 10 PINK = 50; the 99 of a non-member is ignored
      expect(
        offer.combinedQuantity({6113: 20, 6126: 20, 6127: 10, 999: 99}),
        50,
      );
    });

    test('earns nothing until the combined threshold is met', () {
      final offer = buildGroup(purchaseQuantity: 50, rewardQuantity: 1);
      expect(offer.calculateReward(offer.combinedQuantity({6113: 49})), 0);
      // No single line reaches 50, but together they do
      expect(
        offer.calculateReward(offer.combinedQuantity({6113: 30, 6126: 20})),
        1,
      );
    });

    test('reward_type 0 gives the member with the highest quantity', () {
      final offer = buildGroup(rewardType: 0);
      expect(
        offer.resolveGroupRewardItemId({6113: 10, 6126: 35, 6127: 5}),
        6126,
      );
    });

    test('reward_type 2 also gives the highest-quantity member', () {
      final offer = buildGroup(rewardType: 2);
      expect(
        offer.resolveGroupRewardItemId({6113: 5, 6126: 5, 6127: 40}),
        6127,
      );
    });

    test('reward_type 1 gives the configured item regardless of quantities', () {
      final offer = buildGroup(rewardType: 1, rewardItemId: 4242);
      expect(
        offer.resolveGroupRewardItemId({6113: 99, 6126: 1, 6127: 1}),
        4242,
      );
    });

    test('parses group_item_ids from the /groups payload', () {
      final offer = ItemQuantityOffer.fromJson({
        'offer_id': 181,
        'offer_name': 'July offa',
        'item_id': 6113,
        'purchase_quantity': 50,
        'reward_quantity': 1,
        'use_tiered_rewards': 0,
        'start_date': '2026-08-01',
        'end_date': '2026-08-31',
        'priority': 0,
        'use_item_group': 1,
        'group_item_ids': ['6113', 6126, 6127],
      });

      expect(offer.useItemGroup, 1);
      expect(offer.groupItemIds, [6113, 6126, 6127]);
      expect(offer.combinedQuantity({6113: 25, 6126: 25}), 50);
    });
  });
}
