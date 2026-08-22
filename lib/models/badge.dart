import 'package:hive/hive.dart';

part 'badge.g.dart';

@HiveType(typeId: 6)
class Badge extends HiveObject {
  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.iconId,
    this.unlockedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String description;

  @HiveField(3)
  String iconId;

  @HiveField(4)
  DateTime? unlockedAt;
}
