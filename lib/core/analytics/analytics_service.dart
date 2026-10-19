/// Product analytics seam. No analytics SDK is wired in — Firebase Analytics
/// was removed so the release carries no advertising-ID permissions — so the
/// app runs on [NoopAnalyticsService]. Plug a real implementation in here if
/// analytics returns.
///
/// Events carry no personal data — only flow/step names and outcomes.
abstract interface class AnalyticsService {
  Future<void> logEvent(String name, [Map<String, Object>? parameters]);
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {}
}
