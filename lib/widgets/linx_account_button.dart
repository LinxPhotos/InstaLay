import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/linx_client.dart';
import '../services/linx_oauth.dart';
import 'linx_connect.dart';

/// App-bar account control: sign in when disconnected; menu + log out when connected.
class LinxAccountButton extends ConsumerWidget {
  const LinxAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(linxAuthProvider);
    final auth = authAsync.value;
    final connected = auth?.isConnected == true;

    if (!connected) {
      return IconButton(
        tooltip: 'Connect Linx Photos',
        onPressed: () => connectLinxPhotos(context, ref),
        icon: const Icon(Icons.account_circle_outlined),
      );
    }

    final label = auth?.accountName?.trim().isNotEmpty == true
        ? auth!.accountName!
        : (auth?.accountEmail?.trim().isNotEmpty == true
            ? auth!.accountEmail!
            : 'Linx Photos');

    return PopupMenuButton<String>(
      tooltip: 'Linx Photos account',
      icon: const Icon(Icons.account_circle),
      onSelected: (action) async {
        switch (action) {
          case 'logout':
            final store = await ref.read(linxAuthProvider.future);
            await store.disconnect();
            ref.invalidate(linxAuthProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out of Linx Photos')),
              );
            }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Log out'),
            dense: true,
          ),
        ),
      ],
    );
  }
}

/// Starts OAuth (or advanced paste). Used by the account button and the picker.
Future<bool> connectLinxPhotos(BuildContext context, WidgetRef ref) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Connect Linx Photos'),
      content: const Text(
        'Sign in with your Linx Photos account to import albums into InstaLay.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'advanced'),
          child: const Text('Advanced: paste a token'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'oauth'),
          child: const Text('Sign in'),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (choice == 'advanced') {
    final store = await ref.read(linxAuthProvider.future);
    if (!context.mounted) return false;
    final ok = await promptPasteLinxToken(context, store);
    if (ok) ref.invalidate(linxAuthProvider);
    return ok;
  }
  if (choice != 'oauth') return false;
  if (!context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Opening Linx Photos sign-in…')),
        ],
      ),
    ),
  );

  try {
    final store = await ref.read(linxAuthProvider.future);
    await store.connectWithOauth();
    try {
      final profile = await LinxClient(store).fetchMe();
      if (profile != null) {
        await store.saveSession(
          accessToken: store.accessToken!,
          accountEmail: profile.email,
          accountName: profile.name,
        );
      }
    } catch (_) {}
    ref.invalidate(linxAuthProvider);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connected to Linx Photos')),
      );
    }
    return true;
  } on LinxOauthException catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    }
    return false;
  }
}

