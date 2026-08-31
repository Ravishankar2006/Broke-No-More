import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/hive_boxes.dart';
import '../models/category_record.dart';
import '../models/transaction.dart';

class CategoryRepository {
  Box<CategoryRecord> get _box =>
      Hive.box<CategoryRecord>(HiveBoxes.categories);

  List<CategoryRecord> getAll(TransactionType type) {
    final list = _box.values.where((c) => c.type == type).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<CategoryRecord> add({
    required String name,
    required String iconId,
    required TransactionType type,
    double? budget,
  }) async {
    final record = CategoryRecord(
      id: const Uuid().v4(),
      name: name,
      iconId: iconId,
      type: type,
      sortOrder: getAll(type).length,
      budget: budget,
    );
    await _box.add(record);
    return record;
  }

  Future<void> update(
    CategoryRecord record, {
    required String name,
    required String iconId,
    double? budget,
  }) async {
    record
      ..name = name
      ..iconId = iconId
      ..budget = budget;
    await record.save();
  }

  /// Refuses to remove the last category of a type — the log-transaction
  /// grid needs at least one option to stay usable.
  Future<bool> remove(CategoryRecord record) async {
    if (getAll(record.type).length <= 1) return false;
    await record.delete();
    return true;
  }

  Future<void> reorder(
    TransactionType type,
    List<CategoryRecord> newOrder,
  ) async {
    for (var i = 0; i < newOrder.length; i++) {
      newOrder[i].sortOrder = i;
      await newOrder[i].save();
    }
  }

  /// Wipes every category — the JSON backup restore's write path, which
  /// replaces the box wholesale rather than merging.
  Future<void> clear() => _box.clear();

  /// Adds every category in [categories] under a fresh auto-assigned box
  /// key — categories are looked up by their `.id` field everywhere in the
  /// app, never by Hive box key, so (unlike `TransactionRepository.putAll`)
  /// there's no id-keyed `put` to preserve here.
  Future<void> putAll(Iterable<CategoryRecord> categories) async {
    for (final c in categories) {
      await _box.add(c);
    }
  }
}
