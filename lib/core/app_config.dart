class AppConfig {
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: true);

  static const String _prodBaseUrl =
      'https://campusplug-api.onrender.com/api/v1';
  // Android emulator → 10.0.2.2; physical device on same Wi-Fi → machine IP
  static const String _localBaseUrl = 'http://10.0.2.2:8080/api/v1';

  static String get baseUrl => isProduction ? _prodBaseUrl : _localBaseUrl;

  static const String mapsApiKey = 'AIzaSyB1KiyE5au0z3zLB_0PS84999_hD9YbhTc';

  static bool isAllowedEmail(String email) =>
      email.endsWith('@must.ac.ug') || email.endsWith('@std.must.ac.ug');
}
