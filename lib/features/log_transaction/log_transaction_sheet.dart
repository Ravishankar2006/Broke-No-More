import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/category_icons.dart';
import '../../models/category_record.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/xp_engine_provider.dart';

class LogTransactionSheet extends ConsumerStatefulWidget {
  const LogTransactionSheet({super.key});

  @override
  ConsumerState<LogTransactionSheet> createState() => _LogTransactionSheetState();
}

class _LogTransactionSheetState extends ConsumerState<LogTransactionSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  CategoryRecord? _category;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0 || _category == null || _saving) return;

    setState(() => _saving = true);
    final result = await ref.read(xpEngineOrchestratorProvider).logTransaction(
          amount: amount,
          type: _type,
          category: _category!.name,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          timestamp: DateTime.now(),
        );
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = _type == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.lg,
        right: Spacing.lg,
        top: Spacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          SizedBox(height: Spacing.lg),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
                icon: Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
                icon: Icon(Icons.arrow_downward),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) {
              setState(() {
                _type = selection.first;
                _category = null;
              });
            },
          ),
          SizedBox(height: Spacing.lg),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: const InputDecoration(
              prefixText: '₹ ',
              hintText: '0.00',
            ),
          ),
          SizedBox(height: Spacing.lg),
          Text('Category', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: categories.map((category) {
              final selected = category.id == _category?.id;
              return ChoiceChip(
                avatar: Icon(categoryIcon(category.iconId), size: 18),
                label: Text(category.name),
                selected: selected,
                onSelected: (_) => setState(() => _category = category),
              );
            }).toList(),
          ),
          SizedBox(height: Spacing.lg),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Note (optional)',
            ),
          ),
          SizedBox(height: Spacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.onTertiary),
                      ),
                    )
                  : const Text('Log transaction'),
            ),
          ),
        ],
      ),
    );
  }
}
