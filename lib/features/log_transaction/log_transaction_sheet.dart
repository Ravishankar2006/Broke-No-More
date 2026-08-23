import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/category_record.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/xp_engine_provider.dart';

/// Log a new transaction, or edit an existing one.
///
/// One sheet serves both so the two can't drift — an edit form that looked
/// different from the create form would be its own inconsistency.
///
/// Changes from the original form-style layout:
///  - the amount is the hero, not a row equal in weight to the note field;
///  - categories are an icon grid (what the PRD actually asked for) in a
///    scrollable area — the old `Wrap` inside a non-scrollable `Column` would
///    overflow with the keyboard up;
///  - validation is inline and the button disables, instead of silently
///    returning and leaving the user tapping a live button that does nothing;
///  - a date can be chosen, so yesterday's coffee is loggable at all.
class LogTransactionSheet extends ConsumerStatefulWidget {
  const LogTransactionSheet({super.key, this.existing});

  /// When set, the sheet edits this transaction instead of creating one.
  final Transaction? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<LogTransactionSheet> createState() =>
      _LogTransactionSheetState();
}

class _LogTransactionSheetState extends ConsumerState<LogTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late DateTime _date;
  CategoryRecord? _category;
  String? _pendingCategoryName;
  bool _saving = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      // Trim a trailing .0 so editing ₹180 doesn't show "180.0".
      text: existing == null ? '' : _trimAmount(existing.amount),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _type = existing?.type ?? TransactionType.expense;
    _date = existing?.timestamp ?? DateTime.now();
    // Categories aren't available until build; remember the name to match.
    _pendingCategoryName = existing?.category;
    _amountController.addListener(() {
      if (_submitted) setState(() {});
    });
  }

  static String _trimAmount(double amount) {
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _amount {
    final parsed = double.tryParse(_amountController.text.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  String? get _amountError {
    if (!_submitted) return null;
    if (_amountController.text.trim().isEmpty) return 'Enter an amount';
    if (_amount == null) return 'Enter a valid amount above zero';
    return null;
  }

  bool get _canSubmit => _amount != null && _category != null && !_saving;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // No future dating: the XP engine doesn't award anything for a day that
      // hasn't happened, so allowing it would just look broken.
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      // Keep the original time-of-day so ordering within a day is preserved.
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_canSubmit) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    final note = _noteController.text.trim();
    final orchestrator = ref.read(xpEngineOrchestratorProvider);

    final result = widget.isEditing
        ? await orchestrator.updateTransaction(
            id: widget.existing!.id,
            amount: _amount,
            type: _type,
            category: _category!.name,
            note: note.isEmpty ? null : note,
            clearNote: note.isEmpty,
            timestamp: _date,
          )
        : await orchestrator.logTransaction(
            amount: _amount!,
            type: _type,
            category: _category!.name,
            note: note.isEmpty ? null : note,
            timestamp: _date,
          );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semantics;
    final cs = theme.colorScheme;

    final categories = _type == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    // Re-attach the edited transaction's category once the list is available.
    if (_pendingCategoryName != null) {
      final match = categories
          .where((c) => c.name == _pendingCategoryName)
          .firstOrNull;
      if (match != null) {
        _category = match;
        _pendingCategoryName = null;
      }
    }

    final accent =
        _type == TransactionType.expense ? semantics.expense : semantics.income;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: Spacing.md),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            SizedBox(height: Spacing.lg),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: _TypeToggle(
                type: _type,
                onChanged: (type) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _type = type;
                    _category = null;
                  });
                },
              ),
            ),
            SizedBox(height: Spacing.xl),

            // The amount, as the hero.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(width: Spacing.sm),
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          autofocus: !widget.isEditing,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            hintStyle: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_amountError != null) ...[
                    SizedBox(height: Spacing.sm),
                    Text(
                      _amountError!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.error),
                    ),
                  ],
                  SizedBox(height: Spacing.md),
                  _DateChip(date: _date, onTap: _pickDate),
                ],
              ),
            ),
            SizedBox(height: Spacing.xl),

            // Categories as a scrollable icon grid.
            Flexible(
              child: _CategoryGrid(
                categories: categories,
                selected: _category,
                showError: _submitted && _category == null,
                onSelected: (category) {
                  HapticFeedback.selectionClick();
                  setState(() => _category = category);
                },
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Note (optional)',
                      prefixIcon: Icon(Icons.notes, size: 20),
                    ),
                  ),
                  SizedBox(height: Spacing.lg),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  cs.onTertiary,
                                ),
                              ),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Save changes'
                                  : 'Log transaction',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expense/income toggle.
///
/// The old segmented button used `arrow_upward` for Expense and
/// `arrow_downward` for Income, which is inverted from the usual reading of
/// money leaving as down. It also ignored the income/expense semantic colours
/// that already existed in the theme.
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.type, required this.onChanged});

  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(Spacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final option in TransactionType.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.quick,
                  curve: AppMotion.standardCurve,
                  padding: EdgeInsets.symmetric(vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    color: type == option
                        ? (option == TransactionType.expense
                            ? semantics.expense
                            : semantics.income)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option == TransactionType.expense
                            ? Icons.arrow_outward
                            : Icons.south_west,
                        size: 18,
                        color: type == option
                            ? Colors.white
                            : cs.onSurfaceVariant,
                      ),
                      SizedBox(width: Spacing.sm),
                      Text(
                        option == TransactionType.expense
                            ? 'Expense'
                            : 'Income',
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: type == option
                                      ? Colors.white
                                      : cs.onSurfaceVariant,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();

    final label = isSameDay(date, now)
        ? 'Today'
        : isSameDay(date, now.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : _format(date);

    return ActionChip(
      onPressed: onTap,
      avatar: Icon(Icons.calendar_today, size: 16, color: cs.onSurfaceVariant),
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium,
    );
  }

  static String _format(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.showError,
    required this.onSelected,
  });

  final List<CategoryRecord> categories;
  final CategoryRecord? selected;
  final bool showError;
  final ValueChanged<CategoryRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              Text('Category', style: theme.textTheme.titleSmall),
              if (showError) ...[
                SizedBox(width: Spacing.sm),
                Text(
                  'Pick one',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: Spacing.md),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 92,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == selected?.id;
              return _CategoryCell(
                category: category,
                selected: isSelected,
                onTap: () => onSelected(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final CategoryRecord category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.standardCurve,
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              categoryIcon(category.iconId),
              size: 24,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            SizedBox(height: Spacing.xs),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
