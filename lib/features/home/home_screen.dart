import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Text(
                        '${profile.currentStreak}-day streak',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text('Best: ${profile.longestStreak}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreakCalendar(transactions: transactions),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: XpBar(progress: progress),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's spending",
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    dailyBudget != null
                        ? '${formatCurrency(spentToday)} / ${formatCurrency(dailyBudget)}'
                        : formatCurrency(spentToday),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (dailyBudget != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (spentToday / dailyBudget).clamp(0, 1),
                        minHeight: 8,
                        color: spentToday > dailyBudget
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
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
