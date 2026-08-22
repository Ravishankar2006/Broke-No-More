import 'package:hive/hive.dart';

part 'quest.g.dart';

@HiveType(typeId: 3)
enum QuestType {
  @HiveField(0)
  streak,
  @HiveField(1)
  categoryAvoid,
  @HiveField(2)
  budgetLimit,
  @HiveField(3)
  count,
}

@HiveType(typeId: 4)
enum QuestStatus {
  @HiveField(0)
  active,
  @HiveField(1)
  completed,
  @HiveField(2)
  failed,
  @HiveField(3)
  expired,
}

@HiveType(typeId: 5)
class Quest extends HiveObject {
  Quest({
    required this.id,
    required this.title,
    required this.type,
    required this.targetValue,
    this.currentProgress = 0,
    required this.startDate,
    required this.endDate,
    required this.xpReward,
    this.status = QuestStatus.active,
    this.category,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  QuestType type;

  @HiveField(3)
  int targetValue;

  @HiveField(4)
  int currentProgress;

  @HiveField(5)
  DateTime startDate;

  @HiveField(6)
  DateTime endDate;

  @HiveField(7)
  int xpReward;

  @HiveField(8)
  QuestStatus status;

  /// Category the quest targets, when relevant (categoryAvoid / budgetLimit).
  @HiveField(9)
  String? category;
}
