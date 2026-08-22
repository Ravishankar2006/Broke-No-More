import 'package:flutter/material.dart';

class SpendCategory {
  const SpendCategory(this.name, this.icon);
  final String name;
  final IconData icon;
}

/// Category set for the log-transaction icon grid, resolving PRD section 11.
/// Picked for the PRD's target audience (students / young earners): covers
/// day-to-day essentials plus categories that skew young (subscriptions,
/// gig income) rather than a generic household-budget list.
const List<SpendCategory> kExpenseCategories = [
  SpendCategory('Food', Icons.restaurant),
  SpendCategory('Groceries', Icons.local_grocery_store),
  SpendCategory('Transport', Icons.directions_bus),
  SpendCategory('Shopping', Icons.shopping_bag),
  SpendCategory('Entertainment', Icons.movie),
  SpendCategory('Subscriptions', Icons.subscriptions),
  SpendCategory('Bills & Utilities', Icons.receipt_long),
  SpendCategory('Rent & Housing', Icons.home_outlined),
  SpendCategory('Health', Icons.local_hospital),
  SpendCategory('Education', Icons.school),
  SpendCategory('Other', Icons.category),
];

const List<SpendCategory> kIncomeCategories = [
  SpendCategory('Allowance', Icons.account_balance_wallet),
  SpendCategory('Salary', Icons.work),
  SpendCategory('Freelance', Icons.laptop_mac),
  SpendCategory('Gift', Icons.card_giftcard),
  SpendCategory('Other', Icons.category),
];
