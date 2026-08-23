// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryRecordAdapter extends TypeAdapter<CategoryRecord> {
  @override
  final int typeId = 7;

  @override
  CategoryRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryRecord(
      id: fields[0] as String,
      name: fields[1] as String,
      iconId: fields[2] as String,
      type: fields[3] as TransactionType,
      sortOrder: fields[4] as int,
      budget: fields[5] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconId)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.sortOrder)
      ..writeByte(5)
      ..write(obj.budget);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
