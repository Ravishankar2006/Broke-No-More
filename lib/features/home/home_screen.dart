import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/xp_engine.dart';
import '../../models/transaction.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/xp_engine_provider.dart' show LogTransactionResult;
import '../../shared_widgets/animated_progress_bar.dart';
import '../../shared_widgets/app_avatar.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/celebration_effects.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/section_header.dart';
import '../../shared_widgets/skeleton.dart';
import '../../shared_widgets/streak_calendar.dart';
import '../../shared_widgets/transaction_tile.dart';
import '../../shared_widgets/xp_bar.dart';
import '../log_transaction/log_transaction_sheet.dart';
import '../transactions/transaction_history_screen.dart';

/// Opens the edit sheet for a specific transaction — previously tapping a
/// recent row on Home landed on the unfiltered History *list* instead of
/// that transaction, with no way to get from "I see it" to "I can edit it"
/// in one tap. Mirrors `TransactionHistoryScreen._edit`.
Future<void> _openTransactionDetail(
  BuildContext context,
  Transaction transaction,
) async {
  final result = await showModalBottomSheet<LogTransactionResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => LogTransactionSheet(existing: transaction),
  );
  if (!context.mounted || result == null) return;
  if (result.xpGained > 0) showXpGain(context, result.xpGained);
}

/// How many recent transactions Home shows before deferring to full history.
const _kRecentCount = 4;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onLogPressed});

  /// Opens the log sheet. Owned by the shell, which also handles the
  /// celebration dialogs that can follow.
  final VoidCallback? onLogPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    // Only watched to decide first-run vs. normal layout; per-card data
    // below comes from providers that stay cheap regardless of history
    // size instead of scanning this full list on every build.
    final hasTransactions = ref.watch(
      transactionsProvider.select((t) => t.isNotEmpty),
    );
    final spentToday = ref.watch(todaysSpendProvider);

    if (profile == null) {
      return const Scaffold(body: SkeletonScreen());
    }

    final progress = levelProgressForXp(profile.currentXP);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: _Greeting(profile: profile),
            titleSpacing: Spacing.lg,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xxxl,
            ),
            sliver: SliverList.list(
              children: !hasTransactions
                  ? [_FirstRun(onLogPressed: onLogPressed)]
                  : _cards(
                      context: context,
                      ref: ref,
                      profile: profile,
                      spentToday: spentToday,
                      progress: progress,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cards({
    required BuildContext context,
    required WidgetRef ref,
    required UserProfile profile,
    required double spentToday,
    required LevelProgress progress,
  }) {
    final recent = ref.watch(recentTransactionsProvider(_kRecentCount));
    final loggedDays = ref.watch(loggedDaysProvider);
    final monthToDate = ref.watch(monthToDateSpendProvider);

    final cards = <Widget>[
      _StreakHero(profile: profile, loggedDays: loggedDays),
      const SizedBox(height: Spacing.md),
      AppCard(child: XpBar(progress: progress)),
      const SizedBox(height: Spacing.md),
      _SpendingCard(
        profile: profile,
        spentToday: spentToday,
        monthToDate: monthToDate,
      ),
      const SizedBox(height: Spacing.xl),
      SectionHeader(
        title: 'Recent',
        actionLabel: 'See all',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const TransactionHistoryScreen(),
          ),
        ),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Column(
          children: [
            for (final t in recent.take(_kRecentCount))
              TransactionTile(
                transaction: t,
                onTap: () => _openTransactionDetail(context, t),
              ),
          ],
        ),
      ),
    ];

    // Stagger the entrance so the screen assembles rather than snapping in.
    return [
      for (var i = 0; i < cards.length; i++)
        cards[i]
            .animate()
            .fadeIn(
              delay: AppMotion.staggerDelay(i ~/ 2),
              duration: AppMotion.standard,
            )
            .slideY(begin: 0.08, end: 0, curve: AppMotion.enter),
    ];
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        AppAvatar(
          emoji: profile.avatarId,
          size: MedallionSize.avatarCompact,
          showRing: false,
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_timeOfDayGreeting(), style: theme.textTheme.bodySmall),
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _timeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

/// The screen's focal point.
///
/// The streak is the mechanic the whole app is built around, and it used to be
/// one of three identical cards. Here it gets the gold gradient, the animated
/// flame and the oversized number — the only hero on the screen.
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.profile, required this.loggedDays});

  final UserProfile profile;
  final Set<DateTime> loggedDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    return AppCard.hero(
      gradient: AppGradients.streak(theme.brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CelebrationAnimation(
                asset: CelebrationAssets.streakFlame,
                fallbackIcon: Icons.local_fire_department,
                size: IconSize.hero,
                repeat: true,
              ),
              const SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountUpText(
                    value: profile.currentStreak,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: semantics.onGold,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    profile.currentStreak == 1 ? 'DAY' : 'DAYS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantics.onGold.withValues(alpha: 0.75),
                      letterSpacing: kOverlineLetterSpacing,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BEST',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: semantics.onGold.withValues(alpha: 0.7),
                      letterSpacing: kOverlineLetterSpacing,
                    ),
                  ),
                  Text(
                    '${profile.longestStreak}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: semantics.onGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          // Freezes were computed and persisted from day one but never
          // surfaced anywhere — a user whose streak survived a missed day
          // had no idea why, or that the grace only covers one gap a week.
          Row(
            children: [
              Icon(
                Icons.ac_unit,
                size: IconSize.sm,
                color: semantics.onGold.withValues(alpha: 0.85),
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                profile.streakFreezesLeft > 0
                    ? '${profile.streakFreezesLeft} streak freeze available '
                          'this week'
                    : 'No streak freezes left this week',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: semantics.onGold.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          StreakCalendar(loggedDays: loggedDays, onGold: true),
        ],
      ),
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.profile,
    required this.spentToday,
    required this.monthToDate,
  });

  final UserProfile profile;
  final double spentToday;
  final double monthToDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final budget = profile.monthlyBudget;

    final now = DateTime.now();
    final dailyBudget = budget == null ? null : dailyBudgetFor(budget, now);
    final isOver = dailyBudget != null && spentToday > dailyBudget;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Today's spending", style: theme.textTheme.titleSmall),
              const Spacer(),
              if (dailyBudget != null)
                Text(
                  isOver ? 'Over budget' : 'On track',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isOver ? semantics.expenseInk : semantics.incomeInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatCurrency(spentToday, currencyCode: profile.currencyCode),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isOver ? semantics.expenseInk : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (dailyBudget != null)
                Text(
                  ' / ${formatCurrency(dailyBudget, currencyCode: profile.currencyCode)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (dailyBudget != null) ...[
            const SizedBox(height: Spacing.md),
            AnimatedProgressBar(
              value: dailyBudget == 0 ? 0 : spentToday / dailyBudget,
              variant: ProgressVariant.budget,
              isOver: isOver,
            ),
          ],
          const SizedBox(height: Spacing.md),
          const Divider(height: 1, indent: 0, endIndent: 0),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Text('This month', style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                formatCurrency(monthToDate, currencyCode: profile.currencyCode),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (budget != null)
                Text(
                  ' / ${formatCurrency(budget, currencyCode: profile.currencyCode)}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// First-run state.
///
/// A brand-new user previously saw three cards of zeros — a 0-day streak, an
/// empty XP bar and ₹0.00 — with nothing telling them what to do.
class _FirstRun extends StatelessWidget {
  const _FirstRun({required this.onLogPressed});

  final VoidCallback? onLogPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.xxl),
      child: EmptyState(
        icon: Icons.rocket_launch_outlined,
        title: 'Log your first transaction',
        message:
            'Every log earns XP and builds your streak. Start with something '
            'you bought today — it takes about five seconds.',
        actionLabel: onLogPressed == null ? null : 'Log a transaction',
        onAction: onLogPressed,
      ),
    );
  }
}
