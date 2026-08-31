// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 2;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      avatarId: fields[2] as String,
      joinDate: fields[3] as DateTime,
      currentXP: fields[4] as int,
      level: fields[5] as int,
      currentStreak: fields[6] as int,
      longestStreak: fields[7] as int,
      lastLoggedDate: fields[8] as DateTime?,
      monthlyBudget: fields[9] as double?,
      badgeIds: (fields[10] as List?)?.cast<String>(),
      streakFreezesLeft: fields[11] as int,
      lastFreezeResetDate: fields[12] as DateTime?,
      lastBudgetBonusDate: fields[13] as DateTime?,
      daysUnderBudgetCount: fields[14] as int,
      remindersEnabled: fields[15] as bool?,
      currencyCode: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.avatarId)
      ..writeByte(3)
      ..write(obj.joinDate)
      ..writeByte(4)
      ..write(obj.currentXP)
      ..writeByte(5)
      ..write(obj.level)
      ..writeByte(6)
      ..write(obj.currentStreak)
      ..writeByte(7)
      ..write(obj.longestStreak)
      ..writeByte(8)
      ..write(obj.lastLoggedDate)
      ..writeByte(9)
      ..write(obj.monthlyBudget)
      ..writeByte(10)
      ..write(obj.badgeIds)
      ..writeByte(11)
      ..write(obj.streakFreezesLeft)
      ..writeByte(12)
      ..write(obj.lastFreezeResetDate)
      ..writeByte(13)
      ..write(obj.lastBudgetBonusDate)
      ..writeByte(14)
      ..write(obj.daysUnderBudgetCount)
      ..writeByte(15)
      ..write(obj.remindersEnabled)
      ..writeByte(16)
      ..write(obj.currencyCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
