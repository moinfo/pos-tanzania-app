/// Model for item quantity offers (Buy X get Y free)
class ItemQuantityOffer {
  final int offerId;
  final String offerName;
  final String? offerCode;
  final int itemId;
  final String? itemName;
  final String? itemNumber;
  final int? stockLocationId;
  final String? locationName;
  final double purchaseQuantity;
  final double rewardQuantity;
  final int useTieredRewards;
  final double? maxRewardPerTransaction;
  final String startDate;
  final String endDate;
  final String? description;
  final int priority;
  final List<OfferTier>? tiers;

  // Reward item. The reward is not always the item that was purchased -- an offer
  // can hand over a different item entirely (e.g. buy 100 Coca Cola, get 3 Fanta).
  final int rewardType; // 0=same as purchased, 1=specific item, 2=highest qty in group
  final int? rewardItemId;
  final String? rewardItemName;
  final String? rewardItemNumber;
  final double? rewardItemCostPrice;
  final double? rewardItemUnitPrice;
  final int useItemGroup; // 1=combined-quantity group offer

  /// Items whose quantities count toward a group offer's threshold.
  ///
  /// Only populated by the /groups endpoint. Empty for single-item offers.
  final List<int> groupItemIds;

  ItemQuantityOffer({
    required this.offerId,
    required this.offerName,
    this.offerCode,
    required this.itemId,
    this.itemName,
    this.itemNumber,
    this.stockLocationId,
    this.locationName,
    required this.purchaseQuantity,
    required this.rewardQuantity,
    required this.useTieredRewards,
    this.maxRewardPerTransaction,
    required this.startDate,
    required this.endDate,
    this.description,
    required this.priority,
    this.tiers,
    this.rewardType = 0,
    this.rewardItemId,
    this.rewardItemName,
    this.rewardItemNumber,
    this.rewardItemCostPrice,
    this.rewardItemUnitPrice,
    this.useItemGroup = 0,
    this.groupItemIds = const [],
  });

  factory ItemQuantityOffer.fromJson(Map<String, dynamic> json) {
    return ItemQuantityOffer(
      offerId: json['offer_id'] is int
          ? json['offer_id']
          : int.tryParse(json['offer_id']?.toString() ?? '') ?? 0,
      offerName: json['offer_name']?.toString() ?? '',
      offerCode: json['offer_code']?.toString(),
      itemId: json['item_id'] is int
          ? json['item_id']
          : int.tryParse(json['item_id']?.toString() ?? '') ?? 0,
      itemName: json['item_name']?.toString(),
      itemNumber: json['item_number']?.toString(),
      stockLocationId: json['stock_location_id'] != null
          ? (json['stock_location_id'] is int
              ? json['stock_location_id']
              : int.tryParse(json['stock_location_id']?.toString() ?? ''))
          : null,
      locationName: json['location_name']?.toString(),
      purchaseQuantity: (json['purchase_quantity'] is num)
          ? (json['purchase_quantity'] as num).toDouble()
          : double.tryParse(json['purchase_quantity']?.toString() ?? '') ?? 0.0,
      rewardQuantity: (json['reward_quantity'] is num)
          ? (json['reward_quantity'] as num).toDouble()
          : double.tryParse(json['reward_quantity']?.toString() ?? '') ?? 0.0,
      useTieredRewards: json['use_tiered_rewards'] is int
          ? json['use_tiered_rewards']
          : int.tryParse(json['use_tiered_rewards']?.toString() ?? '') ?? 0,
      maxRewardPerTransaction: json['max_reward_per_transaction'] != null
          ? (json['max_reward_per_transaction'] is num
              ? (json['max_reward_per_transaction'] as num).toDouble()
              : double.tryParse(json['max_reward_per_transaction']?.toString() ?? ''))
          : null,
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      description: json['description']?.toString(),
      priority: json['priority'] is int
          ? json['priority']
          : int.tryParse(json['priority']?.toString() ?? '') ?? 0,
      tiers: json['tiers'] != null
          ? (json['tiers'] as List<dynamic>)
              .map((item) => OfferTier.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      rewardType: _asInt(json['reward_type']) ?? 0,
      rewardItemId: _asInt(json['reward_item_id']),
      rewardItemName: json['reward_item_name']?.toString(),
      rewardItemNumber: json['reward_item_number']?.toString(),
      rewardItemCostPrice: _asDouble(json['reward_item_cost_price']),
      rewardItemUnitPrice: _asDouble(json['reward_item_unit_price']),
      useItemGroup: _asInt(json['use_item_group']) ?? 0,
      groupItemIds: (json['group_item_ids'] as List<dynamic>?)
              ?.map((id) => _asInt(id) ?? 0)
              .where((id) => id > 0)
              .toList() ??
          const [],
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'offer_id': offerId,
      'offer_name': offerName,
      if (offerCode != null) 'offer_code': offerCode,
      'item_id': itemId,
      if (itemName != null) 'item_name': itemName,
      if (itemNumber != null) 'item_number': itemNumber,
      if (stockLocationId != null) 'stock_location_id': stockLocationId,
      if (locationName != null) 'location_name': locationName,
      'purchase_quantity': purchaseQuantity,
      'reward_quantity': rewardQuantity,
      'use_tiered_rewards': useTieredRewards,
      if (maxRewardPerTransaction != null) 'max_reward_per_transaction': maxRewardPerTransaction,
      'start_date': startDate,
      'end_date': endDate,
      if (description != null) 'description': description,
      'priority': priority,
      if (tiers != null) 'tiers': tiers!.map((t) => t.toJson()).toList(),
      'reward_type': rewardType,
      if (rewardItemId != null) 'reward_item_id': rewardItemId,
      if (rewardItemName != null) 'reward_item_name': rewardItemName,
      if (rewardItemNumber != null) 'reward_item_number': rewardItemNumber,
      if (rewardItemCostPrice != null) 'reward_item_cost_price': rewardItemCostPrice,
      if (rewardItemUnitPrice != null) 'reward_item_unit_price': rewardItemUnitPrice,
      'use_item_group': useItemGroup,
    };
  }

  /// Item that should actually be handed over as the reward.
  ///
  /// Mirrors `Item_quantity_offer::determine_reward_item()` on the server for the
  /// single-item case. Group offers use resolveGroupRewardItemId instead,
  /// because their reward depends on the quantities of every member in the cart.
  int resolveRewardItemId(int purchasedItemId) {
    if (rewardType == 1 && rewardItemId != null && rewardItemId! > 0) {
      return rewardItemId!;
    }
    return purchasedItemId;
  }

  /// True when the reward is a different item than the one being purchased.
  bool isCrossItemReward(int purchasedItemId) =>
      resolveRewardItemId(purchasedItemId) != purchasedItemId;

  /// Combined quantity of every member item, which is what a group offer's
  /// threshold is measured against.
  ///
  /// [quantities] maps item id -> quantity currently in the cart.
  double combinedQuantity(Map<int, double> quantities) {
    return groupItemIds.fold<double>(
      0,
      (sum, id) => sum + (quantities[id] ?? 0),
    );
  }

  /// Reward item for a group offer.
  ///
  /// Mirrors `Item_quantity_offer::determine_reward_item()`: reward_type 1 is a
  /// specific item, while 0 and 2 both resolve to the member with the highest
  /// quantity in the cart (type 0 delegates to type 2 for group offers).
  int resolveGroupRewardItemId(Map<int, double> quantities) {
    if (rewardType == 1 && rewardItemId != null && rewardItemId! > 0) {
      return rewardItemId!;
    }

    int best = itemId;
    double bestQty = -1;
    for (final id in groupItemIds) {
      final qty = quantities[id] ?? 0;
      if (qty > bestQty) {
        bestQty = qty;
        best = id;
      }
    }
    return best;
  }

  /// Calculate free quantity for a given purchased quantity (legacy ratio-based)
  double calculateFreeQuantity(double purchasedQty) {
    if (purchasedQty <= 0 || purchaseQuantity <= 0) {
      return 0.0;
    }

    // How many complete ratios does purchase satisfy?
    final multiplier = (purchasedQty / purchaseQuantity).floor();
    var freeQty = multiplier * rewardQuantity;

    // Apply max reward limit if set
    if (maxRewardPerTransaction != null && freeQty > maxRewardPerTransaction!) {
      freeQty = maxRewardPerTransaction!;
    }

    return freeQty;
  }

  /// Calculate free quantity using tiered system
  double calculateTieredFreeQuantity(double purchasedQty) {
    if (tiers == null || tiers!.isEmpty || purchasedQty <= 0) {
      return 0.0;
    }

    // Find highest qualifying tier
    OfferTier? qualifyingTier;
    for (var tier in tiers!) {
      if (purchasedQty >= tier.minQuantity) {
        qualifyingTier = tier;
      } else {
        break; // Tiers are ordered by min_quantity, so we can stop here
      }
    }

    return qualifyingTier?.rewardQuantity ?? 0.0;
  }

  /// Auto-calculate free quantity (uses tiered or legacy based on offer type)
  double calculateReward(double purchasedQty) {
    if (useTieredRewards == 1) {
      return calculateTieredFreeQuantity(purchasedQty);
    } else {
      return calculateFreeQuantity(purchasedQty);
    }
  }

  /// Get offer description for display
  String get offerDescription {
    if (useTieredRewards == 1 && tiers != null && tiers!.isNotEmpty) {
      // Show tiered description
      final tierDescriptions = tiers!.map((t) =>
        'Buy ${t.minQuantity.toStringAsFixed(0)} get ${t.rewardQuantity.toStringAsFixed(0)} free'
      ).join(', ');
      return tierDescriptions;
    } else {
      // Show simple ratio description
      return 'Buy ${purchaseQuantity.toStringAsFixed(0)} get ${rewardQuantity.toStringAsFixed(0)} free';
    }
  }

  @override
  String toString() {
    return 'ItemQuantityOffer{offerId: $offerId, offerName: $offerName, $offerDescription}';
  }
}

/// Model for offer tier (for tiered offers)
class OfferTier {
  final int tierId;
  final double minQuantity;
  final double rewardQuantity;
  final int tierOrder;

  OfferTier({
    required this.tierId,
    required this.minQuantity,
    required this.rewardQuantity,
    required this.tierOrder,
  });

  factory OfferTier.fromJson(Map<String, dynamic> json) {
    return OfferTier(
      tierId: json['tier_id'] is int
          ? json['tier_id']
          : int.tryParse(json['tier_id']?.toString() ?? '') ?? 0,
      minQuantity: (json['min_quantity'] is num)
          ? (json['min_quantity'] as num).toDouble()
          : double.tryParse(json['min_quantity']?.toString() ?? '') ?? 0.0,
      rewardQuantity: (json['reward_quantity'] is num)
          ? (json['reward_quantity'] as num).toDouble()
          : double.tryParse(json['reward_quantity']?.toString() ?? '') ?? 0.0,
      tierOrder: json['tier_order'] is int
          ? json['tier_order']
          : int.tryParse(json['tier_order']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tier_id': tierId,
      'min_quantity': minQuantity,
      'reward_quantity': rewardQuantity,
      'tier_order': tierOrder,
    };
  }
}

/// Response from check offer API
class CheckOfferResponse {
  final bool available;
  final ItemQuantityOffer? offer;

  CheckOfferResponse({
    required this.available,
    this.offer,
  });

  factory CheckOfferResponse.fromJson(Map<String, dynamic> json) {
    return CheckOfferResponse(
      available: json['available'] == true,
      offer: json['offer'] != null
          ? ItemQuantityOffer.fromJson(json['offer'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Response from calculate reward API
class RewardCalculationResponse {
  final int offerId;
  final double purchasedQuantity;
  final double freeQuantity;
  final int? multiplier;
  final int? tierId;
  final bool eligible;

  RewardCalculationResponse({
    required this.offerId,
    required this.purchasedQuantity,
    required this.freeQuantity,
    this.multiplier,
    this.tierId,
    required this.eligible,
  });

  factory RewardCalculationResponse.fromJson(Map<String, dynamic> json) {
    return RewardCalculationResponse(
      offerId: json['offer_id'] is int
          ? json['offer_id']
          : int.tryParse(json['offer_id']?.toString() ?? '') ?? 0,
      purchasedQuantity: (json['purchased_quantity'] is num)
          ? (json['purchased_quantity'] as num).toDouble()
          : double.tryParse(json['purchased_quantity']?.toString() ?? '') ?? 0.0,
      freeQuantity: (json['free_quantity'] is num)
          ? (json['free_quantity'] as num).toDouble()
          : double.tryParse(json['free_quantity']?.toString() ?? '') ?? 0.0,
      multiplier: json['multiplier'] != null
          ? (json['multiplier'] is int
              ? json['multiplier']
              : int.tryParse(json['multiplier']?.toString() ?? ''))
          : null,
      tierId: json['tier_id'] != null
          ? (json['tier_id'] is int
              ? json['tier_id']
              : int.tryParse(json['tier_id']?.toString() ?? ''))
          : null,
      eligible: json['eligible'] == true,
    );
  }
}

/// Response from active offers API
class ActiveOffersResponse {
  final List<ItemQuantityOffer> offers;
  final int count;

  ActiveOffersResponse({
    required this.offers,
    required this.count,
  });

  factory ActiveOffersResponse.fromJson(Map<String, dynamic> json) {
    return ActiveOffersResponse(
      offers: (json['offers'] as List<dynamic>?)
              ?.map((item) =>
                  ItemQuantityOffer.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count']?.toString() ?? '') ?? 0,
    );
  }
}