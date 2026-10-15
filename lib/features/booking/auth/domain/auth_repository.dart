import 'package:carservice_customer/features/booking/auth/domain/account.dart';

abstract interface class AuthRepository {
  Future<Account?> restoreSession();
  Future<void> requestOtp(String phone);

  /// `reactivated` бол server дээр өмнө нь deactivate хийсэн account энэ
  /// нэвтрэлтээр дахин идэвхжсэн гэсэн үг (зөвхөн `deactivatedAt`-г цэвэрлэнэ,
  /// `isActive=false` block-той account-ийг login дахин идэвхжүүлдэггүй).
  Future<({Account account, bool reactivated})> verifyOtp({
    required String phone,
    required String code,
    String? name,
  });

  /// Нууц үгээр нэвтрэх. Зөвхөн нууц үг тохируулсан Account-д ажиллана,
  /// шинэ Account үүсгэхгүй. Хариу болон хадгалах session нь [verifyOtp]-тэй
  /// ижил. Дугаар бүртгэлгүй эсвэл нууц үггүй бол буруу нууц үгтэй адил
  /// 401 буцна.
  Future<({Account account, bool reactivated})> loginWithPassword({
    required String phone,
    required String password,
  });
  Future<void> signOut();

  /// Нэвтэрсэн Account нууц үг тохируулсан эсэх.
  Future<bool> hasPassword();

  /// Нууц үг тохируулах/солих/устгахад шаардлагатай OTP-г бүртгэлтэй утсанд
  /// илгээж, masked утасны дугаар буцаана.
  Future<String> requestPasswordOtp();

  /// [requestPasswordOtp]-оор авсан кодоор нууц үг тохируулна эсвэл солино.
  Future<void> setPassword({required String code, required String password});

  /// Нууц үгийг устгана — цаашид зөвхөн OTP-оор нэвтэрнэ.
  Future<void> removePassword(String code);

  /// Account closure (deactivate/delete) хийхээс өмнө утсанд OTP илгээнэ.
  /// Буцаах утга нь бүтэн дугаар биш, тухайлбал `****1234` маягийн masked утас.
  Future<String> requestClosureOtp();

  /// Self-service deactivation: `isActive`-г хэвээр үлдээж зөвхөн
  /// `deactivatedAt`-г тэмдэглэнэ. Хэрэглэгч дахин нэвтэрч сэргээж болно.
  Future<void> deactivateAccount(String code);

  /// Backend дээр PII-г anonymize хийж, session/device/notification устгана.
  /// Буцаах боломжгүй — server талд `isActive=false` болно.
  Future<void> deleteAccount(String code);

  /// Fires whenever the session is invalidated from outside the current
  /// sign-in flow — e.g. any authenticated repository's request gets a 401
  /// and clears local storage. Lets `AuthController` drop its `account` even
  /// when the 401 happened on a screen that never wired up a dedicated
  /// unauthenticated callback.
  Stream<void> get onSessionInvalidated;
}
