import 'package:flutter/material.dart';

/// The Carservice mark (`assets/brand/mark.png` — the wrench in the chamfered
/// frame). It **pops in** on load (scale-up with a slight overshoot + fade),
/// then **breathes** with a gentle scale pulse while the splash is up.
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({this.size = 140, super.key});

  final double size;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  // Pop-in: scale 0.35 → 1.08 (overshoot) → 1.0, with the fade over the first
  // half.
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.35, end: 1.08).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 65,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.08, end: 1.0).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 35,
    ),
  ]).animate(_pop);
  late final Animation<double> _popOpacity = CurvedAnimation(
    parent: _pop,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );
  late final Animation<double> _pulseScale = Tween(begin: 1.0, end: 1.04)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_pulse);

  @override
  void initState() {
    super.initState();
    _pop.forward();
    // The pulse starts only once the pop settles, so the entrance reads as one
    // beat.
    _pop.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _pulse.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Decode at the on-screen size rather than the 1024px source.
    final cacheSize =
        (widget.size * MediaQuery.devicePixelRatioOf(context)).round();
    final mark = Image.asset(
      'assets/brand/mark.png',
      width: widget.size,
      height: widget.size,
      cacheWidth: cacheSize,
      filterQuality: FilterQuality.medium,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_pop, _pulse]),
      builder: (context, child) => Opacity(
        opacity: _popOpacity.value,
        child: Transform.scale(
          scale: _popScale.value * _pulseScale.value,
          child: child,
        ),
      ),
      child: mark,
    );
  }
}
