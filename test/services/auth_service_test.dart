import 'package:flutter_test/flutter_test.dart';
import 'package:heartanalysis/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('signIn stores login state and infers display name', () async {
    await AuthService.instance.signIn('alice@example.com', 'secret1');

    expect(await AuthService.instance.isLoggedIn(), isTrue);
    expect(await AuthService.instance.getUserEmail(), 'alice@example.com');
    expect(await AuthService.instance.getUserName(), 'Alice');
  });

  test('signOut clears login state flag', () async {
    await AuthService.instance.signIn('bob@example.com', 'secret1');
    await AuthService.instance.signOut();

    expect(await AuthService.instance.isLoggedIn(), isFalse);
  });

  test('updateProfile overwrites stored name and email', () async {
    await AuthService.instance.updateProfile(
      name: 'Chris Doe',
      email: 'chris@example.com',
    );

    expect(await AuthService.instance.getUserName(), 'Chris Doe');
    expect(await AuthService.instance.getUserEmail(), 'chris@example.com');
  });
}
