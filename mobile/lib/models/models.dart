class Account {
  final int id;
  final String name;
  final String type;
  final String currency;
  final double balance;
  final String? bankId;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.balance,
    this.bankId,
    required this.createdAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      currency: json['currency'] as String,
      balance: (json['balance'] as num).toDouble(),
      bankId: json['bank_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Category {
  final int id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final double budgetLimit;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.budgetLimit,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      budgetLimit: (json['budget_limit'] as num).toDouble(),
    );
  }
}

class Transaction {
  final int id;
  final int accountId;
  final int? categoryId;
  final double amount;
  final String type;
  final String description;
  final String date;
  final String? bankTransactionId;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.accountId,
    this.categoryId,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    this.bankTransactionId,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      accountId: json['account_id'] as int,
      categoryId: json['category_id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      description: json['description'] as String,
      date: json['date'] as String,
      bankTransactionId: json['bank_transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class Budget {
  final int id;
  final int categoryId;
  final int month;
  final int year;
  final double limitAmount;
  final double spentAmount;

  Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.year,
    required this.limitAmount,
    required this.spentAmount,
  });

  double get remainingAmount => limitAmount - spentAmount;
  double get progress => limitAmount > 0 ? spentAmount / limitAmount : 0;

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      month: json['month'] as int,
      year: json['year'] as int,
      limitAmount: (json['limit_amount'] as num).toDouble(),
      spentAmount: (json['spent_amount'] as num).toDouble(),
    );
  }
}

class MonthlyBalanceReport {
  final int month;
  final int year;
  final double income;
  final double expenses;
  final double balance;

  MonthlyBalanceReport({
    required this.month,
    required this.year,
    required this.income,
    required this.expenses,
    required this.balance,
  });

  factory MonthlyBalanceReport.fromJson(Map<String, dynamic> json) {
    return MonthlyBalanceReport(
      month: json['month'] as int,
      year: json['year'] as int,
      income: (json['income'] as num).toDouble(),
      expenses: (json['expenses'] as num).toDouble(),
      balance: (json['balance'] as num).toDouble(),
    );
  }
}

class SavingsGoal {
  final int id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? targetDate;
  final DateTime createdAt;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.createdAt,
  });

  double get progress => targetAmount > 0 ? currentAmount / targetAmount : 0;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as int,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      targetDate: json['target_date'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
