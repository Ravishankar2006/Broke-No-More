import 'package:intl/intl.dart';

import 'currency_catalog.dart';

// One NumberFormat per currency, built once and reused — callers pass a
// plain code rather than holding a formatter themselves, so this is the
// only place that touches intl's locale data.
final Map<String, NumberFormat> _formatCache = {};

NumberFormat _formatterFor(String currencyCode) {
  return _formatCache.putIfAbsent(currencyCode, () {
    final info = currencyInfoFor(currencyCode);
    return NumberFormat.currency(
      locale: info.locale,
      symbol: info.symbol,
      decimalDigits: 2,
    );
  });
}

String formatCurrency(
  double amount, {
  String currencyCode = kDefaultCurrencyCode,
}) => _formatterFor(currencyCode).format(amount);
