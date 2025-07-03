/// Comprehensive language utilities for the invoice system
class LanguageUtils {
  const LanguageUtils._();

  /// Major world languages with their codes and names
  static const Map<String, LanguageInfo> languages = {
    'en': LanguageInfo('en', 'English', 'English'),
    'ms': LanguageInfo('ms', 'Malay', 'Bahasa Melayu'),
    'id': LanguageInfo('id', 'Indonesian', 'Bahasa Indonesia'),
    'fr': LanguageInfo('fr', 'French', 'Français'),
    'de': LanguageInfo('de', 'German', 'Deutsch'),
    'es': LanguageInfo('es', 'Spanish', 'Español'),
    'it': LanguageInfo('it', 'Italian', 'Italiano'),
    'pt': LanguageInfo('pt', 'Portuguese', 'Português'),
    'ru': LanguageInfo('ru', 'Russian', 'Русский'),
    'zh': LanguageInfo('zh', 'Chinese', '中文'),
    'ja': LanguageInfo('ja', 'Japanese', '日本語'),
    'ko': LanguageInfo('ko', 'Korean', '한국어'),
    'ar': LanguageInfo('ar', 'Arabic', 'العربية'),
    'th': LanguageInfo('th', 'Thai', 'ไทย'),
    'tr': LanguageInfo('tr', 'Turkish', 'Türkçe'),
    'vi': LanguageInfo('vi', 'Vietnamese', 'Tiếng Việt'),
    'hi': LanguageInfo('hi', 'Hindi', 'हिन्दी'),
    'bn': LanguageInfo('bn', 'Bengali', 'বাংলা'),
    'ta': LanguageInfo('ta', 'Tamil', 'தமிழ்'),
    'ur': LanguageInfo('ur', 'Urdu', 'اردو'),
    'fa': LanguageInfo('fa', 'Persian', 'فارسی'),
    'pl': LanguageInfo('pl', 'Polish', 'Polski'),
    'nl': LanguageInfo('nl', 'Dutch', 'Nederlands'),
    'sv': LanguageInfo('sv', 'Swedish', 'Svenska'),
    'fi': LanguageInfo('fi', 'Finnish', 'Suomi'),
    'no': LanguageInfo('no', 'Norwegian', 'Norsk'),
    'da': LanguageInfo('da', 'Danish', 'Dansk'),
    'el': LanguageInfo('el', 'Greek', 'Ελληνικά'),
    'he': LanguageInfo('he', 'Hebrew', 'עברית'),
    'cs': LanguageInfo('cs', 'Czech', 'Čeština'),
    'hu': LanguageInfo('hu', 'Hungarian', 'Magyar'),
    'ro': LanguageInfo('ro', 'Romanian', 'Română'),
    'sk': LanguageInfo('sk', 'Slovak', 'Slovenčina'),
    'uk': LanguageInfo('uk', 'Ukrainian', 'Українська'),
    'bg': LanguageInfo('bg', 'Bulgarian', 'Български'),
    'sr': LanguageInfo('sr', 'Serbian', 'Српски'),
    'hr': LanguageInfo('hr', 'Croatian', 'Hrvatski'),
    'sl': LanguageInfo('sl', 'Slovenian', 'Slovenščina'),
    'et': LanguageInfo('et', 'Estonian', 'Eesti'),
    'lv': LanguageInfo('lv', 'Latvian', 'Latviešu'),
    'lt': LanguageInfo('lt', 'Lithuanian', 'Lietuvių'),
    'fil': LanguageInfo('fil', 'Filipino', 'Filipino'),
    'sw': LanguageInfo('sw', 'Swahili', 'Kiswahili'),
    'zu': LanguageInfo('zu', 'Zulu', 'isiZulu'),
    'af': LanguageInfo('af', 'Afrikaans', 'Afrikaans'),
    'am': LanguageInfo('am', 'Amharic', 'አማርኛ'),
    'my': LanguageInfo('my', 'Burmese', 'မြန်မာ'),
    'km': LanguageInfo('km', 'Khmer', 'ខ្មែរ'),
    'lo': LanguageInfo('lo', 'Lao', 'ລາວ'),
    'si': LanguageInfo('si', 'Sinhala', 'සිංහල'),
    'ne': LanguageInfo('ne', 'Nepali', 'नेपाली'),
    'pa': LanguageInfo('pa', 'Punjabi', 'ਪੰਜਾਬੀ'),
    'gu': LanguageInfo('gu', 'Gujarati', 'ગુજરાતી'),
    'te': LanguageInfo('te', 'Telugu', 'తెలుగు'),
    'kn': LanguageInfo('kn', 'Kannada', 'ಕನ್ನಡ'),
    'ml': LanguageInfo('ml', 'Malayalam', 'മലയാളം'),
    'mr': LanguageInfo('mr', 'Marathi', 'मराठी'),
    'or': LanguageInfo('or', 'Odia', 'ଓଡ଼ିଆ'),
    'as': LanguageInfo('as', 'Assamese', 'অসমীয়া'),
    'bo': LanguageInfo('bo', 'Tibetan', 'བོད་སྐད་'),
    'mn': LanguageInfo('mn', 'Mongolian', 'Монгол'),
    'kk': LanguageInfo('kk', 'Kazakh', 'Қазақ'),
    'uz': LanguageInfo('uz', 'Uzbek', 'Oʻzbek'),
    'ky': LanguageInfo('ky', 'Kyrgyz', 'Кыргызча'),
    'tg': LanguageInfo('tg', 'Tajik', 'Тоҷикӣ'),
    'tk': LanguageInfo('tk', 'Turkmen', 'Türkmen'),
    'az': LanguageInfo('az', 'Azerbaijani', 'Azərbaycanca'),
    'ka': LanguageInfo('ka', 'Georgian', 'ქართული'),
    'hy': LanguageInfo('hy', 'Armenian', 'Հայերեն'),
    'be': LanguageInfo('be', 'Belarusian', 'Беларуская'),
    'mo': LanguageInfo('mo', 'Moldovan', 'Moldovenească'),
  };

  /// Get language info by code
  static LanguageInfo? getLanguageInfo(String code) {
    return languages[code.toLowerCase()];
  }

  /// Get language name by code
  static String getName(String code) {
    return getLanguageInfo(code)?.name ?? 'Unknown Language';
  }

  /// Get native name by code
  static String getNativeName(String code) {
    return getLanguageInfo(code)?.nativeName ?? 'Unknown';
  }

  /// Check if language code is valid
  static bool isValidCode(String code) {
    return languages.containsKey(code.toLowerCase());
  }

  /// Get all language codes
  static List<String> getAllCodes() {
    return languages.keys.toList()..sort();
  }

  /// Get all language names
  static List<String> getAllNames() {
    return languages.values.map((l) => l.name).toList()..sort();
  }
}

/// Language information class
class LanguageInfo {
  final String code;
  final String name;
  final String nativeName;

  const LanguageInfo(this.code, this.name, this.nativeName);

  @override
  String toString() => '$code - $name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageInfo &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
