import 'package:broke_no_more/core/utils/backup_json.dart';
import 'package:broke_no_more/models/badge.dart';
import 'package:broke_no_more/models/category_record.dart';
import 'package:broke_no_more/models/quest.dart';
import 'package:broke_no_more/models/recurring_transaction.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:broke_no_more/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile _profile() => UserProfile(
  id: 'local',
  name: 'Riya',
  avatarId: '🦊',
  joinDate: DateTime(2026, 1, 1),
  currentXP: 640,
  level: 4,
  currentStreak: 6,
  longestStreak: 14,
  lastLoggedDate: DateTime(2026, 8, 20),
  monthlyBudget: 8000,
  badgeIds: const ['first_log', 'streak_3'],
  streakFreezesLeft: 1,
  lastFreezeResetDate: DateTime(2026, 8, 18),
  lastBudgetBonusDate: DateTime(2026, 8, 19),
  daysUnderBudgetCount: 5,
  remindersEnabled: true,
  currencyCode: 'USD',
);

Transaction _transaction() => Transaction(
  id: 't1',
  amount: 249.5,
  type: TransactionType.expense,
  category: 'Food',
  note: 'lunch with a comma, and a "quote"',
  timestamp: DateTime(2026, 8, 20, 13, 30),
  loggedAt: DateTime(2026, 8, 20, 13, 32),
  isQuickLog: true,
  xpAwarded: 10,
);

Quest _quest() => Quest(
  id: 'q1',
  title: 'Spend under \$400 on Food this week',
  type: QuestType.budgetLimit,
  targetValue: 400,
  currentProgress: 120,
  startDate: DateTime(2026, 8, 15),
  endDate: DateTime(2026, 8, 22),
  xpReward: 75,
  status: QuestStatus.active,
  category: 'Food',
);

Badge _badge() => Badge(
  id: 'first_log',
  name: 'First Step',
  description: 'Log your first transaction',
  iconId: 'flag',
  unlockedAt: DateTime(2026, 8, 1),
);

CategoryRecord _category() => CategoryRecord(
  id: 'seed-expense-0',
  name: 'Food',
  iconId: 'restaurant',
  type: TransactionType.expense,
  sortOrder: 0,
  budget: 2000,
);

RecurringTransaction _recurring() => RecurringTransaction(
  id: 'r1',
  amount: 15000,
  type: TransactionType.expense,
  category: 'Rent',
  note: 'monthly rent',
  frequency: RecurrenceFrequency.monthly,
  startDate: DateTime(2026, 1, 1),
  nextDueDate: DateTime(2026, 9, 1),
  endDate: null,
  isActive: true,
);

void main() {
  group('round trip', () {
    test('backupToJson -> backupFromJson reproduces every field exactly', () {
      final json = backupToJson(
        profile: _profile(),
        transactions: [_transaction()],
        quests: [_quest()],
        badges: [_badge()],
        categories: [_category()],
        recurringTransactions: [_recurring()],
        skippedQuestTitles: {'Log 5 transactions this week'},
      );

      final data = backupFromJson(json);

      final p = data.profile;
      expect(p.id, 'local');
      expect(p.name, 'Riya');
      expect(p.avatarId, '🦊');
      expect(p.joinDate, DateTime(2026, 1, 1));
      expect(p.currentXP, 640);
      expect(p.level, 4);
      expect(p.currentStreak, 6);
      expect(p.longestStreak, 14);
      expect(p.lastLoggedDate, DateTime(2026, 8, 20));
      expect(p.monthlyBudget, 8000);
      expect(p.badgeIds, ['first_log', 'streak_3']);
      expect(p.streakFreezesLeft, 1);
      expect(p.lastFreezeResetDate, DateTime(2026, 8, 18));
      expect(p.lastBudgetBonusDate, DateTime(2026, 8, 19));
      expect(p.daysUnderBudgetCount, 5);
      expect(p.remindersEnabled, isTrue);
      expect(p.currencyCode, 'USD');

      final t = data.transactions.single;
      expect(t.id, 't1');
      expect(t.amount, 249.5);
      expect(t.type, TransactionType.expense);
      expect(t.category, 'Food');
      expect(t.note, 'lunch with a comma, and a "quote"');
      expect(t.timestamp, DateTime(2026, 8, 20, 13, 30));
      expect(t.loggedAt, DateTime(2026, 8, 20, 13, 32));
      expect(t.isQuickLog, isTrue);
      expect(t.xpAwarded, 10);

      final q = data.quests.single;
      expect(q.id, 'q1');
      expect(q.type, QuestType.budgetLimit);
      expect(q.targetValue, 400);
      expect(q.currentProgress, 120);
      expect(q.status, QuestStatus.active);
      expect(q.category, 'Food');

      final b = data.badges.single;
      expect(b.id, 'first_log');
      expect(b.unlockedAt, DateTime(2026, 8, 1));

      final c = data.categories.single;
      expect(c.id, 'seed-expense-0');
      expect(c.type, TransactionType.expense);
      expect(c.budget, 2000);

      final r = data.recurringTransactions.single;
      expect(r.id, 'r1');
      expect(r.frequency, RecurrenceFrequency.monthly);
      expect(r.nextDueDate, DateTime(2026, 9, 1));
      expect(r.endDate, isNull);
      expect(r.isActive, isTrue);

      expect(data.skippedQuestTitles, {'Log 5 transactions this week'});
      expect(data.schemaVersion, kBackupSchemaVersion);
    });

    test('an empty backup round-trips to empty lists, not errors', () {
      final json = backupToJson(
        profile: _profile(),
        transactions: const [],
        quests: const [],
        badges: const [],
        categories: const [],
        recurringTransactions: const [],
        skippedQuestTitles: const {},
      );

      final data = backupFromJson(json);

      expect(data.transactions, isEmpty);
      expect(data.quests, isEmpty);
      expect(data.badges, isEmpty);
      expect(data.categories, isEmpty);
      expect(data.recurringTransactions, isEmpty);
      expect(data.skippedQuestTitles, isEmpty);
    });

    test('null-optional fields (monthlyBudget, note, endDate, xpAwarded) '
        'round-trip as null', () {
      final profile = _profile().copyWith(clearMonthlyBudget: true);
      final json = backupToJson(
        profile: profile,
        transactions: [
          Transaction(
            id: 't2',
            amount: 10,
            type: TransactionType.income,
            category: 'Gift',
            timestamp: DateTime(2026, 8, 1),
            loggedAt: DateTime(2026, 8, 1),
            isQuickLog: false,
          ),
        ],
        quests: const [],
        badges: const [],
        categories: const [],
        recurringTransactions: [
          RecurringTransaction(
            id: 'r2',
            amount: 500,
            type: TransactionType.expense,
            category: 'Gym',
            frequency: RecurrenceFrequency.weekly,
            startDate: DateTime(2026, 1, 1),
            nextDueDate: DateTime(2026, 8, 1),
          ),
        ],
        skippedQuestTitles: const {},
      );

      final data = backupFromJson(json);

      expect(data.profile.monthlyBudget, isNull);
      expect(data.transactions.single.note, isNull);
      expect(data.transactions.single.xpAwarded, isNull);
      expect(data.recurringTransactions.single.endDate, isNull);
    });
  });

  group('backupFromJson validation', () {
    test('rejects a backup with no schemaVersion', () {
      expect(
        () => backupFromJson({'profile': _validProfileJson()}),
        throwsFormatException,
      );
    });

    test('rejects a backup from a newer schema version', () {
      expect(
        () => backupFromJson({
          'schemaVersion': kBackupSchemaVersion + 1,
          'profile': _validProfileJson(),
        }),
        throwsFormatException,
      );
    });

    test('rejects a backup with no profile', () {
      expect(
        () => backupFromJson({'schemaVersion': kBackupSchemaVersion}),
        throwsFormatException,
      );
    });

    test('rejects a profile with no name', () {
      expect(
        () => backupFromJson({
          'schemaVersion': kBackupSchemaVersion,
          'profile': {'joinDate': '2026-01-01T00:00:00.000'},
        }),
        throwsFormatException,
      );
    });

    test('rejects a transaction with no id', () {
      expect(
        () => backupFromJson({
          'schemaVersion': kBackupSchemaVersion,
          'profile': _validProfileJson(),
          'transactions': [
            {'amount': 10, 'type': 'expense', 'category': 'Food'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects an invalid enum value', () {
      expect(
        () => backupFromJson({
          'schemaVersion': kBackupSchemaVersion,
          'profile': _validProfileJson(),
          'transactions': [
            {
              'id': 't1',
              'amount': 10,
              'type': 'not-a-real-type',
              'category': 'Food',
              'timestamp': '2026-01-01T00:00:00.000',
            },
          ],
        }),
        throwsFormatException,
      );
    });
  });
}

Map<String, dynamic> _validProfileJson() => {
  'name': 'Test',
  'joinDate': '2026-01-01T00:00:00.000',
};
