import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_elevation.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/currency_catalog.dart';
import '../../core/utils/date_helpers.dart';
import '../../models/category_record.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/xp_engine_provider.dart';
import '../../shared_widgets/celebration_effects.dart';
import '../../shared_widgets/discard_changes_guard.dart';

/// Round, currency-agnostic amounts for the quick-entry chips — not tuned
/// per currency (that would need a table of "sensible round numbers" per
/// currency this app has no data to justify), just fast taps for the
/// common small-to-medium expense sizes.
const List<double> _kQuickAmounts = [50, 100, 200, 500, 1000];

/// Blocks anything that can't become a valid amount as the user types —
/// "1.2.3" or a third decimal digit previously stayed typable and were
/// only ever caught at submit time.
class _DecimalAmountFormatter extends TextInputFormatter {
  static final _pattern = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _pattern.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

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

  bool get _isDirty {
    final existing = widget.existing;
    if (existing == null) {
      return _amountController.text.trim().isNotEmpty ||
          _category != null ||
          _noteController.text.trim().isNotEmpty;
    }
    return _amountController.text.trim() != _trimAmount(existing.amount) ||
        _type != existing.type ||
        _category?.name != existing.category ||
        _noteController.text.trim() != (existing.note ?? '') ||
        _date != existing.timestamp;
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

  /// [addAnother] keeps the sheet open and resets amount/category/note for
  /// a second entry instead of popping — splitting one shopping trip into
  /// several categories previously meant closing and reopening the sheet
  /// each time.
  Future<void> _submit({bool addAnother = false}) async {
    setState(() => _submitted = true);
    if (!_canSubmit) {
      unawaited(HapticFeedback.heavyImpact());
      return;
    }

    setState(() => _saving = true);
    final note = _noteController.text.trim();
    final orchestrator = ref.read(xpEngineOrchestratorProvider);

    try {
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
      if (addAnother) {
        if (result.xpGained > 0) showXpGain(context, result.xpGained);
        unawaited(HapticFeedback.lightImpact());
        setState(() {
          _amountController.clear();
          _noteController.clear();
          _category = null;
          _submitted = false;
          _saving = false;
          // Type and date carry over — a multi-item receipt is usually the
          // same type logged on the same day, one category at a time.
        });
      } else {
        Navigator.of(context).pop(result);
      }
    } catch (_) {
      // The orchestrator throws on a re-entrant mutation or a disk error.
      // Without this, `_saving` stayed true forever and the Save button
      // was permanently dead — the only feedback was a red unhandled-error
      // screen in debug and nothing at all in release.
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
    final semantics = context.semantics;
    final cs = theme.colorScheme;

    final categories = _type == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);
    final recentCategoryNames = ref.watch(recentCategoryNamesProvider(_type));
    final currencySymbol = currencyInfoFor(
      ref.watch(currentCurrencyCodeProvider),
    ).symbol;

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

    final accent = _type == TransactionType.expense
        ? semantics.expense
        : semantics.income;

    return DiscardChangesGuard(
      isDirty: _isDirty,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: Spacing.md),
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
              const SizedBox(height: Spacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
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
              const SizedBox(height: Spacing.xl),

              // The amount, as the hero.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          currencySymbol,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        // IntrinsicWidth alone collapses to the hint's width, so
                        // an empty field rendered as a bare cursor next to the
                        // rupee sign and looked broken. A minimum keeps the
                        // target tappable and the zero legible.
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 90),
                          child: IntrinsicWidth(
                            child: TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [_DecimalAmountFormatter()],
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
                                hintStyle: theme.textTheme.displaySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurfaceVariant.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_amountError != null) ...[
                      const SizedBox(height: Spacing.sm),
                      Text(
                        _amountError!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.md),
                    _DateChip(date: _date, onTap: _pickDate),
                    const SizedBox(height: Spacing.md),
                    _QuickAmountRow(
                      currencySymbol: currencySymbol,
                      onSelected: (amount) {
                        HapticFeedback.selectionClick();
                        _amountController.text =
                            amount == amount.roundToDouble()
                            ? amount.toStringAsFixed(0)
                            : amount.toStringAsFixed(2);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Categories as a scrollable icon grid.
              Flexible(
                child: _CategoryGrid(
                  categories: categories,
                  recentNames: recentCategoryNames,
                  selected: _category,
                  showError: _submitted && _category == null,
                  onSelected: (category) {
                    HapticFeedback.selectionClick();
                    setState(() => _category = category);
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
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
                        prefixIcon: Icon(Icons.notes, size: IconSize.md),
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    Row(
                      children: [
                        // Only for a fresh log — "add another" mid-edit of
                        // an existing transaction doesn't make sense.
                        if (!widget.isEditing) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => _submit(addAnother: true),
                              child: const Text('Save & add another'),
                            ),
                          ),
                          const SizedBox(width: Spacing.md),
                        ],
                        Expanded(
                          flex: widget.isEditing ? 1 : 2,
                          child: FilledButton(
                            onPressed: _saving ? null : () => _submit(),
                            child: _saving
                                ? SizedBox(
                                    height: IconSize.md,
                                    width: IconSize.md,
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
                  ],
                ),
              ),
            ],
          ),
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

    Color accentFor(TransactionType option) => option == TransactionType.expense
        ? semantics.expenseInk
        : semantics.incomeInk;

    return Container(
      padding: const EdgeInsets.all(Spacing.xs),
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
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  decoration: BoxDecoration(
                    // A raised neutral pill carries the selection; the semantic
                    // colour is applied to the label instead. Filling the whole
                    // segment with saturated red meant the sheet opened
                    // shouting, on its *default* state — the PRD is explicit
                    // that the app must not feel punitive.
                    color: type == option ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: type == option
                        ? AppShadows.card(Theme.of(context).brightness)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option == TransactionType.expense
                            ? Icons.arrow_outward
                            : Icons.south_west,
                        size: IconSize.smMd,
                        color: type == option
                            ? accentFor(option)
                            : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        option == TransactionType.expense
                            ? 'Expense'
                            : 'Income',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: type == option
                              ? accentFor(option)
                              : cs.onSurfaceVariant,
                          fontWeight: type == option ? FontWeight.w700 : null,
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

/// A row of round-number amount chips — tapping one fills the amount field
/// instead of typing it out, for the common case of a round-ish spend.
class _QuickAmountRow extends StatelessWidget {
  const _QuickAmountRow({
    required this.currencySymbol,
    required this.onSelected,
  });

  final String currencySymbol;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kQuickAmounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
        itemBuilder: (context, index) {
          final amount = _kQuickAmounts[index];
          return ActionChip(
            onPressed: () => onSelected(amount),
            label: Text('$currencySymbol${amount.toStringAsFixed(0)}'),
            labelStyle: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          );
        },
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
      avatar: Icon(
        Icons.calendar_today,
        size: IconSize.sm,
        color: cs.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: theme.textTheme.labelMedium,
    );
  }

  static String _format(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.recentNames,
    required this.selected,
    required this.showError,
    required this.onSelected,
  });

  final List<CategoryRecord> categories;

  /// Most-recently-used category names, most recent first — see
  /// `recentCategoryNamesProvider`. Rendered as a shortcut row above the
  /// full grid so the common case (the same few categories, over and over)
  /// doesn't need a scroll every time.
  final List<String> recentNames;
  final CategoryRecord? selected;
  final bool showError;
  final ValueChanged<CategoryRecord> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Preserve recency order; a category can be renamed/deleted since it
    // was last used, so drop names no longer in the live list.
    final byName = {for (final c in categories) c.name: c};
    final recent = [for (final name in recentNames) ?byName[name]];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Row(
            children: [
              Text('Category', style: theme.textTheme.titleSmall),
              if (showError) ...[
                const SizedBox(width: Spacing.sm),
                Text(
                  'Pick one',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
            ],
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: Spacing.sm),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
              itemBuilder: (context, index) {
                final category = recent[index];
                final isSelected = category.id == selected?.id;
                return ActionChip(
                  onPressed: () => onSelected(category),
                  avatar: Icon(
                    categoryIcon(category.iconId),
                    size: IconSize.sm,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  label: Text(category.name),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                  backgroundColor: isSelected
                      ? cs.primary
                      : cs.surfaceContainerHigh,
                  side: BorderSide.none,
                );
              },
            ),
          ),
        ],
        const SizedBox(height: Spacing.md),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 92,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.88,
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
              size: IconSize.lg,
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: Spacing.xs),
            Padding(
              // Tight, so "Entertainment" fits on one line instead of
              // breaking a single trailing letter onto a second.
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
              child: Text(
                category.name,
                // Two lines: names like "Bills & Utilities" and "Rent &
                // Housing" truncated to an unreadable stub on one.
                maxLines: 2,
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
