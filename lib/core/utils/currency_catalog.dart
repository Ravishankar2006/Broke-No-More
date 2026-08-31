/// ISO 4217 code, symbol and formatting locale for one supported currency.
class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.locale,
    required this.name,
  });

  final String code;
  final String symbol;

  /// Drives digit grouping and decimal separator via [NumberFormat.currency]
  /// — not the currency itself, which [symbol] already fixes explicitly.
  final String locale;
  final String name;
}

/// Must match [UserProfile.currencyCode]'s literal default ('INR').
const String kDefaultCurrencyCode = 'INR';

/// A deliberately short list — covering every ISO currency would mean a
/// searchable picker for a feature most users touch once, at onboarding.
/// These are the currencies of the app's plausible install base.
const List<CurrencyInfo> kSupportedCurrencies = [
  CurrencyInfo(code: 'INR', symbol: '₹', locale: 'en_IN', name: 'Indian Rupee'),
  CurrencyInfo(code: 'USD', symbol: r'$', locale: 'en_US', name: 'US Dollar'),
  CurrencyInfo(code: 'EUR', symbol: '€', locale: 'en_IE', name: 'Euro'),
  CurrencyInfo(
    code: 'GBP',
    symbol: '£',
    locale: 'en_GB',
    name: 'British Pound',
  ),
  CurrencyInfo(code: 'JPY', symbol: '¥', locale: 'ja_JP', name: 'Japanese Yen'),
  CurrencyInfo(
    code: 'AUD',
    symbol: r'A$',
    locale: 'en_AU',
    name: 'Australian Dollar',
  ),
  CurrencyInfo(
    code: 'CAD',
    symbol: r'C$',
    locale: 'en_CA',
    name: 'Canadian Dollar',
  ),
  CurrencyInfo(
    code: 'SGD',
    symbol: r'S$',
    locale: 'en_SG',
    name: 'Singapore Dollar',
  ),
  CurrencyInfo(code: 'AED', symbol: 'AED', locale: 'ar_AE', name: 'UAE Dirham'),
  CurrencyInfo(code: 'CNY', symbol: '¥', locale: 'zh_CN', name: 'Chinese Yuan'),
];

CurrencyInfo currencyInfoFor(String code) => kSupportedCurrencies.firstWhere(
  (c) => c.code == code,
  orElse: () => kSupportedCurrencies.first,
);
