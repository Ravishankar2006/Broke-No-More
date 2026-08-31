import 'dart:convert';
import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/utils/badge_engine.dart';
import 'package:broke_no_more/data/backup_repository.dart';
import 'package:broke_no_more/data/badge_repository.dart';
import 'package:broke_no_more/data/category_repository.dart';
import 'package:broke_no_more/data/profile_repository.dart';
import 'package:broke_no_more/data/quest_repository.dart';
import 'package:broke_no_more/data/recurring_transaction_repository.dart';
import 'package:broke_no_more/data/skipped_quest_repository.dart';
import 'package:broke_no_more/data/transaction_repository.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// End-to-end coverage for the JSON backup/restore path: seed every box
/// with real data through the real repositories, build a backup, wipe
/// everything, restore it, and check the device ends up equivalent to
/// where it started. This is the app's only disaster-recovery path for an
/// offline device, so it's worth the full round trip rather than testing
/// `backup_json.dart`'s pure functions alone.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_repository_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
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
    }
    await Hive.openBox<Transaction>(HiveBoxes.transactions);
    await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('buildBackupJson throws before a profile exists', () {
    expect(buildBackupJson, throwsStateError);
  });

  test(
    'a full backup-and-restore round trip reproduces every box\'s contents',
    () async {
      // Seed every box through its real repository, the same way the app
      // itself writes this data.
      final profile = await ProfileRepository().create(
        name: 'Riya',
        avatarId: '🦊',
        monthlyBudget: 8000,
        currencyCode: 'USD',
      );
      await ProfileRepository().save(
        profile.copyWith(currentXP: 500, currentStreak: 4),
      );

      final t1 = await TransactionRepository().add(
        amount: 250,
        type: TransactionType.expense,
        category: 'Food',
        note: 'lunch',
        timestamp: DateTime(2026, 8, 20),
      );

      final category = await CategoryRepository().add(
        name: 'Food',
        iconId: 'restaurant',
        type: TransactionType.expense,
        budget: 3000,
      );

      final rule = await RecurringTransactionRepository().add(
        amount: 15000,
        type: TransactionType.expense,
        category: 'Rent',
        frequency: RecurrenceFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );

      final candidates = QuestRepository().generateCandidates(
        [],
        currentStreak: 4,
      );
      final quest = await QuestRepository().accept(candidates.first);

      await BadgeRepository().unlock(
        const BadgeDefinition(
          id: 'first_log',
          name: 'First Step',
          description: 'Log your first transaction',
          iconId: 'flag',
          criteriaType: BadgeCriteriaType.transactionCount,
          threshold: 1,
        ),
      );

      await SkippedQuestRepository().skip('Log 3 transactions this week');

      // Build the backup, then round-trip it through JSON encoding the way
      // the real export/import flow does (file -> string -> decode).
      final json = buildBackupJson();
      final roundTripped = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      final data = backupFromJson(roundTripped);

      // Wipe every box — simulates a fresh install / a different device.
      await TransactionRepository().clear();
      await ProfileRepository().delete();
      await QuestRepository().clear();
      await BadgeRepository().clear();
      await CategoryRepository().clear();
      await RecurringTransactionRepository().clear();
      await SkippedQuestRepository().clear();

      expect(ProfileRepository().hasProfile, isFalse);
      expect(TransactionRepository().getAll(), isEmpty);

      await restoreBackup(data);

      final restoredProfile = ProfileRepository().current!;
      expect(restoredProfile.name, 'Riya');
      expect(restoredProfile.currentXP, 500);
      expect(restoredProfile.currentStreak, 4);
      expect(restoredProfile.monthlyBudget, 8000);
      expect(restoredProfile.currencyCode, 'USD');

      final restoredTransaction = TransactionRepository().getById(t1.id);
      expect(restoredTransaction, isNotNull);
      expect(restoredTransaction!.amount, 250);
      expect(restoredTransaction.category, 'Food');
      expect(restoredTransaction.note, 'lunch');

      final restoredCategories = [
        ...CategoryRepository().getAll(TransactionType.expense),
        ...CategoryRepository().getAll(TransactionType.income),
      ];
      expect(
        restoredCategories.any(
          (c) => c.name == category.name && c.budget == 3000,
        ),
        isTrue,
      );

      final restoredRules = RecurringTransactionRepository().getAll();
      expect(restoredRules.any((r) => r.id == rule.id), isTrue);

      final restoredQuests = QuestRepository().getAll();
      expect(restoredQuests.any((q) => q.id == quest.id), isTrue);

      final restoredBadges = BadgeRepository().getAll();
      expect(restoredBadges.any((b) => b.id == 'first_log'), isTrue);

      expect(
        SkippedQuestRepository().titles,
        contains('Log 3 transactions this week'),
      );
    },
  );

  test('restoring preserves seed-category tracking so defaults are not '
      'resurrected or duplicated', () async {
    await ProfileRepository().create(name: 'Test', avatarId: '🦊');
    // Seed the way initHive does, so kSeededCategoryIdsKey is populated.
    final categoriesBox = Hive.box<CategoryRecord>(HiveBoxes.categories);
    await categoriesBox.add(
      CategoryRecord(
        id: 'seed-expense-0',
        name: 'Food',
        iconId: 'restaurant',
        type: TransactionType.expense,
        sortOrder: 0,
      ),
    );
    await Hive.box<dynamic>(
      HiveBoxes.appState,
    ).put(kSeededCategoryIdsKey, ['seed-expense-0']);

    final json = buildBackupJson();
    final data = backupFromJson(json);

    await CategoryRepository().clear();
    await Hive.box<dynamic>(HiveBoxes.appState).delete(kSeededCategoryIdsKey);

    await restoreBackup(data);

    final seededIds = (Hive.box<dynamic>(
      HiveBoxes.appState,
    ).get(kSeededCategoryIdsKey) as List?)?.cast<String>();
    expect(seededIds, contains('seed-expense-0'));
  });
}
