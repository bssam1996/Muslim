import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A horizontal pager whose height follows its pages' natural content height.
/// The containing page owns vertical scrolling, including at large text sizes.
class ContentHeightPageView extends StatefulWidget {
  const ContentHeightPageView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.onPageChanged,
  });

  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onPageChanged;

  @override
  State<ContentHeightPageView> createState() => _ContentHeightPageViewState();
}

class _ContentHeightPageViewState extends State<ContentHeightPageView> {
  final _heights = <int, double>{};
  double? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-measure after a locale, theme, viewport, or text-scale change.
    _heights.clear();
  }

  void _recordHeight(int index, double height) {
    if (!mounted || _heights[index] == height) return;
    setState(() => _heights[index] = height);
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe even when the page builder is outside this widget's subtree.
    MediaQuery.of(context);
    Theme.of(context);
    Localizations.localeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width != constraints.maxWidth) {
          _width = constraints.maxWidth;
          _heights.clear();
        }
        return SizedBox(
          height: _heights.values.fold<double>(72.0, math.max),
          child: PageView.builder(
            controller: widget.controller,
            itemCount: widget.itemCount,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) => _NaturalHeight(
              onHeight: (height) => _recordHeight(index, height),
              child: widget.itemBuilder(context, index),
            ),
          ),
        );
      },
    );
  }
}

class _NaturalHeight extends SingleChildRenderObjectWidget {
  const _NaturalHeight({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;

  @override
  _RenderNaturalHeight createRenderObject(BuildContext context) =>
      _RenderNaturalHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNaturalHeight renderObject,
  ) {
    renderObject.onHeight = onHeight;
    renderObject.markNeedsLayout();
  }
}

class _RenderNaturalHeight extends RenderProxyBox {
  _RenderNaturalHeight(this.onHeight);
  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    child!.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    size = constraints.constrain(child!.size);
    final height = child!.size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
