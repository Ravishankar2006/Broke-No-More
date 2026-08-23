import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_motion.dart';
import '../../core/utils/category_icons.dart';
import '../../models/category_record.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';

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
    final result = await showDialog<({String name, String iconId})>(
      context: context,
      builder: (_) => _CategoryEditorDialog(existing: existing),
    );
    if (result == null) return;

    final repo = ref.read(categoryRepositoryProvider);
    if (existing == null) {
      await repo.add(name: result.name, iconId: result.iconId, type: _type);
    } else {
      await repo.update(existing, name: result.name, iconId: result.iconId);
    }
    _refresh();
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

  Future<void> _reorder(List<CategoryRecord> current, int oldIndex, int newIndex) async {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Manage categories')),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
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
              padding: EdgeInsets.only(
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
                        child: Padding(
                          padding: EdgeInsets.all(Spacing.sm),
                          child: const Icon(Icons.drag_handle),
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
  const _CategoryEditorDialog({this.existing});

  final CategoryRecord? existing;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _iconId = widget.existing?.iconId ?? kCategoryIconChoices.keys.first;

  @override
  void dispose() {
    _nameController.dispose();
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
            SizedBox(height: Spacing.lg),
            Text('Icon', style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: Spacing.sm),
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
                    return GestureDetector(
                      onTap: () => setState(() => _iconId = entry.key),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: AppMotion.quick,
                        curve: AppMotion.standardCurve,
                        width: 48,
                        height: 48,
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
                          size: 22,
                          color: selected
                              ? cs.onPrimary
                              : cs.onSurfaceVariant,
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
            Navigator.of(context).pop((name: name, iconId: _iconId));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
