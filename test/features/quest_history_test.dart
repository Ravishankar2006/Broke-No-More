import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/quests/quest_history_screen.dart';
import 'package:broke_no_more/features/quests/quests_screen.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The Quests screen's "Finished" section was hard-capped at 5 with no way
/// to reach anything older — this covers the "See all" link that opens the
/// full history instead.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quest_history_test');
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
    final profiles = await Hive.openBox<UserProfile>(HiveBoxes.profile);
    final quests = await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    final now = DateTime.now();
    await profiles.put(
      'local',
      UserProfile(
        id: 'local',
        name: 'Test',
        avatarId: '🦊',
        joinDate: now.subtract(const Duration(days: 40)),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await quests.put(
        'q$i',
        Quest(
          id: 'q$i',
          title: 'Finished quest $i',
          type: QuestType.count,
          targetValue: 5,
          currentProgress: 5,
          startDate: now.subtract(Duration(days: 20 - i)),
          endDate: now.subtract(Duration(days: 13 - i)),
          xpReward: 50,
          status: QuestStatus.completed,
        ),
      );
    }
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets(
    'Finished caps the preview at 5 and "See all" opens the full history',
    (tester) async {
      // Default 800x600 test surface leaves the Finished section below the
      // fold behind the quest hero and badge shelf.
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: AppTheme.light, home: const QuestsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // The 5 most recent (by endDate) render on the Quests screen itself
      // — the rest are reachable only through "See all".
      expect(find.text('Finished quest 7'), findsOneWidget);
      expect(find.text('Finished quest 0'), findsNothing);
      expect(find.text('See all'), findsOneWidget);

      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();

      expect(find.byType(QuestHistoryScreen), findsOneWidget);
      for (var i = 0; i < 8; i++) {
        expect(find.text('Finished quest $i'), findsOneWidget);
      }
    },
  );
}
