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
  final buyUri = Uri.parse('https://ryanjohnson.dev/insta-lay/buy');

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Universal license'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                license.isLicensed
                    ? 'Licensed for every platform build.'
                    : 'Enter your IL-···· key from the Insta Lay website, or buy a lifetime license.',
                style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.7)),
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
            child: const Text('Buy license'),
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
