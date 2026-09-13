import '../../support/business_test_harness.dart';
import 'package:sakrylle_chat/core/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakrylle_chat/core/providers/auth_provider.dart';
import 'package:sakrylle_chat/core/services/auth/sakrylle_oauth_service.dart';
import 'package:sakrylle_chat/features/auth/pages/login_page.dart';
import 'package:sakrylle_chat/l10n/app_localizations.dart';

void main() {
  testWidgets('scope rejection explains registration mismatch', (tester) async {
    final auth = AuthProvider(
      authorize: () async {
        throw const OAuthAuthorizationException('invalid_scope');
      },
    );
    addTearDown(auth.dispose);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LoginPage(),
        ),
      ),
    );
    await tester.tap(find.text('Sign in with Sakrylle'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The sign-in permissions do not match this app’s server registration. Please contact Sakrylle support. (invalid_scope)',
      ),
      findsOneWidget,
    );
    expect(auth.status, AuthStatus.loggedOut);
    expect(auth.isAuthorizing, isFalse);
  });

  testWidgets(
    'cancelled browser login keeps the gate without a failure alert',
    (tester) async {
      final auth = AuthProvider(
        authorize: () async {
          throw PlatformException(code: 'CANCELED');
        },
      );
      addTearDown(auth.dispose);
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LoginPage(),
          ),
        ),
      );
      await tester.tap(find.text('Sign in with Sakrylle'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(auth.status, AuthStatus.loggedOut);
      expect(auth.isAuthorizing, isFalse);
    },
  );
}
