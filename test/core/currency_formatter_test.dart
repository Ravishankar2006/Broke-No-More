import 'package:broke_no_more/core/utils/currency_catalog.dart';
import 'package:broke_no_more/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to the rupee symbol for backward compatibility', () {
    expect(formatCurrency(1234.5), contains('₹'));
  });

  test('formats using the requested currency symbol', () {
    expect(formatCurrency(1234.5, currencyCode: 'USD'), contains(r'$'));
    expect(formatCurrency(1234.5, currencyCode: 'EUR'), contains('€'));
    expect(formatCurrency(1234.5, currencyCode: 'GBP'), contains('£'));
  });

  test('falls back to the first catalog entry for an unknown code', () {
    // currencyInfoFor is the single source of truth formatCurrency defers
    // to — an unrecognized code (a corrupted or pre-catalog profile) must
    // not throw.
    expect(currencyInfoFor('XXX'), kSupportedCurrencies.first);
    expect(
      formatCurrency(10, currencyCode: 'XXX'),
      formatCurrency(10, currencyCode: kSupportedCurrencies.first.code),
    );
  });

  test('every catalog entry formats without throwing', () {
    for (final currency in kSupportedCurrencies) {
      expect(
        () => formatCurrency(999.99, currencyCode: currency.code),
        returnsNormally,
      );
    }
  });
}
