import 'update_apply_plan.dart';
import 'update_feed.dart';

String updateApplyHostArchitecture() => 'x64';

String updateApplyResolvedExecutable() => '';

Future<String> updateApplyUpdatesRoot() async => '';

Future<UpdateApplyPlan> updateApplyStageAndPrepare({
  required UpdatePlatformArtifact artifact,
  required String feedVersion,
}) async {
  throw UnsupportedError('In-app updates are not available on this platform');
}

Future<void> updateApplyLaunchStubAndExit(UpdateApplyPlan plan) async {
  throw UnsupportedError('In-app updates are not available on this platform');
}
