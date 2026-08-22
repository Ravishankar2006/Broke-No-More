import 'package:flutter/material.dart';

class SpendCategory {
  const SpendCategory(this.name, this.icon);
  final String name;
  final IconData icon;
}

/// Placeholder category set for the log-transaction icon grid — PRD
/// section 11 lists the exact set as still an open decision.
const List<SpendCategory> kExpenseCategories = [
  SpendCategory('Food', Icons.restaurant),
  SpendCategory('Transport', Icons.directions_bus),
  SpendCategory('Shopping', Icons.shopping_bag),
  SpendCategory('Entertainment', Icons.movie),
  SpendCategory('Bills', Icons.receipt_long),
  SpendCategory('Groceries', Icons.local_grocery_store),
  SpendCategory('Health', Icons.local_hospital),
  SpendCategory('Education', Icons.school),
  SpendCategory('Other', Icons.category),
];

const List<SpendCategory> kIncomeCategories = [
  SpendCategory('Allowance', Icons.account_balance_wallet),
  SpendCategory('Salary', Icons.work),
  SpendCategory('Gift', Icons.card_giftcard),
  SpendCategory('Other', Icons.category),
];
