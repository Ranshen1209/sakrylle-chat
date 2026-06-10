import 'dart:async';

/// Web stub: loopback OAuth is never used on web ([shouldUseLoopback] is false).
class LoopbackCallback {
  LoopbackCallback({
    required this.redirectUri,
    required this.future,
    required this.close,
  });

  final String redirectUri;
  final Future<Uri> future;
  final Future<void> Function() close;
}

Future<LoopbackCallback> startLoopbackServer({
  Duration timeout = const Duration(minutes: 5),
}) {
  throw UnsupportedError('Loopback OAuth is not supported on this platform.');
}
