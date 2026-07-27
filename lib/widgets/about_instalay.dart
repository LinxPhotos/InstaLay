import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_version.dart';
import '../desktop/desktop_window.dart';
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
      title: const Text('About InstaLay'),
      content: SizedBox(
        width: 420,
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
class AboutInstaLayBody extends StatelessWidget {
  const AboutInstaLayBody({super.key});

  static final _siteUri = Uri.parse('https://linx.photos/apps/instalay');
  static final _linxUri = Uri.parse('https://linx.photos');

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context, 0.65);
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
        const SizedBox(height: 16),
        Text(
          'Batch-frame photos for Instagram without awkward crops. '
          'Pick a ratio, matte, and border — or stitch a tapestry carousel.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Text(
          '© Linx Photos',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 12),
        ),
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
              child: const Text('Linx Photos'),
            ),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'InstaLay',
                applicationVersion: kAppVersionLabel,
                applicationLegalese: '© Linx Photos',
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

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
