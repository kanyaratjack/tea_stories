import 'dart:convert';
import 'dart:io';

class PosBackendSyncService {
  const PosBackendSyncService();

  Future<void> testConnection({required String apiBaseUrl}) async {
    final uri = Uri.parse(apiBaseUrl.trim()).resolve('/healthz');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response);
        throw HttpException(
          'POS backend ping failed(${response.statusCode}): $body',
          uri: uri,
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> mirrorCreateOrder({
    required String apiBaseUrl,
    required String orderNo,
    required String orderType,
    required String orderChannel,
    required double total,
    String? idempotencyKey,
    DateTime? createdAt,
  }) async {
    final uri = Uri.parse(apiBaseUrl.trim()).resolve('/api/v1/orders');
    final payload = <String, Object?>{
      'order_no': orderNo,
      'order_type': orderType == 'delivery' ? 'delivery' : 'in_store',
      'channel': orderChannel,
      'total': total,
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'idempotency_key': idempotencyKey.trim(),
      if (createdAt != null) 'created_at': createdAt.toIso8601String(),
    };
    await _postJson(uri, payload);
  }

  Future<void> mirrorRefund({
    required String apiBaseUrl,
    required String orderNo,
    required double amount,
    required String reason,
    String? idempotencyKey,
    DateTime? createdAt,
  }) async {
    final uri = Uri.parse(
      apiBaseUrl.trim(),
    ).resolve('/api/v1/orders/$orderNo/refunds');
    final payload = <String, Object?>{
      'amount': amount,
      'reason': reason.trim(),
      if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty)
        'idempotency_key': idempotencyKey.trim(),
      if (createdAt != null) 'created_at': createdAt.toIso8601String(),
    };
    await _postJson(uri, payload);
  }

  Future<bool> orderExists({
    required String apiBaseUrl,
    required String orderNo,
  }) async {
    final uri = Uri.parse(
      apiBaseUrl.trim(),
    ).resolve('/api/v1/orders/${Uri.encodeComponent(orderNo)}');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode == HttpStatus.ok) return true;
      if (response.statusCode == HttpStatus.notFound) return false;
      final body = await utf8.decodeStream(response);
      throw HttpException(
        'POS backend orderExists failed(${response.statusCode}): $body',
        uri: uri,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _postJson(Uri uri, Map<String, Object?> payload) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 5));
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response);
        throw HttpException(
          'POS backend sync failed(${response.statusCode}): $body',
          uri: uri,
        );
      }
    } finally {
      client.close(force: true);
    }
  }
}
