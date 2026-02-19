/// Runtime configuration via Dart defines.
///
/// Examples:
/// - flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://10.0.2.2:8000
/// - flutter build apk --release --dart-define=APP_ENV=prod --dart-define=API_BASE_URL=https://your-api.onrender.com
class AppConfig {
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://stroke-app-as3q.onrender.com',
  );

  static bool get isProd => appEnv.toLowerCase() == 'prod';
}

const String apiBaseUrl = AppConfig.apiBaseUrl;
