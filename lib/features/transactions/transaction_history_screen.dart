import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/xp_engine_provider.dart';
import '../../shared_widgets/celebration_effects.dart';
import '../../shared_widgets/empty_state.dart';
import '../../shared_widgets/transaction_tile.dart';
import '../log_transaction/log_transaction_sheet.dart';

/// Everything the user has logged, grouped by day.
///
/// The app previously had no way to see an individual transaction at all —
/// `transactionsProvider` was consumed only for aggregates, so money went in
/// and became unviewable. This is where it can be reviewed, corrected, or
/// removed.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  TransactionType? _typeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Copy before sorting: Hive returns insertion order and the list instance
    // is shared with the provider's state, so sorting in place would mutate
    // what other screens are rendering.
    final all = [...ref.watch(transactionsProvider)]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final filtered = all.where(_matches).toList(growable: false);
    final grouped = _groupByDay(filtered);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.sm,
              Spacing.lg,
              Spacing.md,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search category or note',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                SizedBox(height: Spacing.md),
                // Scrolls rather than overflowing: three chips plus spacing
                // exceed a 320px viewport once text scaling is turned up.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _typeFilter == null,
                        onTap: () => setState(() => _typeFilter = null),
                      ),
                      SizedBox(width: Spacing.sm),
                      _FilterChip(
                        label: 'Expenses',
                        selected: _typeFilter == TransactionType.expense,
                        onTap: () => setState(
                            () => _typeFilter = TransactionType.expense),
                      ),
                      SizedBox(width: Spacing.sm),
                      _FilterChip(
                        label: 'Income',
                        selected: _typeFilter == TransactionType.income,
                        onTap: () => setState(
                            () => _typeFilter = TransactionType.income),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: all.isEmpty
                        ? Icons.receipt_long
                        : Icons.search_off_rounded,
                    title: all.isEmpty ? 'Nothing logged yet' : 'No matches',
                    message: all.isEmpty
                        ? 'Transactions you log will show up here, newest first.'
                        : 'Try a different search or filter.',
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: Spacing.xxl),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final group = grouped[index];
                      return _DayGroup(
                        day: group.day,
                        transactions: group.transactions,
                        onEdit: _edit,
                        onDelete: _confirmDelete,
                      );
                    },
                  ),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }

  bool _matches(Transaction t) {
    if (_typeFilter != null && t.type != _typeFilter) return false;
    if (_query.trim().isEmpty) return true;
    final q = _query.trim().toLowerCase();
    return t.category.toLowerCase().contains(q) ||
        (t.note?.toLowerCase().contains(q) ?? false);
  }

  static List<({DateTime day, List<Transaction> transactions})> _groupByDay(
    List<Transaction> sorted,
  ) {
    final groups = <DateTime, List<Transaction>>{};
    for (final t in sorted) {
      (groups[startOfDay(t.timestamp)] ??= <Transaction>[]).add(t);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days) (day: day, transactions: groups[day]!),
    ];
  }

  Future<void> _edit(Transaction transaction) async {
    final result = await showModalBottomSheet<LogTransactionResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LogTransactionSheet(existing: transaction),
    );
    if (!mounted || result == null) return;
    // An edit can raise XP (a bigger under-budget day) or lower it. Only the
    // gain is worth celebrating; a loss is just a correction.
    if (result.xpGained > 0) showXpGain(context, result.xpGained);
  }

  Future<void> _confirmDelete(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: Text(
          '${formatCurrency(transaction.amount)} · ${transaction.category}\n\n'
          'Your XP, streak and quests will be recalculated without it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(xpEngineOrchestratorProvider)
        .deleteTransaction(transaction.id);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaction deleted')),
    );
  }
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.day,
    required this.transactions,
    required this.onEdit,
    required this.onDelete,
  });

  final DateTime day;
  final List<Transaction> transactions;
  final ValueChanged<Transaction> onEdit;
  final ValueChanged<Transaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;

    final spent = transactions
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.lg,
            Spacing.lg,
            Spacing.sm,
          ),
          child: Row(
            children: [
              Text(
                _dayLabel(day),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (spent > 0)
                Text(
                  formatCurrency(spent),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: semantics.expenseInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Column(
            children: [
              for (final t in transactions)
                Dismissible(
                  key: ValueKey(t.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: Spacing.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                  // Always confirm: deleting recalculates XP, streak and
                  // quests, which is far too much to happen on an accidental
                  // swipe.
                  confirmDismiss: (_) async {
                    onDelete(t);
                    return false;
                  },
                  child: TransactionTile(
                    transaction: t,
                    onTap: () => onEdit(t),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _dayLabel(DateTime day) {
    final today = startOfDay(DateTime.now());
    final diff = daysBetween(day, today);
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    final label =
        '${weekdays[day.weekday - 1]}, ${day.day} ${months[day.month - 1]}';
    return day.year == today.year
        ? label.toUpperCase()
        : '$label ${day.year}'.toUpperCase();
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
