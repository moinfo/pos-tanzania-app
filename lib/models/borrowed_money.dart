class BorrowedMoneyItem {
  final int id;
  final double amount;
  final String date;
  final String description;

  BorrowedMoneyItem({
    required this.id,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory BorrowedMoneyItem.fromJson(Map<String, dynamic> json) {
    return BorrowedMoneyItem(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      date: json['date'] as String,
      description: (json['description'] as String?) ?? '',
    );
  }
}

class BorrowedMoneyCreate {
  final double amount;
  final String date;
  final String description;

  BorrowedMoneyCreate({
    required this.amount,
    required this.date,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'date': date,
        'description': description,
      };
}
