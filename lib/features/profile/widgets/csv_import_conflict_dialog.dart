import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/transaction.dart';

/// Whether [a] and [b] represent the same transaction content — used to tell
/// a genuine edit conflict apart from re-importing an unchanged row.
bool sameTransactionContent(Transaction a, Transaction b) {
  return a.amount == b.amount &&
      a.type == b.type &&
      a.category == b.category &&
      a.note == b.note &&
      a.timestamp.isAtSameMomentAs(b.timestamp);
}

class ImportConflict {
  const ImportConflict({required this.existing, required this.imported});

  final Transaction existing;
  final Transaction imported;
}

/// Lets the user resolve, per row, an imported transaction whose id already
/// exists on the device with different content. Defaults every row to
/// "keep existing" — the non-destructive choice for a conflict the user
/// hasn't looked at yet.
class ImportConflictDialog extends StatefulWidget {
  const ImportConflictDialog({
    super.key,
    required this.conflicts,
    required this.currencyCode,
  });

  final List<ImportConflict> conflicts;
  final String currencyCode;

  @override
  State<ImportConflictDialog> createState() => _ImportConflictDialogState();
}

class _ImportConflictDialogState extends State<ImportConflictDialog> {
  late final List<bool> _useImported = List<bool>.filled(
    widget.conflicts.length,
    false,
  );
  final _dateFormat = DateFormat('MMM d, y');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('${widget.conflicts.length} conflicting transaction(s)'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'These rows already exist on this device with different '
              'details. Choose which version to keep for each.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.conflicts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: Spacing.lg),
                itemBuilder: (context, i) {
                  final conflict = widget.conflicts[i];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict.existing.category,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        'On device: '
                        '${formatCurrency(conflict.existing.amount, currencyCode: widget.currencyCode)}'
                        ' · ${_dateFormat.format(conflict.existing.timestamp)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        'Imported: '
                        '${formatCurrency(conflict.imported.amount, currencyCode: widget.currencyCode)}'
                        ' · ${_dateFormat.format(conflict.imported.timestamp)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: Spacing.xs),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Keep existing'),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Use imported'),
                          ),
                        ],
                        selected: {_useImported[i]},
                        onSelectionChanged: (selection) =>
                            setState(() => _useImported[i] = selection.first),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel import'),
        ),
        FilledButton(
          onPressed: () {
            final resolved = [
              for (var i = 0; i < widget.conflicts.length; i++)
                if (_useImported[i]) widget.conflicts[i].imported,
            ];
            Navigator.of(context).pop(resolved);
          },
          child: const Text('Import'),
        ),
      ],
    );
  }
}
