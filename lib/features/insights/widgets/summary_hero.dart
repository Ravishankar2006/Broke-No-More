import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../providers/insights_provider.dart';
import '../../../shared_widgets/app_card.dart';

/// Total spent plus the change against the previous period — the headline
/// number the screen never had.
class SummaryHero extends StatelessWidget {
  const SummaryHero({
    super.key,
    required this.current,
    required this.previous,
    required this.currencyCode,
  });

  final InsightsWindow current;
  final InsightsWindow previous;
  final String currencyCode;

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
          const SizedBox(height: Spacing.xs),
          Text(
            formatCurrency(total, currencyCode: currencyCode),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Spacing.md),
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
                            spentMore ? Icons.trending_up : Icons.trending_down,
                            size: IconSize.smMd,
                            // Spending less is the good outcome, so down is
                            // green.
                            color: spentMore
                                ? semantics.expenseInk
                                : semantics.incomeInk,
                          ),
                          const SizedBox(width: Spacing.xs),
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
              const SizedBox(width: Spacing.sm),
              Text(
                '${formatCurrency(perDay, currencyCode: currencyCode)}/day',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
