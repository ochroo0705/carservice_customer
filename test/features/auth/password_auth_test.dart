import 'dart:convert';
import 'dart:typed_data';

import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/core/network/api_client.dart';
import 'package:carservice_customer/features/booking/auth/data/fake_auth_repository.dart';
import 'package:carservice_customer/features/booking/auth/data/remote_auth_repository.dart';
import 'package:carservice_customer/features/booking/auth/data/secure_session_store.dart';
import 'package:carservice_customer/features/booking/auth/presentation/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every request and answers with [respond]'s status and JSON body.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final (int, Map<String, Object?>) Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockStorage extends Mock implements FlutterSecureStorage {}

const _sessionJson = {
  'accessToken': 'jwt-1',
  'reactivated': true,
  'account': {
    'id': 'acc-1',
    'phone': '99112233',
    'name': 'Бат',
    'hasPassword': true,
  },
};

void main() {
  group('RemoteAuthRepository password endpoints', () {
    late _MockStorage storage;
    late SecureSessionStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      storage = _MockStorage();
      when(() => storage.readAll()).thenAnswer((_) async => {});
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
      when(() => storage.deleteAll()).thenAnswer((_) async {});
      store = SecureSessionStore(storage: storage);
    });

    RemoteAuthRepository repositoryWith(_RecordingAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1/app'))
        ..httpClientAdapter = adapter;
      return RemoteAuthRepository(
        ApiClient(
          baseUrl: 'https://example.test/api/v1/app',
          dio: dio,
          accessTokenProvider: store.readToken,
          onUnauthorized: store.clear,
        ),
        store,
      );
    }

    test('loginWithPassword posts the credentials and saves the session', () async {
      final adapter = _RecordingAdapter((_) => (200, _sessionJson));
      final repository = repositoryWith(adapter);

      final result = await repository.loginWithPassword(
        phone: '99112233',
        password: 'Shine2026',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/login-password');
      expect(request.data, {'phone': '99112233', 'password': 'Shine2026'});
      expect(result.account.id, 'acc-1');
      expect(result.account.name, 'Бат');
      expect(result.reactivated, isTrue);
      expect(await store.readToken(), 'jwt-1');
    });

    test('a rejected login surfaces the server message', () async {
      final adapter = _RecordingAdapter(
        (_) => (
          401,
          {
            'error': 'Утасны дугаар эсвэл нууц үг буруу байна.',
            'code': 'INVALID_CREDENTIALS',
          },
        ),
      );
      final repository = repositoryWith(adapter);

      await expectLater(
        repository.loginWithPassword(phone: '99112233', password: 'wrong'),
        throwsA(
          isA<UnauthenticatedFailure>().having(
            (f) => f.message,
            'message',
            'Утасны дугаар эсвэл нууц үг буруу байна.',
          ),
        ),
      );
      expect(await store.readToken(), isNull);
    });

    test('password management uses GET, POST request-otp, PUT and DELETE', () async {
      final adapter = _RecordingAdapter(
        (options) => switch ((options.method, options.path)) {
          ('GET', '/account/password') => (200, {'hasPassword': true, 'updatedAt': null}),
          ('POST', '/account/password/request-otp') => (200, {'ok': true, 'maskedPhone': '******33'}),
          ('PUT', '/account/password') => (200, {'ok': true, 'hasPassword': true}),
          ('DELETE', '/account/password') => (200, {'ok': true, 'hasPassword': false}),
          _ => (404, {'error': 'unexpected ${options.method} ${options.path}'}),
        },
      );
      final repository = repositoryWith(adapter);

      expect(await repository.hasPassword(), isTrue);
      expect(await repository.requestPasswordOtp(), '******33');
      await repository.setPassword(code: '123456', password: 'Shine2026');
      await repository.removePassword('654321');

      expect(
        adapter.requests.map((r) => '${r.method} ${r.path}'),
        [
          'GET /account/password',
          'POST /account/password/request-otp',
          'PUT /account/password',
          'DELETE /account/password',
        ],
      );
      expect(adapter.requests[2].data, {'code': '123456', 'password': 'Shine2026'});
      expect(adapter.requests[3].data, {'code': '654321'});
    });
  });

  group('AuthController password login', () {
    test('signs in with a password and finishes sign-in like OTP', () async {
      final repository = FakeAuthRepository()
        ..passwords['99112233'] = 'Shine2026'
        ..nextVerifyReactivated = true;
      final controller = AuthController(repository);
      final signedIn = <String>[];
      controller.beforeSignIn = (account) async => signedIn.add(account.phone);

      controller.usePassword();
      expect(controller.step, AuthStep.password);
      expect(await controller.loginWithPassword('9911 2233', 'Shine2026'), isTrue);

      expect(controller.isAuthenticated, isTrue);
      expect(controller.phone, '99112233');
      expect(signedIn, ['99112233']);
      expect(controller.takeSessionEvent(), SessionEvent.reactivated);
    });

    test('a wrong password shows the error and stays signed out', () async {
      final repository = FakeAuthRepository()..passwords['99112233'] = 'Shine2026';
      final controller = AuthController(repository)..usePassword();

      expect(await controller.loginWithPassword('99112233', 'Buruu2026'), isFalse);

      expect(controller.isAuthenticated, isFalse);
      expect(controller.step, AuthStep.password);
      expect(controller.errorMessage, 'Утасны дугаар эсвэл нууц үг буруу байна.');
    });

    test('checks the phone and an empty password before calling the API', () async {
      final controller = AuthController(FakeAuthRepository())..usePassword();

      expect(await controller.loginWithPassword('123', 'Shine2026'), isFalse);
      expect(controller.errorMessage, '8 оронтой утасны дугаар оруулна уу.');

      expect(await controller.loginWithPassword('99112233', ''), isFalse);
      expect(controller.errorMessage, 'Нууц үгээ оруулна уу.');
    });

    test('switching back to the code flow clears the error', () async {
      final controller = AuthController(FakeAuthRepository())..usePassword();
      await controller.loginWithPassword('99112233', 'Buruu2026');
      expect(controller.errorMessage, isNotNull);

      controller.useOtp();

      expect(controller.step, AuthStep.phone);
      expect(controller.errorMessage, isNull);
    });
  });
}
