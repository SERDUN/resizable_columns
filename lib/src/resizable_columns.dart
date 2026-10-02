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

  @override
  State<ResizableColumns> createState() => _ResizableColumnsState();
}

class _ResizableColumnsState extends State<ResizableColumns> {
  // Relative sizes of the panes. Pixels are derived from them on every layout,
  // so the proportions survive a resize of the parent.
  late List<double> _weights;

  List<double>? _dragStartSizes;
  double _dragOffset = 0.0;

  bool get _isHorizontal => widget.orientation == ResizableOrientation.horizontal;

  @override
  void initState() {
    super.initState();
    _weights = _initialWeights();
  }

  @override
  void didUpdateWidget(ResizableColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != _weights.length) {
      _weights = _initialWeights();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = _availableSize(constraints);
        assert(availableSize.isFinite || widget.initialSizes != null,
            'ResizableColumns needs a bounded size along its orientation, or initialSizes to size the panes');

        final sizes = fitPaneSizes(_weights, available: availableSize, minSize: widget.minChildSize);

        return Flex(
          direction: _isHorizontal ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: _crossAxisAlignment,
          children: [
            for (int i = 0; i < widget.children.length; i++) ...[
              if (i > 0) _buildDivider(context, i - 1, sizes),
              SizedBox(
                width: _isHorizontal ? sizes[i] : null,
                height: _isHorizontal ? null : sizes[i],
                child: Align(
                  alignment: widget.alignment,
                  child: widget.children[i](context),
                ),
              ),
            ],
          ],
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
    final startSizes = _dragStartSizes ??= sizes;
    _dragOffset += delta;

    setState(() {
      _weights = movePaneDivider(
        startSizes,
        index: dividerIndex,
        delta: _dragOffset,
        minSize: widget.minChildSize,
      );
    });
  }

  void _endDrag() {
    _dragStartSizes = null;
    _dragOffset = 0.0;
  }
}
