import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakrylle_chat/core/providers/auth_provider.dart';
import 'package:sakrylle_chat/core/providers/settings_provider.dart';
import 'package:sakrylle_chat/core/providers/user_provider.dart';
import 'package:sakrylle_chat/core/services/auth/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureValues = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureValues.clear();
    SecureStorageService.instance.debugResetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
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
        .setMockMethodCallHandler(secureChannel, null);
    SecureStorageService.instance.debugResetForTest();
  });

  testWidgets('login does not wait for slow profile and catalog sync', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final user = UserProvider();
    final slowUserInfo = Completer<Map<String, dynamic>?>();
    final slowCatalog = Completer<int>();
    final auth = AuthProvider(
      authorize: () async {},
      accessToken: () async => 'access-token',
      userInfo: () => slowUserInfo.future,
      refreshCatalog: (_, _) => slowCatalog.future,
    );

    BuildContext? testContext;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final loginFuture = auth.login(testContext!);
    await tester.pump();

    await expectLater(loginFuture, completion(isTrue));
    expect(auth.status, AuthStatus.loggedIn);
    expect(auth.isAuthorizing, isFalse);
    expect(settings.getProviderConfig('Sakrylle API').apiKey, 'access-token');

    slowUserInfo.complete(const {'name': 'Sakrylle User'});
    slowCatalog.complete(0);
    await tester.pump();
  });

  testWidgets('login sync selects GPT-Pro gpt-5.5 as default chat model', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final user = UserProvider();
    final catalogSynced = Completer<void>();
    final auth = AuthProvider(
      authorize: () async {},
      accessToken: () async => 'access-token',
      userInfo: () async => null,
      refreshCatalog: (settings, providerKey) async {
        final cfg = settings.getProviderConfig(providerKey);
        await settings.setProviderConfig(
          providerKey,
          cfg.copyWith(
            models: const ['12:claude-opus-4-6', '5:gpt-5.5'],
            modelOverrides: const {
              '12:claude-opus-4-6': {
                'name': 'claude-opus-4-6',
                'groupId': 12,
                'groupName': 'Claude-Max',
              },
              '5:gpt-5.5': {
                'name': 'gpt-5.5',
                'groupId': 5,
                'groupName': 'GPT-Pro',
              },
            },
          ),
        );
        catalogSynced.complete();
        return 2;
      },
    );

    BuildContext? testContext;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(await auth.login(testContext!), isTrue);
    await catalogSynced.future;
    for (var i = 0; i < 10 && settings.currentModelProvider == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(settings.currentModelProvider, 'Sakrylle API');
    expect(settings.currentModelId, '5:gpt-5.5');
  });

  testWidgets('logout moves to logged out even when remote logout fails', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final user = UserProvider();
    final auth = AuthProvider(
      isLoggedIn: () async => true,
      accessToken: () async => 'access-token',
      userInfo: () async => null,
      refreshCatalog: (_, _) async => 0,
      logout: () async => throw Exception('revocation unavailable'),
    );

    BuildContext? testContext;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<UserProvider>.value(value: user),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              testContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await auth.bootstrap(testContext!);
    expect(auth.status, AuthStatus.loggedIn);

    await auth.logout(testContext!);

    expect(auth.status, AuthStatus.loggedOut);
  });
}
