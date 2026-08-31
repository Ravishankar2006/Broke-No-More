import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/home/home_shell.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/shared_widgets/celebration_effects.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers the Phase 2.3 accessibility fixes: the bottom nav previously had no
/// button/selected semantics at all, and the celebration effects (confetti,
/// bounce, looping Lottie, skeleton shimmer) always played regardless of the
/// OS "remove animations" setting.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('accessibility_test');
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
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    await profiles.put(
      'local',
      UserProfile(
        id: 'local',
        name: 'Test',
        avatarId: '🦊',
        joinDate: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('bottom nav buttons expose button role and selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const HomeShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // IndexedStack keeps all four tabs mounted, so a plain find.text('Insights')
    // also matches that screen's own AppBar title — scope to the nav bar.
    Finder inNav(String label) => find.descendant(
      of: find.byType(BottomAppBar),
      matching: find.text(label, skipOffstage: false),
    );

    final home = tester.getSemantics(inNav('Home'));
    expect(home.flagsCollection.isButton, isTrue);
    expect(home.flagsCollection.isSelected.toBoolOrNull(), isTrue);

    final insights = tester.getSemantics(inNav('Insights'));
    expect(insights.flagsCollection.isButton, isTrue);
    expect(insights.flagsCollection.isSelected.toBoolOrNull(), isFalse);

    handle.dispose();
  });

  testWidgets(
    'confetti and looping Lottie are suppressed when animations are disabled',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: CelebrationAnimation(
                asset: CelebrationAssets.streakFlame,
                fallbackIcon: Icons.local_fire_department,
                repeat: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Falls straight to the fallback icon instead of driving the Lottie
      // controller, since a looping animation is exactly what "remove
      // animations" is meant to suppress.
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    },
  );

  testWidgets(
    'CelebrationBurst renders its child without confetti when animations are disabled',
    (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: CelebrationBurst(child: Text('celebration content')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('celebration content'), findsOneWidget);
      // CelebrationBurst normally wraps its child in a Stack + ConfettiWidget;
      // with animations disabled it should hand back the child untouched.
      expect(find.byType(ConfettiWidget), findsNothing);
    },
  );
}
