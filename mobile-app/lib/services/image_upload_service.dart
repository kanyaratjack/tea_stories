import 'dart:convert';
import 'dart:io';

class ImageUploadService {
  const ImageUploadService();

  Future<String> uploadProductImage({
    required File file,
    required String apiBaseUrl,
  }) async {
    final baseUri = Uri.parse(apiBaseUrl.trim());
    final fileName = file.uri.pathSegments.isEmpty
        ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : file.uri.pathSegments.last;
    final contentType = _guessContentType(fileName);
    final presignUri = baseUri.resolve('/api/uploads/presign');
    final presignData = await _createPresign(
      uri: presignUri,
      fileName: fileName,
      contentType: contentType,
    );
    await _putBinary(
      uri: Uri.parse(presignData.uploadUrl),
      file: file,
      contentType: contentType,
    );
    return presignData.publicUrl;
  }

  Future<_PresignData> _createPresign({
    required Uri uri,
    required String fileName,
    required String contentType,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'fileName': fileName,
            'contentType': contentType,
            'folder': 'products',
          }),
        ),
      );
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Presign failed(${response.statusCode}): $body',
          uri: uri,
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid presign response.');
      }
      final root = decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;
      final uploadUrl = (root['uploadUrl'] ?? root['upload_url'] ?? '')
          .toString()
          .trim();
      final publicUrl = (root['publicUrl'] ?? root['public_url'] ?? '')
          .toString()
          .trim();
      if (uploadUrl.isEmpty || publicUrl.isEmpty) {
        throw const FormatException(
          'Presign response missing uploadUrl/publicUrl.',
        );
      }
      return _PresignData(uploadUrl: uploadUrl, publicUrl: publicUrl);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _putBinary({
    required Uri uri,
    required File file,
    required String contentType,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.putUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      final length = await file.length();
      request.headers.set(HttpHeaders.contentLengthHeader, length);
      await request.addStream(file.openRead());
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response);
        throw HttpException(
          'Upload failed(${response.statusCode}): $body',
          uri: uri,
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  String _guessContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

class _PresignData {
  const _PresignData({required this.uploadUrl, required this.publicUrl});

  final String uploadUrl;
  final String publicUrl;
}
