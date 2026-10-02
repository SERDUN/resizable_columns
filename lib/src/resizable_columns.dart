import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'pane_sizes.dart';
import 'resizable_drag_mode.dart';
import 'resizable_orientation.dart';

/// Lays its [children] out in a row or a column, with a draggable divider
/// between every two of them.
///
/// The panes share the space along [orientation] and fill the other axis.
/// Their sizes are kept as proportions, so they scale with the parent, and a
/// pane does not shrink below [minChildSize] while the space allows it.
///
/// ```dart
/// ResizableColumns(
///   orientation: ResizableOrientation.horizontal,
///   dividerThickness: 8.0,
///   initialProportions: const [1, 2],
///   children: [
///     (context) => const Text('Navigation'),
///     (context) => const Text('Content'),
///   ],
/// )
/// ```
///
/// The parent has to bound the size along [orientation]. Inside a scroll view
/// along that axis, pass [initialSizes]: they are then used as they are.
///
/// See also:
///
///  * [dragMode], to let a divider push the panes further along.
///  * [dividerHitSize], to change how wide the draggable area of a divider is.
///  * [onSizesChanged], to save the layout and restore it with [initialSizes].
class ResizableColumns extends StatefulWidget {
  /// Creates a layout of resizable panes.
  ///
  /// At most one of [initialSizes] and [initialProportions] can be given, and
  /// its length has to match the number of [children].
  const ResizableColumns({
    super.key,
    required this.children,
    required this.orientation,
    this.dividerThickness = 2.0,
    this.dividerColor = const Color(0x00000000),
    this.dividerHitSize = 12.0,
    this.initialProportions,
    this.initialSizes,
    this.draggable = true,
    this.dragMode = ResizableDragMode.adjacent,
    this.alignment = Alignment.topLeft,
    this.minChildSize = 50.0,
    this.onSizesChanged,
  })  : assert(initialProportions == null || initialProportions.length == children.length,
            'initialProportions length must match the number of children'),
        assert(initialSizes == null || initialSizes.length == children.length,
            'initialSizes length must match the number of children'),
        assert(initialSizes == null || initialProportions == null,
            'Provide either initialSizes or initialProportions, not both');

  /// Whether the panes sit side by side or on top of each other.
  final ResizableOrientation orientation;

  /// The builders of the panes, in layout order.
  ///
  /// They are called when this widget is rebuilt or when something a pane
  /// depends on changes, and not while a divider is dragged. Changing their
  /// number resets the sizes to the initial ones.
  final List<WidgetBuilder> children;

  /// The size of every divider along [orientation].
  final double dividerThickness;

  /// The color of the dividers. Transparent by default.
  final Color dividerColor;

  /// The size along [orientation] of the area a divider can be dragged by.
  ///
  /// The area is centered on the divider and lies over the edges of the two
  /// panes next to it, so it does not take any space in the layout. A drag
  /// that starts there moves the divider; a tap still reaches the pane. It is
  /// never smaller than [dividerThickness].
  final double dividerHitSize;

  /// The share of the space each pane starts with.
  ///
  /// Only the ratio between the values matters: `[1, 2, 1]` gives the middle
  /// pane half of the space. Read once, when the widget is first built or
  /// when the number of [children] changes.
  final List<double>? initialProportions;

  /// The size in pixels each pane starts with.
  ///
  /// Sizes that do not add up to the available space are scaled to fill it.
  /// Read once, when the widget is first built or when the number of
  /// [children] changes.
  final List<double>? initialSizes;

  /// Whether the dividers can be dragged.
  final bool draggable;

  /// What a dragged divider does once the pane next to it is at
  /// [minChildSize]: stop, or go on and shrink the panes further along.
  final ResizableDragMode dragMode;

  /// How each child is aligned within its pane.
  final Alignment alignment;

  /// The size below which a pane is not shrunk.
  ///
  /// When the space cannot hold every pane at this size, the panes share it
  /// equally instead.
  final double minChildSize;

  /// Called while a divider is dragged, with the size of every pane in pixels,
  /// in the order of [children].
  ///
  /// It is not called for the initial layout or when the parent is resized.
  /// Pass the sizes back as [initialSizes] to restore the layout later.
  final ValueChanged<List<double>>? onSizesChanged;

  @override
  State<ResizableColumns> createState() => _ResizableColumnsState();
}

class _ResizableColumnsState extends State<ResizableColumns> {
  // Relative sizes of the panes. Pixels are derived from them on every layout,
  // so the proportions survive a resize of the parent. A notifier rather than
  // setState, so a drag lays the panes out again without rebuilding them.
  late final ValueNotifier<List<double>> _weights;

  List<double>? _dragStartSizes;
  double _dragOffset = 0.0;

  bool get _isHorizontal => widget.orientation == ResizableOrientation.horizontal;

  @override
  void initState() {
    super.initState();
    _weights = ValueNotifier<List<double>>(_initialWeights());
  }

  @override
  void dispose() {
    _weights.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ResizableColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != _weights.value.length) {
      _weights.value = _initialWeights();
      _endDrag();
    }
  }

  List<double> _initialWeights() {
    final count = widget.children.length;
    final initial = widget.initialSizes ?? widget.initialProportions;
    if (initial != null && initial.length == count) return List<double>.of(initial);
    // Distribute sizes equally if initial sizes or proportions are not provided
    return List<double>.filled(count, 1.0);
  }

  double _availableSize(BoxConstraints constraints) {
    final totalDividerThickness = widget.dividerThickness * (widget.children.length - 1);
    final totalSize = _isHorizontal ? constraints.maxWidth : constraints.maxHeight;
    return totalSize - totalDividerThickness;
  }

  CrossAxisAlignment get _crossAxisAlignment {
    final cross = _isHorizontal ? widget.alignment.y : widget.alignment.x;
    if (cross < 0) return CrossAxisAlignment.start;
    if (cross > 0) return CrossAxisAlignment.end;
    return CrossAxisAlignment.center;
  }

  @override
  Widget build(BuildContext context) {
    // Built here and not below, so that only this widget's own rebuild calls
    // the builders. A drag or a resize of the parent reuses the same panes.
    final panes = [
      for (final builder in widget.children) Align(alignment: widget.alignment, child: builder(context)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = _availableSize(constraints);
        assert(availableSize.isFinite || widget.initialSizes != null,
            'ResizableColumns needs a bounded size along its orientation, or initialSizes to size the panes');

        return ValueListenableBuilder<List<double>>(
          valueListenable: _weights,
          builder: (context, weights, _) {
            final sizes = fitPaneSizes(weights, available: availableSize, minSize: widget.minChildSize);

            final flex = Flex(
              direction: _isHorizontal ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: _crossAxisAlignment,
              children: [
                for (int i = 0; i < panes.length; i++) ...[
                  if (i > 0)
                    Container(
                      color: widget.dividerColor,
                      width: _isHorizontal ? widget.dividerThickness : null,
                      height: _isHorizontal ? null : widget.dividerThickness,
                    ),
                  SizedBox(
                    width: _isHorizontal ? sizes[i] : null,
                    height: _isHorizontal ? null : sizes[i],
                    child: panes[i],
                  ),
                ],
              ],
            );
            if (!widget.draggable) return flex;

            // The drag areas lie over the panes instead of between them, so
            // they can be wider than the dividers without moving anything.
            return Stack(
              fit: StackFit.passthrough,
              children: [
                flex,
                for (int i = 0; i < panes.length - 1; i++) _buildDragArea(context, i, sizes),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDragArea(BuildContext context, int dividerIndex, List<double> sizes) {
    final isRtl = _isHorizontal && Directionality.maybeOf(context) == TextDirection.rtl;
    final thickness = widget.dividerThickness;
    final extent = math.max(widget.dividerHitSize, thickness);

    double dividerStart = thickness * dividerIndex;
    for (int i = 0; i <= dividerIndex; i++) {
      dividerStart += sizes[i];
    }
    final start = dividerStart + (thickness - extent) / 2;

    void onUpdate(DragUpdateDetails details) {
      final delta = _isHorizontal ? details.delta.dx : details.delta.dy;
      _onDragUpdate(isRtl ? -delta : delta, dividerIndex, sizes);
    }

    // Translucent, so a tap on the edge of a pane still reaches the pane. The
    // drag counts from the pointer down, or the divider would lag behind by
    // the distance it took to win over the pane's own gestures.
    final area = GestureDetector(
      behavior: HitTestBehavior.translucent,
      dragStartBehavior: DragStartBehavior.down,
      onVerticalDragUpdate: _isHorizontal ? null : onUpdate,
      onVerticalDragEnd: _isHorizontal ? null : (_) => _endDrag(),
      onVerticalDragCancel: _isHorizontal ? null : _endDrag,
      onHorizontalDragUpdate: _isHorizontal ? onUpdate : null,
      onHorizontalDragEnd: _isHorizontal ? (_) => _endDrag() : null,
      onHorizontalDragCancel: _isHorizontal ? _endDrag : null,
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: _isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow,
      ),
    );

    return _isHorizontal
        ? PositionedDirectional(start: start, top: 0, bottom: 0, width: extent, child: area)
        : Positioned(top: start, left: 0, right: 0, height: extent, child: area);
  }

  void _onDragUpdate(double delta, int dividerIndex, List<double> sizes) {
    // The move is measured from where the drag began, so a pointer that went
    // past a pane's minimum has to come back before the divider follows it.
    final previousSizes = _dragStartSizes == null ? sizes : _weights.value;
    final startSizes = _dragStartSizes ??= sizes;
    _dragOffset += delta;

    final movedSizes = movePaneDivider(
      startSizes,
      index: dividerIndex,
      delta: _dragOffset,
      minSize: widget.minChildSize,
      push: widget.dragMode == ResizableDragMode.push,
    );
    if (listEquals(movedSizes, previousSizes)) return;

    _weights.value = movedSizes;
    widget.onSizesChanged?.call(List<double>.unmodifiable(movedSizes));
  }

  void _endDrag() {
    _dragStartSizes = null;
    _dragOffset = 0.0;
  }
}
