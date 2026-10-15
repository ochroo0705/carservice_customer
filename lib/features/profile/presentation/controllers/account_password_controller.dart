import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/features/booking/auth/domain/auth_repository.dart';
import 'package:flutter/foundation.dart';

/// What the password page is doing. [save] sets a first password or changes
/// the current one (the same `PUT`); [remove] goes back to code-only login.
/// Both need a code sent to the account's own phone first.
enum PasswordAction { save, remove }

/// State for the account password page: whether a password is set, and the
/// request-code → confirm flow for [PasswordAction]s. The rules checked here
/// (8–128 characters, letters and digits) only give early feedback — the
/// server stays the authority and its 422 message is shown as is.
class AccountPasswordController extends ChangeNotifier {
  AccountPasswordController(this._repository);

  final AuthRepository _repository;

  /// `null` until [load] succeeds.
  bool? hasPassword;
  bool isLoading = false;
  String? loadError;

  PasswordAction? action;

  /// Where the code for [action] was sent; `null` until it was.
  String? maskedPhone;
  bool isBusy = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    loadError = null;
    notifyListeners();
    try {
      hasPassword = await _repository.hasPassword();
    } on AppFailure catch (failure) {
      loadError = failure.message;
    } catch (_) {
      loadError = 'Тодорхойгүй алдаа гарлаа.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void start(PasswordAction value) {
    action = value;
    maskedPhone = null;
    errorMessage = null;
    notifyListeners();
  }

  void cancel() {
    action = null;
    maskedPhone = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> requestOtp() => _run(() async {
    maskedPhone = await _repository.requestPasswordOtp();
  });

  /// Confirms [action] with the code (and, for [PasswordAction.save], the
  /// new password). On success [hasPassword] reflects the change and the
  /// flow closes; on failure the inputs stay and [errorMessage] is set.
  Future<bool> submit({
    required String code,
    String password = '',
    String confirmation = '',
  }) async {
    final current = action;
    if (current == null) return false;
    final trimmed = code.trim();
    final error = !RegExp(r'^\d{6}$').hasMatch(trimmed)
        ? '6 оронтой кодоо оруулна уу.'
        : current == PasswordAction.save
        ? validatePassword(password, confirmation)
        : null;
    if (error != null) {
      errorMessage = error;
      notifyListeners();
      return false;
    }
    return _run(() async {
      if (current == PasswordAction.save) {
        await _repository.setPassword(code: trimmed, password: password);
        hasPassword = true;
      } else {
        await _repository.removePassword(trimmed);
        hasPassword = false;
      }
      action = null;
      maskedPhone = null;
    });
  }

  /// The server's password rule: 8–128 characters with a letter and a digit.
  static String? validatePassword(String password, String confirmation) {
    if (password.length < 8 || password.length > 128) {
      return 'Нууц үг 8–128 тэмдэгт байна.';
    }
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password)) {
      return 'Нууц үг үсэг болон тоо агуулсан байна.';
    }
    if (password != confirmation) return 'Нууц үг таарахгүй байна.';
    return null;
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (isBusy) return false;
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppFailure catch (failure) {
      errorMessage = failure.message;
      return false;
    } catch (_) {
      errorMessage = 'Тодорхойгүй алдаа гарлаа.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
