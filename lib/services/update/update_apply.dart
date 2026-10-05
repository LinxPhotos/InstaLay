import 'update_apply_stub.dart'
    if (dart.library.io) 'update_apply_io.dart';

import 'update_apply_plan.dart';
import 'update_feed.dart';

export 'update_apply_plan.dart';

/// Platform apply helpers (IO) or no-ops (web).
abstract final class UpdateApply {
  /// Host CPU architecture token (`x64` / `arm64`).
  static String hostArchitecture() => updateApplyHostArchitecture();

  /// Absolute path of the running executable (empty on unsupported hosts).
  static String resolvedExecutable() => updateApplyResolvedExecutable();

  /// Staging root for downloads (Windows: %LOCALAPPDATA%\InstaLay\updates).
  static Future<String> updatesRoot() => updateApplyUpdatesRoot();

  /// Download [artifact] into staging, verify sha256, write quit-then-apply stub.
  static Future<UpdateApplyPlan> stageAndPrepareApply({
    required UpdatePlatformArtifact artifact,
    required String feedVersion,
  }) =>
      updateApplyStageAndPrepare(
        artifact: artifact,
        feedVersion: feedVersion,
      );

  /// Start the stub detached and return; caller should exit the app.
  static Future<void> launchStubAndExit(UpdateApplyPlan plan) =>
      updateApplyLaunchStubAndExit(plan);
}
