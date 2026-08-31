import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/data/profile_repository.dart';
import 'package:broke_no_more/data/quest_repository.dart';
import 'package:broke_no_more/data/recurring_transaction_repository.dart';
import 'package:broke_no_more/data/gamification_repair.dart';
import 'package:broke_no_more/data/transaction_repository.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// `main.dart`'s boot sequence runs three steps in a fixed order —
/// materialize due recurring transactions, expire overdue quests, then
/// repair gamification state — and each step's doc comment explains why the
/// order is load-bearing rather than incidental. Nothing previously verified
/// that claim; this proves it two ways: run the steps out of order and show
/// the result is visibly wrong.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('boot_sequence_test');
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
    await Hive.openBox<dynamic>(HiveBoxes.appState);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('expiry must run before repair — otherwise a completed budgetLimit '
      "quest's reward never reaches the profile", () async {
    final joinDate = DateTime.now().subtract(const Duration(days: 10));
    await Hive.box<UserProfile>(HiveBoxes.profile).put(
      kLocalProfileKey,
      UserProfile(
        id: kLocalProfileKey,
        name: 'Test',
        avatarId: '🦊',
        joinDate: joinDate,
      ),
    );
    // No Food transactions at all, so this trivially stays under its
    // ₹200 limit for the whole (already-elapsed) window — expiry should
    // resolve it to `completed`, per QuestRepository.expireOverdueQuests.
    await Hive.box<Quest>(HiveBoxes.quests).put(
      'q1',
      Quest(
        id: 'q1',
        title: 'Keep Food under 200',
        type: QuestType.budgetLimit,
        targetValue: 200,
        startDate: joinDate,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        xpReward: 50,
        category: 'Food',
      ),
    );

    // Correct order: main.dart's own sequence.
    await QuestRepository().expireOverdueQuests();
    await repairGamificationState();

    expect(QuestRepository().getAll().single.status, QuestStatus.completed);
    expect(
      ProfileRepository().current!.currentXP,
      50,
      reason:
          'repair ran after the quest settled, so it folded the '
          'reward in',
    );
  });

  test('running repair before expiry leaves a just-completed quest reward '
      'stranded until the next boot', () async {
    final joinDate = DateTime.now().subtract(const Duration(days: 10));
    await Hive.box<UserProfile>(HiveBoxes.profile).put(
      kLocalProfileKey,
      UserProfile(
        id: kLocalProfileKey,
        name: 'Test',
        avatarId: '🦊',
        joinDate: joinDate,
      ),
    );
    await Hive.box<Quest>(HiveBoxes.quests).put(
      'q1',
      Quest(
        id: 'q1',
        title: 'Keep Food under 200',
        type: QuestType.budgetLimit,
        targetValue: 200,
        startDate: joinDate,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        xpReward: 50,
        category: 'Food',
      ),
    );

    // Deliberately reversed order.
    await repairGamificationState();
    await QuestRepository().expireOverdueQuests();

    // Expiry itself still ran and settled the quest...
    expect(QuestRepository().getAll().single.status, QuestStatus.completed);
    // ...but repair already ran before that happened, so the profile
    // never folded the reward in. This is exactly the bug the fixed
    // ordering in main.dart exists to avoid.
    expect(ProfileRepository().current!.currentXP, 0);
  });

  test('materialization must run before repair — otherwise a due recurring '
      "transaction's day is missing from the replay", () async {
    final joinDate = DateTime.now().subtract(const Duration(days: 10));
    await Hive.box<UserProfile>(HiveBoxes.profile).put(
      kLocalProfileKey,
      UserProfile(
        id: kLocalProfileKey,
        name: 'Test',
        avatarId: '🦊',
        joinDate: joinDate,
      ),
    );
    await RecurringTransactionRepository().add(
      amount: 100,
      type: TransactionType.expense,
      category: 'Rent',
      frequency: RecurrenceFrequency.daily,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(TransactionRepository().getAll(), isEmpty);

    // Correct order.
    await RecurringTransactionRepository().materializeDue();
    expect(TransactionRepository().getAll(), isNotEmpty);

    await repairGamificationState();

    expect(
      ProfileRepository().current!.currentXP,
      greaterThan(0),
      reason:
          'repair ran after materialization, so the generated '
          'transaction was part of the replay',
    );
  });

  test('running repair before materialization leaves the profile stale '
      "relative to a transaction that already exists on disk", () async {
    final joinDate = DateTime.now().subtract(const Duration(days: 10));
    await Hive.box<UserProfile>(HiveBoxes.profile).put(
      kLocalProfileKey,
      UserProfile(
        id: kLocalProfileKey,
        name: 'Test',
        avatarId: '🦊',
        joinDate: joinDate,
      ),
    );
    await RecurringTransactionRepository().add(
      amount: 100,
      type: TransactionType.expense,
      category: 'Rent',
      frequency: RecurrenceFrequency.daily,
      startDate: DateTime.now().subtract(const Duration(days: 1)),
    );

    // Deliberately reversed order: nothing to replay yet.
    await repairGamificationState();
    expect(ProfileRepository().current!.currentXP, 0);

    await RecurringTransactionRepository().materializeDue();

    // The transaction now exists on disk, but the profile was computed
    // before it did and nothing re-ran repair afterward — the two boxes
    // now disagree, exactly the inconsistency the fixed ordering avoids.
    expect(TransactionRepository().getAll(), isNotEmpty);
    expect(ProfileRepository().current!.currentXP, 0);
  });
}
