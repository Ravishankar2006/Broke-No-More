import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/xp_engine.dart';
import '../../models/transaction.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../providers/transaction_provider.dart';
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
import '../transactions/transaction_history_screen.dart';

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
    final transactions = ref.watch(transactionsProvider);
    final spentToday = ref.watch(todaysSpendProvider);

    if (profile == null) {
      return const Scaffold(body: SkeletonScreen());
    }

    final progress = levelProgressForXp(profile.currentXP);
    final recent = [...transactions]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: _Greeting(profile: profile),
            titleSpacing: Spacing.lg,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.md,
              Spacing.lg,
              Spacing.xxxl,
            ),
            sliver: SliverList.list(
              children: transactions.isEmpty
                  ? [_FirstRun(onLogPressed: onLogPressed)]
                  : _cards(
                      context: context,
                      profile: profile,
                      transactions: transactions,
                      recent: recent,
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
    required UserProfile profile,
    required List<Transaction> transactions,
    required List<Transaction> recent,
    required double spentToday,
    required LevelProgress progress,
  }) {
    final cards = <Widget>[
      _StreakHero(profile: profile, transactions: transactions),
      SizedBox(height: Spacing.md),
      AppCard(child: XpBar(progress: progress)),
      SizedBox(height: Spacing.md),
      _SpendingCard(profile: profile, spentToday: spentToday, transactions: transactions),
      SizedBox(height: Spacing.xl),
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
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Column(
          children: [
            for (final t in recent.take(_kRecentCount))
              TransactionTile(
                transaction: t,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TransactionHistoryScreen(),
                  ),
                ),
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
        AppAvatar(emoji: profile.avatarId, size: 36, showRing: false),
        SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _timeOfDayGreeting(),
                style: theme.textTheme.bodySmall,
              ),
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
  const _StreakHero({required this.profile, required this.transactions});

  final UserProfile profile;
  final List<Transaction> transactions;

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
                size: 56,
                repeat: true,
              ),
              SizedBox(width: Spacing.sm),
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
                      letterSpacing: 1.2,
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
                      letterSpacing: 1.1,
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
          SizedBox(height: Spacing.lg),
          StreakCalendar(transactions: transactions, onGold: true),
        ],
      ),
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.profile,
    required this.spentToday,
    required this.transactions,
  });

  final UserProfile profile;
  final double spentToday;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final budget = profile.monthlyBudget;

    // Prorate against the actual month length. The old `monthlyBudget / 30`
    // was wrong for every month except June/September/November/April.
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyBudget = budget == null ? null : budget / daysInMonth;
    final isOver = dailyBudget != null && spentToday > dailyBudget;

    final monthToDate = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.timestamp.year == now.year &&
            t.timestamp.month == now.month)
        .fold<double>(0, (sum, t) => sum + t.amount);

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
          SizedBox(height: Spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatCurrency(spentToday),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isOver ? semantics.expenseInk : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (dailyBudget != null)
                Text(
                  ' / ${formatCurrency(dailyBudget)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (dailyBudget != null) ...[
            SizedBox(height: Spacing.md),
            AnimatedProgressBar(
              value: dailyBudget == 0 ? 0 : spentToday / dailyBudget,
              variant: ProgressVariant.budget,
              isOver: isOver,
            ),
          ],
          SizedBox(height: Spacing.md),
          Divider(height: 1, indent: 0, endIndent: 0),
          SizedBox(height: Spacing.md),
          Row(
            children: [
              Text(
                'This month',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                formatCurrency(monthToDate),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (budget != null)
                Text(
                  ' / ${formatCurrency(budget)}',
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
      padding: EdgeInsets.only(top: Spacing.xxl),
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
