import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/core/network/api_client.dart';
import 'package:carservice_customer/features/booking/auth/data/secure_session_store.dart';
import 'package:carservice_customer/features/booking/auth/domain/account.dart';
import 'package:carservice_customer/features/booking/auth/domain/auth_repository.dart';

/// Account realm-ийн phone + OTP / нууц үгийн authentication adapter.
///
/// OTP амжилттай бол server-ийн access token болон Account-ийг нэг session
/// болгон secure storage-д хадгална. Customer API нь refresh endpoint-гүй тул
/// дараагийн app launch дээр token-ийг дахин ашиглах нь зориудын хэрэгжилт.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._client, this._sessionStore);

  final ApiClient _client;
  final SecureSessionStore _sessionStore;

  @override
  Stream<void> get onSessionInvalidated => _sessionStore.onCleared;

  @override
  /// Өмнө хадгалсан session-ийг сэргээнэ. Secure storage-д шаардлагатай
  /// талбарын аль нэг нь дутуу бол хагас session үүсгэхгүй.
  Future<Account?> restoreSession() => _sessionStore.readAccount();

  @override
  /// OTP хүсэх endpoint зөвхөн phone-г хүлээн авна; кодыг client талд
  /// хадгалахгүй, verify алхам дээр хэрэглэгч дахин оруулна.
  Future<void> requestOtp(String phone) async {
    await _client.postJson('/auth/request-otp', {'phone': phone});
  }

  @override
  Future<({Account account, bool reactivated})> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async {
    final json = await _client.postJson('/auth/verify-otp', {
      'phone': phone,
      'code': code,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    return _startSession(json);
  }

  @override
  Future<({Account account, bool reactivated})> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final json = await _client.postJson('/auth/login-password', {
      'phone': phone,
      'password': password,
    });
    return _startSession(json);
  }

  /// `verify-otp` болон `login-password` ижил хариу буцаана: token болон
  /// account-ийг шалгаж нэг session болгон хадгална.
  Future<({Account account, bool reactivated})> _startSession(
    Map<String, dynamic> json,
  ) async {
    final token = json['accessToken'];
    final accountJson = json['account'];
    if (token is! String || token.isEmpty || accountJson is! Map) {
      throw const UnexpectedFailure('Нэвтрэх хариу буруу байна.');
    }
    final map = Map<String, dynamic>.from(accountJson);
    final id = map['id'];
    final accountPhone = map['phone'];
    if (id is! String || accountPhone is! String) {
      throw const UnexpectedFailure('Хэрэглэгчийн мэдээлэл буруу байна.');
    }
    final account = Account(
      id: id,
      phone: accountPhone,
      name: map['name'] is String ? map['name'] as String : null,
    );
    // Token болон identity-г хамтад нь хадгална. Нэг нь хадгалагдаад нөгөө нь
    // тасарвал launch үеийн restore нь буруу authenticated төлөв үүсгэхээс
    // сэргийлж incomplete session-ийг хүлээж авахгүй.
    await _sessionStore.save(token: token, account: account);
    return (account: account, reactivated: json['reactivated'] == true);
  }

  @override
  /// Local session-г цэвэрлэнэ. Device registration removal нь тусдаа
  /// best-effort урсгалд хийгддэг бөгөөд authentication logout-ийг блоклохгүй.
  Future<void> signOut() => _sessionStore.clear();

  @override
  Future<bool> hasPassword() async {
    final json = await _client.getJson('/account/password');
    return json['hasPassword'] == true;
  }

  @override
  Future<String> requestPasswordOtp() async {
    final json = await _client.postJson(
      '/account/password/request-otp',
      const {},
    );
    return json['maskedPhone'] as String? ?? '';
  }

  @override
  Future<void> setPassword({
    required String code,
    required String password,
  }) async {
    await _client.putJson('/account/password', {
      'code': code,
      'password': password,
    });
  }

  @override
  Future<void> removePassword(String code) async {
    await _client.deleteJson('/account/password', {'code': code});
  }

  @override
  Future<String> requestClosureOtp() async {
    final json = await _client.postJson('/account/close/request-otp', const {});
    return json['maskedPhone'] as String? ?? '';
  }

  @override
  Future<void> deactivateAccount(String code) async {
    await _client.postJson('/account/deactivate', {'code': code});
    await _sessionStore.clear();
  }

  @override
  Future<void> deleteAccount(String code) async {
    await _client.postJson('/account/delete', {'code': code});
    await _sessionStore.clear();
  }
}
