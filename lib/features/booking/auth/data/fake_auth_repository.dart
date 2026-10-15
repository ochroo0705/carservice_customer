import 'dart:async';

import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/features/booking/auth/domain/account.dart';
import 'package:carservice_customer/features/booking/auth/domain/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({bool signedIn = false}) {
    if (signedIn) {
      _account = const Account(id: 'fake-account', phone: '99112233');
    }
  }

  Account? _account;

  /// Set to make [verifyOtp] report the server's `reactivated` flag.
  bool nextVerifyReactivated = false;

  /// Set to make [deactivateAccount]/[deleteAccount] throw, simulating a
  /// wrong/expired closure OTP (server 422 `OTP_INVALID`).
  bool closureShouldFail = false;

  /// When true, [requestClosureOtp] fails (e.g. a 429 throttle).
  bool closureOtpShouldFail = false;

  /// Records the last successful closure call as `(kind, code)`, where
  /// `kind` is `'deactivate'` or `'delete'`.
  (String, String)? lastClosure;

  /// Passwords by phone, in memory only: [setPassword] adds the signed-in
  /// account's, [removePassword] drops it, [loginWithPassword] checks it.
  final Map<String, String> passwords = {};

  @override
  // Fake mode never triggers a real 401, so nothing ever fires here — kept
  // only to satisfy the interface.
  Stream<void> get onSessionInvalidated => const Stream.empty();

  @override
  Future<Account?> restoreSession() async => _account;

  @override
  Future<void> requestOtp(String phone) async {
    if (!RegExp(r'^\d{8}$').hasMatch(phone)) {
      throw const ValidationFailure('8 оронтой утасны дугаар оруулна уу.');
    }
  }

  @override
  Future<({Account account, bool reactivated})> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ValidationFailure('6 оронтой код оруулна уу.');
    }
    _account = Account(
      id: 'fake-account',
      phone: phone,
      name: name?.trim().isEmpty ?? true ? null : name!.trim(),
    );
    return (account: _account!, reactivated: nextVerifyReactivated);
  }

  @override
  Future<({Account account, bool reactivated})> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    // Same answer for an unknown phone and a wrong password, like the server.
    if (passwords[phone] != password) {
      throw const UnauthenticatedFailure(
        'Утасны дугаар эсвэл нууц үг буруу байна.',
      );
    }
    _account = Account(id: 'fake-account', phone: phone);
    return (account: _account!, reactivated: nextVerifyReactivated);
  }

  @override
  Future<void> signOut() async => _account = null;

  @override
  Future<bool> hasPassword() async =>
      passwords.containsKey(_signedInAccount().phone);

  @override
  Future<String> requestPasswordOtp() async {
    final phone = _signedInAccount().phone;
    return '${'*' * (phone.length - 2)}${phone.substring(phone.length - 2)}';
  }

  @override
  Future<void> setPassword({
    required String code,
    required String password,
  }) async {
    _checkPasswordOtp(code);
    passwords[_signedInAccount().phone] = password;
  }

  @override
  Future<void> removePassword(String code) async {
    _checkPasswordOtp(code);
    passwords.remove(_signedInAccount().phone);
  }

  Account _signedInAccount() =>
      _account ?? (throw const UnauthenticatedFailure());

  void _checkPasswordOtp(String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ValidationFailure('Код буруу байна.');
    }
  }

  @override
  Future<String> requestClosureOtp() async {
    if (closureOtpShouldFail) {
      throw const ValidationFailure('Хэт олон код хүслээ.');
    }
    return '****1234';
  }

  @override
  Future<void> deactivateAccount(String code) async {
    if (closureShouldFail) {
      throw const ValidationFailure('Код буруу эсвэл хугацаа дууссан.');
    }
    lastClosure = ('deactivate', code);
    _account = null;
  }

  @override
  Future<void> deleteAccount(String code) async {
    if (closureShouldFail) {
      throw const ValidationFailure('Код буруу эсвэл хугацаа дууссан.');
    }
    lastClosure = ('delete', code);
    _account = null;
  }
}
