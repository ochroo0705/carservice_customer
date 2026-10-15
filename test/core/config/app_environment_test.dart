import 'package:carservice_customer/core/config/app_environment.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(dotenv.clean);

  test('falls back to defaults when .env is not loaded', () {
    expect(dotenv.isInitialized, isFalse);
    expect(AppEnvironment.apiBaseUrl, 'http://10.0.2.2:4000/api/v1/app');
    expect(AppEnvironment.environmentName, 'development');
    expect(AppEnvironment.useFakeApi, isFalse);
    expect(AppEnvironment.bookingEnabled, isTrue);
  });

  test('reads values from the loaded .env', () {
    dotenv.loadFromString(
      envString: '''
API_BASE_URL=https://api.example.test/api/v1/app
APP_ENV=staging
USE_FAKE_API=TRUE
BOOKING_ENABLED=false
''',
    );

    expect(AppEnvironment.apiBaseUrl, 'https://api.example.test/api/v1/app');
    expect(AppEnvironment.environmentName, 'staging');
    expect(AppEnvironment.useFakeApi, isTrue);
    expect(AppEnvironment.bookingEnabled, isFalse);
  });

  test('blank or unparseable .env values fall back to defaults', () {
    dotenv.loadFromString(
      envString: '''
API_BASE_URL=
USE_FAKE_API=yes
''',
    );

    expect(AppEnvironment.apiBaseUrl, 'http://10.0.2.2:4000/api/v1/app');
    expect(AppEnvironment.useFakeApi, isFalse);
  });
}
