import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/transaction.dart';

String transactionsToCsv(List<Transaction> transactions) {
  final buffer = StringBuffer('date,type,category,amount,note\n');
  for (final t in transactions) {
    final note = (t.note ?? '').replaceAll(',', ';').replaceAll('\n', ' ');
    buffer.writeln(
      '${t.timestamp.toIso8601String()},${t.type.name},${t.category},${t.amount},$note',
    );
  }
  return buffer.toString();
}

/// Writes transactions to a CSV file in app documents storage and returns
/// its path — this doubles as the local backup mechanism (PRD section 9).
Future<String> exportTransactionsToFile(List<Transaction> transactions) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/broke_no_more_export_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(transactionsToCsv(transactions));
  return file.path;
}
