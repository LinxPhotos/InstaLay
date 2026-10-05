import 'dart:async';
import 'dart:io';

/// RFC 8252 loopback listener for Windows/Linux desktop.
Future<({String redirectUri, Future<String> callbackUrl})> startOauthLoopback() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  final redirectUri = 'http://127.0.0.1:$port/oauth/callback';
  final completer = Completer<String>();

  server.listen((HttpRequest request) async {
    final requestUri = request.requestedUri;
    final path = requestUri.path.replaceAll(RegExp(r'/+$'), '');
    if (path != '/oauth/callback') {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    final location = requestUri.toString();
    request.response.statusCode = 200;
    request.response.headers.contentType = ContentType.html;
    request.response.write(
      '<!DOCTYPE html><html><body style="font-family:system-ui;background:#1a1b1e;color:#eee;'
      'display:grid;place-items:center;min-height:100vh">'
      '<p>Sign-in complete. You can close this window and return to InstaLay.</p>'
      '<script>window.close();</script></body></html>',
    );
    await request.response.close();
    if (!completer.isCompleted) completer.complete(location);
    await server.close(force: true);
  });

  final callbackUrl = completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () {
      server.close(force: true);
      throw TimeoutException('Sign-in timed out');
    },
  );

  return (redirectUri: redirectUri, callbackUrl: callbackUrl);
}
