import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'linx_auth_store.dart';

class LinxAlbumSummary {
  const LinxAlbumSummary({required this.id, required this.name});

  final String id;
  final String name;

  factory LinxAlbumSummary.fromJson(Map<String, dynamic> json) {
    return LinxAlbumSummary(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Album',
    );
  }
}

class LinxVariantSummary {
  const LinxVariantSummary({
    required this.variantId,
    required this.itemId,
    required this.fileNameHint,
    this.deliveryUrl,
    this.mimeType,
  });

  final String variantId;
  final String itemId;
  final String fileNameHint;
  final String? deliveryUrl;
  final String? mimeType;

  factory LinxVariantSummary.fromJson(Map<String, dynamic> json) {
    return LinxVariantSummary(
      variantId: json['variantId'] as String,
      itemId: json['itemId'] as String,
      fileNameHint: (json['fileNameHint'] as String?) ?? 'photo.jpg',
      deliveryUrl: json['deliveryUrl'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// Thin Linx Photos client for the asset picker (no Linx navigation).
class LinxClient {
  LinxClient(this.auth);

  final LinxAuthStore auth;

  Map<String, String> get _headers {
    final t = auth.accessToken;
    if (t == null || t.isEmpty) {
      throw StateError('Not connected to Linx Photos');
    }
    return {
      'authorization': 'Bearer $t',
      'accept': 'application/json',
    };
  }

  Future<List<LinxAlbumSummary>> listAlbums() async {
    final uri = Uri.parse('${auth.apiBase}/api/desktop/v1/albums');
    final res = await http.get(uri, headers: _headers);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['ok'] != true) {
      throw StateError(body['error']?.toString() ?? 'listAlbums failed (${res.statusCode})');
    }
    final albums = (body['albums'] as List<dynamic>? ?? [])
        .map((e) => LinxAlbumSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    return albums;
  }

  Future<List<LinxVariantSummary>> listAlbumVariants(String albumId) async {
    final uri = Uri.parse(
      '${auth.apiBase}/api/desktop/v1/albums/${Uri.encodeComponent(albumId)}/variants',
    );
    final res = await http.get(uri, headers: _headers);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['ok'] != true) {
      throw StateError(
        body['error']?.toString() ?? 'listAlbumVariants failed (${res.statusCode})',
      );
    }
    return (body['variants'] as List<dynamic>? ?? [])
        .map((e) => LinxVariantSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Uint8List> downloadVariant(LinxVariantSummary variant) async {
    final url = variant.deliveryUrl;
    if (url == null || url.isEmpty) {
      throw StateError('Variant ${variant.variantId} has no deliveryUrl');
    }
    final res = await http.get(Uri.parse(url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Download failed (${res.statusCode})');
    }
    return res.bodyBytes;
  }
}
