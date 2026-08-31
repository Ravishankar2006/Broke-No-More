import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared_widgets/app_card.dart';
import '../../../shared_widgets/empty_state.dart';
import 'category_colors.dart';

class CategoryBreakdown extends StatefulWidget {
  const CategoryBreakdown({
    super.key,
    required this.byCategory,
    required this.total,
    required this.colors,
    required this.currencyCode,
    required this.onCategoryTap,
    this.categoriesWithActiveQuest = const {},
  });

  final Map<String, double> byCategory;
  final double total;
  final Map<String, Color> colors;
  final String currencyCode;

  /// Categories an active quest currently targets — ties Insights' spending
  /// view back to the game layer, which was previously invisible here.
  final Set<String> categoriesWithActiveQuest;

  /// Drill-down: opens that category's history pre-filtered, from either a
  /// pie-slice tap or a legend row tap (the slice is excluded from
  /// semantics, so the legend is also the accessible path to this).
  final ValueChanged<String> onCategoryTap;

  @override
  State<CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<CategoryBreakdown> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.byCategory.isEmpty) {
      // Previously this left a 200px hole under a visible header.
      return const AppCard(
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
          Semantics(
            // Same reasoning as the trend chart: fl_chart's canvas is
            // invisible to a screen reader, so give it the breakdown as text.
            // The legend just below repeats this per-row, but a reader
            // landing on the chart itself shouldn't hit a silent gap first.
            label: _pieSummary(entries),
            container: true,
            child: ExcludeSemantics(
              child: SizedBox(
                height: ChartSize.pie,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 52,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final index =
                            event.isInterestedForInteractions &&
                                response?.touchedSection != null
                            ? response!.touchedSection!.touchedSectionIndex
                            : -1;
                        setState(() => _touchedIndex = index);
                        if (event is FlTapUpEvent && index >= 0) {
                          widget.onCategoryTap(entries[index].key);
                        }
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
            ),
          ),
          const SizedBox(height: Spacing.lg),
          // Amounts, not just percentages — the legend used to show names only.
          for (final entry in entries)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onCategoryTap(entry.key),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: Spacing.xs,
                  ).copyWith(bottom: Spacing.sm),
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
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(
                          entry.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (widget.categoriesWithActiveQuest.contains(
                        entry.key,
                      )) ...[
                        Tooltip(
                          message: 'An active quest targets this category',
                          child: Icon(
                            Icons.flag_rounded,
                            size: IconSize.sm,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                      ],
                      Text(
                        formatCurrency(
                          entry.value,
                          currencyCode: widget.currencyCode,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
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
        color: onSliceTextColor(context, color),
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

  String _pieSummary(List<MapEntry<String, double>> entries) {
    final top = entries.take(3).map((e) => '${e.key} ${_percent(e.value)}%');
    return 'Category breakdown chart. ${top.join(', ')}'
        '${entries.length > 3 ? ', and ${entries.length - 3} more' : ''}.';
  }
}
