import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_version.dart';
import 'update_apply.dart';
import 'update_channel.dart';
import 'update_feed.dart';
import 'update_policy.dart';
import 'version_compare.dart';

enum UpdateUiStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToApply,
  externalChannel,
  disabled,
  unsupported,
  error,
}

class UpdateSnapshot {
  const UpdateSnapshot({
    required this.status,
    required this.channel,
    this.message,
    this.feed,
    this.artifact,
    this.plan,
    this.currentVersion = kAppVersion,
  });

  final UpdateUiStatus status;
  final UpdateChannel channel;
  final String? message;
  final UpdateFeed? feed;
  final UpdatePlatformArtifact? artifact;
  final UpdateApplyPlan? plan;
  final String currentVersion;

  static UpdateSnapshot initial(UpdateChannel channel) => UpdateSnapshot(
        status: UpdateUiStatus.idle,
        channel: channel,
        currentVersion: kAppVersion,
      );
}

typedef FeedFetcher = Future<String> Function(Uri url);

/// Checks the marketing-site feed and stages installer-based updates.
class UpdateService {
  UpdateService({
    this.feedUrl = kDefaultUpdateFeedUrl,
    FeedFetcher? fetchFeed,
    http.Client? client,
  })  : _fetchFeed = fetchFeed,
        _client = client;

  final String feedUrl;
  final FeedFetcher? _fetchFeed;
  final http.Client? _client;

  static const lastCheckPrefsKey = 'instalay_update_last_check_v1';
  static const throttle = Duration(hours: 24);

  UpdateChannel detectChannel() => detectUpdateChannel(
        resolvedExecutable: UpdateApply.resolvedExecutable(),
      );

  String? platformKey() => updatePlatformKey(
        architecture: UpdateApply.hostArchitecture(),
      );

  Future<UpdatePolicy> policy() => UpdatePolicy.load();

  Future<UpdateSnapshot> check({bool force = false}) async {
    final channel = detectChannel();
    final pol = await policy();
    if (!pol.allowCheck) {
      return UpdateSnapshot(
        status: UpdateUiStatus.disabled,
        channel: channel,
        message:
            'Updates are disabled by policy (INSTALAY_UPDATE_POLICY / managed prefs).',
      );
    }
    if (channel == UpdateChannel.unsupported) {
      return UpdateSnapshot(
        status: UpdateUiStatus.unsupported,
        channel: channel,
        message: 'This build does not use the in-app updater '
            '(web, mobile, or Linux Phase 1).',
      );
    }
    if (channel == UpdateChannel.msStore) {
      return UpdateSnapshot(
        status: UpdateUiStatus.externalChannel,
        channel: channel,
        message:
            'Installed from the Microsoft Store. Use Store updates, or winget if you installed that way.',
      );
    }
    if (channel == UpdateChannel.homebrew) {
      return UpdateSnapshot(
        status: UpdateUiStatus.externalChannel,
        channel: channel,
        message: 'Installed via Homebrew. Run: brew upgrade --cask instalay',
      );
    }

    try {
      final raw = await _loadFeed();
      final feed = UpdateFeed.parse(raw);
      await _markChecked();
      if (feed.version.isEmpty) {
        return UpdateSnapshot(
          status: UpdateUiStatus.error,
          channel: channel,
          message: 'Update feed is missing a version.',
          feed: feed,
        );
      }
      if (!isVersionNewer(feed.version, kAppVersion)) {
        return UpdateSnapshot(
          status: UpdateUiStatus.upToDate,
          channel: channel,
          message: 'You are on the latest version ($kAppVersion).',
          feed: feed,
        );
      }
      final key = platformKey();
      final artifact = key == null ? null : feed.platform(key);
      if (artifact == null || artifact.url.isEmpty) {
        return UpdateSnapshot(
          status: UpdateUiStatus.error,
          channel: channel,
          message: 'Feed has ${feed.version} but no artifact for $key.',
          feed: feed,
        );
      }
      // Prefer exe-setup on Windows; zip-app on macOS.
      if (defaultTargetPlatform == TargetPlatform.windows &&
          artifact.installerKind != 'exe-setup') {
        // Still allow if URL looks like setup.exe
        final name = artifact.url.toLowerCase();
        if (!name.contains('setup') || !name.endsWith('.exe')) {
          return UpdateSnapshot(
            status: UpdateUiStatus.error,
            channel: channel,
            message:
                'Windows in-app updates require the setup EXE (installerKind exe-setup).',
            feed: feed,
            artifact: artifact,
          );
        }
      }
      return UpdateSnapshot(
        status: UpdateUiStatus.available,
        channel: channel,
        message: 'Version ${feed.version} is available '
            '(you have $kAppVersion).',
        feed: feed,
        artifact: artifact,
      );
    } catch (e) {
      return UpdateSnapshot(
        status: UpdateUiStatus.error,
        channel: channel,
        message: 'Update check failed: $e',
      );
    }
  }

  /// Download + verify + write apply stub. Does not exit the app.
  Future<UpdateSnapshot> downloadAndStage(UpdateSnapshot available) async {
    final channel = available.channel;
    final pol = await policy();
    if (!pol.allowApply) {
      return available.copyWith(
        status: UpdateUiStatus.disabled,
        message: 'Policy allows notify-only; apply is disabled.',
      );
    }
    final artifact = available.artifact;
    final feed = available.feed;
    if (artifact == null || feed == null) {
      return available.copyWith(
        status: UpdateUiStatus.error,
        message: 'Nothing to download.',
      );
    }
    try {
      final plan = await UpdateApply.stageAndPrepareApply(
        artifact: artifact,
        feedVersion: feed.version,
      );
      return available.copyWith(
        status: UpdateUiStatus.readyToApply,
        message: plan.message,
        plan: plan,
      );
    } catch (e) {
      return available.copyWith(
        status: UpdateUiStatus.error,
        message: 'Staging failed: $e',
      );
    }
  }

  Future<void> applyAndRestart(UpdateApplyPlan plan) {
    return UpdateApply.launchStubAndExit(plan);
  }

  Future<void> openMsStorePage() async {
    final storeSearch =
        Uri.parse('ms-windows-store://search/?query=InstaLay');
    if (await canLaunchUrl(storeSearch)) {
      await launchUrl(storeSearch);
      return;
    }
    await launchUrl(
      Uri.parse('https://instalay.linx.photos/download'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> shouldBackgroundCheck() async {
    final pol = await policy();
    if (!pol.allowCheck) return false;
    final channel = detectChannel();
    if (channel != UpdateChannel.downloadPage) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(lastCheckPrefsKey);
      if (raw == null) return true;
      final last = DateTime.tryParse(raw);
      if (last == null) return true;
      return DateTime.now().toUtc().difference(last) >= throttle;
    } catch (_) {
      return true;
    }
  }

  Future<String> _loadFeed() async {
    final uri = Uri.parse(feedUrl);
    if (_fetchFeed != null) return _fetchFeed(uri);
    final client = _client ?? http.Client();
    final owned = _client == null;
    try {
      final res = await client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('Feed HTTP ${res.statusCode}', uri);
      }
      return res.body;
    } finally {
      if (owned) client.close();
    }
  }

  Future<void> _markChecked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        lastCheckPrefsKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }
}

extension UpdateSnapshotCopy on UpdateSnapshot {
  UpdateSnapshot copyWith({
    UpdateUiStatus? status,
    UpdateChannel? channel,
    String? message,
    UpdateFeed? feed,
    UpdatePlatformArtifact? artifact,
    UpdateApplyPlan? plan,
    String? currentVersion,
  }) {
    return UpdateSnapshot(
      status: status ?? this.status,
      channel: channel ?? this.channel,
      message: message ?? this.message,
      feed: feed ?? this.feed,
      artifact: artifact ?? this.artifact,
      plan: plan ?? this.plan,
      currentVersion: currentVersion ?? this.currentVersion,
    );
  }
}

/// Minimal Exception for feed HTTP failures (avoid dart:io on web import path).
class HttpException implements Exception {
  HttpException(this.message, [this.uri]);
  final String message;
  final Uri? uri;
  @override
  String toString() => uri == null ? message : '$message ($uri)';
}

