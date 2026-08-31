import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';

/// Edits (or clears) the monthly budget. Returns `null` if cancelled, or a
/// `(clear, value)` record — a bare `double?` can't distinguish "the user
/// asked to clear it" from "the user cancelled", since both pop `null`.
class BudgetDialog extends StatefulWidget {
  const BudgetDialog({
    super.key,
    required this.initial,
    required this.currencySymbol,
  });

  final double? initial;
  final String currencySymbol;

  @override
  State<BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<BudgetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial?.toStringAsFixed(0) ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    // The old dialog silently closed on unparseable input, discarding the edit
    // with no explanation.
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter an amount above zero');
      return;
    }
    Navigator.of(context).pop((clear: false, value: value));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Monthly budget'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your daily allowance is this divided by the days in the month.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${widget.currencySymbol} ',
              hintText: 'e.g. 8000',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        // Only offered once a budget actually exists — clearing an unset
        // budget isn't a meaningful action.
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((clear: true, value: null)),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
