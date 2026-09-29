import 'dart:convert';
import 'dart:io';

/// Small token-aware REST client. Configure the API origin before integration.
class ApiClient {
  ApiClient({required this.baseUrl, this.token});
  final String baseUrl;
  String? token;

  Future<dynamic> request(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      if (token case final value?) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $value');
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final payload = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('API request failed (${response.statusCode}): $payload', uri: uri);
      }
      if (payload.isEmpty) return null;
      return jsonDecode(payload);
    } finally {
      client.close(force: true);
    }
  }
}
