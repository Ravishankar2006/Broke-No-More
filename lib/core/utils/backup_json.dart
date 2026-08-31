/// Full-device JSON backup — no Flutter/Hive dependency, same reasoning as
/// the other `core/utils` files: the encode/decode logic is independently
/// testable without box scaffolding. The actual Hive reads/writes live in
/// `core/database/hive_boxes.dart` (`restoreBackup`), which is the only
/// place that needs the real boxes.
///
/// Closes the PRD §4 "local backup" gap: until this existed, only
/// transactions round-tripped (via CSV) — profile, XP/streak state, quests,
/// badges, categories and recurring rules had no restore path at all, so
/// losing the device (or just reinstalling) meant losing every non-transaction
/// fact permanently.
library;

import '../../models/badge.dart';
import '../../models/category_record.dart';
import '../../models/quest.dart';
import '../../models/recurring_transaction.dart';
import '../../models/transaction.dart';
import '../../models/user_profile.dart';

/// Must match `core/database/hive_boxes.dart`'s `kCurrentSchemaVersion` —
/// the backup file's shape follows the on-disk Hive shape one-for-one, so
/// the same version number that gates a Hive migration also gates whether
/// this app build can make sense of a given backup file. Kept as a literal
/// rather than importing that constant to avoid a two-way dependency
/// between this file and `hive_boxes.dart` (which imports this one for the
/// actual restore I/O).
const int kBackupSchemaVersion = 1;

class BackupData {
  const BackupData({
    required this.schemaVersion,
    required this.exportedAt,
    required this.profile,
    required this.transactions,
    required this.quests,
    required this.badges,
    required this.categories,
    required this.recurringTransactions,
    required this.skippedQuestTitles,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final UserProfile profile;
  final List<Transaction> transactions;
  final List<Quest> quests;
  final List<Badge> badges;
  final List<CategoryRecord> categories;
  final List<RecurringTransaction> recurringTransactions;
  final Set<String> skippedQuestTitles;
}

Map<String, dynamic> backupToJson({
  required UserProfile profile,
  required List<Transaction> transactions,
  required List<Quest> quests,
  required List<Badge> badges,
  required List<CategoryRecord> categories,
  required List<RecurringTransaction> recurringTransactions,
  required Set<String> skippedQuestTitles,
}) {
  return {
    'schemaVersion': kBackupSchemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'profile': _profileToJson(profile),
    'transactions': transactions.map(_transactionToJson).toList(),
    'quests': quests.map(_questToJson).toList(),
    'badges': badges.map(_badgeToJson).toList(),
    'categories': categories.map(_categoryToJson).toList(),
    'recurringTransactions': recurringTransactions
        .map(_recurringToJson)
        .toList(),
    'skippedQuestTitles': skippedQuestTitles.toList(),
  };
}

/// Restoring is all-or-nothing, unlike the CSV import's per-row tolerance:
/// a partially-applied backup would leave the device in a state that never
/// genuinely existed on either device, which is worse than refusing the
/// whole file. Throws [FormatException] with a human-readable reason on
/// any structural problem.
BackupData backupFromJson(Map<String, dynamic> json) {
  final schemaVersion = json['schemaVersion'];
  if (schemaVersion is! int) {
    throw const FormatException('Missing or invalid "schemaVersion"');
  }
  if (schemaVersion > kBackupSchemaVersion) {
    throw FormatException(
      'This backup was made with a newer version of the app '
      '(schema $schemaVersion, this app supports up to '
      '$kBackupSchemaVersion) — update the app before restoring it.',
    );
  }

  final profileJson = json['profile'];
  if (profileJson is! Map) {
    throw const FormatException('Missing or invalid "profile"');
  }

  return BackupData(
    schemaVersion: schemaVersion,
    exportedAt: DateTime.tryParse('${json['exportedAt']}') ?? DateTime.now(),
    profile: _profileFromJson(profileJson.cast<String, dynamic>()),
    transactions: _list(json['transactions'], _transactionFromJson),
    quests: _list(json['quests'], _questFromJson),
    badges: _list(json['badges'], _badgeFromJson),
    categories: _list(json['categories'], _categoryFromJson),
    recurringTransactions: _list(
      json['recurringTransactions'],
      _recurringFromJson,
    ),
    skippedQuestTitles: (json['skippedQuestTitles'] as List? ?? [])
        .cast<String>()
        .toSet(),
  );
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return [];
  return [
    for (final entry in raw) parse((entry as Map).cast<String, dynamic>()),
  ];
}

DateTime _requireDate(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse('${json[key]}');
  if (parsed == null) {
    throw FormatException('Missing or invalid "$key"');
  }
  return parsed;
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return DateTime.tryParse('$value');
}

// ---------------------------------------------------------------------------
// UserProfile
// ---------------------------------------------------------------------------

Map<String, dynamic> _profileToJson(UserProfile p) => {
  'id': p.id,
  'name': p.name,
  'avatarId': p.avatarId,
  'joinDate': p.joinDate.toIso8601String(),
  'currentXP': p.currentXP,
  'level': p.level,
  'currentStreak': p.currentStreak,
  'longestStreak': p.longestStreak,
  'lastLoggedDate': p.lastLoggedDate.toIso8601String(),
  'monthlyBudget': p.monthlyBudget,
  'badgeIds': p.badgeIds,
  'streakFreezesLeft': p.streakFreezesLeft,
  'lastFreezeResetDate': p.lastFreezeResetDate.toIso8601String(),
  'lastBudgetBonusDate': p.lastBudgetBonusDate?.toIso8601String(),
  'daysUnderBudgetCount': p.daysUnderBudgetCount,
  'remindersEnabled': p.remindersEnabled,
  'currencyCode': p.currencyCode,
};

UserProfile _profileFromJson(Map<String, dynamic> json) {
  final name = json['name'];
  if (name is! String || name.isEmpty) {
    throw const FormatException('Profile is missing a name');
  }
  return UserProfile(
    // Literal rather than importing ProfileRepository.kLocalProfileKey —
    // core/utils stays below data/ in the layering, same reasoning as
    // every other engine file here.
    id: '${json['id'] ?? 'local'}',
    name: name,
    avatarId: '${json['avatarId'] ?? '🦊'}',
    joinDate: _requireDate(json, 'joinDate'),
    currentXP: (json['currentXP'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 1,
    currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
    longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
    lastLoggedDate: _optionalDate(json, 'lastLoggedDate'),
    monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble(),
    badgeIds: (json['badgeIds'] as List? ?? []).cast<String>(),
    streakFreezesLeft: (json['streakFreezesLeft'] as num?)?.toInt() ?? 1,
    lastFreezeResetDate: _optionalDate(json, 'lastFreezeResetDate'),
    lastBudgetBonusDate: _optionalDate(json, 'lastBudgetBonusDate'),
    daysUnderBudgetCount: (json['daysUnderBudgetCount'] as num?)?.toInt() ?? 0,
    remindersEnabled: json['remindersEnabled'] as bool?,
    currencyCode: json['currencyCode'] as String?,
  );
}

// ---------------------------------------------------------------------------
// Transaction
// ---------------------------------------------------------------------------

Map<String, dynamic> _transactionToJson(Transaction t) => {
  'id': t.id,
  'amount': t.amount,
  'type': t.type.name,
  'category': t.category,
  'note': t.note,
  'timestamp': t.timestamp.toIso8601String(),
  'loggedAt': t.loggedAt.toIso8601String(),
  'isQuickLog': t.isQuickLog,
  'xpAwarded': t.xpAwarded,
};

Transaction _transactionFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('Transaction is missing an id');
  }
  return Transaction(
    id: id,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    type: _enumByName(TransactionType.values, json['type'], 'type'),
    category: '${json['category'] ?? ''}',
    note: json['note'] as String?,
    timestamp: _requireDate(json, 'timestamp'),
    loggedAt:
        _optionalDate(json, 'loggedAt') ?? _requireDate(json, 'timestamp'),
    isQuickLog: json['isQuickLog'] as bool? ?? false,
    xpAwarded: (json['xpAwarded'] as num?)?.toInt(),
  );
}

// ---------------------------------------------------------------------------
// Quest
// ---------------------------------------------------------------------------

Map<String, dynamic> _questToJson(Quest q) => {
  'id': q.id,
  'title': q.title,
  'type': q.type.name,
  'targetValue': q.targetValue,
  'currentProgress': q.currentProgress,
  'startDate': q.startDate.toIso8601String(),
  'endDate': q.endDate.toIso8601String(),
  'xpReward': q.xpReward,
  'status': q.status.name,
  'category': q.category,
};

Quest _questFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('Quest is missing an id');
  }
  return Quest(
    id: id,
    title: '${json['title'] ?? ''}',
    type: _enumByName(QuestType.values, json['type'], 'type'),
    targetValue: (json['targetValue'] as num?)?.toInt() ?? 0,
    currentProgress: (json['currentProgress'] as num?)?.toInt() ?? 0,
    startDate: _requireDate(json, 'startDate'),
    endDate: _requireDate(json, 'endDate'),
    xpReward: (json['xpReward'] as num?)?.toInt() ?? 0,
    status: _enumByName(QuestStatus.values, json['status'], 'status'),
    category: json['category'] as String?,
  );
}

// ---------------------------------------------------------------------------
// Badge
// ---------------------------------------------------------------------------

Map<String, dynamic> _badgeToJson(Badge b) => {
  'id': b.id,
  'name': b.name,
  'description': b.description,
  'iconId': b.iconId,
  'unlockedAt': b.unlockedAt?.toIso8601String(),
};

Badge _badgeFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('Badge is missing an id');
  }
  return Badge(
    id: id,
    name: '${json['name'] ?? ''}',
    description: '${json['description'] ?? ''}',
    iconId: '${json['iconId'] ?? ''}',
    unlockedAt: _optionalDate(json, 'unlockedAt'),
  );
}

// ---------------------------------------------------------------------------
// CategoryRecord
// ---------------------------------------------------------------------------

Map<String, dynamic> _categoryToJson(CategoryRecord c) => {
  'id': c.id,
  'name': c.name,
  'iconId': c.iconId,
  'type': c.type.name,
  'sortOrder': c.sortOrder,
  'budget': c.budget,
};

CategoryRecord _categoryFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('Category is missing an id');
  }
  return CategoryRecord(
    id: id,
    name: '${json['name'] ?? ''}',
    iconId: '${json['iconId'] ?? ''}',
    type: _enumByName(TransactionType.values, json['type'], 'type'),
    sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    budget: (json['budget'] as num?)?.toDouble(),
  );
}

// ---------------------------------------------------------------------------
// RecurringTransaction
// ---------------------------------------------------------------------------

Map<String, dynamic> _recurringToJson(RecurringTransaction r) => {
  'id': r.id,
  'amount': r.amount,
  'type': r.type.name,
  'category': r.category,
  'note': r.note,
  'frequency': r.frequency.name,
  'startDate': r.startDate.toIso8601String(),
  'nextDueDate': r.nextDueDate.toIso8601String(),
  'endDate': r.endDate?.toIso8601String(),
  'isActive': r.isActive,
};

RecurringTransaction _recurringFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw const FormatException('Recurring rule is missing an id');
  }
  return RecurringTransaction(
    id: id,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    type: _enumByName(TransactionType.values, json['type'], 'type'),
    category: '${json['category'] ?? ''}',
    note: json['note'] as String?,
    frequency: _enumByName(
      RecurrenceFrequency.values,
      json['frequency'],
      'frequency',
    ),
    startDate: _requireDate(json, 'startDate'),
    nextDueDate:
        _optionalDate(json, 'nextDueDate') ?? _requireDate(json, 'startDate'),
    endDate: _optionalDate(json, 'endDate'),
    isActive: json['isActive'] as bool? ?? true,
  );
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, String field) {
  return values.firstWhere(
    (v) => v.name == raw,
    orElse: () => throw FormatException('Invalid "$field": "$raw"'),
  );
}
