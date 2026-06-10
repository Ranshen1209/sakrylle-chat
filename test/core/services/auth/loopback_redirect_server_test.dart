import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sakrylle_chat/core/services/auth/loopback_redirect_server.dart';

void main() {
  test('loopback server resolves with the full callback uri', () async {
    final cb = await startLoopbackServer();
    expect(cb.redirectUri, startsWith('http://127.0.0.1:'));
    expect(cb.redirectUri, endsWith('/callback'));

    final res = await http.get(
      Uri.parse('${cb.redirectUri}?code=abc&state=xyz'),
    );
    expect(res.statusCode, 200);

    final uri = await cb.future;
    expect(uri.queryParameters['code'], 'abc');
    expect(uri.queryParameters['state'], 'xyz');
    await cb.close();
  });

  test('loopback server times out and closes', () async {
    final cb = await startLoopbackServer(
      timeout: const Duration(milliseconds: 200),
    );
    expect(() => cb.future, throwsA(isA<Exception>()));
    await cb.close();
  });
}
