import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports its child's laid-out size whenever it changes, after the frame —
/// for overlays whose height something else has to make room for (e.g. map
/// padding under a floating header or a bottom sheet).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({required this.onChange, super.child, super.key});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasureSize).onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final current = size;
    if (current == _reported) return;
    _reported = current;
    // Never call back mid-layout: the listener typically calls setState.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(current));
  }
}
