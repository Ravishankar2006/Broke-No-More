import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/database/hive_boxes.dart';
import '../core/utils/backup_json.dart';
import '../models/transaction.dart';
import 'badge_repository.dart';
import 'category_repository.dart';
import 'profile_repository.dart';
import 'quest_repository.dart';
import 'recurring_transaction_repository.dart';
import 'skipped_quest_repository.dart';
import 'transaction_repository.dart';

export '../core/utils/backup_json.dart' show BackupData, backupFromJson;

/// Writes [json] to a file and hands it to the OS share sheet — same
/// pattern as `csv_export.dart`'s `shareTransactionsCsv`.
Future<void> shareBackupFile(Map<String, dynamic> json) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(
    '${dir.path}/broke_no_more_backup_${DateTime.now().millisecondsSinceEpoch}.json',
  );
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Broke No More backup',
    ),
  );
}

/// Collects a full-device snapshot from every repository into one JSON-ready
/// map — the counterpart the Profile screen hands to [restoreBackup] later.
///
/// Throws [StateError] if there's no profile yet: a backup without one
/// can't be restored (see [restoreBackup]), so building one would be
/// pointless.
Map<String, dynamic> buildBackupJson() {
  final profile = ProfileRepository().current;
  if (profile == null) {
    throw StateError('buildBackupJson called before a profile exists');
  }
  return backupToJson(
    profile: profile,
    transactions: TransactionRepository().getAll(),
    quests: QuestRepository().getAll(),
    badges: BadgeRepository().getAll(),
    categories: [
      ...CategoryRepository().getAll(TransactionType.expense),
      ...CategoryRepository().getAll(TransactionType.income),
    ],
    recurringTransactions: RecurringTransactionRepository().getAll(),
    skippedQuestTitles: SkippedQuestRepository().titles,
  );
}

/// Replaces every box's contents with [data] — full disaster recovery, not
/// a merge. Each box is cleared and rewritten independently; there's no
/// partial-failure case that leaves things inconsistent, since every write
/// here is idempotent and the data was already validated by
/// [backupFromJson] before this runs.
Future<void> restoreBackup(BackupData data) async {
  await TransactionRepository().clear();
  await ProfileRepository().delete();
  await QuestRepository().clear();
  await BadgeRepository().clear();
  await CategoryRepository().clear();
  await RecurringTransactionRepository().clear();

  await TransactionRepository().putAll(data.transactions);
  await ProfileRepository().save(data.profile);
  await QuestRepository().putAll(data.quests);
  await BadgeRepository().putAll(data.badges);
  await CategoryRepository().putAll(data.categories);
  await RecurringTransactionRepository().putAll(data.recurringTransactions);
  await SkippedQuestRepository().replaceAll(data.skippedQuestTitles);

  // Keeps the "ever seeded" tracker consistent with what's actually in the
  // restored categories box — otherwise the next default-category reseed
  // could either duplicate a restored seed category or resurrect one the
  // backed-up device had deliberately deleted.
  final restoredSeedIds = data.categories
      .map((c) => c.id)
      .where((id) => id.startsWith('seed-'))
      .toList();
  await Hive.box<dynamic>(
    HiveBoxes.appState,
  ).put(kSeededCategoryIdsKey, restoredSeedIds);
}
