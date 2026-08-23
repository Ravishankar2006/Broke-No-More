import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_semantic_colors.dart';
import '../core/utils/category_icons.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction.dart';
import '../providers/category_provider.dart';

/// One logged transaction as a list row.
///
/// Shared by Home's recent list and the history screen so a transaction looks
/// the same wherever it appears. Until now nothing in the app rendered an
/// individual transaction at all — logged money went straight into an aggregate
/// and became unviewable.
class TransactionTile extends ConsumerWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.showXp = true,
    this.showDate = false,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  /// Shows the "+N XP" chip when the replay attributed XP to this row.
  final bool showXp;

  /// Shows the date alongside the category — for lists that aren't already
  /// grouped by day.
  final bool showDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final cs = theme.colorScheme;

    final isExpense = transaction.type == TransactionType.expense;
    final amountColor = isExpense ? semantics.expenseInk : semantics.incomeInk;

    final iconId = ref.watch(categoryIconIdsProvider)[transaction.category];
    final icon = iconId == null ? Icons.category : categoryIcon(iconId);

    final xp = transaction.xpAwarded;
    final subtitle = [
      if (showDate) _formatDay(transaction.timestamp),
      if (transaction.note != null && transaction.note!.trim().isNotEmpty)
        transaction.note!.trim()
      else
        transaction.category,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isExpense ? semantics.expense : semantics.income)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, size: 20, color: amountColor),
              ),
              SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    SizedBox(height: Spacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              SizedBox(width: Spacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? '−' : '+'}${formatCurrency(transaction.amount)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showXp && xp != null && xp > 0) ...[
                    SizedBox(height: Spacing.xxs),
                    Text(
                      '+$xp XP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: semantics.goldInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDay(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
