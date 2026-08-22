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
}
