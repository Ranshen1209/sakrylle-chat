import 'dart:convert';
import 'package:sakrylle_chat/core/models/api_keys.dart';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakrylle_chat/core/database/app_database.dart';
import 'package:sakrylle_chat/core/database/business_preferences.dart';
import 'package:sakrylle_chat/core/database/business_repository.dart';
import 'package:sakrylle_chat/core/providers/settings_provider.dart';
import 'package:sakrylle_chat/core/services/auth/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureValues = <String, String>{};
  late AppDatabase database;
  late BusinessPreferences preferences;
  late SettingsProvider settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secureValues.clear();
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
    SecureStorageService.instance.debugResetForTest();
    database = AppDatabase(NativeDatabase.memory());
    preferences = BusinessPreferences(BusinessRepository(database));
    settings = SettingsProvider(preferences);
    await settings.loaded;
  });
  tearDown(() async {
    settings.dispose();
    await database.close();
    SecureStorageService.instance.debugResetForTest();
  });

  test(
    'saving, reordering and removing providers never persists resolved keys',
    () async {
      final first = settings.ensureProviderConfig('first');
      await settings.setProviderConfig(
        'first',
        first.copyWith(apiKey: 'first-secret'),
      );
      final second = settings.ensureProviderConfig('second');
      await settings.setProviderConfig(
        'second',
        second.copyWith(apiKey: 'second-secret'),
      );
      for (final secret in ['first-secret', 'second-secret']) {
        expect(
          preferences.getString('provider_configs_v1'),
          isNot(contains(secret)),
        );
      }
      await settings.setProvidersOrder(['OpenAI', 'first', 'second']);
      expect(
        preferences.getString('provider_configs_v1'),
        isNot(contains('first-secret')),
      );
      await settings.removeProviderConfig('second');
      expect(
        preferences.getString('provider_configs_v1'),
        isNot(contains('first-secret')),
      );
      final reloaded = SettingsProvider(
        BusinessPreferences(BusinessRepository(database)),
      );
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.providerConfigs['first']?.apiKey, 'first-secret');
    },
  );

  test(
    'disabled multi-key configs retain empty slots through a cold reload',
    () async {
      final config = settings
          .ensureProviderConfig('rotation')
          .copyWith(
            multiKeyEnabled: false,
            apiKeys: [
              const ApiKeyConfig(
                id: 'empty',
                key: '',
                createdAt: 0,
                updatedAt: 0,
              ),
              const ApiKeyConfig(
                id: 'second',
                key: 'rotation-secret',
                createdAt: 0,
                updatedAt: 0,
              ),
            ],
          );
      await settings.setProviderConfig('rotation', config);
      final reloaded = SettingsProvider(
        BusinessPreferences(BusinessRepository(database)),
      );
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.providerConfigs['rotation']!.apiKeys!.map((e) => e.key), [
        '',
        'rotation-secret',
      ]);
      expect(
        preferences.getString('provider_configs_v1'),
        isNot(contains('rotation-secret')),
      );
    },
  );

  test('clearing a key survives restart', () async {
    final config = settings.ensureProviderConfig('first');
    await settings.setProviderConfig(
      'first',
      config.copyWith(apiKey: 'secret'),
    );
    await settings.setProviderConfig('first', config.copyWith(apiKey: ''));
    expect(await SecureStorageService.instance.getApiKey('first'), isEmpty);
    final stored =
        jsonDecode(preferences.getString('provider_configs_v1')!) as Map;
    expect((stored['first'] as Map)['apiKey'], isEmpty);
  });

  test(
    'failed secure write is reported without changing saved or active config',
    () async {
      final config = settings.ensureProviderConfig('first');
      await settings.setProviderConfig(
        'first',
        config.copyWith(apiKey: 'old-secret'),
      );
      final before = preferences.getString('provider_configs_v1');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => throw PlatformException(code: 'keychain_locked'),
          );
      await expectLater(
        settings.setProviderConfig(
          'first',
          config.copyWith(apiKey: 'new-secret'),
        ),
        throwsA(isA<PlatformException>()),
      );
      expect(preferences.getString('provider_configs_v1'), before);
      expect(settings.providerConfigs['first']?.apiKey, 'old-secret');
    },
  );
}
