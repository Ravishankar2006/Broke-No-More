import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/insights_provider.dart';
import '../../../shared_widgets/app_card.dart';
import '../../../shared_widgets/stat_tile.dart';

/// Income, expenses, and what's left over — income was logged from the
/// start but never surfaced anywhere beyond an individual transaction row.
class NetSummaryCard extends StatelessWidget {
  const NetSummaryCard({
    super.key,
    required this.window,
    required this.currencyCode,
  });

  final InsightsWindow window;
  final String currencyCode;

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
                  value: formatCurrency(income, currencyCode: currencyCode),
                  valueColor: semantics.incomeInk,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Expenses',
                  value: formatCurrency(expense, currencyCode: currencyCode),
                  valueColor: semantics.expenseInk,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Net',
                  // Same sign convention as every transaction row: a
                  // manually-prefixed sign over the absolute value, rather
                  // than relying on NumberFormat's own negative rendering.
                  value:
                      '${netPositive ? '+' : '−'}'
                      '${formatCurrency(net.abs(), currencyCode: currencyCode)}',
                  valueColor: netPositive
                      ? semantics.incomeInk
                      : semantics.expenseInk,
                ),
              ),
            ],
          ),
          if (savingsRate != null) ...[
            const SizedBox(height: Spacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
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
