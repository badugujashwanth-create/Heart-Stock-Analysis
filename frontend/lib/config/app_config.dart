import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String _compileTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    final fromDefine = _compileTimeBaseUrl.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    final raw = dotenv.env['API_BASE_URL']?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw;
    }
    return 'http://localhost:8000';
  }
}
