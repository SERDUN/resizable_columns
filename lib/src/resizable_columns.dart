import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'pane_sizes.dart';
import 'resizable_columns_controller.dart';
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
///  * [controller], to collapse a pane and expand it again.
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
    this.controller,
    this.collapsedSizes,
  })  : assert(collapsedSizes == null || collapsedSizes.length == children.length,
            'collapsedSizes length must match the number of children'),
        assert(initialProportions == null || initialProportions.length == children.length,
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
  ///
  /// A collapsed pane is not reported with its collapsed size but with the
  /// weight that expands it back to its former size. To restore a layout with
  /// collapsed panes, pass the list as [initialSizes] and the same collapsed
  /// indexes to the [controller]: both the layout and the sizes the collapsed
  /// panes expand to come back.
  final ValueChanged<List<double>>? onSizesChanged;

  /// Collapses and expands the panes.
  ///
  /// When the set of collapsed panes changes, the builders in [children] run
  /// again, so a pane can read [ResizableColumnsController.isCollapsed] and
  /// show something smaller, such as a rail of icons, while it is collapsed.
  ///
  /// A divider next to a collapsed pane cannot be dragged. Dragging the other
  /// dividers moves only the expanded panes.
  final ResizableColumnsController? controller;

  /// The size along [orientation] of each pane while it is collapsed, in the
  /// order of [children]. Without it a collapsed pane takes no space at all.
  ///
  /// A collapsed pane ignores [minChildSize].
  final List<double>? collapsedSizes;

  @override
  State<ResizableColumns> createState() => _ResizableColumnsState();
}

class _ResizableColumnsState extends State<ResizableColumns> {
  // Relative sizes of the panes. Pixels are derived from them on every layout,
  // so the proportions survive a resize of the parent. A notifier rather than
  // setState, so a drag lays the panes out again without rebuilding them.
  //
  // A collapsed pane keeps its weight, which is what it gets back when it is
  // expanded. All weights are in one unit: the initial ones until the first
  // drag or collapse, pixels after it.
  late final ValueNotifier<List<double>> _weights;

  // The panes collapsed now, and the space of the last layout, which a drag
  // needs to turn the weights of collapsed panes into pixels.
  Set<int> _collapsed = const {};
  double _lastAvailable = double.infinity;

  List<double>? _dragStartSizes;
  double _dragOffset = 0.0;

  bool get _isHorizontal => widget.orientation == ResizableOrientation.horizontal;

  Set<int> _collapsedOf(ResizableColumnsController? controller) {
    if (controller == null) return const {};
    return {
      for (final index in controller.collapsed)
        if (index < widget.children.length) index
    };
  }

  @override
  void initState() {
    super.initState();
    _weights = ValueNotifier<List<double>>(_initialWeights());
    _collapsed = _collapsedOf(widget.controller);
    widget.controller?.addListener(_onCollapsedChanged);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onCollapsedChanged);
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
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onCollapsedChanged);
      widget.controller?.addListener(_onCollapsedChanged);
      _applyCollapsed();
    } else if (widget.children.length != oldWidget.children.length) {
      _collapsed = _collapsedOf(widget.controller);
    }
  }

  void _onCollapsedChanged() => setState(_applyCollapsed);

  // The weights do not change when a pane collapses or expands: the expanded
  // panes share what the collapsed ones leave in the same proportions, and a
  // pane that expands gets its share back.
  void _applyCollapsed() {
    final collapsed = _collapsedOf(widget.controller);
    if (setEquals(collapsed, _collapsed)) return;
    _collapsed = collapsed;
    _endDrag();
  }

  /// The weights in pixels of [sizes], the layout a drag starts from.
  ///
  /// An expanded pane gets its laid-out size. A collapsed pane gets the weight
  /// that, next to those, expands it to the size it would have now if it were
  /// expanded - so the two kinds of weight stay in one unit.
  List<double> _pixelWeights(List<double> sizes) {
    final weights = _weights.value;
    if (_collapsed.isEmpty || sizes.length != weights.length) return List<double>.of(sizes);

    final available = _lastAvailable;
    final expandedTotal = [
      for (int i = 0; i < sizes.length; i++)
        if (!_collapsed.contains(i)) sizes[i]
    ].fold(0.0, (sum, size) => sum + size);
    final hypothetical = fitPaneSizes(weights, available: available, minSize: widget.minChildSize);
    final hypotheticalTotal = _collapsed.fold(0.0, (sum, i) => sum + hypothetical[i]);
    // Scaled so that, once the layout fits every weight into the space again,
    // each collapsed pane comes out at its hypothetical size.
    final scale = available.isFinite && hypotheticalTotal < available && expandedTotal > 0
        ? expandedTotal / (available - hypotheticalTotal)
        : 1.0;

    return [
      for (int i = 0; i < sizes.length; i++) _collapsed.contains(i) ? hypothetical[i] * scale : sizes[i],
    ];
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
            final sizes = layoutPaneSizes(
              weights,
              available: availableSize,
              minSize: widget.minChildSize,
              collapsed: _collapsed,
              collapsedSizes: widget.collapsedSizes,
            );
            _lastAvailable = availableSize;

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
                for (int i = 0; i < panes.length - 1; i++)
                  if (!_collapsed.contains(i) && !_collapsed.contains(i + 1)) _buildDragArea(context, i, sizes),
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
    //
    // Only the expanded panes take part: the divider moves within them, and a
    // collapsed pane keeps the weight it is expanded back to.
    if (_dragStartSizes == null) {
      _dragStartSizes = sizes;
      _weights.value = _pixelWeights(sizes);
    }
    final startSizes = _dragStartSizes!;
    _dragOffset += delta;

    final expanded = [
      for (int i = 0; i < startSizes.length; i++)
        if (!_collapsed.contains(i)) i
    ];
    final moved = movePaneDivider(
      [for (final i in expanded) startSizes[i]],
      index: expanded.indexOf(dividerIndex),
      delta: _dragOffset,
      minSize: widget.minChildSize,
      push: widget.dragMode == ResizableDragMode.push,
    );
    final movedWeights = List<double>.of(_weights.value);
    for (int k = 0; k < expanded.length; k++) {
      movedWeights[expanded[k]] = moved[k];
    }
    if (listEquals(movedWeights, _weights.value)) return;

    _weights.value = movedWeights;
    widget.onSizesChanged?.call(List<double>.unmodifiable(movedWeights));
  }

  void _endDrag() {
    _dragStartSizes = null;
    _dragOffset = 0.0;
  }
}
