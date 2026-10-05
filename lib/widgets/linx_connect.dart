import 'package:flutter/material.dart';

import '../services/linx_auth_store.dart';

/// Advanced fallback: paste a desktop pairing / OAuth access token.
Future<bool> promptPasteLinxToken(BuildContext context, LinxAuthStore auth) async {
  final controller = TextEditingController();
  final baseController = TextEditingController(text: auth.apiBase);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Paste Linx access token'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: baseController,
            decoration: const InputDecoration(labelText: 'API base URL'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Bearer access token',
              hintText: 'from pairing or OAuth',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok != true) return false;
  final token = controller.text.trim();
  if (token.isEmpty) return false;
  await auth.saveSession(accessToken: token, apiBase: baseController.text.trim());
  return true;
}
