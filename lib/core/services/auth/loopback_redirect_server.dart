import 'dart:async';
import 'dart:io';

/// Handle to a one-shot loopback OAuth redirect server.
class LoopbackCallback {
  LoopbackCallback({
    required this.redirectUri,
    required this.future,
    required this.close,
  });

  /// The redirect_uri the authorization request must use (with bound port).
  final String redirectUri;

  /// Resolves with the full callback [Uri] (query contains code/state/error),
  /// or throws on timeout.
  final Future<Uri> future;

  /// Shut down the underlying server.
  final Future<void> Function() close;
}

/// Bind an ephemeral loopback server and wait for a single `/callback` request.
Future<LoopbackCallback> startLoopbackServer({
  Duration timeout = const Duration(minutes: 5),
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final completer = Completer<Uri>();

  server.listen(
    (HttpRequest request) async {
      if (request.uri.path != '/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><html><head><meta charset="utf-8"></head>'
          '<body style="font-family:sans-serif;text-align:center;padding-top:3rem">'
          '<h2>登录成功，可关闭此窗口</h2><p>You may close this window.</p>'
          '</body></html>',
        );
      await request.response.close();
      if (!completer.isCompleted) completer.complete(request.uri);
    },
    onError: (Object _, StackTrace __) {
      // Ignore transient socket errors (e.g. client disconnects mid-request).
    },
  );

  return LoopbackCallback(
    redirectUri: 'http://127.0.0.1:${server.port}/callback',
    future: completer.future.timeout(timeout),
    close: () async {
      await server.close(force: true);
    },
  );
}
