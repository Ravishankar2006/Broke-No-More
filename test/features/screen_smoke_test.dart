import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/home/home_screen.dart';
import 'package:broke_no_more/features/insights/insights_screen.dart';
import 'package:broke_no_more/features/log_transaction/log_transaction_sheet.dart';
import 'package:broke_no_more/features/onboarding/onboarding_screen.dart';
import 'package:broke_no_more/features/profile/category_management_screen.dart';
import 'package:broke_no_more/features/profile/profile_screen.dart';
import 'package:broke_no_more/features/quests/quests_screen.dart';
import 'package:broke_no_more/features/transactions/transaction_history_screen.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:broke_no_more/models/badge.dart';

/// Renders every screen at the sizes and text scales most likely to break the
/// revamped layouts.
///
/// A `RenderFlex overflowed` is reported through FlutterError, which the test
/// binding turns into a failure — so simply pumping each screen is a real
/// assertion that it fits. The log sheet's category area and the bottom nav bar
/// are the two places most at risk, since both pack fixed-size content into a
/// constrained row.
///
/// Uses timed `pump`s rather than `pumpAndSettle` throughout: Home's streak
/// hero runs a looping Lottie, so the tree never reaches a settled state.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bnm_smoke');
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

    final transactions =
        await Hive.openBox<Transaction>(HiveBoxes.transactions);
    final profiles = await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    final categories =
        await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    // A realistic category set — a short list would hide grid overflow.
    const expenseCategories = [
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
    var order = 0;
    for (final (name, iconId) in expenseCategories) {
      await categories.add(CategoryRecord(
        id: 'e$order',
        name: name,
        iconId: iconId,
        type: TransactionType.expense,
        sortOrder: order++,
      ));
    }
    await categories.add(CategoryRecord(
      id: 'i0',
      name: 'Allowance',
      iconId: 'wallet',
      type: TransactionType.income,
      sortOrder: 0,
    ));

    final now = DateTime.now();
    await profiles.put(
      'local',
      UserProfile(
        id: 'local',
        // Long enough to exercise ellipsis in the header.
        name: 'Ravishankar Iyer',
        avatarId: '🦊',
        joinDate: now.subtract(const Duration(days: 40)),
        currentXP: 640,
        level: 4,
        currentStreak: 6,
        longestStreak: 14,
        monthlyBudget: 8000,
      ),
    );

    for (var i = 0; i < 12; i++) {
      final day = now.subtract(Duration(days: i));
      await transactions.put(
        't$i',
        Transaction(
          id: 't$i',
          // A large amount, to stress currency formatting width.
          amount: i.isEven ? 1249.75 : 180,
          type: i % 5 == 0 ? TransactionType.income : TransactionType.expense,
          category: expenseCategories[i % expenseCategories.length].$1,
          note: i.isEven ? 'A fairly long note about this purchase' : null,
          timestamp: day,
          loggedAt: day,
          isQuickLog: i.isEven,
          xpAwarded: 10,
        ),
      );
    }
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    required double textScale,
    required Brightness brightness,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(textScale),
            ),
            child: screen,
          ),
        ),
      ),
    );
    // Let entrance animations and asset loads progress without waiting for a
    // settled tree, which a looping animation never reaches.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  // 320x640 is about the smallest phone still in use; 412x915 is a typical
  // modern Android viewport.
  const sizes = <String, Size>{
    'small 320x640': Size(320, 640),
    'typical 412x915': Size(412, 915),
  };

  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Insights': () => const InsightsScreen(),
    'Quests': () => const QuestsScreen(),
    'Profile': () => const ProfileScreen(),
    'History': () => const TransactionHistoryScreen(),
    'Onboarding': () => const OnboardingScreen(),
    'Categories': () => const CategoryManagementScreen(),
    'Log sheet': () => const Scaffold(body: LogTransactionSheet()),
  };

  for (final sizeEntry in sizes.entries) {
    for (final screenEntry in screens.entries) {
      testWidgets(
        '${screenEntry.key} lays out on ${sizeEntry.key}',
        (tester) async {
          await pumpScreen(
            tester,
            screenEntry.value(),
            size: sizeEntry.value,
            textScale: 1.0,
            brightness: Brightness.light,
          );
        },
      );
    }
  }

  // Large text is where fixed-height rows and chips typically break.
  for (final screenEntry in screens.entries) {
    testWidgets(
      '${screenEntry.key} lays out at 1.5x text scale',
      (tester) async {
        await pumpScreen(
          tester,
          screenEntry.value(),
          size: const Size(412, 915),
          textScale: 1.5,
          brightness: Brightness.light,
        );
      },
    );
  }

  // Dark mode exercises the second half of every ThemeExtension token,
  // including the new shadow and gradient treatments.
  for (final screenEntry in screens.entries) {
    testWidgets(
      '${screenEntry.key} lays out in dark mode',
      (tester) async {
        await pumpScreen(
          tester,
          screenEntry.value(),
          size: const Size(412, 915),
          textScale: 1.0,
          brightness: Brightness.dark,
        );
      },
    );
  }

  testWidgets('Home renders its first-run empty state with no transactions',
      (tester) async {
    // Hive.clear() does a real dart:io write, which never resolves on
    // flutter_test's fake clock unless it runs inside runAsync.
    await tester.runAsync(() async {
      await Hive.box<Transaction>(HiveBoxes.transactions).clear();
    });

    await pumpScreen(
      tester,
      const HomeScreen(),
      size: const Size(412, 915),
      textScale: 1.0,
      brightness: Brightness.light,
    );

    expect(find.text('Log your first transaction'), findsOneWidget);
  });
}
