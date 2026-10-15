import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/features/booking/auth/data/fake_auth_repository.dart';
import 'package:carservice_customer/features/profile/presentation/controllers/account_password_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineAuthRepository extends FakeAuthRepository {
  _OfflineAuthRepository() : super(signedIn: true);

  @override
  Future<bool> hasPassword() async => throw const NetworkFailure();
}

void main() {
  test('sets a first password through the request-code flow', () async {
    final repository = FakeAuthRepository(signedIn: true);
    final controller = AccountPasswordController(repository);
    await controller.load();
    expect(controller.hasPassword, isFalse);

    controller.start(PasswordAction.save);
    expect(await controller.requestOtp(), isTrue);
    expect(controller.maskedPhone, '******33');

    final saved = await controller.submit(
      code: '123456',
      password: 'Shine2026',
      confirmation: 'Shine2026',
    );

    expect(saved, isTrue);
    expect(controller.hasPassword, isTrue);
    expect(controller.action, isNull);
    expect(controller.maskedPhone, isNull);
    expect(repository.passwords['99112233'], 'Shine2026');
  });

  test('removes the password so only the code login is left', () async {
    final repository = FakeAuthRepository(signedIn: true)
      ..passwords['99112233'] = 'Shine2026';
    final controller = AccountPasswordController(repository);
    await controller.load();
    expect(controller.hasPassword, isTrue);

    controller.start(PasswordAction.remove);
    await controller.requestOtp();
    expect(await controller.submit(code: '123456'), isTrue);

    expect(controller.hasPassword, isFalse);
    expect(repository.passwords, isEmpty);
  });

  test('checks the code and password rules before calling the API', () async {
    final repository = FakeAuthRepository(signedIn: true);
    final controller = AccountPasswordController(repository)
      ..start(PasswordAction.save);

    Future<String?> errorFor(String code, String password, String confirmation) async {
      await controller.submit(code: code, password: password, confirmation: confirmation);
      return controller.errorMessage;
    }

    expect(await errorFor('12', 'Shine2026', 'Shine2026'), '6 оронтой кодоо оруулна уу.');
    expect(await errorFor('123456', 'Sh1', 'Sh1'), 'Нууц үг 8–128 тэмдэгт байна.');
    expect(await errorFor('123456', 'nuutsugnuutsug', 'nuutsugnuutsug'), 'Нууц үг үсэг болон тоо агуулсан байна.');
    expect(await errorFor('123456', '12345678', '12345678'), 'Нууц үг үсэг болон тоо агуулсан байна.');
    expect(await errorFor('123456', 'Shine2026', 'Shine2027'), 'Нууц үг таарахгүй байна.');
    expect(repository.passwords, isEmpty);
  });

  test('accepts Cyrillic letters as the letter part', () {
    expect(AccountPasswordController.validatePassword('Нууц2026үг', 'Нууц2026үг'), isNull);
  });

  test('a failed status load is shown with a retry', () async {
    final controller = AccountPasswordController(_OfflineAuthRepository());

    await controller.load();

    expect(controller.hasPassword, isNull);
    expect(controller.loadError, 'Сүлжээний холболтоо шалгана уу.');
  });

  test('a rejected code keeps the flow open with the server message', () async {
    final repository = FakeAuthRepository(signedIn: true);
    final controller = AccountPasswordController(repository)
      ..start(PasswordAction.remove);
    await controller.requestOtp();

    // The fake rejects anything but 6 digits; force a server-side failure by
    // removing while signed out.
    await repository.signOut();
    expect(await controller.submit(code: '123456'), isFalse);

    expect(controller.action, PasswordAction.remove);
    expect(controller.maskedPhone, isNotNull);
    expect(controller.errorMessage, 'Нэвтрэх шаардлагатай.');
  });
}
