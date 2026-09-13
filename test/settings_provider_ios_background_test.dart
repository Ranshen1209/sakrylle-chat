import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/providers/settings_provider.dart';
import 'support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('defaults iOS background options to disabled', () async {
    final h = await createBusinessTestHarness();
    final settings = SettingsProvider(h.preferences);
    await settings.loaded;
    expect(settings.mobileBackground.iosEnabled, isFalse);
    expect(settings.mobileBackground.liveActivitiesEnabled, isFalse);
    expect(settings.mobileBackground.notificationsEnabled, isFalse);
    settings.dispose();
  });
  test('upgrades explicitly enabled legacy iOS settings', () async {
    final h = await createBusinessTestHarness(
      initial: {
        'ios_background_generation_enabled_v1': true,
        'ios_background_task_refresh_enabled_v1': true,
        'ios_live_activity_enabled_v1': true,
        'ios_background_notifications_enabled_v1': true,
      },
    );
    final settings = SettingsProvider(h.preferences);
    await settings.loaded;
    expect(settings.mobileBackground.iosEnabled, isTrue);
    expect(settings.mobileBackground.liveActivitiesEnabled, isTrue);
    expect(settings.mobileBackground.notificationsEnabled, isTrue);
    expect(settings.mobileBackground.silentAudioEnabled, isFalse);
    expect(settings.mobileBackground.locationEnabled, isFalse);
    expect(
      h.preferences.getBool('ios_background_task_refresh_enabled_v1'),
      isTrue,
    );
    settings.dispose();
  });
  test(
    'persists mode changes and does not reapply legacy enabled values',
    () async {
      final h = await createBusinessTestHarness(
        initial: {'ios_background_generation_enabled_v1': true},
      );
      final settings = SettingsProvider(h.preferences);
      await settings.loaded;
      await settings.setMobileBackground(
        settings.mobileBackground.copyWith(
          iosEnabled: false,
          liveActivitiesEnabled: true,
        ),
      );
      final stored =
          jsonDecode(h.preferences.getString('mobile_background_settings_v1')!)
              as Map;
      expect(stored['iosEnabled'], isFalse);
      expect(stored['liveActivitiesEnabled'], isTrue);
      final reloaded = SettingsProvider(h.preferences);
      await reloaded.loaded;
      expect(reloaded.mobileBackground.iosEnabled, isFalse);
      expect(reloaded.mobileBackground.liveActivitiesEnabled, isTrue);
      reloaded.dispose();
      settings.dispose();
    },
  );
}
