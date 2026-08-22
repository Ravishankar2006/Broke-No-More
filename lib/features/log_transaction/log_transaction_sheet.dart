import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/categories.dart';
import '../../models/transaction.dart';
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
  SpendCategory? _category;
  bool _saving = false;

  List<SpendCategory> get _categories =>
      _type == TransactionType.expense ? kExpenseCategories : kIncomeCategories;

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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: Theme.of(context).textTheme.headlineMedium,
            decoration: const InputDecoration(
              prefixText: '₹ ',
              hintText: '0.00',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Category', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categories.map((category) {
              final selected = category.name == _category?.name;
              return ChoiceChip(
                avatar: Icon(category.icon, size: 18),
                label: Text(category.name),
                selected: selected,
                onSelected: (_) => setState(() => _category = category),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
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
                  : const Text('Log transaction'),
            ),
          ),
        ],
      ),
    );
  }
}
