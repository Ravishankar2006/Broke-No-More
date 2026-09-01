import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared_widgets/animated_progress_bar.dart';
import '../../../shared_widgets/app_card.dart';

/// "How is this calendar month shaping up" — three things that were either
/// entirely invisible in Insights (the global monthly budget only ever
/// showed on Profile, recurring rules were never referenced at all) or
/// never computed anywhere (a burn-rate projection).
///
/// Deliberately calendar-month, independent of the range selector above it
/// — switching to "Week" shouldn't make "how much of my budget is left"
/// change meaning.
class MonthOutlookCard extends StatelessWidget {
  const MonthOutlookCard({
    super.key,
    required this.monthlyBudget,
    required this.monthToDateSpend,
    required this.burnRateProjection,
    required this.recurringForecast,
    required this.currencyCode,
  });

  final double? monthlyBudget;
  final double monthToDateSpend;
  final double? burnRateProjection;
  final double recurringForecast;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    // Nothing to say this month — no budget set, no projection possible
    // (e.g. nothing logged yet), and no recurring commitments. Showing an
    // empty card would just be noise.
    if (monthlyBudget == null &&
        burnRateProjection == null &&
        recurringForecast <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final semantics = context.semantics;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This month', style: theme.textTheme.titleSmall),
          if (monthlyBudget != null) ...[
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatCurrency(monthToDateSpend, currencyCode: currencyCode)} '
                    'of ${formatCurrency(monthlyBudget!, currencyCode: currencyCode)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  '${(monthToDateSpend / monthlyBudget! * 100).clamp(0, 999).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            AnimatedProgressBar(
              value: monthlyBudget! == 0
                  ? 0
                  : monthToDateSpend / monthlyBudget!,
              variant: ProgressVariant.budget,
              isOver: monthToDateSpend > monthlyBudget!,
            ),
          ],
          if (burnRateProjection != null) ...[
            const SizedBox(height: Spacing.md),
            _OutlookRow(
              icon: Icons.trending_up_rounded,
              text:
                  'At this pace, you\'ll spend '
                  '${formatCurrency(burnRateProjection!, currencyCode: currencyCode)} '
                  'by month end',
              color:
                  monthlyBudget != null && burnRateProjection! > monthlyBudget!
                  ? semantics.expenseInk
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
          if (recurringForecast > 0) ...[
            const SizedBox(height: Spacing.md),
            _OutlookRow(
              icon: Icons.autorenew_rounded,
              text:
                  '${formatCurrency(recurringForecast, currencyCode: currencyCode)} '
                  'in recurring bills left this month',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _OutlookRow extends StatelessWidget {
  const _OutlookRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: IconSize.smMd, color: color),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
