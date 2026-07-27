/// App version shown in the UI.
///
/// Keep the name in sync with `version:` in [pubspec.yaml] (the part before
/// `+`). Build number is the part after `+`.
const String kAppVersion = '0.7.6';
const String kAppBuildNumber = '16';

/// User-facing label, e.g. `0.7.6 (16)`.
String get kAppVersionLabel => '$kAppVersion ($kAppBuildNumber)';
