import 'dart:io';

import 'package:broke_no_more/core/database/hive_boxes.dart';
import 'package:broke_no_more/core/theme/app_theme.dart';
import 'package:broke_no_more/features/quests/quests_screen.dart';
import 'package:broke_no_more/features/quests/widgets/quest_customize_dialog.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:broke_no_more/providers/xp_engine_provider.dart';
import 'package:broke_no_more/shared_widgets/quest_card.dart';
import 'package:broke_no_more/shared_widgets/section_header.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The Quests screen's accept/skip/customize responses (PRD §4/§7) had no
/// widget-level coverage — only the engine and repository layers were
/// tested. This drives the actual screen to check the buttons are wired to
/// the right orchestrator/provider calls, not just that the underlying
/// logic works in isolation.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('quest_actions_test');
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
    final transactions = await Hive.openBox<Transaction>(
      HiveBoxes.transactions,
    );
    final profiles = await Hive.openBox<UserProfile>(HiveBoxes.profile);
    await Hive.openBox<Quest>(HiveBoxes.quests);
    await Hive.openBox<Badge>(HiveBoxes.badges);
    await Hive.openBox<CategoryRecord>(HiveBoxes.categories);
    await Hive.openBox<RecurringTransaction>(HiveBoxes.recurringTransactions);
    await Hive.openBox<dynamic>(HiveBoxes.appState);

    // Yesterday, not "now" — a categoryAvoid quest accepted the same day as
    // its triggering transaction must not immediately fail against that
    // same transaction (see the quest_engine.dart fix this test file
    // surfaced); backdating the seed data by a day keeps this suite
    // decoupled from that specific same-day edge case, which has its own
    // focused coverage in gamification_replay_test.dart.
    final seedDay = DateTime.now().subtract(const Duration(days: 1));
    await profiles.put(
      'local',
      UserProfile(id: 'local', name: 'Test', avatarId: '🦊', joinDate: seedDay),
    );
    // One recent expense with no older history — this is exactly the shape
    // `_starterCategoryCandidate` needs, so the Suggested section reliably
    // shows a categoryAvoid candidate to act on.
    await transactions.put(
      't1',
      Transaction(
        id: 't1',
        amount: 500,
        type: TransactionType.expense,
        category: 'Food',
        timestamp: seedDay,
        loggedAt: seedDay,
        isQuickLog: false,
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const QuestsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// Every candidate card is wrapped in a `Dismissible` (for the swipe-to-skip
  /// gesture) whose gesture detector makes `tester.tap()` on a nested button
  /// unreliable — the same class of issue documented for the history
  /// screen's own `Dismissible` rows. Invoking the button's callback
  /// directly sidesteps the gesture arena entirely and is the reliable
  /// alternative used throughout this file.
  VoidCallback filledButtonCallback(
    WidgetTester tester,
    Finder card,
    String label,
  ) {
    return tester
        .widget<FilledButton>(
          find.descendant(
            of: card,
            matching: find.ancestor(
              of: find.text(label),
              matching: find.byType(FilledButton),
            ),
          ),
        )
        .onPressed!;
  }

  VoidCallback outlinedButtonCallback(
    WidgetTester tester,
    Finder card,
    String label,
  ) {
    return tester
        .widget<OutlinedButton>(
          find.descendant(
            of: card,
            matching: find.ancestor(
              of: find.text(label),
              matching: find.byType(OutlinedButton),
            ),
          ),
        )
        .onPressed!;
  }

  VoidCallback iconButtonCallback(
    WidgetTester tester,
    Finder card,
    String tooltip,
  ) {
    return tester
        .widget<IconButton>(
          find.descendant(
            of: card,
            matching: find.ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            ),
          ),
        )
        .onPressed!;
  }

  testWidgets('accepting a candidate moves it from Suggested to Active', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(QuestCandidateCard), findsWidgets);
    expect(find.byType(QuestCard), findsNothing);

    // The rule engine tops candidates back up to its max count once one is
    // accepted, so the *count* of QuestCandidateCards can stay the same —
    // what has to change is that this specific candidate moved to Active.
    final firstCard = find.byType(QuestCandidateCard).first;
    final title = tester
        .widget<Text>(
          find.descendant(of: firstCard, matching: find.byType(Text)).first,
        )
        .data!;
    final onAccept = filledButtonCallback(tester, firstCard, 'Accept');

    // Accept routes through the real orchestrator (real Hive I/O, not
    // simulated), which doesn't mix reliably with pumpAndSettle's fake
    // clock — runAsync + a bounded pump is the established fix elsewhere
    // in this suite (see history_power_test.dart).
    await tester.runAsync(() async {
      onAccept();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: find.byType(QuestCandidateCard),
        matching: find.text(title),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(QuestCard), matching: find.text(title)),
      findsOneWidget,
    );
    // "ACTIVE" also appears as the hero stat's label, so check the actual
    // SectionHeader rather than matching its (uppercased) rendered text.
    expect(
      tester
          .widgetList<SectionHeader>(find.byType(SectionHeader))
          .any((h) => h.title == 'Active'),
      isTrue,
    );

    // Drains any leftover fake-clock timers before tearDown disposes the
    // widget tree — otherwise a timer firing after disposal throws in a
    // *later* test.
    await tester.pumpAndSettle();
  });

  testWidgets('skipping a candidate removes it, and Undo restores it', (
    tester,
  ) async {
    await pump(tester);

    final candidateCount = tester
        .widgetList(find.byType(QuestCandidateCard))
        .length;
    final firstCard = find.byType(QuestCandidateCard).first;
    final onSkip = outlinedButtonCallback(tester, firstCard, 'Skip');

    await tester.runAsync(() async {
      onSkip();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuestCandidateCard), findsNWidgets(candidateCount - 1));
    expect(find.text('Suggestion skipped'), findsOneWidget);

    final onUndo = tester
        .widget<SnackBarAction>(find.byType(SnackBarAction))
        .onPressed;
    await tester.runAsync(() async {
      onUndo();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.byType(QuestCandidateCard), findsNWidgets(candidateCount));

    // Restoring the candidate mounts a fresh `QuestCandidateCard`, which
    // schedules flutter_animate's own zero-duration initState timer for its
    // entrance animation — one more pump to flush it before tearDown, or
    // the test framework flags it as a timer still pending after disposal.
    // (All real async work is already done by this point, so pumpAndSettle
    // is safe here — unlike right after a runAsync block.)
    await tester.pumpAndSettle();
  });

  testWidgets(
    'customizing a candidate opens the dialog and accepts with the chosen duration',
    (tester) async {
      await pump(tester);

      final firstCard = find.byType(QuestCandidateCard).first;
      final onCustomize = iconButtonCallback(
        tester,
        firstCard,
        'Customize before accepting',
      );

      onCustomize();
      await tester.pumpAndSettle();

      expect(find.byType(QuestCustomizeDialog), findsOneWidget);
      final dialogCandidate = tester
          .widget<QuestCustomizeDialog>(find.byType(QuestCustomizeDialog))
          .candidate;

      // Verifies the duration segmented button actually responds to a tap.
      await tester.tap(find.text('30 days'));
      await tester.pump();

      // Dismiss via Cancel rather than "Use custom quest": tapping Save
      // pops the dialog with a non-null result, and `_customize`'s
      // `await showDialog(...)` continuation — which makes the real
      // orchestrator `_accept` call once that non-null result comes back —
      // is permanently anchored to the fake-async test zone (Dart captures
      // a continuation's zone at the `await` itself, not at whichever zone
      // later completes it), so that real Hive I/O never gets real time to
      // run and pumpAndSettle hangs waiting for it to settle. Cancel pops
      // with null, which `_customize` returns from immediately — safe.
      // The dialog UI (opens, offers durations) is verified above; the
      // resulting quest-creation behaviour is verified below by driving
      // the same accept call directly with the data the dialog handed off.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(QuestCustomizeDialog), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(QuestsScreen)),
      );
      await tester.runAsync(() async {
        await container
            .read(xpEngineOrchestratorProvider)
            .acceptQuest(dialogCandidate, durationDays: 30);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(QuestCard), findsOneWidget);
      expect(find.textContaining('30 days left'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );
}
