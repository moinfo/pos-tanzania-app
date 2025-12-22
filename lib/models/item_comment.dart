/// Model for item comments in suspended summary
class ItemComment {
  final int? id;
  final int itemId;
  final int locationId;
  final String comment;
  final String commentDate;
  final int? userEntryId;
  final String? createdAt;
  final String? updatedAt;

  ItemComment({
    this.id,
    required this.itemId,
    required this.locationId,
    required this.comment,
    required this.commentDate,
    this.userEntryId,
    this.createdAt,
    this.updatedAt,
  });

  factory ItemComment.fromJson(Map<String, dynamic> json) {
    return ItemComment(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      itemId: json['item_id'] is int
          ? json['item_id']
          : int.tryParse(json['item_id']?.toString() ?? '') ?? 0,
      locationId: json['stock_location_id'] is int
          ? json['stock_location_id']
          : int.tryParse(json['stock_location_id']?.toString() ?? '') ?? 0,
      comment: json['comment']?.toString() ?? '',
      commentDate: json['comment_date']?.toString() ?? '',
      userEntryId: json['user_entry_id'] is int
          ? json['user_entry_id']
          : int.tryParse(json['user_entry_id']?.toString() ?? ''),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'comment_id': id,
      'item_id': itemId,
      'location_id': locationId,
      'comment': comment,
      'comment_date': commentDate,
    };
  }
}

/// Comment history item with user details
class CommentHistoryItem {
  final int id;
  final int itemId;
  final int locationId;
  final String comment;
  final String commentDate;
  final String firstName;
  final String lastName;
  final String? createdAt;

  CommentHistoryItem({
    required this.id,
    required this.itemId,
    required this.locationId,
    required this.comment,
    required this.commentDate,
    required this.firstName,
    required this.lastName,
    this.createdAt,
  });

  factory CommentHistoryItem.fromJson(Map<String, dynamic> json) {
    return CommentHistoryItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      itemId: json['item_id'] is int
          ? json['item_id']
          : int.tryParse(json['item_id']?.toString() ?? '') ?? 0,
      locationId: json['stock_location_id'] is int
          ? json['stock_location_id']
          : int.tryParse(json['stock_location_id']?.toString() ?? '') ?? 0,
      comment: json['comment']?.toString() ?? '',
      commentDate: json['comment_date']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
    );
  }

  String get fullName => '$firstName $lastName';
}

/// Response for get comment API
class ItemCommentResponse {
  final ItemComment? comment;
  final List<CommentHistoryItem> history;

  ItemCommentResponse({
    this.comment,
    required this.history,
  });

  factory ItemCommentResponse.fromJson(Map<String, dynamic> json) {
    return ItemCommentResponse(
      comment: json['comment'] != null
          ? ItemComment.fromJson(json['comment'] as Map<String, dynamic>)
          : null,
      history: (json['history'] as List<dynamic>?)
              ?.map((item) =>
                  CommentHistoryItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
