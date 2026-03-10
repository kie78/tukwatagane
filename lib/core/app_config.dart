import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: true);

  static const String _prodBaseUrl =
      'https://campusplug-api.onrender.com/api/v1';
  // Android emulator → 10.0.2.2; physical device on same Wi-Fi → machine IP
  static const String _localBaseUrl = 'http://10.0.2.2:8080/api/v1';

  static String get baseUrl => isProduction ? _prodBaseUrl : _localBaseUrl;

    static String get mapsApiKey =>
            dotenv.env['GOOGLE_API_KEY'] ?? dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static bool isAllowedEmail(String email) =>
      email.endsWith('@must.ac.ug') || email.endsWith('@std.must.ac.ug');
}
