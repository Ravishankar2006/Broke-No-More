import 'package:hive/hive.dart';

import 'transaction.dart';

part 'category_record.g.dart';

/// A user-editable spend/income category for the log-transaction grid
/// (Profile > Manage categories). Transactions store the category as a
/// plain string (PRD section 5), so renaming or deleting one here only
/// affects future logs — past transactions keep whatever name they were
/// logged under.
@HiveType(typeId: 7)
class CategoryRecord extends HiveObject {
  CategoryRecord({
    required this.id,
    required this.name,
    required this.iconId,
    required this.type,
    required this.sortOrder,
    this.budget,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String iconId;

  @HiveField(3)
  TransactionType type;

  @HiveField(4)
  int sortOrder;

  /// Optional monthly spending cap for this category. Expense categories
  /// only in practice — the editor doesn't offer it for income — but not
  /// enforced at the model layer, matching how [TransactionType] itself
  /// isn't restricted here either.
  @HiveField(5)
  double? budget;
}
