import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/models/mobile_background_settings.dart';
import 'package:sakrylle_chat/core/services/mobile_background.dart';
import 'package:sakrylle_chat/l10n/app_localizations.dart';

// Legacy iOS service scenarios run against the replacement serial coordinator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.sakrylle.ios_background');
  final calls = <MethodCall>[];
  late MobileBackgroundCoordinator service;
  late AppLocalizations l10n;
  setUp(() async {
    calls.clear();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getStatus' || call.method == 'sync') {
            return {
              'notificationsAuthorized': true,
              'liveActivitiesEnabled': true,
            };
          }
          return null;
        });
    service = MobileBackgroundCoordinator(
      platform: TargetPlatform.iOS,
      channel: channel,
    );
  });
  tearDown(() async {
    await service.flush();
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> start() => service.start(
    id: 'run',
    conversationId: 'chat',
    title: 'Generating',
    cancel: () async {},
  );
  Map snapshot() =>
      calls.lastWhere((call) => call.method == 'sync').arguments as Map;
  test('does nothing on desktop platforms', () async {
    service.dispose();
    service = MobileBackgroundCoordinator(
      platform: TargetPlatform.macOS,
      channel: channel,
    );
    await start();
    expect(calls, isEmpty);
    expect(service.activeTaskIds, isEmpty);
  });
  test('disabled settings never enable native background resources', () async {
    await service.configure(const MobileBackgroundSettings(), l10n);
    await start();
    final settings = snapshot()['settings'] as Map;
    expect(settings['iosEnabled'], isFalse);
    expect(settings['liveActivitiesEnabled'], isFalse);
    expect(calls.map((c) => c.method), isNot(contains('requestPermission')));
  });
  test('late updates cannot resurrect a completed session', () async {
    await service.configure(
      const MobileBackgroundSettings(iosEnabled: true),
      l10n,
    );
    await start();
    await service.finish('run', BackgroundTaskOutcome.completed);
    service.update('run', phase: BackgroundTaskPhase.generating, tokens: 12);
    await service.flush();
    expect(service.activeTaskIds, isEmpty);
    expect(snapshot()['tasks'], isEmpty);
  });
  test('streams real token counts without synthetic progress', () async {
    await service.configure(
      const MobileBackgroundSettings(iosEnabled: true),
      l10n,
    );
    await start();
    service.update('run', phase: BackgroundTaskPhase.generating, tokens: 12);
    await service.flush();
    final task = (snapshot()['tasks'] as List).single as Map;
    expect(task['tokens'], 12);
    expect(task.containsKey('progress'), isFalse);
  });
  test('cancellation clears session and duplicate finish is ignored', () async {
    await service.configure(
      const MobileBackgroundSettings(iosEnabled: true),
      l10n,
    );
    await start();
    await service.finish('run', BackgroundTaskOutcome.cancelled);
    final count = calls.length;
    await service.finish('run', BackgroundTaskOutcome.completed);
    expect(calls.length, count);
    expect(service.activeTaskIds, isEmpty);
  });
  test('native status exposes permission state', () async {
    await service.refreshStatus();
    expect(service.status.flag('notificationsAuthorized'), isTrue);
    expect(service.status.flag('liveActivitiesEnabled'), isTrue);
    expect(service.status.flag('unknown'), isFalse);
  });
  test('permissions and settings are explicit actions', () async {
    await service.configure(const MobileBackgroundSettings(), l10n);
    calls.clear();
    await service.requestPermission('notifications');
    await service.openSettings('app');
    expect(calls.where((c) => c.method == 'requestPermission'), hasLength(1));
    expect(calls.where((c) => c.method == 'openSettings'), hasLength(1));
  });
}
