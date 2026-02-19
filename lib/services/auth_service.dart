import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  static const _kIsLoggedIn = 'is_logged_in';
  static const _kUserEmail = 'user_email';
  static const _kUserName = 'user_name';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> signIn(String email, String password) async {
    if (email.isEmpty || password.length < 6) {
      throw Exception('Invalid credentials');
    }

    await _write(_kIsLoggedIn, 'true');
    await _write(_kUserEmail, email);

    // Provide a friendly default user name based on email if missing.
    final existingName = await getUserName();
    if (existingName.isEmpty) {
      final localPart = email.split('@').first;
      final display = localPart.isNotEmpty ? localPart[0].toUpperCase() + localPart.substring(1) : 'User';
      await _write(_kUserName, display);
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    if (email.isEmpty || password.length < 6 || name.isEmpty) {
      throw Exception('Please fill all fields correctly');
    }
    await _write(_kUserName, name);
    await _write(_kUserEmail, email);
  }

  Future<void> signOut() async {
    await _write(_kIsLoggedIn, 'false');
  }

  Future<bool> isLoggedIn() async {
    return (await _read(_kIsLoggedIn)) == 'true';
  }

  Future<String> getUserName() async {
    return await _read(_kUserName) ?? '';
  }

  Future<String> getUserEmail() async {
    return await _read(_kUserEmail) ?? '';
  }

  Future<void> updateUserName(String name) async {
    await _write(_kUserName, name);
  }

  Future<void> updateProfile({required String name, required String email}) async {
    await _write(_kUserName, name);
    await _write(_kUserEmail, email);
  }

  Future<String?> _read(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } on MissingPluginException {
      // Test and unsupported-platform fallback.
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      return;
    } on MissingPluginException {
      // Test and unsupported-platform fallback.
    } catch (_) {
      // Fallback below.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
