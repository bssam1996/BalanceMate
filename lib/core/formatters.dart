import 'package:intl/intl.dart';

const currencies = <String, String>{
  'GBP': 'British pound',
  'USD': 'US dollar',
  'EUR': 'Euro',
  'EGP': 'Egyptian pound',
  'AED': 'UAE dirham',
  'AUD': 'Australian dollar',
  'CAD': 'Canadian dollar',
  'INR': 'Indian rupee',
  'JPY': 'Japanese yen',
  'PKR': 'Pakistani rupee',
  'SAR': 'Saudi riyal',
};

String formatMoney(int minor, String currencyCode) {
  final symbols = <String, String>{
    'GBP': '£',
    'USD': r'$',
    'EUR': '€',
    'AED': 'د.إ',
    'AUD': r'A$',
    'CAD': r'C$',
    'EGP': 'E£',
    'INR': '₹',
    'JPY': '¥',
    'PKR': '₨',
    'SAR': 'ر.س',
  };
  return NumberFormat.currency(
    symbol: symbols[currencyCode] ?? '$currencyCode ',
    decimalDigits: currencyCode == 'JPY' ? 0 : 2,
  ).format(minor / 100);
}

String currencyIcon(String code) => switch (code) {
  'GBP' => '🇬🇧',
  'USD' => '🇺🇸',
  'EUR' => '🇪🇺',
  'EGP' => '🇪🇬',
  'AED' => '🇦🇪',
  'AUD' => '🇦🇺',
  'CAD' => '🇨🇦',
  'INR' => '🇮🇳',
  'JPY' => '🇯🇵',
  'PKR' => '🇵🇰',
  'SAR' => '🇸🇦',
  _ => '💱',
};

String currencyLabel(String code) =>
    '${currencyIcon(code)}  $code · ${currencies[code] ?? code}';

String formatDate(DateTime date) => DateFormat('d MMM y').format(date);
