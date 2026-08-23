import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/section_header.dart';
import '../../shared_widgets/stat_tile.dart';

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

/// Selectable time window. "7 days" used to be hardcoded in three places with
/// no way to look at anything else.
enum InsightsRange {
  week('Week', 7),
  month('Month', 30),
  all('All', null);

  const InsightsRange(this.label, this.days);

  final String label;

  /// null means "everything since the first transaction".
  final int? days;
}

/// A bounded time window plus the transactions inside it, split by type.
class _Window {
  const _Window({
    required this.start,
    required this.end,
    required this.expenses,
    required this.income,
  });

  final DateTime start;
  final DateTime end;
  final List<Transaction> expenses;
  final List<Transaction> income;

  double get total => expenses.fold<double>(0, (sum, t) => sum + t.amount);
  double get incomeTotal => income.fold<double>(0, (sum, t) => sum + t.amount);
  double get net => incomeTotal - total;

  int get dayCount => daysBetween(start, end) + 1;
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightsRange _range = InsightsRange.week;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final transactions = ref.watch(transactionsProvider);

    final now = DateTime.now();
    final current = _windowFor(transactions, now, _range);
    final previous = _previousWindow(transactions, now, _range, current);

    final byCategory = _totalsByCategory(current);
    final categoryColors =
        _assignCategoryColors(byCategory.keys, semantics.chartPalette);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Insights'),
            titleSpacing: Spacing.lg,
          ),
          if (transactions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.insights_rounded,
                title: 'Nothing logged yet',
                message:
                    'Log a few transactions and this fills up with category '
                    'breakdowns, trends, and how much you\'re saving.',
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                Spacing.xxxl,
              ),
              sliver: SliverList.list(
                children: [
                  _RangeSelector(
                    range: _range,
                    onChanged: (range) => setState(() => _range = range),
                  ),
                  SizedBox(height: Spacing.lg),
                  _SummaryHero(current: current, previous: previous),
                  SizedBox(height: Spacing.lg),
                  _NetSummaryCard(window: current),
                  SizedBox(height: Spacing.xl),
                  SectionHeader(title: 'By category'),
                  _CategoryBreakdown(
                    byCategory: byCategory,
                    total: current.total,
                    colors: categoryColors,
                  ),
                  SizedBox(height: Spacing.xl),
                  SectionHeader(title: 'Daily trend'),
                  _TrendChart(window: current, range: _range),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the current window. Both ends are bounded — the previous version
  /// bounded the week total but not the per-category totals, so a transaction
  /// dated in the future inflated a category past the denominator and rendered
  /// as ">100%", "NaN%" or "Infinity%".
  static _Window _windowFor(
    List<Transaction> transactions,
    DateTime now,
    InsightsRange range,
  ) {
    final end = startOfDay(now);
    final DateTime start;
    if (range.days != null) {
      start = end.subtract(Duration(days: range.days! - 1));
    } else if (transactions.isEmpty) {
      start = end;
    } else {
      start = transactions
          .map((t) => startOfDay(t.timestamp))
          .reduce((a, b) => a.isBefore(b) ? a : b);
    }
    return _windowFromRange(transactions, start, end);
  }

  static _Window _previousWindow(
    List<Transaction> transactions,
    DateTime now,
    InsightsRange range,
    _Window current,
  ) {
    // "All" has no meaningful previous period.
    if (range.days == null) {
      return _Window(
        start: current.start,
        end: current.start,
        expenses: const [],
        income: const [],
      );
    }
    final end = current.start.subtract(const Duration(days: 1));
    final start = end.subtract(Duration(days: range.days! - 1));
    return _windowFromRange(transactions, start, end);
  }

  static _Window _windowFromRange(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
  ) {
    final inWindow = _within(transactions, start, end);
    return _Window(
      start: start,
      end: end,
      expenses: inWindow
          .where((t) => t.type == TransactionType.expense)
          .toList(growable: false),
      income: inWindow
          .where((t) => t.type == TransactionType.income)
          .toList(growable: false),
    );
  }

  static List<Transaction> _within(
    List<Transaction> transactions,
    DateTime start,
    DateTime end,
  ) {
    return transactions.where((t) {
      final day = startOfDay(t.timestamp);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList(growable: false);
  }

  static Map<String, double> _totalsByCategory(_Window window) {
    final totals = <String, double>{};
    for (final t in window.expenses) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    return totals;
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});

  final InsightsRange range;
  final ValueChanged<InsightsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<InsightsRange>(
      segments: [
        for (final option in InsightsRange.values)
          ButtonSegment(value: option, label: Text(option.label)),
      ],
      selected: {range},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Total spent plus the change against the previous period — the headline
/// number the screen never had.
class _SummaryHero extends StatelessWidget {
  const _SummaryHero({required this.current, required this.previous});

  final _Window current;
  final _Window previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    final total = current.total;
    final prior = previous.total;
    final hasComparison = prior > 0;
    final delta = hasComparison ? (total - prior) / prior * 100 : 0.0;
    final spentMore = delta > 0;
    final perDay = current.dayCount == 0 ? 0.0 : total / current.dayCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total spent', style: theme.textTheme.labelMedium),
          SizedBox(height: Spacing.xs),
          Text(
            formatCurrency(total),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: Spacing.md),
          Row(
            children: [
              // Flexible, not fixed: this sentence is long and the row also
              // carries the per-day figure, so on a narrow screen it has to be
              // allowed to shrink rather than overflow.
              Expanded(
                child: hasComparison
                    ? Row(
                        children: [
                          Icon(
                            spentMore
                                ? Icons.trending_up
                                : Icons.trending_down,
                            size: 18,
                            // Spending less is the good outcome, so down is
                            // green.
                            color: spentMore
                                ? semantics.expenseInk
                                : semantics.incomeInk,
                          ),
                          SizedBox(width: Spacing.xs),
                          Expanded(
                            child: Text(
                              '${delta.abs().toStringAsFixed(0)}% '
                              '${spentMore ? 'more' : 'less'} than last period',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: spentMore
                                    ? semantics.expenseInk
                                    : semantics.incomeInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'No previous period to compare',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
              ),
              SizedBox(width: Spacing.sm),
              Text(
                '${formatCurrency(perDay)}/day',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Income, expenses, and what's left over — income was logged from the
/// start but never surfaced anywhere beyond an individual transaction row.
class _NetSummaryCard extends StatelessWidget {
  const _NetSummaryCard({required this.window});

  final _Window window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    final income = window.incomeTotal;
    final expense = window.total;
    final net = window.net;
    final netPositive = net >= 0;
    // A rate is only meaningful once there's income to measure it against —
    // dividing by zero income would read as either 0% or an undefined spike.
    final savingsRate = income > 0 ? net / income * 100 : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Income',
                  value: formatCurrency(income),
                  valueColor: semantics.incomeInk,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Expenses',
                  value: formatCurrency(expense),
                  valueColor: semantics.expenseInk,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Net',
                  // Same sign convention as every transaction row: a
                  // manually-prefixed sign over the absolute value, rather
                  // than relying on NumberFormat's own negative rendering.
                  value: '${netPositive ? '+' : '−'}'
                      '${formatCurrency(net.abs())}',
                  valueColor:
                      netPositive ? semantics.incomeInk : semantics.expenseInk,
                ),
              ),
            ],
          ),
          if (savingsRate != null) ...[
            SizedBox(height: Spacing.md),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              decoration: BoxDecoration(
                color: netPositive
                    ? semantics.incomeInk.withValues(alpha: 0.12)
                    : semantics.expenseInk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                netPositive
                    ? 'Saving ${savingsRate.toStringAsFixed(0)}% of income'
                    : 'Spending ${(-savingsRate).toStringAsFixed(0)}% more '
                        'than income',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: netPositive
                      ? semantics.incomeInk
                      : semantics.expenseInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatefulWidget {
  const _CategoryBreakdown({
    required this.byCategory,
    required this.total,
    required this.colors,
  });

  final Map<String, double> byCategory;
  final double total;
  final Map<String, Color> colors;

  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.byCategory.isEmpty) {
      // Previously this left a 200px hole under a visible header.
      return AppCard(
        child: EmptyState(
          compact: true,
          icon: Icons.pie_chart_outline,
          title: 'Nothing in this period',
          message: 'Pick a wider range, or log an expense.',
        ),
      );
    }

    final entries = widget.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 52,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      _touchedIndex = event.isInterestedForInteractions &&
                              response?.touchedSection != null
                          ? response!.touchedSection!.touchedSectionIndex
                          : -1;
                    });
                  },
                ),
                sections: [
                  for (var i = 0; i < entries.length; i++)
                    _section(entries[i], i == _touchedIndex),
                ],
              ),
              duration: AppMotion.standard,
              curve: AppMotion.standardCurve,
            ),
          ),
          SizedBox(height: Spacing.lg),
          // Amounts, not just percentages — the legend used to show names only.
          for (final entry in entries)
            Padding(
              padding: EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.colors[entry.key],
                      borderRadius: BorderRadius.circular(AppRadius.xs / 2),
                    ),
                  ),
                  SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    formatCurrency(entry.value),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: Spacing.sm),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${_percent(entry.value)}%',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  PieChartSectionData _section(MapEntry<String, double> entry, bool touched) {
    final color = widget.colors[entry.key]!;
    return PieChartSectionData(
      value: entry.value,
      title: '${_percent(entry.value)}%',
      color: color,
      radius: touched ? 70 : 60,
      titleStyle: TextStyle(
        fontSize: touched ? 13 : 11,
        color: _onSlice(color),
        fontWeight: FontWeight.w700,
      ),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.surface,
        width: 2,
      ),
    );
  }

  /// Guarded against a zero total. The old call divided by a differently-bounded
  /// window sum and could produce NaN or Infinity.
  int _percent(double value) {
    if (widget.total <= 0) return 0;
    return (value / widget.total * 100).round();
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.window, required this.range});

  final _Window window;
  final InsightsRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final daily = _dailyTotals();
    final maxValue = daily.fold<double>(0, (m, d) => d.value > m ? d.value : m);

    return AppCard(
      child: SizedBox(
        height: 180,
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
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  formatCurrency(rod.toY),
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
                  barRods: [
                    BarChartRodData(
                      toY: daily[i].value,
                      color: semantics.chartBar,
                      width: daily.length > 14 ? 6 : 16,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xs),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxValue <= 0 ? 1 : maxValue * 1.15,
                        color: semantics.barTrack,
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
    );
  }

  FlTitlesData _titles(
    BuildContext context,
    List<({String label, double value})> daily,
  ) {
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
              padding: EdgeInsets.only(top: Spacing.xs),
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

  List<({String label, double value})> _dailyTotals() {
    // Two-letter weekdays for a week view; day-of-month for longer ranges,
    // where repeating weekday letters would be meaningless.
    const weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final days = window.dayCount;

    // Bucket once — the previous version re-scanned every expense for every
    // day (O(days × expenses)), which on "All" over a year of history meant
    // a few hundred full-list scans on every rebuild.
    final totalsByDay = <DateTime, double>{};
    for (final t in window.expenses) {
      final day = startOfDay(t.timestamp);
      totalsByDay[day] = (totalsByDay[day] ?? 0) + t.amount;
    }

    return List.generate(days, (i) {
      final day = window.start.add(Duration(days: i));
      final label = days <= 7 ? weekdays[day.weekday - 1] : '${day.day}';
      return (label: label, value: totalsByDay[day] ?? 0);
    });
  }
}
