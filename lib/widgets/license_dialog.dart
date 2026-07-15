import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/license_service.dart';
import '../theme/app_theme.dart';

Future<void> showLicenseDialog(
  BuildContext context,
  LicenseService license,
) async {
  final controller = TextEditingController(text: license.licenseKey ?? '');
  final buyUri = Uri.parse('https://linxphotos.github.io/insta-lay/buy');

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('InstaLay license'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                license.isLicensed
                    ? 'Licensed — thanks for supporting the developer. Same app as InstaLay Free.'
                    : 'InstaLay Free is the full app. Enter an IL-···· key, or buy yearly (\$30) or lifetime (\$100) to support the developer.',
                style: TextStyle(color: AppTheme.muted(ctx, 0.7)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'License key',
                  hintText: 'IL-XXXX-XXXX-XXXX-XXXX',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (await canLaunchUrl(buyUri)) {
                await launchUrl(buyUri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Buy InstaLay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await license.activate(controller.text);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'License activated' : 'Invalid key format'),
                ),
              );
              if (ok) Navigator.pop(ctx);
            },
            child: const Text('Activate'),
          ),
        ],
      );
    },
  );
}
