import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/responsive.dart';
import '../providers/app_providers.dart';
import '../services/linx_auth_store.dart';
import '../services/linx_client.dart';
import 'linx_account_button.dart';
import 'linx_connect.dart';

/// Modal picker: choose Linx album variants to import. Not a Linx nav shell.
Future<List<LinxVariantSummary>?> showLinxPhotoPickerDialog(
  BuildContext context, {
  required LinxAuthStore auth,
  String? initialAlbumId,
  WidgetRef? ref,
}) async {
  var store = auth;
  if (!store.isConnected) {
    if (ref != null) {
      final ok = await connectLinxPhotos(context, ref);
      if (!ok || !context.mounted) return null;
      store = await ref.read(linxAuthProvider.future);
    } else {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Connect Linx Photos'),
          content: const Text(
            'Sign in with your Linx Photos account, or use Advanced to paste a token.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'advanced'),
              child: const Text('Advanced: paste a token'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'oauth'), child: const Text('Sign in')),
          ],
        ),
      );
      if (choice == 'advanced' && context.mounted) {
        final ok = await promptPasteLinxToken(context, store);
        if (!ok) return null;
      } else if (choice == 'oauth' && context.mounted) {
        try {
          await store.connectWithOauth();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
          }
          return null;
        }
      } else {
        return null;
      }
    }
    if (!store.isConnected) return null;
  }

  if (!context.mounted) return null;
  return showDialog<List<LinxVariantSummary>>(
    context: context,
    builder: (ctx) => _LinxPickerBody(auth: store, initialAlbumId: initialAlbumId),
  );
}

class _LinxPickerBody extends StatefulWidget {
  const _LinxPickerBody({required this.auth, this.initialAlbumId});

  final LinxAuthStore auth;
  final String? initialAlbumId;

  @override
  State<_LinxPickerBody> createState() => _LinxPickerBodyState();
}

class _LinxPickerBodyState extends State<_LinxPickerBody> {
  late final LinxClient _client = LinxClient(widget.auth);
  List<LinxAlbumSummary> _albums = [];
  List<LinxVariantSummary> _variants = [];
  String? _albumId;
  final Set<String> _selected = {};
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final albums = await _client.listAlbums();
      final initial = widget.initialAlbumId ?? (albums.isNotEmpty ? albums.first.id : null);
      setState(() {
        _albums = albums;
        _albumId = initial;
      });
      if (initial != null) await _loadVariants(initial);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVariants(String albumId) async {
    setState(() {
      _loading = true;
      _error = null;
      _selected.clear();
    });
    try {
      final variants = await _client.listAlbumVariants(albumId);
      setState(() {
        _albumId = albumId;
        _variants = variants;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('Add from Linx'),
      content: SizedBox(
        width: dialogContentWidth(context, preferred: 480),
        height: isWideLayout(context) ? 420 : MediaQuery.sizeOf(context).height * 0.55,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _albumId,
                    hint: const Text('Album'),
                    items: _albums
                        .map(
                          (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) _loadVariants(id);
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _variants.length,
                      itemBuilder: (ctx, i) {
                        final v = _variants[i];
                        final checked = _selected.contains(v.variantId);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(v.fileNameHint),
                          subtitle: Text(v.variantId, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onChanged: (on) {
                            setState(() {
                              if (on == true) {
                                _selected.add(v.variantId);
                              } else {
                                _selected.remove(v.variantId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () {
                  final picked =
                      _variants.where((v) => _selected.contains(v.variantId)).toList();
                  Navigator.pop(context, picked);
                },
          child: Text('Import (${_selected.length})'),
        ),
      ],
    );
  }
}
