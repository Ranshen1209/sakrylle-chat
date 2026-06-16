import 'package:flutter_test/flutter_test.dart';

import 'package:sakrylle_chat/core/services/auth/sakrylle_oauth_service.dart';

void main() {
  group('oauthCallbackParameters', () {
    test('reads OAuth parameters from query string callbacks', () {
      final params = oauthCallbackParameters(
        Uri.parse('sakrylle-chat://oauth/callback?code=abc&state=state-1'),
      );

      expect(params['code'], 'abc');
      expect(params['state'], 'state-1');
    });

    test('reads OAuth parameters from fragment callbacks', () {
      final params = oauthCallbackParameters(
        Uri.parse('sakrylle-chat://oauth/callback#code=abc&state=state-1'),
      );

      expect(params['code'], 'abc');
      expect(params['state'], 'state-1');
    });

    test('returns an empty map when callback carries no OAuth parameters', () {
      final params = oauthCallbackParameters(
        Uri.parse('sakrylle-chat://oauth/callback'),
      );

      expect(params, isEmpty);
    });

    test('keeps OAuth error parameters available for failure reporting', () {
      final params = oauthCallbackParameters(
        Uri.parse(
          'sakrylle-chat://oauth/callback#error=access_denied&state=state-1',
        ),
      );

      expect(params['error'], 'access_denied');
      expect(params['state'], 'state-1');
    });
  });
}
