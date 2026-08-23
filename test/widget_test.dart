import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/main.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('broke_no_more_test');
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
    }
    await Hive.openBox<Transaction>(HiveBoxes.transactions);
    await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    final categoryBox =
        await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await categoryBox.add(CategoryRecord(
      id: 'test-food',
      name: 'Food',
      iconId: 'restaurant',
      type: TransactionType.expense,
      sortOrder: 0,
    ));
    await categoryBox.add(CategoryRecord(
      id: 'test-allowance',
      name: 'Allowance',
      iconId: 'wallet',
      type: TransactionType.income,
      sortOrder: 0,
    ));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('shows onboarding when no local profile exists yet',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrokeNoMoreApp()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Broke No More'), findsOneWidget);
  });

  testWidgets(
    'completing onboarding lands on the home dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BrokeNoMoreApp()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Riya');
      await tester.pump();
      // Drop focus so the cursor stops blinking — a focused TextField
      // schedules frames forever and would make pumpAndSettle() hang.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.ensureVisible(find.text('Get started'));
      await tester.pump();

      // Profile creation goes through Hive, which does real dart:io file
      // writes. Those never resolve on flutter_test's fake clock unless the
      // awaiting call happens inside runAsync — otherwise the tap's
      // onPressed future just hangs forever and so does tearDown after it.
      await tester.runAsync(() async {
        await tester.tap(find.text('Get started'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      // Home staggers its card entrance with flutter_animate, which implements
      // per-item delay as a Timer. Pump past the longest stagger so none are
      // left pending when the test ends.
      await tester.pump(const Duration(milliseconds: 600));

      // The home header now shows a time-of-day greeting above the name
      // rather than a single "Hey, {name}" string. Assert on the name, which
      // is the part that doesn't depend on when the suite runs.
      expect(find.text('Riya'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
