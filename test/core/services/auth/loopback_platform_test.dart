import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/services/auth/sakrylle_oauth_service.dart';

void main() {
  group('shouldUseLoopback', () {
    test('windows/linux use loopback', () {
      expect(shouldUseLoopback(TargetPlatform.windows), isTrue);
      expect(shouldUseLoopback(TargetPlatform.linux), isTrue);
    });
    test('mobile/macos use custom scheme', () {
      expect(shouldUseLoopback(TargetPlatform.android), isFalse);
      expect(shouldUseLoopback(TargetPlatform.iOS), isFalse);
      expect(shouldUseLoopback(TargetPlatform.macOS), isFalse);
    });
    test('web never uses loopback', () {
      expect(shouldUseLoopback(TargetPlatform.windows, isWeb: true), isFalse);
    });
  });
}
