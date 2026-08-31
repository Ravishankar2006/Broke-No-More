import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/transaction.dart';

/// Column order for both [transactionsToCsv] and [parseTransactionsCsv] —
/// the single definition both share, so writer and reader can't drift.
///
/// `xpAwarded` is deliberately excluded: it's a cache the gamification
/// replay recomputes from scratch on every mutation, so persisting it here
/// would just be a second, potentially stale, source of truth.
const List<String> _kCsvColumns = [
  'id',
  'timestamp',
  'type',
  'category',
  'amount',
  'note',
  'loggedAt',
  'isQuickLog',
];

/// Quotes a CSV field per RFC 4180: wrapped in double quotes, with embedded
/// quotes doubled, whenever it contains a comma, quote, or newline. A plain
/// field is left unquoted.
String _csvField(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String transactionsToCsv(List<Transaction> transactions) {
  final buffer = StringBuffer('${_kCsvColumns.join(',')}\n');
  for (final t in transactions) {
    final fields = [
      t.id,
      t.timestamp.toIso8601String(),
      t.type.name,
      t.category,
      t.amount.toString(),
      t.note ?? '',
      t.loggedAt.toIso8601String(),
      t.isQuickLog.toString(),
    ];
    buffer.writeln(fields.map(_csvField).join(','));
  }
  return buffer.toString();
}

Future<File> _writeCsvFile(List<Transaction> transactions) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(
    '${dir.path}/broke_no_more_export_${DateTime.now().millisecondsSinceEpoch}.csv',
  );
  await file.writeAsString(transactionsToCsv(transactions));
  return file;
}

/// Hands the exported CSV to the OS share sheet.
///
/// Writing to app documents storage alone (the previous "export") isn't
/// reachable by the user on Android — this is what actually gets the file
/// out of the app, to email/Drive/Files/another device.
Future<void> shareTransactionsCsv(List<Transaction> transactions) async {
  final file = await _writeCsvFile(transactions);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Broke No More export',
    ),
  );
}

/// One call to [parseTransactionsCsv]'s outcome: the rows that parsed
/// cleanly, plus a human-readable reason for each row that didn't.
///
/// Malformed rows are skipped and reported rather than aborting the whole
/// import — a single bad row in a 500-row backup shouldn't block restoring
/// the other 499.
class CsvParseResult {
  const CsvParseResult({required this.transactions, required this.errors});

  final List<Transaction> transactions;
  final List<String> errors;
}

/// Parses a CSV previously produced by [transactionsToCsv] (or a compatible
/// hand-edited file, matched by column name rather than position) back into
/// [Transaction]s.
CsvParseResult parseTransactionsCsv(String csv) {
  final rows = _parseCsvRows(csv);
  if (rows.isEmpty) return const CsvParseResult(transactions: [], errors: []);

  final header = rows.first;
  final columnIndex = <String, int>{
    for (var i = 0; i < header.length; i++) header[i].trim(): i,
  };
  final missing = _kCsvColumns.where((c) => !columnIndex.containsKey(c));
  if (missing.isNotEmpty) {
    return CsvParseResult(
      transactions: const [],
      errors: ['Missing column(s): ${missing.join(', ')}'],
    );
  }

  final transactions = <Transaction>[];
  final errors = <String>[];

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.length == 1 && row.first.isEmpty) continue; // blank line
    try {
      transactions.add(_rowToTransaction(row, columnIndex));
    } catch (e) {
      errors.add('Row ${i + 1}: $e');
    }
  }
  return CsvParseResult(transactions: transactions, errors: errors);
}

Transaction _rowToTransaction(List<String> row, Map<String, int> col) {
  String field(String name) {
    final index = col[name]!;
    if (index >= row.length) {
      throw FormatException('missing "$name"');
    }
    return row[index];
  }

  final rawType = field('type').trim();
  final type = TransactionType.values.firstWhere(
    (t) => t.name == rawType,
    orElse: () => throw FormatException('invalid type "$rawType"'),
  );

  final rawAmount = field('amount').trim();
  final amount = double.tryParse(rawAmount);
  if (amount == null || amount <= 0) {
    throw FormatException('invalid amount "$rawAmount"');
  }

  final rawTimestamp = field('timestamp').trim();
  final timestamp = DateTime.tryParse(rawTimestamp);
  if (timestamp == null) {
    throw FormatException('invalid timestamp "$rawTimestamp"');
  }
  final loggedAt = DateTime.tryParse(field('loggedAt').trim()) ?? timestamp;

  final category = field('category').trim();
  if (category.isEmpty) throw const FormatException('empty category');

  final id = field('id').trim();
  final note = field('note');
  final isQuickLog = field('isQuickLog').trim().toLowerCase() == 'true';
  final resolvedNote = note.isEmpty ? null : note;

  return Transaction(
    // A blank id (e.g. a hand-built CSV) used to get a fresh random uuid —
    // re-importing the very same file twice then created two distinct
    // rows instead of recognising the second import as a repeat, since a
    // random id can never collide with anything already on the device. A
    // content hash is stable across imports of unchanged rows, so the
    // normal existing-id conflict check downstream (profile_screen.dart)
    // can actually catch the repeat.
    id: id.isEmpty
        ? _contentHashId(
            amount: amount,
            type: type,
            category: category,
            timestamp: timestamp,
            note: resolvedNote,
          )
        : id,
    amount: amount,
    type: type,
    category: category,
    note: resolvedNote,
    timestamp: timestamp,
    loggedAt: loggedAt,
    isQuickLog: isQuickLog,
  );
}

String _contentHashId({
  required double amount,
  required TransactionType type,
  required String category,
  required DateTime timestamp,
  required String? note,
}) {
  final key =
      '$amount|${type.name}|$category|'
      '${timestamp.toIso8601String()}|${note ?? ''}';
  return 'csv-${key.hashCode.toUnsigned(32).toRadixString(16)}';
}

/// Hand-rolled RFC 4180 parser: tracks quote state across the *whole*
/// input (not line by line), so a note containing a literal newline — which
/// [_csvField] quotes rather than strips, unlike the old exporter — round
/// trips correctly.
List<List<String>> _parseCsvRows(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = 0;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = [];
  }

  while (i < input.length) {
    final char = input[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i += 2;
        } else {
          inQuotes = false;
          i++;
        }
      } else {
        field.write(char);
        i++;
      }
      continue;
    }

    if (char == '"') {
      inQuotes = true;
      i++;
    } else if (char == ',') {
      endField();
      i++;
    } else if (char == '\r') {
      i++; // normalize CRLF — the \n that follows ends the row
    } else if (char == '\n') {
      endRow();
      i++;
    } else {
      field.write(char);
      i++;
    }
  }
  // A final row with no trailing newline still needs to be flushed.
  if (field.isNotEmpty || row.isNotEmpty) {
    endRow();
  }
  return rows;
}
