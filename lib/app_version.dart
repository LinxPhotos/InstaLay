/// App version shown in the UI.
///
/// Keep the name in sync with `version:` in [pubspec.yaml] (the part before
/// `+`). Build number is the part after `+`.
const String kAppVersion = '0.8.1';
const String kAppBuildNumber = '18';

/// User-facing label, e.g. `0.8.0 (17)`.
String get kAppVersionLabel => '$kAppVersion ($kAppBuildNumber)';
