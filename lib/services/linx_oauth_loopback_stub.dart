/// Stub when `dart:io` is unavailable (web).
Future<({String redirectUri, Future<String> callbackUrl})> startOauthLoopback() {
  throw UnsupportedError('Loopback OAuth is not available on this platform');
}
