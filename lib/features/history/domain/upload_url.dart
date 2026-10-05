import 'package:carcare_customer_mobile/core/config/app_environment.dart';

/// Серверийн `/uploads/...` харьцангуй замыг API-ийн origin дээр үндэслэн
/// бүтэн URL болгоно. `http(s)://` URL өөрчлөгдөхгүй. Origin нь
/// `API_BASE_URL`-ийн `/api/v1/app` замыг хассан хэсэг.
String resolveUploadUrl(String url, {String? baseUrl}) {
  final trimmed = url.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  final base = Uri.tryParse(baseUrl ?? AppEnvironment.apiBaseUrl);
  if (base == null || !base.hasScheme || base.host.isEmpty) return trimmed;
  final origin =
      '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
  return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
}
