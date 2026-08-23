import 'package:broke_no_more/core/utils/csv_export.dart';
import 'package:broke_no_more/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx({
  String id = 't1',
  double amount = 100,
  TransactionType type = TransactionType.expense,
  String category = 'Food',
  String? note,
  DateTime? timestamp,
  DateTime? loggedAt,
  bool isQuickLog = false,
}) {
  return Transaction(
    id: id,
    amount: amount,
    type: type,
    category: category,
    note: note,
    timestamp: timestamp ?? DateTime(2026, 8, 22, 12, 30),
    loggedAt: loggedAt ?? timestamp ?? DateTime(2026, 8, 22, 12, 31),
    isQuickLog: isQuickLog,
  );
}

void main() {
  group('round trip', () {
    test('a plain transaction survives export then parse unchanged', () {
      final original = _tx(note: 'lunch with friends');
      final csv = transactionsToCsv([original]);
      final result = parseTransactionsCsv(csv);

      expect(result.errors, isEmpty);
      expect(result.transactions, hasLength(1));
      final parsed = result.transactions.single;
      expect(parsed.id, original.id);
      expect(parsed.amount, original.amount);
      expect(parsed.type, original.type);
      expect(parsed.category, original.category);
      expect(parsed.note, original.note);
      expect(parsed.timestamp, original.timestamp);
      expect(parsed.loggedAt, original.loggedAt);
      expect(parsed.isQuickLog, original.isQuickLog);
    });

    test('a note containing a comma survives round trip', () {
      final original = _tx(note: 'coffee, tea, and snacks');
      final result = parseTransactionsCsv(transactionsToCsv([original]));
      expect(result.transactions.single.note, original.note);
    });

    test('a note containing a double quote survives round trip', () {
      final original = _tx(note: 'the "good" kind');
      final result = parseTransactionsCsv(transactionsToCsv([original]));
      expect(result.transactions.single.note, original.note);
    });

    test('a note containing a literal newline survives round trip', () {
      final original = _tx(note: 'line one\nline two');
      final result = parseTransactionsCsv(transactionsToCsv([original]));
      expect(result.transactions.single.note, original.note);
    });

    test('a null note round trips as null, not an empty string literal', () {
      final original = _tx();
      final result = parseTransactionsCsv(transactionsToCsv([original]));
      expect(result.transactions.single.note, isNull);
    });

    test('income and quick-log flags survive round trip', () {
      final original = _tx(
        type: TransactionType.income,
        isQuickLog: true,
      );
      final result = parseTransactionsCsv(transactionsToCsv([original]));
      final parsed = result.transactions.single;
      expect(parsed.type, TransactionType.income);
      expect(parsed.isQuickLog, isTrue);
    });

    test('multiple rows all survive, in order', () {
      final originals = [
        _tx(id: 'a', category: 'Food'),
        _tx(id: 'b', category: 'Transport', note: 'bus'),
        _tx(id: 'c', category: 'Rent & Housing', amount: 5000),
      ];
      final result = parseTransactionsCsv(transactionsToCsv(originals));
      expect(result.transactions.map((t) => t.id), ['a', 'b', 'c']);
    });
  });

  group('malformed input', () {
    test('an empty file parses to no transactions, no errors', () {
      final result = parseTransactionsCsv('');
      expect(result.transactions, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('a header-only file parses to no transactions, no errors', () {
      final result = parseTransactionsCsv(
        'id,timestamp,type,category,amount,note,loggedAt,isQuickLog\n',
      );
      expect(result.transactions, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('a file missing required columns reports one error and no rows',
        () {
      final result = parseTransactionsCsv('foo,bar\n1,2\n');
      expect(result.transactions, isEmpty);
      expect(result.errors, hasLength(1));
    });

    test('a bad row is skipped and reported without blocking the rest', () {
      final good = _tx(id: 'good');
      final csv = '${transactionsToCsv([good])}'
          'bad-id,not-a-date,expense,Food,10,,not-a-date,false\n';
      final result = parseTransactionsCsv(csv);

      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.id, 'good');
      expect(result.errors, hasLength(1));
    });

    test('a non-positive amount is rejected', () {
      const csv = 'id,timestamp,type,category,amount,note,loggedAt,isQuickLog\n'
          't1,2026-08-22T12:00:00.000,expense,Food,0,,2026-08-22T12:00:00.000,false\n';
      final result = parseTransactionsCsv(csv);
      expect(result.transactions, isEmpty);
      expect(result.errors, hasLength(1));
    });

    test('an unknown type is rejected', () {
      const csv = 'id,timestamp,type,category,amount,note,loggedAt,isQuickLog\n'
          't1,2026-08-22T12:00:00.000,transfer,Food,10,,2026-08-22T12:00:00.000,false\n';
      final result = parseTransactionsCsv(csv);
      expect(result.transactions, isEmpty);
      expect(result.errors, hasLength(1));
    });

    test('a blank id is assigned a fresh one rather than rejected', () {
      const csv = 'id,timestamp,type,category,amount,note,loggedAt,isQuickLog\n'
          ',2026-08-22T12:00:00.000,expense,Food,10,,2026-08-22T12:00:00.000,false\n';
      final result = parseTransactionsCsv(csv);
      expect(result.errors, isEmpty);
      expect(result.transactions.single.id, isNotEmpty);
    });
  });
}
