import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category_record.dart';
import '../../../shared_widgets/animated_progress_bar.dart';
import '../../../shared_widgets/app_card.dart';

/// Spend-this-month against each category that has a budget set (Profile >
/// Manage categories) — only categories that opted in appear here.
class CategoryBudgetsCard extends StatelessWidget {
  const CategoryBudgetsCard({
    super.key,
    required this.categories,
    required this.spentByCategory,
    required this.currencyCode,
  });

  final List<CategoryRecord> categories;
  final Map<String, double> spentByCategory;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == categories.length - 1 ? 0 : Spacing.lg,
              ),
              child: _CategoryBudgetRow(
                category: categories[i],
                spent: spentByCategory[categories[i].name] ?? 0,
                currencyCode: currencyCode,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.category,
    required this.spent,
    required this.currencyCode,
  });

  final CategoryRecord category;
  final double spent;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final budget = category.budget!;
    final isOver = spent > budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              categoryIcon(category.iconId),
              size: IconSize.smMd,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${formatCurrency(spent, currencyCode: currencyCode)} / '
              '${formatCurrency(budget, currencyCode: currencyCode)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isOver ? semantics.expenseInk : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        AnimatedProgressBar(
          value: budget == 0 ? 0 : spent / budget,
          variant: ProgressVariant.budget,
          isOver: isOver,
        ),
      ],
    );
  }
}
