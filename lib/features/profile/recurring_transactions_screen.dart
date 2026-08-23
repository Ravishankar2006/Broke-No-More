import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../shared_widgets/app_card.dart';
import '../../shared_widgets/empty_state.dart';

String recurrenceFrequencyLabel(RecurrenceFrequency frequency) {
  return switch (frequency) {
    RecurrenceFrequency.daily => 'Daily',
    RecurrenceFrequency.weekly => 'Weekly',
    RecurrenceFrequency.monthly => 'Monthly',
  };
}

/// Standing rules (rent, subscriptions, an allowance) that log themselves on
/// schedule instead of the user re-entering the same transaction every
/// period — the exact friction the streak mechanic otherwise punishes.
class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = [...ref.watch(recurringTransactionsProvider)]
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    final iconIds = ref.watch(categoryIconIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring transactions')),
      body: rules.isEmpty
          ? EmptyState(
              icon: Icons.autorenew_rounded,
              title: 'Nothing set up yet',
              message: 'Rent, a subscription, an allowance — set it up once '
                  'and it logs itself on schedule from here on.',
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                Spacing.xxxl * 2,
              ),
              itemCount: rules.length,
              itemBuilder: (context, index) {
                final rule = rules[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: Spacing.md),
                  child: _RecurringTransactionCard(
                    rule: rule,
                    iconId: iconIds[rule.category],
                    onTap: () => _openEditor(context, ref, existing: rule),
                    onToggleActive: (active) => ref
                        .read(recurringTransactionRepositoryProvider)
                        .setActive(rule, active)
                        .then((_) => ref
                            .read(recurringTransactionsProvider.notifier)
                            .refresh()),
                    onDelete: () => _delete(context, ref, rule),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add recurring'),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    RecurringTransaction? existing,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecurringTransactionEditorSheet(existing: existing),
    );
    if (saved == true) {
      ref.read(recurringTransactionsProvider.notifier).refresh();
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${rule.category}"?'),
        content: const Text(
          'Transactions this rule already logged are kept — only future '
          'occurrences stop.',
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
    if (confirmed != true || !context.mounted) return;

    await ref.read(recurringTransactionRepositoryProvider).delete(rule.id);
    ref.read(recurringTransactionsProvider.notifier).refresh();
  }
}

class _RecurringTransactionCard extends StatelessWidget {
  const _RecurringTransactionCard({
    required this.rule,
    required this.iconId,
    required this.onTap,
    required this.onToggleActive,
    required this.onDelete,
  });

  final RecurringTransaction rule;
  final String? iconId;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final isExpense = rule.type == TransactionType.expense;
    final amountColor = isExpense ? semantics.expenseInk : semantics.incomeInk;
    final icon = iconId == null ? Icons.category : categoryIcon(iconId!);
    final dateFormat = DateFormat('MMM d, y');

    return Opacity(
      // Paused rules recede rather than disappear — the setup is still
      // there, just dormant.
      opacity: rule.isActive ? 1 : 0.6,
      child: AppCard(
        onTap: onTap,
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
                    rule.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  SizedBox(height: Spacing.xxs),
                  Text(
                    rule.isActive
                        ? '${recurrenceFrequencyLabel(rule.frequency)} · '
                            'Next ${dateFormat.format(rule.nextDueDate)}'
                        : '${recurrenceFrequencyLabel(rule.frequency)} · Paused',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Spacing.sm),
            Text(
              '${isExpense ? '−' : '+'}${formatCurrency(rule.amount)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: Spacing.xs),
            Switch(value: rule.isActive, onChanged: onToggleActive),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTransactionEditorSheet extends ConsumerStatefulWidget {
  const _RecurringTransactionEditorSheet({this.existing});

  final RecurringTransaction? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<_RecurringTransactionEditorSheet> createState() =>
      _RecurringTransactionEditorSheetState();
}

class _RecurringTransactionEditorSheetState
    extends ConsumerState<_RecurringTransactionEditorSheet> {
  late TransactionType _type = widget.existing?.type ?? TransactionType.expense;
  late final _amountController = TextEditingController(
    text: widget.existing?.amount.toStringAsFixed(0) ?? '',
  );
  late final _noteController =
      TextEditingController(text: widget.existing?.note ?? '');
  late String? _category = widget.existing?.category;
  late RecurrenceFrequency _frequency =
      widget.existing?.frequency ?? RecurrenceFrequency.monthly;
  late DateTime _startDate = widget.existing?.startDate ?? DateTime.now();
  DateTime? _endDate;
  bool _submitted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _endDate = widget.existing?.endDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  bool get _canSubmit =>
      _amount != null && _amount! > 0 && _category != null && !_saving;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_canSubmit) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    final note = _noteController.text.trim();
    final repo = ref.read(recurringTransactionRepositoryProvider);

    try {
      if (widget.isEditing) {
        await repo.update(
          widget.existing!,
          amount: _amount!,
          type: _type,
          category: _category!,
          note: note.isEmpty ? null : note,
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        await repo.add(
          amount: _amount!,
          type: _type,
          category: _category!,
          note: note.isEmpty ? null : note,
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save — please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, y');
    final categories = _type == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    // The category list changed type (or a saved category no longer
    // exists) — drop a selection that's no longer valid rather than
    // silently submitting a stale one.
    if (_category != null && !categories.any((c) => c.name == _category)) {
      _category = null;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Edit recurring' : 'Add recurring',
                  style: theme.textTheme.titleLarge,
                ),
                SizedBox(height: Spacing.lg),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Expense'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Income'),
                    ),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => setState(() {
                    _type = selection.first;
                  }),
                ),
                SizedBox(height: Spacing.lg),
                TextField(
                  controller: _amountController,
                  autofocus: !widget.isEditing,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    errorText: _submitted && _amount == null
                        ? 'Enter an amount above zero'
                        : null,
                  ),
                ),
                SizedBox(height: Spacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    errorText: _submitted && _category == null
                        ? 'Pick a category'
                        : null,
                  ),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.name, child: Text(c.name)),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                ),
                SizedBox(height: Spacing.lg),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                ),
                SizedBox(height: Spacing.lg),
                Text('Repeats', style: theme.textTheme.titleSmall),
                SizedBox(height: Spacing.sm),
                SegmentedButton<RecurrenceFrequency>(
                  segments: const [
                    ButtonSegment(
                      value: RecurrenceFrequency.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment(
                      value: RecurrenceFrequency.weekly,
                      label: Text('Weekly'),
                    ),
                    ButtonSegment(
                      value: RecurrenceFrequency.monthly,
                      label: Text('Monthly'),
                    ),
                  ],
                  selected: {_frequency},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => setState(() {
                    _frequency = selection.first;
                  }),
                ),
                SizedBox(height: Spacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickStartDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('Starts ${dateFormat.format(_startDate)}'),
                      ),
                    ),
                    SizedBox(width: Spacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEndDate,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _endDate == null
                              ? 'No end date'
                              : 'Ends ${dateFormat.format(_endDate!)}',
                        ),
                      ),
                    ),
                  ],
                ),
                if (_endDate != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _endDate = null),
                      child: const Text('Clear end date'),
                    ),
                  ),
                SizedBox(height: Spacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.isEditing ? 'Save' : 'Add'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
