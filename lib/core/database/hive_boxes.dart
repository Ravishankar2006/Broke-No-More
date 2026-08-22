import 'package:hive_flutter/hive_flutter.dart';

import '../../models/badge.dart';
import '../../models/quest.dart';
import '../../models/transaction.dart';
import '../../models/user_profile.dart';

/// Box names, centralized so repositories never hardcode strings.
abstract class HiveBoxes {
  static const String transactions = 'transactions';
  static const String profile = 'profile';
  static const String quests = 'quests';
  static const String badges = 'badges';
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

  await Future.wait([
    Hive.openBox<Transaction>(HiveBoxes.transactions),
    Hive.openBox<UserProfile>(HiveBoxes.profile),
    Hive.openBox<Quest>(HiveBoxes.quests),
    Hive.openBox<Badge>(HiveBoxes.badges),
  ]);
}
