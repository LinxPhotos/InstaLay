import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'update_apply_plan.dart';
import 'update_feed.dart';

String updateApplyHostArchitecture() {
  if (Platform.isWindows) {
    final proc = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
    final wow = Platform.environment['PROCESSOR_ARCHITEW6432'] ?? '';
    return _normArch(wow.isNotEmpty ? wow : proc);
  }
  try {
    final r = Process.runSync('uname', ['-m']);
    if (r.exitCode == 0) {
      return _normArch('${r.stdout}'.trim());
    }
  } catch (_) {}
  return _normArch(Platform.resolvedExecutable);
}

String _normArch(String raw) {
  final a = raw.toLowerCase();
  if (a.contains('arm64') || a.contains('aarch64') || a == 'arm') {
    return 'arm64';
  }
  return 'x64';
}

String updateApplyResolvedExecutable() => Platform.resolvedExecutable;

Future<String> updateApplyUpdatesRoot() async {
  if (Platform.isWindows) {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null || local.isEmpty) {
      throw StateError('LOCALAPPDATA is not set');
    }
    final root = Directory(p.join(local, 'InstaLay', 'updates'));
    await root.create(recursive: true);
    return root.path;
  }
  // macOS: beside Application Support is fine; keep a stable InstaLay folder.
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  final root = Directory(p.join(home, 'Library', 'Caches', 'InstaLay', 'updates'));
  await root.create(recursive: true);
  return root.path;
}

Future<UpdateApplyPlan> updateApplyStageAndPrepare({
  required UpdatePlatformArtifact artifact,
  required String feedVersion,
}) async {
  if (artifact.url.isEmpty || artifact.sha256.isEmpty) {
    throw StateError('Update artifact is missing url or sha256');
  }
  if (artifact.hasSignature) {
    // Structure is wired; verification lands when signing keys exist.
  }

  final root = await updateApplyUpdatesRoot();
  final staging = Directory(p.join(root, 'staging'));
  if (await staging.exists()) {
    await staging.delete(recursive: true);
  }
  await staging.create(recursive: true);

  final uri = Uri.parse(artifact.url);
  final fileName = p.basename(uri.path).isEmpty
      ? 'update.bin'
      : p.basename(uri.path);
  final artifactPath = p.join(staging.path, fileName);

  await _downloadToFile(uri, artifactPath);
  await _verifySha256(artifactPath, artifact.sha256);

  final stubPath = Platform.isWindows
      ? await _writeWindowsStub(
          staging: staging.path,
          installerPath: artifactPath,
          feedVersion: feedVersion,
        )
      : await _writeMacStub(
          staging: staging.path,
          zipPath: artifactPath,
          feedVersion: feedVersion,
        );

  return UpdateApplyPlan(
    stagingDir: staging.path,
    artifactPath: artifactPath,
    stubPath: stubPath,
    message: Platform.isWindows
        ? 'Installer staged. InstaLay will quit, run the setup quietly, '
            'refresh Start Menu shortcuts via the installer, then relaunch.'
        : 'Update staged. InstaLay will quit, replace the app bundle, then relaunch.',
  );
}

Future<void> updateApplyLaunchStubAndExit(UpdateApplyPlan plan) async {
  if (Platform.isWindows) {
    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        plan.stubPath,
      ],
      mode: ProcessStartMode.detached,
      workingDirectory: plan.stagingDir,
    );
  } else {
    await Process.start(
      '/bin/bash',
      [plan.stubPath],
      mode: ProcessStartMode.detached,
      workingDirectory: plan.stagingDir,
    );
  }
  // Give the stub a moment to attach before we disappear.
  await Future<void>.delayed(const Duration(milliseconds: 400));
  exit(0);
}

Future<void> _downloadToFile(Uri uri, String destPath) async {
  final client = http.Client();
  try {
    final req = http.Request('GET', uri);
    final res = await client.send(req);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException(
        'Download failed HTTP ${res.statusCode} for $uri',
        uri: uri,
      );
    }
    final file = File(destPath);
    final sink = file.openWrite();
    await res.stream.pipe(sink);
    await sink.close();
  } finally {
    client.close();
  }
}

Future<void> _verifySha256(String path, String expectedHex) async {
  final file = File(path);
  final digest = await sha256.bind(file.openRead()).first;
  final actual = digest.toString();
  if (actual.toLowerCase() != expectedHex.toLowerCase()) {
    throw StateError(
      'SHA-256 mismatch for $path (expected $expectedHex, got $actual)',
    );
  }
}

Future<String> _writeWindowsStub({
  required String staging,
  required String installerPath,
  required String feedVersion,
}) async {
  final exe = Platform.resolvedExecutable;
  final ourPid = pid;
  final stub = File(p.join(staging, 'apply_update.ps1'));
  // Prefer quiet Inno upgrade after our process exits. Do NOT rewrite .lnk here —
  // the setup EXE refreshes Start Menu shortcuts after files are unlocked.
  final script = '''
\$ErrorActionPreference = 'Stop'
\$Installer = '${installerPath.replaceAll("'", "''")}'
\$AppPid = $ourPid
\$Relaunch = '${exe.replaceAll("'", "''")}'
\$Log = Join-Path \$PSScriptRoot 'apply_update.log'
function Log(\$m) { Add-Content -Path \$Log -Value ("[{0}] {1}" -f (Get-Date -Format o), \$m) }
Log "Waiting for PID \$AppPid (feed $feedVersion)"
\$deadline = (Get-Date).AddMinutes(5)
while (\$true) {
  try {
    \$p = Get-Process -Id \$AppPid -ErrorAction Stop
    if (-not \$p) { break }
  } catch { break }
  if ((Get-Date) -gt \$deadline) { Log 'Timed out waiting for app exit'; break }
  Start-Sleep -Milliseconds 300
}
Start-Sleep -Milliseconds 500
Log "Starting installer \$Installer"
\$args = @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/CLOSEAPPLICATIONS','/FORCECLOSEAPPLICATIONS')
\$proc = Start-Process -FilePath \$Installer -ArgumentList \$args -PassThru -Wait
Log "Installer exit code \$(\$proc.ExitCode)"
Start-Sleep -Milliseconds 800
if (Test-Path \$Relaunch) {
  Log "Relaunching \$Relaunch"
  Start-Process -FilePath \$Relaunch
} else {
  Log "Relaunch path missing: \$Relaunch"
}
'''
  await stub.writeAsString(script);
  return stub.path;
}

Future<String> _writeMacStub({
  required String staging,
  required String zipPath,
  required String feedVersion,
}) async {
  final exe = Platform.resolvedExecutable;
  // .../InstaLay.app/Contents/MacOS/instalay → bundle is 3 levels up from exe? 
  // resolvedExecutable = InstaLay.app/Contents/MacOS/instalay
  final macosDir = p.dirname(exe);
  final contentsDir = p.dirname(macosDir);
  final appBundle = p.dirname(contentsDir);
  final ourPid = pid;
  final stub = File(p.join(staging, 'apply_update.sh'));
  final script = '''
#!/bin/bash
set -euo pipefail
LOG="\$(dirname "\$0")/apply_update.log"
log() { echo "[\$(date -u +%Y-%m-%dT%H:%M:%SZ)] \$*" >> "\$LOG"; }
ZIP='${zipPath.replaceAll("'", "'\\''")}'
APP='${appBundle.replaceAll("'", "'\\''")}'
PID=$ourPid
log "Waiting for PID \$PID (feed $feedVersion)"
for i in \$(seq 1 600); do
  if ! kill -0 "\$PID" 2>/dev/null; then break; fi
  sleep 0.25
done
sleep 0.5
STAGE="\$(dirname "\$0")/app_stage"
rm -rf "\$STAGE"
mkdir -p "\$STAGE"
log "Unzipping \$ZIP"
ditto -x -k "\$ZIP" "\$STAGE"
NEW_APP="\$(find "\$STAGE" -maxdepth 3 -name '*.app' -print -quit || true)"
if [[ -z "\$NEW_APP" ]]; then
  log "No .app in zip"
  exit 1
fi
PARENT="\$(dirname "\$APP")"
BASE="\$(basename "\$APP")"
BACKUP="\$PARENT/\$BASE.bak-instalay-update"
rm -rf "\$BACKUP"
log "Replacing \$APP"
if [[ -d "\$APP" ]]; then
  mv "\$APP" "\$BACKUP"
fi
mv "\$NEW_APP" "\$APP"
rm -rf "\$BACKUP"
log "Relaunching \$APP"
open "\$APP"
'''
  await stub.writeAsString(script);
  await Process.run('chmod', ['+x', stub.path]);
  return stub.path;
}
