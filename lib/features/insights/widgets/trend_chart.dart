import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../providers/insights_provider.dart';
import '../../../shared_widgets/app_card.dart';

typedef _DailyTotal = ({String label, double expense, double income});

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.window,
    required this.range,
    required this.currencyCode,
  });

  final InsightsWindow window;
  final InsightsRange range;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final daily = _dailyTotals();
    final maxValue = daily.fold<double>(
      0,
      (m, d) => [m, d.expense, d.income].reduce((a, b) => a > b ? a : b),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Legend(semantics: semantics),
          const SizedBox(height: Spacing.md),
          Semantics(
            // fl_chart draws to a canvas with no semantic tree of its own,
            // so without this a screen reader sees a blank card where the
            // trend chart is — give it the summary a sighted user gets at
            // a glance.
            label: _summary(daily),
            container: true,
            child: ExcludeSemantics(
              child: SizedBox(
                height: ChartSize.trend,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxValue <= 0 ? 1 : maxValue * 1.15,
                    titlesData: _titles(context, daily),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: semantics.chartGrid, strokeWidth: 1),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            theme.colorScheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                              formatCurrency(
                                rod.toY,
                                currencyCode: currencyCode,
                              ),
                              theme.textTheme.labelSmall!.copyWith(
                                color: theme.colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < daily.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 2,
                          barRods: [
                            BarChartRodData(
                              toY: daily[i].expense,
                              color: semantics.expense,
                              width: daily.length > 14 ? 4 : 8,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.xs),
                              ),
                            ),
                            BarChartRodData(
                              toY: daily[i].income,
                              color: semantics.income,
                              width: daily.length > 14 ? 4 : 8,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.xs),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: AppMotion.standard,
                  curve: AppMotion.standardCurve,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          _CumulativeNetChart(
            daily: daily,
            currencyCode: currencyCode,
            semantics: semantics,
          ),
        ],
      ),
    );
  }

  String _summary(List<_DailyTotal> daily) {
    if (daily.isEmpty) return 'Spending trend chart. No data.';
    final total = daily.fold<double>(0, (s, d) => s + d.expense);
    if (total <= 0) {
      return 'Spending trend chart. No spending over ${daily.length} days.';
    }
    final peak = daily.reduce((a, b) => b.expense > a.expense ? b : a);
    return 'Spending and income trend chart. Total spent '
        '${formatCurrency(total, currencyCode: currencyCode)} over '
        '${daily.length} days. Highest-spend day was ${peak.label}: '
        '${formatCurrency(peak.expense, currencyCode: currencyCode)}.';
  }

  FlTitlesData _titles(BuildContext context, List<_DailyTotal> daily) {
    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));
    // With many bars, labelling every one is unreadable — thin them out.
    final step = (daily.length / 7).ceil();

    return FlTitlesData(
      topTitles: hidden,
      rightTitles: hidden,
      leftTitles: hidden,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= daily.length) return const SizedBox.shrink();
            if (step > 1 && i % step != 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                daily[i].label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
    );
  }

  List<_DailyTotal> _dailyTotals() {
    // Two-letter weekdays for a week view; day-of-month for longer ranges,
    // where repeating weekday letters would be meaningless.
    const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final days = window.dayCount;

    // Bucket once — the previous version re-scanned every expense for every
    // day (O(days × expenses)), which on "All" over a year of history meant
    // a few hundred full-list scans on every rebuild.
    final expenseByDay = <DateTime, double>{};
    for (final t in window.expenses) {
      final day = startOfDay(t.timestamp);
      expenseByDay[day] = (expenseByDay[day] ?? 0) + t.amount;
    }
    final incomeByDay = <DateTime, double>{};
    for (final t in window.income) {
      final day = startOfDay(t.timestamp);
      incomeByDay[day] = (incomeByDay[day] ?? 0) + t.amount;
    }

    return List.generate(days, (i) {
      final day = window.start.add(Duration(days: i));
      final label = days <= 7 ? weekdays[day.weekday - 1] : '${day.day}';
      return (
        label: label,
        expense: expenseByDay[day] ?? 0,
        income: incomeByDay[day] ?? 0,
      );
    });
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.semantics});

  final AppSemanticColors semantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _LegendDot(color: semantics.expense, label: 'Expense'),
        const SizedBox(width: Spacing.lg),
        _LegendDot(color: semantics.income, label: 'Income'),
        const Spacer(),
        Text('Daily trend', style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Spacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Running income-minus-expense across the window — separate from the bar
/// chart because the two answer different questions: the bars show daily
/// activity, this shows whether the period as a whole is trending toward
/// saving or bleeding money.
class _CumulativeNetChart extends StatelessWidget {
  const _CumulativeNetChart({
    required this.daily,
    required this.currencyCode,
    required this.semantics,
  });

  final List<_DailyTotal> daily;
  final String currencyCode;
  final AppSemanticColors semantics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var running = 0.0;
    final points = <FlSpot>[];
    for (var i = 0; i < daily.length; i++) {
      running += daily[i].income - daily[i].expense;
      points.add(FlSpot(i.toDouble(), running));
    }
    if (points.isEmpty) return const SizedBox.shrink();

    final endingNet = points.last.y;
    final lineColor = endingNet >= 0
        ? semantics.incomeInk
        : semantics.expenseInk;
    final minY = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    // A flat-zero series (no transactions yet) would otherwise collapse the
    // chart's y-range to a single point and draw nothing sensible.
    final padding = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY).abs() * 0.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Running net', style: theme.textTheme.labelMedium),
        const SizedBox(height: Spacing.sm),
        Semantics(
          label:
              'Running net chart. Currently '
              '${endingNet >= 0 ? 'up' : 'down'} '
              '${formatCurrency(endingNet.abs(), currencyCode: currencyCode)} '
              'over this period.',
          container: true,
          child: ExcludeSemantics(
            child: SizedBox(
              height: ChartSize.trend * 0.6,
              child: LineChart(
                LineChartData(
                  minY: minY - padding,
                  maxY: maxY + padding,
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 0,
                        color: semantics.chartGrid,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                      getTooltipItems: (spots) => spots
                          .map(
                            (s) => LineTooltipItem(
                              formatCurrency(s.y, currencyCode: currencyCode),
                              theme.textTheme.labelSmall!.copyWith(
                                color: theme.colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      isCurved: true,
                      color: lineColor,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
                duration: AppMotion.standard,
                curve: AppMotion.standardCurve,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
