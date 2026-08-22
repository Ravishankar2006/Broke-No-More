// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quest.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuestAdapter extends TypeAdapter<Quest> {
  @override
  final int typeId = 5;

  @override
  Quest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Quest(
      id: fields[0] as String,
      title: fields[1] as String,
      type: fields[2] as QuestType,
      targetValue: fields[3] as int,
      currentProgress: fields[4] as int,
      startDate: fields[5] as DateTime,
      endDate: fields[6] as DateTime,
      xpReward: fields[7] as int,
      status: fields[8] as QuestStatus,
      category: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Quest obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.targetValue)
      ..writeByte(4)
      ..write(obj.currentProgress)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.xpReward)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuestTypeAdapter extends TypeAdapter<QuestType> {
  @override
  final int typeId = 3;

  @override
  QuestType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QuestType.streak;
      case 1:
        return QuestType.categoryAvoid;
      case 2:
        return QuestType.budgetLimit;
      case 3:
        return QuestType.count;
      default:
        return QuestType.streak;
    }
  }

  @override
  void write(BinaryWriter writer, QuestType obj) {
    switch (obj) {
      case QuestType.streak:
        writer.writeByte(0);
        break;
      case QuestType.categoryAvoid:
        writer.writeByte(1);
        break;
      case QuestType.budgetLimit:
        writer.writeByte(2);
        break;
      case QuestType.count:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QuestStatusAdapter extends TypeAdapter<QuestStatus> {
  @override
  final int typeId = 4;

  @override
  QuestStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return QuestStatus.active;
      case 1:
        return QuestStatus.completed;
      case 2:
        return QuestStatus.failed;
      case 3:
        return QuestStatus.expired;
      default:
        return QuestStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, QuestStatus obj) {
    switch (obj) {
      case QuestStatus.active:
        writer.writeByte(0);
        break;
      case QuestStatus.completed:
        writer.writeByte(1);
        break;
      case QuestStatus.failed:
        writer.writeByte(2);
        break;
      case QuestStatus.expired:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
