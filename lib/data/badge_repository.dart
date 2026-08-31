import 'package:hive/hive.dart';

import '../core/database/hive_boxes.dart';
import '../core/utils/badge_engine.dart';
import '../models/badge.dart';

class BadgeRepository {
  Box<Badge> get _box => Hive.box<Badge>(HiveBoxes.badges);

  List<Badge> getAll() => _box.values.toList(growable: false);

  Set<String> get unlockedIds => _box.keys.cast<String>().toSet();

  Future<Badge> unlock(BadgeDefinition definition, {DateTime? now}) async {
    final badge = Badge(
      id: definition.id,
      name: definition.name,
      description: definition.description,
      iconId: definition.iconId,
      unlockedAt: now ?? DateTime.now(),
    );
    await _box.put(definition.id, badge);
    return badge;
  }

  /// Wipes every badge — the JSON backup restore's write path, which
  /// replaces the box wholesale rather than merging.
  Future<void> clear() => _box.clear();

  /// Writes every badge in [badges] by id, overwriting any existing row
  /// with the same id. Same reasoning as `TransactionRepository.putAll`.
  Future<void> putAll(Iterable<Badge> badges) {
    return _box.putAll({for (final b in badges) b.id: b});
  }
}
