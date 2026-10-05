import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import '../desktop/desktop_window.dart';
import '../layout/responsive.dart';
import '../providers/update_provider.dart';
import '../services/update/update_channel.dart';
import '../services/update/update_service.dart';
import '../theme/app_theme.dart';
import 'instalay_wordmark.dart';

/// Opens About as a desktop dialog, or a full page on mobile / web.
Future<void> showAboutInstaLay(BuildContext context) {
  if (isDesktopWindowHost) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const _AboutDialog(),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const AboutInstaLayPage()),
  );
}

class AboutInstaLayPage extends StatelessWidget {
  const AboutInstaLayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const AboutInstaLayBody(),
          ),
        ),
      ),
    );
  }
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('About InstaLay'),
      content: SizedBox(
        width: dialogContentWidth(context, preferred: 420),
        child: const SingleChildScrollView(
          child: AboutInstaLayBody(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Shared About content for dialog and page.
class AboutInstaLayBody extends ConsumerWidget {
  const AboutInstaLayBody({super.key});

  static final _siteUri = Uri.parse('https://linx.photos/apps/instalay');
  static final _linxUri = Uri.parse('https://linx.photos');
  static final _notesUri =
      Uri.parse('https://github.com/LinxPhotos/InstaLay/releases');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = AppTheme.muted(context, 0.65);
    final update = ref.watch(updateSnapshotProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SvgPicture.asset(
            'assets/branding/instalay_logo.svg',
            height: 56,
            width: 56,
          ),
        ),
        const SizedBox(height: 12),
        const Center(child: InstaLayWordmark(fontSize: 28)),
        const SizedBox(height: 6),
        Text(
          'Version $kAppVersionLabel',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          _channelLabel(update.channel),
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Text(
          'Batch-frame photos for Instagram without awkward crops. '
          'Pick a ratio, mat, and border — or stitch a tapestry carousel.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Text(
          '(c) Linx Photos',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _UpdateSection(update: update),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: () => _open(_siteUri),
              child: const Text('Website'),
            ),
            TextButton(
              onPressed: () => _open(_linxUri),
              child: const Text('(c) Linx Photos'),
            ),
            TextButton(
              onPressed: () => _open(
                Uri.tryParse(update.feed?.notesUrl ?? '') ?? _notesUri,
              ),
              child: const Text('Release notes'),
            ),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'InstaLay',
                applicationVersion: kAppVersionLabel,
                applicationLegalese: '(c) Linx Photos',
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SvgPicture.asset(
                    'assets/branding/instalay_logo.svg',
                    height: 48,
                    width: 48,
                  ),
                ),
              ),
              child: const Text('Licenses'),
            ),
          ],
        ),
      ],
    );
  }

  static String _channelLabel(UpdateChannel channel) => switch (channel) {
        UpdateChannel.downloadPage => 'Channel: download page',
        UpdateChannel.msStore => 'Channel: Microsoft Store',
        UpdateChannel.homebrew => 'Channel: Homebrew',
        UpdateChannel.unsupported => 'Channel: no in-app updater',
      };

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _UpdateSection extends ConsumerWidget {
  const _UpdateSection({required this.update});

  final UpdateSnapshot update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = AppTheme.muted(context, 0.65);
    final busy = update.status == UpdateUiStatus.checking ||
        update.status == UpdateUiStatus.downloading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (update.message != null && update.message!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              update.message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12, height: 1.35),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () => ref
                      .read(updateSnapshotProvider.notifier)
                      .check(force: true),
              child: Text(busy ? 'Working…' : 'Check for updates'),
            ),
            if (update.status == UpdateUiStatus.available)
              FilledButton(
                onPressed: () => ref
                    .read(updateSnapshotProvider.notifier)
                    .downloadAndStage(),
                child: const Text('Download update'),
              ),
            if (update.status == UpdateUiStatus.readyToApply)
              FilledButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Restart to update?'),
                      content: const Text(
                        'InstaLay will quit, apply the update, then relaunch. '
                        'Save your work first. Start Menu shortcuts are '
                        'refreshed by the installer after exit (avoids locked .lnk issues).',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Later'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Restart now'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(updateSnapshotProvider.notifier)
                        .applyAndRestart();
                  }
                },
                child: const Text('Restart to apply'),
              ),
            if (update.status == UpdateUiStatus.externalChannel &&
                update.channel == UpdateChannel.msStore)
              TextButton(
                onPressed: () => ref
                    .read(updateSnapshotProvider.notifier)
                    .openExternalChannel(),
                child: const Text('Open Store'),
              ),
          ],
        ),
      ],
    );
  }
}


