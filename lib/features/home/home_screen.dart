import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/xp_engine.dart';
import '../../providers/profile_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../shared_widgets/streak_calendar.dart';
import '../../shared_widgets/xp_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantics = context.semantics;
    final profile = ref.watch(profileProvider);
    final transactions = ref.watch(transactionsProvider);
    final spentToday = ref.watch(todaysSpendProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = levelProgressForXp(profile.currentXP);
    final dailyBudget =
        profile.monthlyBudget != null ? profile.monthlyBudget! / 30 : null;

    return Scaffold(
      appBar: AppBar(title: Text('Hey, ${profile.name}')),
      body: ListView(
        padding: EdgeInsets.all(Spacing.lg),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_fire_department,
                          color: semantics.streakInk),
                      SizedBox(width: Spacing.sm),
                      Text(
                        '${profile.currentStreak}-day streak',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text('Best: ${profile.longestStreak}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  SizedBox(height: Spacing.lg),
                  StreakCalendar(transactions: transactions),
                ],
              ),
            ),
          ),
          SizedBox(height: Spacing.md),
          Card(
            child: Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: XpBar(progress: progress),
            ),
          ),
          SizedBox(height: Spacing.md),
          Card(
            child: Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's spending",
                      style: Theme.of(context).textTheme.titleMedium),
                  SizedBox(height: Spacing.sm),
                  Text(
                    dailyBudget != null
                        ? '${formatCurrency(spentToday)} / ${formatCurrency(dailyBudget)}'
                        : formatCurrency(spentToday),
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                          color: spentToday > (dailyBudget ?? 0)
                              ? semantics.expenseInk
                              : null,
                        ),
                  ),
                  if (dailyBudget != null) ...[
                    SizedBox(height: Spacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: (spentToday / dailyBudget).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: semantics.barTrack,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          spentToday > dailyBudget
                              ? semantics.budgetOver
                              : semantics.budgetUnder,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
