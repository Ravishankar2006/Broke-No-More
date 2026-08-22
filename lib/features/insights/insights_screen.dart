import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';

const _categoryPalette = [
  AppColors.primary,
  AppColors.secondary,
  AppColors.xp,
  AppColors.streak,
  Color(0xFF8E24AA),
  Color(0xFF00838F),
  Color(0xFF6D4C41),
  Color(0xFFEF6C00),
  Color(0xFF3949AB),
  Color(0xFF2E7D32),
  Color(0xFFAD1457),
];

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final expenses =
        transactions.where((t) => t.type == TransactionType.expense).toList();

    final now = DateTime.now();
    final thisWeek = _sumInWindow(expenses, now, 7);
    final lastWeek = _sumInWindow(expenses, now.subtract(const Duration(days: 7)), 7);
    final byCategory = _totalsByCategory(expenses, now, 7);
    final dailyTotals = _dailyTotals(expenses, now, 7);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: expenses.isEmpty
          ? Center(
              child: Text(
                'Log a few transactions to see spending insights here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Week over week',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _WeekStat(
                                label: 'This week',
                                amount: thisWeek,
                              ),
                            ),
                            Expanded(
                              child: _WeekStat(
                                label: 'Last week',
                                amount: lastWeek,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By category (7 days)',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: byCategory.isEmpty
                              ? const SizedBox.shrink()
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 36,
                                    sections: [
                                      for (final entry
                                          in byCategory.entries.toList().asMap().entries)
                                        PieChartSectionData(
                                          value: entry.value.value,
                                          title: entry.value.key,
                                          color: _categoryPalette[
                                              entry.key % _categoryPalette.length],
                                          radius: 60,
                                          titleStyle: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spending trend (7 days)',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: BarChart(
                            BarChartData(
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= dailyTotals.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          dailyTotals[i].$1,
                                          style: Theme.of(context).textTheme.labelSmall,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              gridData: const FlGridData(show: false),
                              barGroups: [
                                for (final entry in dailyTotals.asMap().entries)
                                  BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.$2,
                                        color: AppColors.primary,
                                        width: 14,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  double _sumInWindow(List<Transaction> expenses, DateTime end, int days) {
    final start = startOfDay(end).subtract(Duration(days: days - 1));
    return expenses
        .where((t) => !startOfDay(t.timestamp).isBefore(start) &&
            !startOfDay(t.timestamp).isAfter(startOfDay(end)))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<String, double> _totalsByCategory(
      List<Transaction> expenses, DateTime end, int days) {
    final start = startOfDay(end).subtract(Duration(days: days - 1));
    final totals = <String, double>{};
    for (final t in expenses) {
      if (startOfDay(t.timestamp).isBefore(start)) continue;
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }

  List<(String, double)> _dailyTotals(
      List<Transaction> expenses, DateTime end, int days) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return List.generate(days, (i) {
      final day = startOfDay(end).subtract(Duration(days: days - 1 - i));
      final total = expenses
          .where((t) => isSameDay(t.timestamp, day))
          .fold(0.0, (sum, t) => sum + t.amount);
      return (labels[day.weekday - 1], total);
    });
  }
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(formatCurrency(amount), style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
