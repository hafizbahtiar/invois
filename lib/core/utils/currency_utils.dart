import 'number_utils.dart';

/// Comprehensive currency utilities for the invoice system
class CurrencyUtils {
  const CurrencyUtils._();

  // ==================== CURRENCY DATA ====================

  /// Major world currencies with their codes, symbols, and names
  static const Map<String, CurrencyInfo> currencies = {
    'USD': CurrencyInfo('USD', '\$', 'US Dollar', 'United States'),
    'EUR': CurrencyInfo('EUR', '€', 'Euro', 'European Union'),
    'GBP': CurrencyInfo('GBP', '£', 'British Pound', 'United Kingdom'),
    'JPY': CurrencyInfo('JPY', '¥', 'Japanese Yen', 'Japan'),
    'CAD': CurrencyInfo('CAD', 'C\$', 'Canadian Dollar', 'Canada'),
    'AUD': CurrencyInfo('AUD', 'A\$', 'Australian Dollar', 'Australia'),
    'CHF': CurrencyInfo('CHF', 'CHF', 'Swiss Franc', 'Switzerland'),
    'CNY': CurrencyInfo('CNY', '¥', 'Chinese Yuan', 'China'),
    'INR': CurrencyInfo('INR', '₹', 'Indian Rupee', 'India'),
    'BRL': CurrencyInfo('BRL', 'R\$', 'Brazilian Real', 'Brazil'),
    'KRW': CurrencyInfo('KRW', '₩', 'South Korean Won', 'South Korea'),
    'MXN': CurrencyInfo('MXN', '\$', 'Mexican Peso', 'Mexico'),
    'SGD': CurrencyInfo('SGD', 'S\$', 'Singapore Dollar', 'Singapore'),
    'HKD': CurrencyInfo('HKD', 'HK\$', 'Hong Kong Dollar', 'Hong Kong'),
    'NZD': CurrencyInfo('NZD', 'NZ\$', 'New Zealand Dollar', 'New Zealand'),
    'SEK': CurrencyInfo('SEK', 'kr', 'Swedish Krona', 'Sweden'),
    'NOK': CurrencyInfo('NOK', 'kr', 'Norwegian Krone', 'Norway'),
    'DKK': CurrencyInfo('DKK', 'kr', 'Danish Krone', 'Denmark'),
    'PLN': CurrencyInfo('PLN', 'zł', 'Polish Złoty', 'Poland'),
    'CZK': CurrencyInfo('CZK', 'Kč', 'Czech Koruna', 'Czech Republic'),
    'HUF': CurrencyInfo('HUF', 'Ft', 'Hungarian Forint', 'Hungary'),
    'RUB': CurrencyInfo('RUB', '₽', 'Russian Ruble', 'Russia'),
    'TRY': CurrencyInfo('TRY', '₺', 'Turkish Lira', 'Turkey'),
    'ZAR': CurrencyInfo('ZAR', 'R', 'South African Rand', 'South Africa'),
    'MYR': CurrencyInfo('MYR', 'RM', 'Malaysian Ringgit', 'Malaysia'),
    'THB': CurrencyInfo('THB', '฿', 'Thai Baht', 'Thailand'),
    'IDR': CurrencyInfo('IDR', 'Rp', 'Indonesian Rupiah', 'Indonesia'),
    'PHP': CurrencyInfo('PHP', '₱', 'Philippine Peso', 'Philippines'),
    'VND': CurrencyInfo('VND', '₫', 'Vietnamese Dong', 'Vietnam'),
    'AED': CurrencyInfo('AED', 'د.إ', 'UAE Dirham', 'United Arab Emirates'),
    'SAR': CurrencyInfo('SAR', 'ر.س', 'Saudi Riyal', 'Saudi Arabia'),
    'QAR': CurrencyInfo('QAR', 'ر.ق', 'Qatari Riyal', 'Qatar'),
    'KWD': CurrencyInfo('KWD', 'د.ك', 'Kuwaiti Dinar', 'Kuwait'),
    'BHD': CurrencyInfo('BHD', '.د.ب', 'Bahraini Dinar', 'Bahrain'),
    'OMR': CurrencyInfo('OMR', 'ر.ع.', 'Omani Rial', 'Oman'),
    'JOD': CurrencyInfo('JOD', 'د.ا', 'Jordanian Dinar', 'Jordan'),
    'LBP': CurrencyInfo('LBP', 'ل.ل', 'Lebanese Pound', 'Lebanon'),
    'EGP': CurrencyInfo('EGP', 'ج.م', 'Egyptian Pound', 'Egypt'),
    'NGN': CurrencyInfo('NGN', '₦', 'Nigerian Naira', 'Nigeria'),
    'KES': CurrencyInfo('KES', 'KSh', 'Kenyan Shilling', 'Kenya'),
    'GHS': CurrencyInfo('GHS', 'GH₵', 'Ghanaian Cedi', 'Ghana'),
    'UGX': CurrencyInfo('UGX', 'USh', 'Ugandan Shilling', 'Uganda'),
    'TZS': CurrencyInfo('TZS', 'TSh', 'Tanzanian Shilling', 'Tanzania'),
    'ETB': CurrencyInfo('ETB', 'Br', 'Ethiopian Birr', 'Ethiopia'),
    'MAD': CurrencyInfo('MAD', 'د.م.', 'Moroccan Dirham', 'Morocco'),
    'TND': CurrencyInfo('TND', 'د.ت', 'Tunisian Dinar', 'Tunisia'),
    'DZD': CurrencyInfo('DZD', 'د.ج', 'Algerian Dinar', 'Algeria'),
    'LYD': CurrencyInfo('LYD', 'ل.د', 'Libyan Dinar', 'Libya'),
    'SDG': CurrencyInfo('SDG', 'ج.س.', 'Sudanese Pound', 'Sudan'),
    'SOS': CurrencyInfo('SOS', 'S', 'Somali Shilling', 'Somalia'),
    'DJF': CurrencyInfo('DJF', 'Fdj', 'Djiboutian Franc', 'Djibouti'),
    'KMF': CurrencyInfo('KMF', 'CF', 'Comorian Franc', 'Comoros'),
    'MUR': CurrencyInfo('MUR', '₨', 'Mauritian Rupee', 'Mauritius'),
    'SCR': CurrencyInfo('SCR', '₨', 'Seychellois Rupee', 'Seychelles'),
    'MVR': CurrencyInfo('MVR', 'MVR', 'Maldivian Rufiyaa', 'Maldives'),
    'LKR': CurrencyInfo('LKR', 'Rs', 'Sri Lankan Rupee', 'Sri Lanka'),
    'BDT': CurrencyInfo('BDT', '৳', 'Bangladeshi Taka', 'Bangladesh'),
    'NPR': CurrencyInfo('NPR', '₨', 'Nepalese Rupee', 'Nepal'),
    'PKR': CurrencyInfo('PKR', '₨', 'Pakistani Rupee', 'Pakistan'),
    'AFN': CurrencyInfo('AFN', '؋', 'Afghan Afghani', 'Afghanistan'),
    'IRR': CurrencyInfo('IRR', '﷼', 'Iranian Rial', 'Iran'),
    'IQD': CurrencyInfo('IQD', 'ع.د', 'Iraqi Dinar', 'Iraq'),
    'SYP': CurrencyInfo('SYP', 'ل.س', 'Syrian Pound', 'Syria'),
    'YER': CurrencyInfo('YER', '﷼', 'Yemeni Rial', 'Yemen'),
    'KHR': CurrencyInfo('KHR', '៛', 'Cambodian Riel', 'Cambodia'),
    'LAK': CurrencyInfo('LAK', '₭', 'Lao Kip', 'Laos'),
    'MMK': CurrencyInfo('MMK', 'K', 'Myanmar Kyat', 'Myanmar'),
    'MNT': CurrencyInfo('MNT', '₮', 'Mongolian Tugrik', 'Mongolia'),
    'KZT': CurrencyInfo('KZT', '₸', 'Kazakhstani Tenge', 'Kazakhstan'),
    'UZS': CurrencyInfo('UZS', 'so\'m', 'Uzbekistani Som', 'Uzbekistan'),
    'TJS': CurrencyInfo('TJS', 'ЅМ', 'Tajikistani Somoni', 'Tajikistan'),
    'TMT': CurrencyInfo('TMT', 'T', 'Turkmenistan Manat', 'Turkmenistan'),
    'GEL': CurrencyInfo('GEL', '₾', 'Georgian Lari', 'Georgia'),
    'AMD': CurrencyInfo('AMD', '֏', 'Armenian Dram', 'Armenia'),
    'AZN': CurrencyInfo('AZN', '₼', 'Azerbaijani Manat', 'Azerbaijan'),
    'BYN': CurrencyInfo('BYN', 'Br', 'Belarusian Ruble', 'Belarus'),
    'MDL': CurrencyInfo('MDL', 'L', 'Moldovan Leu', 'Moldova'),
    'UAH': CurrencyInfo('UAH', '₴', 'Ukrainian Hryvnia', 'Ukraine'),
    'BGN': CurrencyInfo('BGN', 'лв', 'Bulgarian Lev', 'Bulgaria'),
    'RON': CurrencyInfo('RON', 'lei', 'Romanian Leu', 'Romania'),
    'HRK': CurrencyInfo('HRK', 'kn', 'Croatian Kuna', 'Croatia'),
    'RSD': CurrencyInfo('RSD', 'дин.', 'Serbian Dinar', 'Serbia'),
    'BAM': CurrencyInfo(
      'BAM',
      'KM',
      'Bosnia-Herzegovina Convertible Mark',
      'Bosnia and Herzegovina',
    ),
    'ALL': CurrencyInfo('ALL', 'L', 'Albanian Lek', 'Albania'),
    'MKD': CurrencyInfo('MKD', 'ден', 'Macedonian Denar', 'North Macedonia'),
    'XCD': CurrencyInfo(
      'XCD',
      'EC\$',
      'East Caribbean Dollar',
      'Eastern Caribbean',
    ),
    'BBD': CurrencyInfo('BBD', 'Bds\$', 'Barbadian Dollar', 'Barbados'),
    'JMD': CurrencyInfo('JMD', 'J\$', 'Jamaican Dollar', 'Jamaica'),
    'TTD': CurrencyInfo(
      'TTD',
      'TT\$',
      'Trinidad and Tobago Dollar',
      'Trinidad and Tobago',
    ),
    'BZD': CurrencyInfo('BZD', 'BZ\$', 'Belize Dollar', 'Belize'),
    'GYD': CurrencyInfo('GYD', 'G\$', 'Guyanese Dollar', 'Guyana'),
    'SRD': CurrencyInfo('SRD', 'SR\$', 'Surinamese Dollar', 'Suriname'),
    'FJD': CurrencyInfo('FJD', 'FJ\$', 'Fijian Dollar', 'Fiji'),
    'PGK': CurrencyInfo(
      'PGK',
      'K',
      'Papua New Guinean Kina',
      'Papua New Guinea',
    ),
    'SBD': CurrencyInfo(
      'SBD',
      'SI\$',
      'Solomon Islands Dollar',
      'Solomon Islands',
    ),
    'VUV': CurrencyInfo('VUV', 'VT', 'Vanuatu Vatu', 'Vanuatu'),
    'WST': CurrencyInfo('WST', 'T', 'Samoan Tala', 'Samoa'),
    'TOP': CurrencyInfo('TOP', 'T\$', 'Tongan Paʻanga', 'Tonga'),
    'KID': CurrencyInfo('KID', '\$', 'Kiribati Dollar', 'Kiribati'),
    'TVD': CurrencyInfo('TVD', 'TV\$', 'Tuvaluan Dollar', 'Tuvalu'),
    'NIO': CurrencyInfo('NIO', 'C\$', 'Nicaraguan Córdoba', 'Nicaragua'),
    'HNL': CurrencyInfo('HNL', 'L', 'Honduran Lempira', 'Honduras'),
    'GTQ': CurrencyInfo('GTQ', 'Q', 'Guatemalan Quetzal', 'Guatemala'),
    'SVC': CurrencyInfo('SVC', '₡', 'Salvadoran Colón', 'El Salvador'),
    'CRC': CurrencyInfo('CRC', '₡', 'Costa Rican Colón', 'Costa Rica'),
    'PAB': CurrencyInfo('PAB', 'B/.', 'Panamanian Balboa', 'Panama'),
    'PYG': CurrencyInfo('PYG', '₲', 'Paraguayan Guaraní', 'Paraguay'),
    'UYU': CurrencyInfo('UYU', '\$U', 'Uruguayan Peso', 'Uruguay'),
    'CLP': CurrencyInfo('CLP', '\$', 'Chilean Peso', 'Chile'),
    'PEN': CurrencyInfo('PEN', 'S/', 'Peruvian Sol', 'Peru'),
    'BOB': CurrencyInfo('BOB', 'Bs.', 'Bolivian Boliviano', 'Bolivia'),
    'ARS': CurrencyInfo('ARS', '\$', 'Argentine Peso', 'Argentina'),
    'COP': CurrencyInfo('COP', '\$', 'Colombian Peso', 'Colombia'),
    'VES': CurrencyInfo('VES', 'Bs.', 'Venezuelan Bolívar', 'Venezuela'),
    'GYE': CurrencyInfo('GYE', '\$', 'Guyanese Dollar', 'Guyana'),
    'SRG': CurrencyInfo('SRG', 'ƒ', 'Surinamese Guilder', 'Suriname'),
    'BWP': CurrencyInfo('BWP', 'P', 'Botswana Pula', 'Botswana'),
    'NAD': CurrencyInfo('NAD', 'N\$', 'Namibian Dollar', 'Namibia'),
    'LSL': CurrencyInfo('LSL', 'L', 'Lesotho Loti', 'Lesotho'),
    'SZL': CurrencyInfo('SZL', 'L', 'Eswatini Lilangeni', 'Eswatini'),
    'MZN': CurrencyInfo('MZN', 'MT', 'Mozambican Metical', 'Mozambique'),
    'MWK': CurrencyInfo('MWK', 'MK', 'Malawian Kwacha', 'Malawi'),
    'ZMW': CurrencyInfo('ZMW', 'ZK', 'Zambian Kwacha', 'Zambia'),
    'ZWL': CurrencyInfo('ZWL', 'Z\$', 'Zimbabwean Dollar', 'Zimbabwe'),
    'AOA': CurrencyInfo('AOA', 'Kz', 'Angolan Kwanza', 'Angola'),
    'CDF': CurrencyInfo(
      'CDF',
      'FC',
      'Congolese Franc',
      'Democratic Republic of the Congo',
    ),
    'XAF': CurrencyInfo(
      'XAF',
      'FCFA',
      'Central African CFA Franc',
      'Central African Republic',
    ),
    'XOF': CurrencyInfo(
      'XOF',
      'CFA',
      'West African CFA Franc',
      'West African Economic and Monetary Union',
    ),
    'XPF': CurrencyInfo('XPF', 'CFP', 'CFP Franc', 'French Polynesia'),
    'CVE': CurrencyInfo('CVE', '\$', 'Cape Verdean Escudo', 'Cape Verde'),
    'GMD': CurrencyInfo('GMD', 'D', 'Gambian Dalasi', 'Gambia'),
    'GNF': CurrencyInfo('GNF', 'FG', 'Guinean Franc', 'Guinea'),
    'LRD': CurrencyInfo('LRD', 'L\$', 'Liberian Dollar', 'Liberia'),
    'SLL': CurrencyInfo('SLL', 'Le', 'Sierra Leonean Leone', 'Sierra Leone'),
    'MRO': CurrencyInfo('MRO', 'UM', 'Mauritanian Ouguiya', 'Mauritania'),
    'STD': CurrencyInfo(
      'STD',
      'Db',
      'São Tomé and Príncipe Dobra',
      'São Tomé and Príncipe',
    ),
  };

  // ==================== CURRENCY INFO CLASS ====================

  /// Get currency info by code
  static CurrencyInfo? getCurrencyInfo(String code) {
    return currencies[code.toUpperCase()];
  }

  /// Get currency symbol by code
  static String getSymbol(String code) {
    return getCurrencyInfo(code)?.symbol ?? '\$';
  }

  /// Get currency name by code
  static String getName(String code) {
    return getCurrencyInfo(code)?.name ?? 'Unknown Currency';
  }

  /// Get country by code
  static String getCountry(String code) {
    return getCurrencyInfo(code)?.country ?? 'Unknown';
  }

  /// Check if currency code is valid
  static bool isValidCode(String code) {
    return currencies.containsKey(code.toUpperCase());
  }

  /// Get all currency codes
  static List<String> getAllCodes() {
    return currencies.keys.toList()..sort();
  }

  /// Get all currency names
  static List<String> getAllNames() {
    return currencies.values.map((c) => c.name).toList()..sort();
  }

  /// Get currencies by region
  static Map<String, List<CurrencyInfo>> getCurrenciesByRegion() {
    final regions = <String, List<CurrencyInfo>>{};

    for (final currency in currencies.values) {
      final region = _getRegion(currency.country);
      regions.putIfAbsent(region, () => []).add(currency);
    }

    return regions;
  }

  /// Get region from country
  static String _getRegion(String country) {
    // Simplified region mapping - you can expand this
    if (['United States', 'Canada', 'Mexico'].contains(country)) {
      return 'North America';
    }
    if ([
      'Brazil',
      'Argentina',
      'Chile',
      'Colombia',
      'Peru',
      'Venezuela',
    ].contains(country)) {
      return 'South America';
    }
    if ([
      'United Kingdom',
      'Germany',
      'France',
      'Italy',
      'Spain',
      'Netherlands',
    ].contains(country)) {
      return 'Europe';
    }
    if ([
      'China',
      'Japan',
      'South Korea',
      'India',
      'Indonesia',
      'Thailand',
    ].contains(country)) {
      return 'Asia';
    }
    if ([
      'Australia',
      'New Zealand',
      'Fiji',
      'Papua New Guinea',
    ].contains(country)) {
      return 'Oceania';
    }
    if ([
      'South Africa',
      'Nigeria',
      'Kenya',
      'Ghana',
      'Egypt',
      'Morocco',
    ].contains(country)) {
      return 'Africa';
    }
    return 'Other';
  }

  // ==================== FORMATTING HELPERS ====================

  /// Format amount with currency symbol
  static String formatAmount(
    double amount,
    String currencyCode, {
    int decimalPlaces = 2,
  }) {
    final symbol = getSymbol(currencyCode);
    final formattedAmount = NumberUtils.formatCurrency(
      amount,
      decimalPlaces: decimalPlaces,
    );
    return '$symbol$formattedAmount';
  }

  /// Format amount with currency code
  static String formatAmountWithCode(
    double amount,
    String currencyCode, {
    int decimalPlaces = 2,
  }) {
    final formattedAmount = NumberUtils.formatCurrency(
      amount,
      decimalPlaces: decimalPlaces,
    );
    return '$formattedAmount $currencyCode';
  }

  /// Format amount with full currency name
  static String formatAmountWithName(
    double amount,
    String currencyCode, {
    int decimalPlaces = 2,
  }) {
    final name = getName(currencyCode);
    final formattedAmount = NumberUtils.formatCurrency(
      amount,
      decimalPlaces: decimalPlaces,
    );
    return '$formattedAmount $name';
  }

  /// Parse currency amount from string
  static double? parseAmount(String amount, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    final cleanAmount = amount
        .replaceAll(symbol, '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleanAmount);
  }

  // ==================== CONVERSION HELPERS ====================

  /// Convert amount between currencies (placeholder for exchange rates)
  static double convertAmount(
    double amount,
    String fromCurrency,
    String toCurrency, {
    double? exchangeRate,
  }) {
    if (fromCurrency == toCurrency) return amount;
    if (exchangeRate != null) return amount * exchangeRate;

    // Placeholder - in real app, you'd use an exchange rate API
    return amount;
  }

  /// Get exchange rate (placeholder)
  static double? getExchangeRate(String fromCurrency, String toCurrency) {
    // Placeholder - in real app, you'd fetch from an API
    return null;
  }
}

/// Currency information class
class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String country;

  const CurrencyInfo(this.code, this.symbol, this.name, this.country);

  @override
  String toString() => '$code ($symbol) - $name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrencyInfo &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
