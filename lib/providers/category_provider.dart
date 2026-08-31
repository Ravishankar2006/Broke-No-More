import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_repository.dart';
import '../models/category_record.dart';
import '../models/transaction.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

class ExpenseCategoriesNotifier extends Notifier<List<CategoryRecord>> {
  @override
  List<CategoryRecord> build() {
    return ref
        .watch(categoryRepositoryProvider)
        .getAll(TransactionType.expense);
  }

  void refresh() {
    state = ref
        .read(categoryRepositoryProvider)
        .getAll(TransactionType.expense);
  }
}

class IncomeCategoriesNotifier extends Notifier<List<CategoryRecord>> {
  @override
  List<CategoryRecord> build() {
    return ref.watch(categoryRepositoryProvider).getAll(TransactionType.income);
  }

  void refresh() {
    state = ref.read(categoryRepositoryProvider).getAll(TransactionType.income);
  }
}

final expenseCategoriesProvider =
    NotifierProvider<ExpenseCategoriesNotifier, List<CategoryRecord>>(
      ExpenseCategoriesNotifier.new,
    );

final incomeCategoriesProvider =
    NotifierProvider<IncomeCategoriesNotifier, List<CategoryRecord>>(
      IncomeCategoriesNotifier.new,
    );

/// Maps a category *name* to its icon id.
///
/// Transactions store their category as a plain string (PRD section 5), not as
/// a reference, so rendering a logged transaction's icon means looking the name
/// back up. Names can collide across expense/income, but the icon is only
/// decorative here, so last-write-wins is fine.
///
/// Returns null for a category the user has since deleted or renamed — callers
/// fall back to a generic icon rather than dropping the row.
final categoryIconIdsProvider = Provider<Map<String, String>>((ref) {
  return {
    for (final c in ref.watch(expenseCategoriesProvider)) c.name: c.iconId,
    for (final c in ref.watch(incomeCategoriesProvider)) c.name: c.iconId,
  };
});
