import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/boot_failure_screen.dart';
import 'core/database/hive_boxes.dart';
import 'core/theme/app_theme.dart';
import 'data/gamification_repair.dart';
import 'data/quest_repository.dart';
import 'data/recurring_transaction_repository.dart';
import 'features/home/home_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers/badge_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/quest_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/transaction_provider.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        originalOnError?.call(details);
      };
      runApp(const _BootGate());
    },
    (error, stack) {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
}

/// Runs the fast startup steps (Hive, recurring materialization, quest
/// expiry) and shows [BootFailureScreen] with a retry if any of them throw,
/// instead of the app dying silently at the native splash. The slow step —
/// [repairGamificationState] — deliberately does not gate the first frame;
/// see [_RepairScheduler].
class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  late Future<void> _fastBoot = _runFastBootSteps();

  Future<void> _runFastBootSteps() async {
    await initHive();
    // Turns any due recurring rules into real transactions — same "no backend
    // to run this on a schedule" constraint as quest expiry below, so this is
    // the one checkpoint. Must run before repair, so newly-created rows are
    // already in the transactions box when it replays.
    await RecurringTransactionRepository().materializeDue();
    // Catches quests that passed their endDate while the app was closed —
    // nothing else runs while offline, so this is the one guaranteed
    // checkpoint.
    await QuestRepository().expireOverdueQuests();
    // repairGamificationState() runs after the first frame instead of here
    // — see _RepairScheduler. Measured at ~1.8s over a 10,000-transaction
    // history (a plausible multi-year power-user dataset), which is long
    // enough that gating the first frame on it turns a cold start into a
    // multi-second hold on a blank screen. materializeDue/expireOverdueQuests
    // stay blocking because they're consistently near-instant (no-ops on the
    // common day) and, unlike repair, a visible frame before they've run
    // would show something concretely wrong — a recurring charge that
    // hasn't appeared yet, an obviously-overdue quest still marked active.
  }

  void _retry() {
    setState(() {
      _fastBoot = _runFastBootSteps();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _fastBoot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // No Dart-level splash needed: the native launch screen stays
          // visible until the first frame, which is this transparent one.
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint(
              'Boot failed: ${snapshot.error}\n${snapshot.stackTrace}',
            );
          }
          return BootFailureScreen(error: snapshot.error!, onRetry: _retry);
        }
        return const ProviderScope(
          child: _RepairScheduler(child: BrokeNoMoreApp()),
        );
      },
    );
  }
}

/// Runs [repairGamificationState] once the app is already live, then
/// invalidates every provider it can have touched so the UI picks up
/// whatever it changed.
///
/// [repairGamificationState] was written to run *before* `runApp` ("nothing
/// is watching yet"), writing straight to repositories. That assumption no
/// longer holds now that it runs after the first frame — this widget is
/// what keeps it sound: providers may already hold pre-repair state by the
/// time repair finishes, so it isn't enough to just run the function,
/// results have to be pushed back into the widget tree. In the common case
/// (nothing was actually inconsistent) every invalidated provider rebuilds
/// to the exact same values, so this is invisible; it only produces a
/// visible correction in the rare case of a genuinely interrupted write.
class _RepairScheduler extends ConsumerStatefulWidget {
  const _RepairScheduler({required this.child});

  final Widget child;

  @override
  ConsumerState<_RepairScheduler> createState() => _RepairSchedulerState();
}

class _RepairSchedulerState extends ConsumerState<_RepairScheduler> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() async {
      await repairGamificationState();
      if (!mounted) return;
      ref.invalidate(profileProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(questsProvider);
      ref.invalidate(badgesProvider);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class BrokeNoMoreApp extends ConsumerWidget {
  const BrokeNoMoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final hasProfile = ref.watch(hasProfileProvider);

    return MaterialApp(
      title: 'Broke No More',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: hasProfile ? const HomeShell() : const OnboardingScreen(),
      builder: (context, child) {
        // Material's own guidance tops out at 200% — beyond that, the hero
        // numbers (streak count, log-sheet amount) and medallion-plus-label
        // rows that were hand-tuned around displaySmall/headlineLarge start
        // overflowing rather than just growing. Floor stays just under 1 so
        // a system "smaller text" setting is still honoured.
        final mediaQuery = MediaQuery.of(context);
        final clamped = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 2.0,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clamped),
          child: child!,
        );
      },
    );
  }
}
