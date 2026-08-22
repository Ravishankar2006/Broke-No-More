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
    return ref.watch(categoryRepositoryProvider).getAll(TransactionType.expense);
  }

  void refresh() {
    state = ref.read(categoryRepositoryProvider).getAll(TransactionType.expense);
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
        ExpenseCategoriesNotifier.new);

final incomeCategoriesProvider =
    NotifierProvider<IncomeCategoriesNotifier, List<CategoryRecord>>(
        IncomeCategoriesNotifier.new);
