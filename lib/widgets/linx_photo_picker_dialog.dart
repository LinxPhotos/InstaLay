import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/linx_auth_store.dart';
import '../services/linx_client.dart';

/// Modal picker: choose Linx album variants to import. Not a Linx nav shell.
Future<List<LinxVariantSummary>?> showLinxPhotoPickerDialog(
  BuildContext context, {
  required LinxAuthStore auth,
  String? initialAlbumId,
}) async {
  if (!auth.isConnected) {
    final connect = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connect Linx Photos'),
        content: const Text(
          'Pair InstaLay with your Linx account (same desktop connect flow as Capture One), '
          'then paste the access token here — or open the connect page in your browser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('${auth.apiBase}/account/desktop-connect');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Open connect page'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Paste token'),
          ),
        ],
      ),
    );
    if (connect != true || !context.mounted) return null;
    final token = await _promptToken(context, auth);
    if (token == null || !context.mounted) return null;
  }

  return showDialog<List<LinxVariantSummary>>(
    context: context,
    builder: (ctx) => _LinxPickerBody(auth: auth, initialAlbumId: initialAlbumId),
  );
}

Future<String?> _promptToken(BuildContext context, LinxAuthStore auth) async {
  final controller = TextEditingController();
  final baseController = TextEditingController(text: auth.apiBase);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Linx access token'),
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
              hintText: 'from pairing claim response',
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
  if (ok != true) return null;
  final token = controller.text.trim();
  if (token.isEmpty) return null;
  await auth.saveSession(accessToken: token, apiBase: baseController.text.trim());
  return token;
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
      title: const Text('Add from Linx'),
      content: SizedBox(
        width: 480,
        height: 420,
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
