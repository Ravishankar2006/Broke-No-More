import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/providers/category_provider.dart';
import 'package:broke_no_more/providers/profile_provider.dart';
import 'package:broke_no_more/providers/quest_provider.dart';
import 'package:broke_no_more/providers/recurring_transaction_provider.dart';
import 'package:broke_no_more/providers/theme_provider.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers the providers previously exercised only incidentally through
/// screen smoke tests — `quest_`, `category_`, `theme_` and
/// `recurring_transaction_provider`. Only `xp_engine_provider` had direct
/// provider-level tests before this.
void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('provider_test');
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

    container = ProviderContainer();
    await container
        .read(profileProvider.notifier)
        .createProfile(name: 'Test', avatarId: '🦊');
  });

  tearDown(() async {
    container.dispose();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('category providers', () {
    test('expenseCategoriesProvider.refresh picks up a row added directly '
        'through the repository', () async {
      expect(container.read(expenseCategoriesProvider), isEmpty);

      await container
          .read(categoryRepositoryProvider)
          .add(
            name: 'Food',
            iconId: 'restaurant',
            type: TransactionType.expense,
          );
      container.read(expenseCategoriesProvider.notifier).refresh();

      expect(container.read(expenseCategoriesProvider).map((c) => c.name), [
        'Food',
      ]);
    });

    test('categoryIconIdsProvider maps both expense and income category '
        'names to their icon ids', () async {
      await container
          .read(categoryRepositoryProvider)
          .add(
            name: 'Food',
            iconId: 'restaurant',
            type: TransactionType.expense,
          );
      await container
          .read(categoryRepositoryProvider)
          .add(name: 'Salary', iconId: 'work', type: TransactionType.income);
      container.read(expenseCategoriesProvider.notifier).refresh();
      container.read(incomeCategoriesProvider.notifier).refresh();

      final iconIds = container.read(categoryIconIdsProvider);
      expect(iconIds['Food'], 'restaurant');
      expect(iconIds['Salary'], 'work');
      expect(iconIds['Unknown'], isNull);
    });
  });

  group('themeModeProvider', () {
    test('defaults to system when nothing is stored', () {
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('setMode persists across a fresh read of the same box, simulating '
        'a restart', () async {
      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // A new container reading the same on-disk box, rather than the same
      // in-memory notifier state, is what actually proves persistence.
      final restarted = ProviderContainer();
      expect(restarted.read(themeModeProvider), ThemeMode.dark);
      restarted.dispose();
    });
  });

  group('recurringTransactionsProvider', () {
    test(
      'refresh picks up a rule added directly through the repository',
      () async {
        expect(container.read(recurringTransactionsProvider), isEmpty);

        await container
            .read(recurringTransactionRepositoryProvider)
            .add(
              amount: 500,
              type: TransactionType.expense,
              category: 'Rent',
              frequency: RecurrenceFrequency.monthly,
              startDate: DateTime.now(),
            );
        container.read(recurringTransactionsProvider.notifier).refresh();

        expect(container.read(recurringTransactionsProvider), hasLength(1));
      },
    );
  });

  group('quest providers', () {
    test(
      'questsProvider.accept persists the candidate and refreshes state',
      () async {
        expect(container.read(questsProvider), isEmpty);

        final candidates = container.read(questCandidatesProvider);
        expect(candidates, isNotEmpty);

        await container.read(questsProvider.notifier).accept(candidates.first);

        expect(container.read(questsProvider), hasLength(1));
        expect(container.read(activeQuestsProvider), hasLength(1));
      },
    );

    test('accepting a candidate excludes it from future suggestions', () async {
      final before = container.read(questCandidatesProvider);
      expect(before, isNotEmpty);
      final accepted = before.first;

      await container.read(questsProvider.notifier).accept(accepted);

      final after = container.read(questCandidatesProvider);
      expect(
        after.map((c) => (c.type, c.category)),
        isNot(contains((accepted.type, accepted.category))),
      );
    });

    test('visibleQuestCandidatesProvider hides a skipped title, and '
        'unskip brings it back', () async {
      final candidates = container.read(questCandidatesProvider);
      expect(candidates, isNotEmpty);
      final target = candidates.first;

      expect(
        container.read(visibleQuestCandidatesProvider).map((c) => c.title),
        contains(target.title),
      );

      await container.read(skippedQuestsProvider.notifier).skip(target.title);

      expect(
        container.read(visibleQuestCandidatesProvider).map((c) => c.title),
        isNot(contains(target.title)),
      );
      // The underlying candidate list is untouched — only the visible
      // (filtered) view changes.
      expect(
        container.read(questCandidatesProvider).map((c) => c.title),
        contains(target.title),
      );

      await container.read(skippedQuestsProvider.notifier).unskip(target.title);

      expect(
        container.read(visibleQuestCandidatesProvider).map((c) => c.title),
        contains(target.title),
      );
    });

    test('a skip persists across a restart', () async {
      final candidates = container.read(questCandidatesProvider);
      final target = candidates.first;
      await container.read(skippedQuestsProvider.notifier).skip(target.title);

      final restarted = ProviderContainer();
      expect(restarted.read(skippedQuestsProvider), contains(target.title));
      restarted.dispose();
    });
  });
}
