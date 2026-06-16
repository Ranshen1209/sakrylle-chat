import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sakrylle_chat/core/providers/assistant_provider.dart';
import 'package:sakrylle_chat/core/providers/settings_provider.dart';
import 'package:sakrylle_chat/core/services/auth/secure_storage_service.dart';
import 'package:sakrylle_chat/features/provider/pages/provider_detail_page.dart';
import 'package:sakrylle_chat/icons/lucide_adapter.dart';
import 'package:sakrylle_chat/l10n/app_localizations.dart';

Future<SettingsProvider> _createSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsProvider();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await settings.setProviderConfig(
    'TestProvider',
    ProviderConfig(
      id: 'TestProvider',
      enabled: true,
      name: 'Test Provider',
      apiKey: 'test-key',
      baseUrl: 'https://example.test',
      providerType: ProviderKind.openai,
      models: const ['model-a', 'model-b'],
    ),
  );
  return settings;
}

Widget _buildHarness({
  required SettingsProvider settings,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<AssistantProvider>(
        create: (_) => AssistantProvider(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async => null);
    SecureStorageService.instance.debugResetForTest();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    SecureStorageService.instance.debugResetForTest();
  });

  testWidgets(
    'model selection toolbar hides all action labels on narrow phones',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settings = await _createSettings(tester);
      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          child: const ProviderDetailPage(
            keyName: 'TestProvider',
            displayName: 'Test Provider',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Models'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Lucide.CheckSquare).first);
      await tester.pumpAndSettle();

      expect(find.text('Detect'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Select All'), findsNothing);
      expect(find.byIcon(Lucide.HeartPulse), findsOneWidget);
      expect(find.byIcon(Lucide.Trash2), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
