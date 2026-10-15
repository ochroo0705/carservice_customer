import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Орчны тохиргоо. Утгууд `main()`-д ачаалсан `.env` asset-аас
/// (`flutter_dotenv`) уншигдана — тиймээс энгийн `flutter run` хангалттай.
/// Тухайн түлхүүрийг `--dart-define`-ээр өгвөл `.env`-ээс давуу эрхтэй
/// (release build-ийн production утгууд, README-г үзнэ үү). Аль нь ч
/// байхгүй, эсвэл `.env` ачаалагдаагүй (жишээ нь тест) үед доорх default
/// утгууд хэрэглэгдэнэ — ингэснээр debug app хоосон тохиргоотойгоор ч асаж,
/// тохиргооны алдаа нь compile-time биш runtime-д илэрнэ.
abstract final class AppEnvironment {
  static String get apiBaseUrl => const bool.hasEnvironment('API_BASE_URL')
      ? const String.fromEnvironment('API_BASE_URL')
      : _read('API_BASE_URL') ?? 'http://10.0.2.2:4000/api/v1/app';

  static String get environmentName => const bool.hasEnvironment('APP_ENV')
      ? const String.fromEnvironment('APP_ENV')
      : _read('APP_ENV') ?? 'development';

  static bool get useFakeApi => const bool.hasEnvironment('USE_FAKE_API')
      ? const bool.fromEnvironment('USE_FAKE_API')
      : _readBool('USE_FAKE_API') ?? false;

  static bool get bookingEnabled => const bool.hasEnvironment('BOOKING_ENABLED')
      ? const bool.fromEnvironment('BOOKING_ENABLED')
      : _readBool('BOOKING_ENABLED') ?? true;

  /// `.env`-ийн утга; ачаалагдаагүй, түлхүүр байхгүй эсвэл хоосон бол `null`.
  static String? _read(String key) {
    if (!dotenv.isInitialized) return null;
    final value = dotenv.maybeGet(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static bool? _readBool(String key) => switch (_read(key)?.toLowerCase()) {
    'true' => true,
    'false' => false,
    _ => null,
  };
}
