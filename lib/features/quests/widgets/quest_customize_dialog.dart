import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/quest_template_engine.dart';
import '../../../models/quest.dart';

/// What accepting a customized quest needs beyond the original candidate.
typedef CustomizedQuest = ({QuestCandidate candidate, int durationDays});

/// PRD §4/§7 lists accept / skip / **customize** as the three quest
/// responses; only the first two were ever built. Lets the user adjust the
/// target and duration before accepting, rather than take-it-or-leave-it on
/// whatever the rule engine happened to generate.
class QuestCustomizeDialog extends StatefulWidget {
  const QuestCustomizeDialog({
    super.key,
    required this.candidate,
    required this.currencySymbol,
  });

  final QuestCandidate candidate;
  final String currencySymbol;

  @override
  State<QuestCustomizeDialog> createState() => _QuestCustomizeDialogState();
}

class _QuestCustomizeDialogState extends State<QuestCustomizeDialog> {
  late int _target = widget.candidate.targetValue.clamp(_minTarget, _maxTarget);
  late final _amountController = TextEditingController(
    text: '${widget.candidate.targetValue}',
  );
  int _durationDays = kQuestDurationDays;
  String? _amountError;

  bool get _isAmount => widget.candidate.type == QuestType.budgetLimit;

  int get _minTarget => 1;

  /// A categoryAvoid quest can't ask for more avoid-days than the quest
  /// itself runs for — the evaluator clamps progress to the window, so a
  /// target past the duration would simply be unreachable.
  int get _maxTarget => switch (widget.candidate.type) {
    QuestType.streak => 60,
    QuestType.count => 50,
    QuestType.categoryAvoid => _durationDays,
    QuestType.budgetLimit => 1, // unused — amount uses a text field instead
  };

  String get _targetLabel => switch (widget.candidate.type) {
    QuestType.streak => 'Target streak length',
    QuestType.count => 'Transactions to log',
    QuestType.categoryAvoid => 'Days to avoid',
    QuestType.budgetLimit => 'Spending limit',
  };

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    var target = _target;
    if (_isAmount) {
      final amount = int.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        setState(() => _amountError = 'Enter an amount above zero');
        return;
      }
      target = amount;
    }
    final candidate = widget.candidate.withTarget(
      target,
      currencySymbol: widget.currencySymbol,
    );
    final result = (candidate: candidate, durationDays: _durationDays);
    Navigator.of(context).pop<CustomizedQuest>(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A duration change can invalidate an avoid-days target chosen against
    // a longer window — clamp rather than let it silently become unreachable.
    if (_target > _maxTarget) _target = _maxTarget;

    return AlertDialog(
      title: const Text('Customize quest'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_targetLabel, style: theme.textTheme.labelMedium),
            const SizedBox(height: Spacing.sm),
            if (_isAmount)
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '${widget.currencySymbol} ',
                  errorText: _amountError,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _target.toDouble(),
                      min: _minTarget.toDouble(),
                      max: _maxTarget.toDouble(),
                      divisions: _maxTarget - _minTarget,
                      label: '$_target',
                      onChanged: (value) =>
                          setState(() => _target = value.round()),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('$_target', textAlign: TextAlign.end),
                  ),
                ],
              ),
            const SizedBox(height: Spacing.lg),
            Text('Duration', style: theme.textTheme.labelMedium),
            const SizedBox(height: Spacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 days')),
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 14, label: Text('14 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
              ],
              selected: {_durationDays},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _durationDays = selection.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Use custom quest')),
      ],
    );
  }
}
