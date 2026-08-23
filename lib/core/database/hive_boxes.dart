import 'package:hive_flutter/hive_flutter.dart';

import '../../models/badge.dart';
import '../../models/category_record.dart';
import '../../models/quest.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../models/user_profile.dart';

/// Box names, centralized so repositories never hardcode strings.
abstract class HiveBoxes {
  static const String transactions = 'transactions';
  static const String profile = 'profile';
  static const String quests = 'quests';
  static const String badges = 'badges';
  static const String categories = 'categories';
  static const String recurringTransactions = 'recurring_transactions';

  /// Untyped key/value box for small bits of app state that don't warrant a
  /// model — currently the set of quest titles the user has skipped.
  static const String appState = 'app_state';
}

/// Registers all Hive adapters and opens every box used by the app.
/// Must run once, before `runApp`.
Future<void> initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(TransactionTypeAdapter());
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(QuestTypeAdapter());
  Hive.registerAdapter(QuestStatusAdapter());
  Hive.registerAdapter(QuestAdapter());
  Hive.registerAdapter(BadgeAdapter());
  Hive.registerAdapter(CategoryRecordAdapter());
  Hive.registerAdapter(RecurrenceFrequencyAdapter());
  Hive.registerAdapter(RecurringTransactionAdapter());

  await Future.wait([
    Hive.openBox<Transaction>(HiveBoxes.transactions),
    Hive.openBox<UserProfile>(HiveBoxes.profile),
    Hive.openBox<Quest>(HiveBoxes.quests),
    Hive.openBox<Badge>(HiveBoxes.badges),
    Hive.openBox<CategoryRecord>(HiveBoxes.categories),
    Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions),
    Hive.openBox<dynamic>(HiveBoxes.appState),
  ]);

  await _seedDefaultCategoriesIfEmpty();
}

/// First-run seed so the log-transaction grid isn't empty before the user
/// has ever touched Profile > Manage categories. Mirrors the category set
/// finalized for the log-transaction grid (PRD section 11).
Future<void> _seedDefaultCategoriesIfEmpty() async {
  final box = Hive.box<CategoryRecord>(HiveBoxes.categories);
  if (box.isNotEmpty) return;

  const expenseDefaults = [
    ('Food', 'restaurant'),
    ('Groceries', 'groceries'),
    ('Transport', 'transport'),
    ('Shopping', 'shopping'),
    ('Entertainment', 'movie'),
    ('Subscriptions', 'subscriptions'),
    ('Bills & Utilities', 'bills'),
    ('Rent & Housing', 'home'),
    ('Health', 'health'),
    ('Education', 'education'),
    ('Other', 'other'),
  ];
  const incomeDefaults = [
    ('Allowance', 'wallet'),
    ('Salary', 'work'),
    ('Freelance', 'laptop'),
    ('Gift', 'gift'),
    ('Other', 'other'),
  ];

  var order = 0;
  for (final (name, iconId) in expenseDefaults) {
    await box.add(CategoryRecord(
      id: 'seed-expense-$order',
      name: name,
      iconId: iconId,
      type: TransactionType.expense,
      sortOrder: order++,
    ));
  }
  order = 0;
  for (final (name, iconId) in incomeDefaults) {
    await box.add(CategoryRecord(
      id: 'seed-income-$order',
      name: name,
      iconId: iconId,
      type: TransactionType.income,
      sortOrder: order++,
    ));
  }
}
