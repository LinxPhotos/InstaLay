import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update/update_channel.dart';
import '../services/update/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final updateSnapshotProvider =
    NotifierProvider<UpdateSnapshotNotifier, UpdateSnapshot>(
  UpdateSnapshotNotifier.new,
);

class UpdateSnapshotNotifier extends Notifier<UpdateSnapshot> {
  @override
  UpdateSnapshot build() {
    final service = ref.read(updateServiceProvider);
    return UpdateSnapshot.initial(service.detectChannel());
  }

  UpdateService get _service => ref.read(updateServiceProvider);

  Future<void> check({bool force = false}) async {
    state = state.copyWith(
      status: UpdateUiStatus.checking,
      message: 'Checking...',
    );
    state = await _service.check(force: force);
  }

  Future<void> downloadAndStage() async {
    if (state.status != UpdateUiStatus.available || state.artifact == null) {
      return;
    }
    state = state.copyWith(
      status: UpdateUiStatus.downloading,
      message: 'Downloading update...',
    );
    state = await _service.downloadAndStage(state);
  }

  Future<void> applyAndRestart() async {
    final plan = state.plan;
    if (plan == null) return;
    await _service.applyAndRestart(plan);
  }

  Future<void> openExternalChannel() async {
    if (state.channel == UpdateChannel.msStore) {
      await _service.openMsStorePage();
    }
  }

  /// Throttled launch check for download-page desktop builds.
  Future<void> maybeBackgroundCheck() async {
    if (!await _service.shouldBackgroundCheck()) return;
    final next = await _service.check();
    if (state.status == UpdateUiStatus.idle ||
        state.status == UpdateUiStatus.upToDate) {
      state = next;
    }
  }
}

