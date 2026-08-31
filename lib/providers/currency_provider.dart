import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/currency_formatter.dart';
import 'profile_provider.dart';

/// A currency-aware `formatCurrency` closure, current as of whatever the
/// user has selected. Shadow the top-level `formatCurrency` import with
/// `final formatCurrency = ref.watch(currencyFormatterProvider);` at the top
/// of a widget's build method — every existing `formatCurrency(x)` call in
/// that scope then picks up the active currency with no further changes.
final currencyFormatterProvider = Provider<String Function(double)>((ref) {
  final code = ref.watch(currentCurrencyCodeProvider);
  return (amount) => formatCurrency(amount, currencyCode: code);
});
