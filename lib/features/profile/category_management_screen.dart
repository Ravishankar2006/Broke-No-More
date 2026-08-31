import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/currency_catalog.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/category_record.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/xp_engine_provider.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState
    extends ConsumerState<CategoryManagementScreen> {
  TransactionType _type = TransactionType.expense;

  void _refresh() {
    ref.read(expenseCategoriesProvider.notifier).refresh();
    ref.read(incomeCategoriesProvider.notifier).refresh();
  }

  Future<void> _openEditor({CategoryRecord? existing}) async {
    final currencyCode = ref.read(currentCurrencyCodeProvider);
    final result =
        await showDialog<({String name, String iconId, double? budget})>(
          context: context,
          builder: (_) => _CategoryEditorDialog(
            type: _type,
            existing: existing,
            currencySymbol: currencyInfoFor(currencyCode).symbol,
          ),
        );
    if (result == null) return;

    final repo = ref.read(categoryRepositoryProvider);
    if (existing == null) {
      await repo.add(
        name: result.name,
        iconId: result.iconId,
        type: _type,
        budget: result.budget,
      );
    } else {
      final oldName = existing.name;
      await repo.update(
        existing,
        name: result.name,
        iconId: result.iconId,
        budget: result.budget,
      );
      if (oldName != result.name) {
        await _offerHistoryMigration(oldName, result.name);
      }
    }
    _refresh();
  }

  /// `Transaction.category` and `RecurringTransaction.category` are both
  /// denormalized strings — renaming a category here otherwise leaves every
  /// past row (and every future occurrence a recurring rule would generate)
  /// still pointing at the old name. Only prompts when there's actually
  /// something under the old name to migrate.
  Future<void> _offerHistoryMigration(String oldName, String newName) async {
    final transactionCount = ref
        .read(transactionRepositoryProvider)
        .countForCategory(oldName);
    final recurringCount = ref
        .read(recurringTransactionRepositoryProvider)
        .countForCategory(oldName);
    if (transactionCount == 0 && recurringCount == 0) return;

    final parts = [
      if (transactionCount > 0)
        '$transactionCount transaction${transactionCount == 1 ? '' : 's'}',
      if (recurringCount > 0)
        '$recurringCount recurring rule${recurringCount == 1 ? '' : 's'}',
    ];

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update existing history too?'),
        content: Text(
          '${parts.join(' and ')} still say "$oldName". Rename them to '
          '"$newName" as well?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Leave as-is'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rename everywhere'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(xpEngineOrchestratorProvider)
          .renameCategory(oldName, newName);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't update existing history — please try again."),
        ),
      );
    }
  }

  /// Confirms first, then offers an undo.
  ///
  /// Deletion used to be immediate with no confirmation and no way back, from
  /// an icon button sitting right next to the drag affordance — an easy
  /// mis-tap with a permanent result.
  Future<void> _delete(CategoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${record.name}"?'),
        content: const Text(
          'Transactions already logged under this category keep their name — '
          'only future logs are affected.',
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

    // Capture before removal so undo can rebuild it.
    final name = record.name;
    final iconId = record.iconId;
    final type = record.type;

    final removed = await ref.read(categoryRepositoryProvider).remove(record);
    if (!mounted) return;
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Can't remove the last category of a type."),
        ),
      );
      return;
    }
    _refresh();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "$name"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref
                .read(categoryRepositoryProvider)
                .add(name: name, iconId: iconId, type: type);
            _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _reorder(
    List<CategoryRecord> current,
    int oldIndex,
    int newIndex,
  ) async {
    final reordered = List<CategoryRecord>.from(current);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await ref.read(categoryRepositoryProvider).reorder(_type, reordered);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final categories = _type == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);
    final currencyCode = ref.watch(currentCurrencyCodeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage categories')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.lg,
              Spacing.lg,
              Spacing.sm,
            ),
            child: SegmentedButton<TransactionType>(
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
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              // Bottom room for the extended FAB, which used to sit on top of
              // the last row.
              padding: const EdgeInsets.only(
                top: Spacing.sm,
                bottom: Spacing.xxxl * 2,
              ),
              itemCount: categories.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorder(categories, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  key: ValueKey(category.id),
                  leading: Icon(categoryIcon(category.iconId)),
                  title: Text(category.name),
                  subtitle: category.budget != null
                      ? Text(
                          'Budget: '
                          '${formatCurrency(category.budget!, currencyCode: currencyCode)}'
                          '/mo',
                        )
                      : null,
                  onTap: () => _openEditor(existing: category),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _delete(category),
                      ),
                      // A real drag listener. This was a decorative Icon, so
                      // the one thing that looked like a handle wasn't one.
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(Spacing.sm),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
    );
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({
    required this.type,
    this.existing,
    required this.currencySymbol,
  });

  final TransactionType type;
  final CategoryRecord? existing;
  final String currencySymbol;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _budgetController = TextEditingController(
    text: widget.existing?.budget?.toStringAsFixed(0) ?? '',
  );
  late String _iconId =
      widget.existing?.iconId ?? kCategoryIconChoices.keys.first;
  String? _budgetError;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add category' : 'Edit category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            // Budgets are a spending concept — offering one for an income
            // category ("cap how much I earn") wouldn't mean anything.
            if (widget.type == TransactionType.expense) ...[
              const SizedBox(height: Spacing.lg),
              TextField(
                controller: _budgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monthly budget (optional)',
                  prefixText: '${widget.currencySymbol} ',
                  hintText: 'e.g. 2000',
                  errorText: _budgetError,
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            Text('Icon', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.sm),
            // A scrollable grid of rounded cells with an animated selection,
            // replacing a Wrap of raw CircleAvatars that had no selection
            // affordance beyond a flat colour swap.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.sm,
                  children: kCategoryIconChoices.entries.map((entry) {
                    final selected = entry.key == _iconId;
                    final cs = Theme.of(context).colorScheme;
                    // Bare icon glyphs otherwise carry zero information for a
                    // screen reader — the id doubles as a readable label
                    // since every key is already a plain English word.
                    final label =
                        entry.key[0].toUpperCase() + entry.key.substring(1);
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: label,
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => setState(() => _iconId = entry.key),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: AppMotion.quick,
                          curve: AppMotion.standardCurve,
                          width: MedallionSize.categoryCell,
                          height: MedallionSize.categoryCell,
                          decoration: BoxDecoration(
                            color: selected
                                ? cs.primary
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: selected
                                ? Border.all(color: cs.primary, width: 2)
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            size: IconSize.mdLg,
                            color: selected
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;

            double? budget;
            if (widget.type == TransactionType.expense) {
              final budgetText = _budgetController.text.trim();
              if (budgetText.isNotEmpty) {
                budget = double.tryParse(budgetText);
                if (budget == null || budget <= 0) {
                  setState(() => _budgetError = 'Enter an amount above zero');
                  return;
                }
              }
            }
            Navigator.of(
              context,
            ).pop((name: name, iconId: _iconId, budget: budget));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
