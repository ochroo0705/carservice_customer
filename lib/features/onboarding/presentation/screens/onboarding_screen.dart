import 'dart:math' as math;

import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/analytics/analytics_service.dart';
import 'package:carservice_customer/core/permissions/notification_permission_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// First-run onboarding, three pages: welcome (car illustration with live
/// status pills) → how it works (find / book / track) → ready (notification
/// ask). Shown once; [onFinish] fires when the user finishes — `login: true`
/// means route them to sign-in, `false` means drop them into the app to browse.
///
/// The whole flow is drawn on the navy "CustWelcome" board in both light and
/// dark mode, so its colors are fixed rather than theme tokens.
///
/// Location is deliberately not asked here: iOS shows its prompt only once, so
/// a cold "no" during onboarding is effectively permanent. The discovery map
/// asks in context instead (locate-me button / location banner).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.onFinish,
    this.notificationService =
        const PermissionHandlerNotificationPermissionService(),
    this.analytics = const NoopAnalyticsService(),
    super.key,
  });

  final void Function({required bool login}) onFinish;
  final NotificationPermissionService notificationService;

  /// Funnel events: `onboarding_page_view`, `onboarding_skip`,
  /// `onboarding_notification_result`, `onboarding_finish`.
  final AnalyticsService analytics;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// Fixed palette of the navy welcome board.
abstract final class _Navy {
  static const background = Color(0xFF2C3E50);
  static const raised = Color(0xFF34495E);
  static const line = Color(0xFF3B5167);
  static const ink = Color(0xFFECF0F1);
  static const muted = Color(0xFFC9D2D4);
  static const dim = Color(0xFF5F7183);
  static const primary = AppColors.accentLightText; // #C0392B
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  static const _lastIndex = 2; // welcome, how it works, ready
  static const _pageNames = ['welcome', 'how_it_works', 'ready'];

  @override
  void initState() {
    super.initState();
    _logPageView(0);
  }

  void _logPageView(int page) => widget.analytics.logEvent(
    'onboarding_page_view',
    {'page': page, 'page_name': _pageNames[page]},
  );

  void _finish({required bool login}) {
    widget.analytics.logEvent('onboarding_finish', {
      'method': login ? 'login' : 'browse',
      'page_name': _pageNames[_index],
    });
    widget.onFinish(login: login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  // Skip jumps past the info pages but never past the last page — its
  // notification ask is what booking confirmations depend on.
  void _skip() {
    widget.analytics.logEvent('onboarding_skip', {
      'page_name': _pageNames[_index],
    });
    _animateTo(_lastIndex);
  }

  @override
  Widget build(BuildContext context) {
    final onLast = _index == _lastIndex;
    // System back steps to the previous page instead of leaving the app.
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _animateTo(_index - 1);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _Navy.background,
          body: DefaultTextStyle.merge(
            style: const TextStyle(color: _Navy.ink),
            child: IconTheme.merge(
              data: const IconThemeData(color: _Navy.ink),
              child: Stack(
                children: [
                  // Concentric rings behind everything (decorative).
                  const Positioned(
                    top: 120,
                    left: -15,
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          size: Size(420, 420),
                          painter: _RingsPainter(),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        _TopBar(onSkip: onLast ? null : _skip),
                        Expanded(
                          child: PageView(
                            controller: _controller,
                            onPageChanged: (i) {
                              setState(() => _index = i);
                              _logPageView(i);
                            },
                            children: [
                              _WelcomePage(active: _index == 0),
                              _HowItWorksPage(active: _index == 1),
                              _ReadyPage(
                                active: _index == 2,
                                notificationService: widget.notificationService,
                                analytics: widget.analytics,
                              ),
                            ],
                          ),
                        ),
                        _BottomBar(
                          index: _index,
                          count: _lastIndex + 1,
                          onNext: () => _animateTo(_index + 1),
                          onStart: () => _finish(login: false),
                          onLogin: () => _finish(login: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand mark + wordmark, and "Алгасах" (hidden on the last page).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 60),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'c',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'carservice',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: onSkip == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: _Navy.muted,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Алгасах'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dots, then the primary CTA and (on the first and last page) an outlined
/// sign-in — the bottom of the CustWelcome board.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.count,
    required this.onNext,
    required this.onStart,
    required this.onLogin,
  });

  final int index;
  final int count;
  final VoidCallback onNext;
  final VoidCallback onStart;
  final VoidCallback onLogin;

  static final _primary = FilledButton.styleFrom(
    backgroundColor: _Navy.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(54),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static final _secondary = OutlinedButton.styleFrom(
    foregroundColor: _Navy.ink,
    backgroundColor: Colors.transparent,
    side: const BorderSide(color: _Navy.dim),
    minimumSize: const Size.fromHeight(54),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );

  @override
  Widget build(BuildContext context) {
    final last = index == count - 1;
    final Widget? secondary = switch (index) {
      // Returning users (e.g. after a reinstall) skip the tour to sign-in.
      0 => OutlinedButton(
        key: const ValueKey('onboarding-welcome-login'),
        onPressed: onLogin,
        style: _secondary,
        child: const Text('Бүртгэлтэй, нэвтрэх'),
      ),
      _ when last => OutlinedButton(
        key: const ValueKey('onboarding-login'),
        onPressed: onLogin,
        style: _secondary,
        child: const Text('Бүртгэлдээ нэвтрэх'),
      ),
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Dots(count: count, index: index),
          const SizedBox(height: 20),
          if (last)
            FilledButton(
              key: const ValueKey('onboarding-start'),
              onPressed: onStart,
              style: _primary,
              child: const Text('Эхлэх'),
            )
          else
            FilledButton(
              onPressed: onNext,
              style: _primary,
              child: const Text('Цааш'),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: secondary == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: secondary,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Lays a page's content out from the top-left while letting it scroll when
/// it doesn't fit — small phones and large system text sizes would otherwise
/// overflow.
class _ScrollablePage extends StatelessWidget {
  const _ScrollablePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    ),
  );
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.title,
    required this.body,
    this.large = false,
  });

  final String title;
  final String body;

  /// The welcome headline is the board's 32px hero title.
  final bool large;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: large ? 32 : 28,
          height: large ? 38 / 32 : 34 / 28,
          fontWeight: FontWeight.w700,
          letterSpacing: (large ? 32 : 28) * -0.02,
          color: _Navy.ink,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        body,
        style: const TextStyle(
          fontSize: 15,
          height: 23 / 15,
          color: _Navy.muted,
        ),
      ),
    ],
  );
}

/// Plays a one-shot animation each time its page becomes [active] (so swiping
/// back replays it), and resets while the page is off-screen. With the
/// platform "reduce motion" setting on, it shows the finished state instead.
class _PlayWhenActive extends StatefulWidget {
  const _PlayWhenActive({
    required this.active,
    required this.duration,
    required this.builder,
  });

  final bool active;
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_PlayWhenActive> createState() => _PlayWhenActiveState();
}

class _PlayWhenActiveState extends State<_PlayWhenActive>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool? _reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _sync();
    }
  }

  @override
  void didUpdateWidget(_PlayWhenActive old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (_reduceMotion ?? false) {
      _controller.value = 1;
    } else if (widget.active) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

/// Maps overall progress [t] onto the sub-range [begin]..[end], eased.
double _interval(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeInOut,
]) => curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => _ScrollablePage(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlayWhenActive(
          active: active,
          duration: const Duration(milliseconds: 1400),
          builder: (context, t) => _CarIllustration(t: t),
        ),
        const SizedBox(height: 24),
        const _PageHeading(
          large: true,
          title: 'Машиныхаа засварыг утаснаасаа хянаарай',
          body:
              'Ойролцоох сервист цаг захиалж, засварын явц, үнийн саналыг '
              'шууд хараарай.',
        ),
      ],
    ),
  );
}

/// The line-art car with two floating status pills — a hint of what the app
/// tells you, without screenshots that would drift from the real UI. Driven by
/// [t] (0..1): the car rolls in, then the pills pop up one after the other.
class _CarIllustration extends StatelessWidget {
  const _CarIllustration({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final car = _interval(t, 0, 0.5, Curves.easeOutCubic);
    final ready = _interval(t, 0.4, 0.75, Curves.easeOutBack);
    final booked = _interval(t, 0.6, 1, Curves.easeOutBack);
    return ExcludeSemantics(
      child: SizedBox(
        height: 250,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: car,
              child: Transform.translate(
                offset: Offset((1 - car) * -36, 0),
                child: const FittedBox(
                  child: CustomPaint(
                    size: Size(300, 160),
                    painter: _CarPainter(),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 22,
              child: _FloatingPill(
                progress: ready,
                leading: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.greenLightText,
                    shape: BoxShape.circle,
                  ),
                ),
                label: 'Машин бэлэн боллоо',
              ),
            ),
            Positioned(
              left: 10,
              bottom: 26,
              child: _FloatingPill(
                progress: booked,
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.accentLightText,
                ),
                label: 'Маргааш · 10:30',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingPill extends StatelessWidget {
  const _FloatingPill({
    required this.progress,
    required this.leading,
    required this.label,
  });

  final double progress;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: progress.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(0, (1 - progress) * 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: _Navy.ink,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _Navy.background,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The CustWelcome car outline (300×160 viewBox).
class _CarPainter extends CustomPainter {
  const _CarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 300, size.height / 160);
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color color) => Paint()..color = color;

    // Ground line.
    canvas.drawLine(
      const Offset(20, 140),
      const Offset(280, 140),
      stroke(_Navy.line, 2),
    );

    final body = Path()
      ..moveTo(30, 110)
      ..lineTo(270, 110)
      ..lineTo(270, 96)
      ..cubicTo(270, 88, 265, 82, 257, 80)
      ..lineTo(219, 71)
      ..lineTo(189, 43)
      ..cubicTo(183, 37, 175, 34, 167, 34)
      ..lineTo(97, 34)
      ..cubicTo(88, 34, 80, 38, 75, 45)
      ..lineTo(52, 78)
      ..lineTo(37, 82)
      ..cubicTo(32, 83, 30, 87, 30, 92)
      ..close();
    canvas
      ..drawPath(body, fill(_Navy.raised))
      ..drawPath(body, stroke(_Navy.ink, 2.5));

    final windows = Path()
      ..moveTo(84, 74)
      ..lineTo(102, 50)
      ..cubicTo(105, 46, 109, 44, 114, 44)
      ..lineTo(166, 44)
      ..cubicTo(171, 44, 175, 46, 178, 49)
      ..lineTo(203, 74)
      ..close();
    canvas
      ..drawPath(windows, fill(_Navy.background))
      ..drawPath(windows, stroke(_Navy.ink, 2))
      ..drawLine(const Offset(146, 44), const Offset(146, 74), stroke(_Navy.ink, 2));

    for (final x in const [88.0, 220.0]) {
      final c = Offset(x, 112);
      canvas
        ..drawCircle(c, 22, fill(_Navy.background))
        ..drawCircle(c, 22, stroke(_Navy.ink, 2.5))
        ..drawCircle(c, 8, fill(_Navy.ink));
    }

    // Tail light.
    canvas.drawLine(
      const Offset(256, 88),
      const Offset(270, 88),
      stroke(AppColors.accent, 4),
    );
  }

  @override
  bool shouldRepaint(_CarPainter old) => false;
}

/// Three concentric rings, the inner one dashed in accent.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final scale = size.width / 420;
    Paint ring(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas
      ..drawCircle(center, 200 * scale, ring(_Navy.raised))
      ..drawCircle(center, 150 * scale, ring(_Navy.line));

    // Dashed inner ring: 4 on, 8 off along the circumference.
    final radius = 100 * scale;
    final circumference = 2 * math.pi * radius;
    final dashes = (circumference / 12).floor();
    final step = 2 * math.pi / dashes;
    final sweep = step * 4 / 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = ring(AppColors.accent);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage({required this.active});

  final bool active;

  static const _steps = [
    ('Олох', 'Газрын зураг дээрээс ойролцоох сервисүүдийг хараарай.'),
    ('Захиалах', 'Сул цагийг нь шалгаад шууд захиалаарай.'),
    ('Хянах', 'Захиалгын явц, түүх, оношилгооны тайлангаа хараарай.'),
  ];

  @override
  Widget build(BuildContext context) => _ScrollablePage(
    child: _PlayWhenActive(
      active: active,
      duration: const Duration(milliseconds: 2200),
      // Steps light up in turn with the connector filling between them, then
      // the sample booking flips from pending to confirmed.
      builder: (context, t) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHeading(
            title: 'Гурван алхамд',
            body: 'Сервисээ олохоос засвар дуустал бүгд нэг аппад.',
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < _steps.length; i++)
            _Step(
              number: i + 1,
              title: _steps[i].$1,
              body: _steps[i].$2,
              lit: _interval(t, 0.05 + i * 0.22, 0.2 + i * 0.22),
              connector: i == _steps.length - 1
                  ? null
                  : _interval(t, 0.2 + i * 0.22, 0.27 + i * 0.22),
            ),
          const SizedBox(height: 12),
          _BookingPreview(confirmed: t >= 0.85),
        ],
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.lit,
    required this.connector,
  });

  final int number;
  final String title;
  final String body;

  /// 0 → dim, 1 → fully lit.
  final double lit;

  /// Fill of the line down to the next step; `null` for the last step.
  final double? connector;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color.lerp(_Navy.line, AppColors.accent, lit),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Color.lerp(_Navy.muted, Colors.white, lit),
                ),
              ),
            ),
            if (connector != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: CustomPaint(
                    size: const Size(2, 0),
                    painter: _ConnectorPainter(
                      fill: connector!,
                      track: _Navy.line,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: _Navy.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: _Navy.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// A vertical line between steps, filled top-down to [fill] (0..1). Painted
/// rather than laid out so it has no intrinsic height of its own — the
/// surrounding [IntrinsicHeight] sizes it from the step text.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.fill, required this.track});

  final double fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawRect(rect, Paint()..color = track)
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * fill),
        Paint()..color = AppColors.accent,
      );
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.fill != fill || old.track != track;
}

/// A decorative booking card whose status flips from pending to confirmed —
/// what "track" means.
class _BookingPreview extends StatelessWidget {
  const _BookingPreview({required this.confirmed});

  final bool confirmed;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: _MiniCard(
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          confirmed ? Icons.event_available_rounded : Icons.schedule_rounded,
          key: ValueKey(confirmed),
          size: 18,
          color: AppColors.accent,
        ),
      ),
      title: 'Тосны солилт · Маргааш 10:00',
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: confirmed
            ? const _StatusChip(
                key: ValueKey('booking-preview-confirmed'),
                label: 'Баталгаажсан',
                color: AppColors.green,
                icon: Icons.check_rounded,
              )
            : const _StatusChip(
                key: ValueKey('booking-preview-pending'),
                label: 'Хүлээгдэж буй',
                color: AppColors.warning,
              ),
      ),
    ),
  );
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final Widget leading;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _Navy.raised,
      borderRadius: BorderRadius.circular(AppRadii.control),
      border: Border.all(color: _Navy.line),
    ),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _Navy.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
        ),
      ],
    ),
  );
}

/// A tinted status pill; the dark-tuned status colors read well on navy.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// The last page: the notification ask, primed by what it's for — booking
/// confirmations. The get-started / sign-in CTAs live in the bottom bar.
/// Nothing here blocks moving on.
class _ReadyPage extends StatefulWidget {
  const _ReadyPage({
    required this.active,
    required this.notificationService,
    required this.analytics,
  });

  final bool active;
  final NotificationPermissionService notificationService;
  final AnalyticsService analytics;

  @override
  State<_ReadyPage> createState() => _ReadyPageState();
}

class _ReadyPageState extends State<_ReadyPage> with WidgetsBindingObserver {
  PermissionState _notif = PermissionState.denied;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reflect the current OS state, so a revisit shows an already-granted row.
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // openSettings() returns as soon as Settings opens, not when the user comes
  // back — so the real re-read has to happen on resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final notif = await widget.notificationService.check();
    if (mounted) setState(() => _notif = notif);
  }

  Future<void> _askNotifications() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Permanently denied: the OS won't prompt again, so send the user to
    // Settings; the resume hook re-reads the status when they come back.
    if (_notif == PermissionState.permanentlyDenied) {
      await widget.notificationService.openSettings();
      if (mounted) setState(() => _busy = false);
      return;
    }
    final state = await widget.notificationService.request();
    widget.analytics.logEvent('onboarding_notification_result', {
      'result': state.name,
    });
    if (mounted) {
      setState(() {
        _notif = state;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _ScrollablePage(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PageHeading(
          title: 'Бэлэн боллоо!',
          body:
              'Одоо сервисээ сонгож эхлээрэй. Захиалга хийхэд бүртгэл '
              'шаардлагатай.',
        ),
        const SizedBox(height: 28),
        _PlayWhenActive(
          active: widget.active,
          duration: const Duration(milliseconds: 900),
          builder: (context, t) => _PermissionRow(
            icon: Icons.notifications_active_rounded,
            // One small ring of the bell as the page comes into view.
            iconAngle: math.sin(t * math.pi * 6) * (1 - t) * 0.3,
            title: 'Мэдэгдэл авах',
            subtitle: 'Захиалга баталгаажих, цаг ойртоход танд мэдэгдэнэ',
            state: _notif,
            keyPrefix: 'notif',
            onTap: _askNotifications,
          ),
        ),
      ],
    ),
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.keyPrefix,
    required this.onTap,
    this.iconAngle = 0,
  });

  final IconData icon;
  final double iconAngle;
  final String title;
  final String subtitle;
  final PermissionState state;
  final String keyPrefix;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final granted = state == PermissionState.granted;
    // Permanently denied → the only way back is the system Settings.
    final settings = state == PermissionState.permanentlyDenied;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Navy.raised,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: _Navy.line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Transform.rotate(
              angle: iconAngle,
              alignment: Alignment.topCenter,
              child: Icon(icon, size: 22, color: AppColors.accentHover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _Navy.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  settings ? 'Тохиргооноос зөвшөөрнө үү' : subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: _Navy.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Scales down rather than overflowing on narrow screens with large
          // text; the granted check pops in.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: granted
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('granted'),
                        color: AppColors.green,
                      )
                    : OutlinedButton(
                        key: ValueKey(
                          settings
                              ? '$keyPrefix-open-settings'
                              : '$keyPrefix-grant',
                        ),
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _Navy.ink,
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: _Navy.dim),
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Text(settings ? 'Тохиргоо' : 'Зөвшөөрөх'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Хуудас ${index + 1} / $count',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : _Navy.dim,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        );
      }),
    ),
  );
}
