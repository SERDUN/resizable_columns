import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'pane_sizes.dart';
import 'resizable_orientation.dart';

class ResizableColumns extends StatefulWidget {
  const ResizableColumns({
    super.key,
    required this.children,
    required this.orientation,
    this.dividerThickness = 2.0,
    this.dividerColor = const Color(0x00000000),
    this.initialProportions,
    this.initialSizes,
    this.draggable = true,
    this.alignment = Alignment.topLeft,
    this.minChildSize = 50.0,
    this.onSizesChanged,
  }) : assert(initialProportions == null || initialProportions.length == children.length,
            'initialProportions length must match the number of children');

  final ResizableOrientation orientation;
  final List<WidgetBuilder> children;
  final double dividerThickness;
  final Color dividerColor;
  final List<double>? initialProportions;
  final List<double>? initialSizes;
  final bool draggable;
  final Alignment alignment;
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
    for (final initial in [widget.initialSizes, widget.initialProportions]) {
      if (initial != null && initial.length == count) return List<double>.of(initial);
    }
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

            return Flex(
              direction: _isHorizontal ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: _crossAxisAlignment,
              children: [
                for (int i = 0; i < panes.length; i++) ...[
                  if (i > 0) _buildDivider(context, i - 1, sizes),
                  SizedBox(
                    width: _isHorizontal ? sizes[i] : null,
                    height: _isHorizontal ? null : sizes[i],
                    child: panes[i],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDivider(BuildContext context, int dividerIndex, List<double> sizes) {
    final draggable = widget.draggable;
    final isRtl = _isHorizontal && Directionality.maybeOf(context) == TextDirection.rtl;

    void onUpdate(DragUpdateDetails details) {
      final delta = _isHorizontal ? details.delta.dx : details.delta.dy;
      _onDragUpdate(isRtl ? -delta : delta, dividerIndex, sizes);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: draggable && !_isHorizontal ? onUpdate : null,
      onVerticalDragEnd: draggable && !_isHorizontal ? (_) => _endDrag() : null,
      onVerticalDragCancel: draggable && !_isHorizontal ? _endDrag : null,
      onHorizontalDragUpdate: draggable && _isHorizontal ? onUpdate : null,
      onHorizontalDragEnd: draggable && _isHorizontal ? (_) => _endDrag() : null,
      onHorizontalDragCancel: draggable && _isHorizontal ? _endDrag : null,
      child: MouseRegion(
        cursor: draggable
            ? (_isHorizontal ? SystemMouseCursors.resizeColumn : SystemMouseCursors.resizeRow)
            : MouseCursor.defer,
        child: Container(
          color: widget.dividerColor,
          width: _isHorizontal ? widget.dividerThickness : null,
          height: _isHorizontal ? null : widget.dividerThickness,
        ),
      ),
    );
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
