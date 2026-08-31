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
  /// model — currently the set of quest titles the user has skipped and the
  /// schema version stamp ([kSchemaVersionKey]).
  static const String appState = 'app_state';
}

/// Hive `typeId`s in use, listed so a new `@HiveType` can pick the next free
/// one without colliding. Never reuse or renumber an id already shipped —
/// existing installs have data tagged with these on disk.
///
/// 0: TransactionType (enum)   5: Quest
/// 1: Transaction              6: Badge
/// 2: UserProfile              7: CategoryRecord
/// 3: QuestType (enum)         8: RecurrenceFrequency (enum)
/// 4: QuestStatus (enum)       9: RecurringTransaction
///
/// Next free id: 10.
const int kNextFreeHiveTypeId = 10;

/// Key in [HiveBoxes.appState] holding the schema version this install's
/// data was last migrated to. Absent (pre-versioning installs) is treated
/// as version 1.
const String kSchemaVersionKey = 'schemaVersion';

/// Current schema version. Bump this and add a branch in [_migrate] whenever
/// a change to a model's `@HiveField`s needs on-disk data to be transformed
/// (as opposed to a purely additive nullable field, which Hive already
/// deserializes fine on its own — see [UserProfile.remindersEnabled] and
/// [Transaction.xpAwarded] for that pattern).
const int kCurrentSchemaVersion = 1;

/// Registers all Hive adapters and opens every box used by the app.
/// Must run once, before `runApp`.
Future<void> initHive() async {
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(TransactionTypeAdapter().typeId)) {
    Hive.registerAdapter(TransactionTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(TransactionAdapter().typeId)) {
    Hive.registerAdapter(TransactionAdapter());
  }
  if (!Hive.isAdapterRegistered(UserProfileAdapter().typeId)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(QuestTypeAdapter().typeId)) {
    Hive.registerAdapter(QuestTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(QuestStatusAdapter().typeId)) {
    Hive.registerAdapter(QuestStatusAdapter());
  }
  if (!Hive.isAdapterRegistered(QuestAdapter().typeId)) {
    Hive.registerAdapter(QuestAdapter());
  }
  if (!Hive.isAdapterRegistered(BadgeAdapter().typeId)) {
    Hive.registerAdapter(BadgeAdapter());
  }
  if (!Hive.isAdapterRegistered(CategoryRecordAdapter().typeId)) {
    Hive.registerAdapter(CategoryRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(RecurrenceFrequencyAdapter().typeId)) {
    Hive.registerAdapter(RecurrenceFrequencyAdapter());
  }
  if (!Hive.isAdapterRegistered(RecurringTransactionAdapter().typeId)) {
    Hive.registerAdapter(RecurringTransactionAdapter());
  }

  await Future.wait([
    Hive.openBox<Transaction>(HiveBoxes.transactions),
    Hive.openBox<UserProfile>(HiveBoxes.profile),
    Hive.openBox<Quest>(HiveBoxes.quests),
    Hive.openBox<Badge>(HiveBoxes.badges),
    Hive.openBox<CategoryRecord>(HiveBoxes.categories),
    Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions),
    Hive.openBox<dynamic>(HiveBoxes.appState),
  ]);

  await _migrate();
  await _seedDefaultCategoriesIfEmpty();
}

/// Runs any migrations needed to bring on-disk data from its stamped
/// version up to [kCurrentSchemaVersion], then updates the stamp.
///
/// There are no migrations yet (schema has only ever been version 1), so
/// this just establishes the stamp for installs that predate it. When a
/// future model change needs one, add `if (from < N) { ... }` steps here,
/// each transforming box contents in place before the stamp advances.
Future<void> _migrate() async {
  final box = Hive.box<dynamic>(HiveBoxes.appState);
  final from = (box.get(kSchemaVersionKey) as int?) ?? 1;
  if (from == kCurrentSchemaVersion) return;

  // Future migration steps go here, e.g.:
  // if (from < 2) { ... }

  await box.put(kSchemaVersionKey, kCurrentSchemaVersion);
}

/// Key in [HiveBoxes.appState] holding the `List<String>` of seed category
/// ids ever inserted by [_seedDefaultCategoriesIfEmpty], so a category the
/// user deliberately deleted is never resurrected — see that function's doc
/// comment.
const String kSeededCategoryIdsKey = 'seededCategoryIds';

/// First-run seed so the log-transaction grid isn't empty before the user
/// has ever touched Profile > Manage categories. Mirrors the category set
/// finalized for the log-transaction grid (PRD section 11).
///
/// Tracks which seed ids have ever been inserted (in [kSeededCategoryIdsKey],
/// not by checking current box contents), and adds only the ones missing
/// from that record. Checking the box's current contents instead would get
/// this wrong in both directions: a user who deletes a default category
/// would find it reappear on the next launch, while — under the old
/// `box.isNotEmpty` all-or-nothing guard this replaces — a user who deleted
/// even one category would never receive defaults added in a later release.
Future<void> _seedDefaultCategoriesIfEmpty() async {
  final categoryBox = Hive.box<CategoryRecord>(HiveBoxes.categories);
  final appStateBox = Hive.box<dynamic>(HiveBoxes.appState);
  final alreadySeeded =
      (appStateBox.get(kSeededCategoryIdsKey) as List?)
          ?.cast<String>()
          .toSet() ??
      <String>{};

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

  final newlySeeded = <String>[];

  for (var order = 0; order < expenseDefaults.length; order++) {
    final id = 'seed-expense-$order';
    if (alreadySeeded.contains(id)) continue;
    final (name, iconId) = expenseDefaults[order];
    await categoryBox.add(
      CategoryRecord(
        id: id,
        name: name,
        iconId: iconId,
        type: TransactionType.expense,
        sortOrder: order,
      ),
    );
    newlySeeded.add(id);
  }
  for (var order = 0; order < incomeDefaults.length; order++) {
    final id = 'seed-income-$order';
    if (alreadySeeded.contains(id)) continue;
    final (name, iconId) = incomeDefaults[order];
    await categoryBox.add(
      CategoryRecord(
        id: id,
        name: name,
        iconId: iconId,
        type: TransactionType.income,
        sortOrder: order,
      ),
    );
    newlySeeded.add(id);
  }

  if (newlySeeded.isNotEmpty) {
    await appStateBox.put(kSeededCategoryIdsKey, [
      ...alreadySeeded,
      ...newlySeeded,
    ]);
  }
}

/// Erases every box's contents — Settings > Reset app. There is no way
/// back from this short of restoring a JSON backup made beforehand, so the
/// caller is responsible for a serious confirmation before reaching here.
///
/// Re-seeds default categories immediately after clearing (rather than
/// waiting for the next cold start to run [_seedDefaultCategoriesIfEmpty]
/// via [initHive]) so the log-transaction grid isn't empty if the app
/// isn't restarted — [HomeShell]/[OnboardingScreen] swap reactively once
/// callers invalidate `profileProvider`.
Future<void> resetAllData() async {
  await Future.wait([
    Hive.box<Transaction>(HiveBoxes.transactions).clear(),
    Hive.box<UserProfile>(HiveBoxes.profile).clear(),
    Hive.box<Quest>(HiveBoxes.quests).clear(),
    Hive.box<Badge>(HiveBoxes.badges).clear(),
    Hive.box<CategoryRecord>(HiveBoxes.categories).clear(),
    Hive.box<RecurringTransaction>(HiveBoxes.recurringTransactions).clear(),
    Hive.box<dynamic>(HiveBoxes.appState).clear(),
  ]);
  await _seedDefaultCategoriesIfEmpty();
}
