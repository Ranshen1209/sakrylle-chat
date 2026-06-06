import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakrylle_chat/core/providers/assistant_provider.dart';
import 'package:sakrylle_chat/core/providers/settings_provider.dart';
import 'package:sakrylle_chat/core/services/auth/secure_storage_service.dart';
import 'package:sakrylle_chat/features/provider/pages/provider_detail_page.dart';
import 'package:sakrylle_chat/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secureValues = <String, String>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureValues.clear();
    SecureStorageService.instance.debugResetForTest();
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
    SecureStorageService.instance.debugResetForTest();
  });

  testWidgets('renders localized Sakrylle login button', (tester) async {
    final settings = SettingsProvider();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AssistantProvider>(
            create: (_) => AssistantProvider(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProviderDetailPage(
            keyName: 'Sakrylle API',
            displayName: 'Sakrylle API',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login with Sakrylle'), findsOneWidget);
    expect(find.text('Logging in...'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
