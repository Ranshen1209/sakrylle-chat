import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakrylle_chat/core/services/auth/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final service = SecureStorageService.instance;
  final secureValues = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureValues.clear();
    service.debugResetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          final key = args['key'] as String?;
          switch (call.method) {
            case 'read':
              return secureValues[key];
            case 'write':
              secureValues[key!] = args['value'] as String;
              return null;
            case 'delete':
              secureValues.remove(key);
              return null;
            case 'readAll':
              return Map<String, String>.from(secureValues);
            case 'containsKey':
              return secureValues.containsKey(key);
            case 'deleteAll':
              secureValues.clear();
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    service.debugResetForTest();
  });

  test('stores API keys and OAuth tokens only in secure storage', () async {
    await service.setApiKey('Sakrylle API', 'api-key');
    await service.setOAuthToken('access_token', 'access-token');

    expect(await service.getApiKey('Sakrylle API'), 'api-key');
    expect(await service.getOAuthToken('access_token'), 'access-token');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(
      secureValues,
      containsPair('sakrylle_chat.apikey.Sakrylle API', 'api-key'),
    );
    expect(
      secureValues,
      containsPair('sakrylle_chat.oauth.access_token', 'access-token'),
    );
  });

  test(
    'migrates legacy fallback values after secure storage is available',
    () async {
      SharedPreferences.setMockInitialValues({
        'secure_fallback.sakrylle_chat.oauth.id_token': 'legacy-id-token',
      });
      service.debugResetForTest();

      final value = await service.getOAuthToken('id_token');

      expect(value, 'legacy-id-token');
      expect(
        secureValues,
        containsPair('sakrylle_chat.oauth.id_token', 'legacy-id-token'),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey('secure_fallback.sakrylle_chat.oauth.id_token'),
        isFalse,
      );
    },
  );

  test('fails closed when secure storage is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });
    service.debugResetForTest();

    expect(
      () => service.setOAuthToken('access_token', 'token'),
      throwsA(isA<SecureStorageUnavailableException>()),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
