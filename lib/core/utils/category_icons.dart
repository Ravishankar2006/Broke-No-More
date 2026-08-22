import 'package:flutter/material.dart';

/// String -> IconData lookup for [CategoryRecord.iconId], keeping the Hive
/// model (and CategoryRecord itself) free of Flutter's IconData — same
/// pattern as badge_icons.dart for badges.
const Map<String, IconData> kCategoryIconChoices = {
  'restaurant': Icons.restaurant,
  'groceries': Icons.local_grocery_store,
  'transport': Icons.directions_bus,
  'shopping': Icons.shopping_bag,
  'movie': Icons.movie,
  'subscriptions': Icons.subscriptions,
  'bills': Icons.receipt_long,
  'home': Icons.home_outlined,
  'health': Icons.local_hospital,
  'education': Icons.school,
  'wallet': Icons.account_balance_wallet,
  'work': Icons.work,
  'laptop': Icons.laptop_mac,
  'gift': Icons.card_giftcard,
  'coffee': Icons.local_cafe,
  'fitness': Icons.fitness_center,
  'pets': Icons.pets,
  'travel': Icons.flight,
  'phone': Icons.smartphone,
  'games': Icons.sports_esports,
  'savings': Icons.savings,
  'other': Icons.category,
};

IconData categoryIcon(String iconId) =>
    kCategoryIconChoices[iconId] ?? Icons.category;
