import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';

/// Stable hash for category-to-colour assignment. Hand-rolled djb2 (not String.hashCode,
/// which Dart does not guarantee stable across runs/platforms).
int _paletteSeed(String key) {
  var h = 5381;
  for (final u in key.codeUnits) {
    h = ((h * 33) ^ u) & 0x7fffffff;
  }
  return h;
}

/// Assign each category a stable colour index. Called once per build to map category
/// names to chart palette slots deterministically, independent of logging order.
Map<String, Color> _assignCategoryColors(
    Iterable<String> categories, List<Color> palette) {
  final sorted = categories.toList()..sort();
  final taken = <int>{};
  final out = <String, Color>{};
  for (final name in sorted) {
    var i = _paletteSeed(name) % palette.length;
    while (taken.contains(i) && taken.length < palette.length) {
      i = (i + 1) % palette.length;
    }
    taken.add(i);
    out[name] = palette[i];
  }
  return out;
}

/// Compute the high-contrast text colour for a slice background.
Color _onSlice(Color bg) =>
    bg.computeLuminance() > 0.45 ? const Color(0xFF1A1200) : Colors.white;

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantics = context.semantics;
    final transactions = ref.watch(transactionsProvider);
    final expenses =
        transactions.where((t) => t.type == TransactionType.expense).toList();

    final now = DateTime.now();
    final thisWeek = _sumInWindow(expenses, now, 7);
    final lastWeek = _sumInWindow(expenses, now.subtract(const Duration(days: 7)), 7);
    final byCategory = _totalsByCategory(expenses, now, 7);
    final dailyTotals = _dailyTotals(expenses, now, 7);
    final categoryColors = _assignCategoryColors(byCategory.keys, semantics.chartPalette);

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
              padding: EdgeInsets.all(Spacing.lg),
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Week over week',
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: Spacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: _WeekStat(
                                label: 'This week',
                                amount: thisWeek,
                                isPrevious: false,
                              ),
                            ),
                            Expanded(
                              child: _WeekStat(
                                label: 'Last week',
                                amount: lastWeek,
                                isPrevious: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: Spacing.md),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By category (7 days)',
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: Spacing.lg),
                        SizedBox(
                          height: 200,
                          child: byCategory.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                  children: [
                                    Expanded(
                                      child: PieChart(
                                        PieChartData(
                                          sectionsSpace: 2,
                                          centerSpaceRadius: 48,
                                          sections: [
                                            for (final entry in byCategory.entries
                                                .toList()
                                              ..sort((a, b) =>
                                                  b.value.compareTo(a.value)))
                                              PieChartSectionData(
                                                value: entry.value,
                                                title:
                                                    '${(entry.value / thisWeek * 100).round()}%',
                                                color: categoryColors[entry.key]!,
                                                radius: 60,
                                                titleStyle: TextStyle(
                                                  fontSize: 11,
                                                  color: _onSlice(
                                                      categoryColors[entry.key]!),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surface,
                                                  width: 2,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: Spacing.lg),
                                    Wrap(
                                      spacing: Spacing.md,
                                      runSpacing: Spacing.sm,
                                      children: [
                                        for (final entry
                                            in byCategory.entries.toList()
                                              ..sort((a, b) =>
                                                  b.value.compareTo(a.value)))
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: categoryColors[entry.key],
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              SizedBox(width: Spacing.sm),
                                              Text(
                                                entry.key,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall,
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: Spacing.md),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(Spacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spending trend (7 days)',
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: Spacing.lg),
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
                                        padding: EdgeInsets.only(top: Spacing.xs),
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
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: semantics.chartGrid,
                                  strokeWidth: 1,
                                ),
                              ),
                              barGroups: [
                                for (final entry in dailyTotals.asMap().entries)
                                  BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.$2,
                                        color: semantics.chartBar,
                                        width: 16,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(AppRadius.xs),
                                        ),
                                        backDrawRodData: BackgroundBarChartRodData(
                                          show: true,
                                          toY: dailyTotals
                                              .fold<double>(
                                                  0,
                                                  (max, val) =>
                                                      val.$2 > max ? val.$2 : max)
                                              .ceil()
                                              .toDouble(),
                                          color: semantics.barTrack,
                                        ),
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
  const _WeekStat({
    required this.label,
    required this.amount,
    required this.isPrevious,
  });

  final String label;
  final double amount;
  final bool isPrevious;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        SizedBox(height: Spacing.xs),
        Text(
          formatCurrency(amount),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}
