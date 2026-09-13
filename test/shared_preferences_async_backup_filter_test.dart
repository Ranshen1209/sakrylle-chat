import 'package:sakrylle_chat/core/database/business_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/database/business_settings_router.dart';
import 'support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('snapshot excludes local-only fonts and desktop hotkeys', () {
    final snapshot = BusinessSettingsRouter.normalizeAndRoute({
      'display_chat_font_scale_v1': 1.3,
      'desktop_hotkeys_commands_v1': ['close_window=cmd+w'],
      'desktop_hotkeys_enabled_v1': ['close_window=1'],
      'display_auto_scroll_enabled_v1': false,
    });
    final exported = BusinessSettingsRouter.exportSnapshot(snapshot);
    expect(exported.containsKey('display_chat_font_scale_v1'), isFalse);
    expect(exported.containsKey('desktop_hotkeys_commands_v1'), isFalse);
    expect(exported.containsKey('desktop_hotkeys_enabled_v1'), isFalse);
    expect(exported['display_auto_scroll_enabled_v1'], isFalse);
  });
  test(
    'restoring old backup ignores font scale and preserves synced settings',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      await harness.repository.replaceSnapshot(
        BusinessSettingsRouter.normalizeAndRoute({
          'display_chat_font_scale_v1': 1.5,
          'display_auto_scroll_enabled_v1': false,
        }),
      );
      final restored = BusinessPreferences(harness.repository);
      await restored.load();
      expect(restored.containsKey('display_chat_font_scale_v1'), isFalse);
      expect(restored.getBool('display_auto_scroll_enabled_v1'), isFalse);
    },
  );
  test('single local font preference cannot enter business storage', () async {
    final harness = await createBusinessTestHarness(initial: {});
    await expectLater(
      harness.preferences.setDouble('display_chat_font_scale_v1', 1.5),
      throwsArgumentError,
    );
  });
  test(
    'restore rejects platform-specific hotkeys from another platform',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      await harness.repository.replaceSnapshot(
        BusinessSettingsRouter.normalizeAndRoute({
          'desktop_hotkeys_commands_v1': ['close_window=cmd+w'],
          'desktop_hotkeys_enabled_v1': ['close_window=1'],
        }),
      );
      final exported = BusinessSettingsRouter.exportSnapshot(
        await harness.repository.readSnapshot(),
      );
      expect(exported.containsKey('desktop_hotkeys_commands_v1'), isFalse);
      expect(exported.containsKey('desktop_hotkeys_enabled_v1'), isFalse);
    },
  );
}
