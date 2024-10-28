import 'package:flutter/material.dart';

import 'resizable_orientation.dart';

class ResizableColumns extends StatelessWidget {
  const ResizableColumns({
    super.key,
    required this.children,
    required this.orientation,
    this.dividerThickness = 2.0,
    this.dividerColor = Colors.transparent,
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
  Widget build(BuildContext context) {
    assert(children.length >= 2, 'At least two children are required for resizing');

    return LayoutBuilder(
      builder: (context, constraints) {
        return _ResizableLayout(
          children: children,
          constraints: constraints,
          orientation: orientation,
          dividerThickness: dividerThickness,
          dividerColor: dividerColor,
          initialProportions: initialProportions,
          initialSizes: initialSizes,
          draggable: draggable,
          alignment: alignment,
          minChildSize: minChildSize,
        );
      },
    );
  }
}

class _ResizableLayout extends StatefulWidget {
  const _ResizableLayout({
    required this.children,
    required this.constraints,
    required this.orientation,
    required this.dividerThickness,
    required this.dividerColor,
    this.initialProportions,
    this.initialSizes,
    required this.draggable,
    required this.alignment,
    required this.minChildSize,
  }) : assert(initialProportions == null || initialProportions.length == children.length,
            'initialProportions length must match the number of children');

  final List<WidgetBuilder> children;
  final BoxConstraints constraints;
  final ResizableOrientation orientation;
  final double dividerThickness;
  final Color dividerColor;
  final List<double>? initialProportions;
  final List<double>? initialSizes;
  final bool draggable;
  final Alignment alignment;
  final double minChildSize;

  @override
  _ResizableLayoutState createState() => _ResizableLayoutState();
}

class _ResizableLayoutState extends State<_ResizableLayout> {
  late List<double> _sizes;

  @override
  void initState() {
    super.initState();
    _initializeSizes();
  }

  void _initializeSizes() {
    final availableSize = _getAvailableSize();

    if (widget.initialSizes != null && widget.initialSizes!.length == widget.children.length) {
      _sizes = List<double>.from(widget.initialSizes!);
    } else if (widget.initialProportions != null && widget.initialProportions!.length == widget.children.length) {
      final totalProportion = widget.initialProportions!.reduce((a, b) => a + b);
      _sizes = widget.initialProportions!.map((proportion) => (proportion / totalProportion) * availableSize).toList();
    } else {
      // Distribute sizes equally if initial sizes or proportions are not provided
      final sizePerChild = availableSize / widget.children.length;
      _sizes = List<double>.filled(widget.children.length, sizePerChild);
    }

    _applyConstraints();
  }

  double _getAvailableSize() {
    final totalDividerThickness = widget.dividerThickness * (widget.children.length - 1);
    final totalSize = widget.orientation == ResizableOrientation.vertical
        ? widget.constraints.maxHeight
        : widget.constraints.maxWidth;
    return totalSize - totalDividerThickness;
  }

  void _applyConstraints() {
    final minSize = widget.minChildSize;
    final maxSize = double.infinity;
    final availableSize = _getAvailableSize();

    // Adjust sizes to respect min and max constraints
    for (int i = 0; i < _sizes.length; i++) {
      _sizes[i] = _sizes[i].clamp(minSize, maxSize);
    }

    // Calculate total size and adjust sizes proportionally
    double totalSizes = _sizes.reduce((a, b) => a + b);

    if (totalSizes != availableSize) {
      final scaleFactor = availableSize / totalSizes;
      for (int i = 0; i < _sizes.length; i++) {
        _sizes[i] *= scaleFactor;
        _sizes[i] = _sizes[i].clamp(minSize, maxSize);
      }

      // Recalculate total sizes after scaling
      totalSizes = _sizes.reduce((a, b) => a + b);

      // Distribute any remaining difference
      double difference = availableSize - totalSizes;
      double adjustmentPerChild = difference / _sizes.length;

      for (int i = 0; i < _sizes.length; i++) {
        _sizes[i] += adjustmentPerChild;
      }
    }

    // Final adjustment to ensure total sizes match exactly
    totalSizes = _sizes.reduce((a, b) => a + b);
    if ((availableSize - totalSizes).abs() > 0.1) {
      // Adjust the last child size to absorb any tiny discrepancies
      _sizes[_sizes.length - 1] += availableSize - totalSizes;
    }
  }

  @override
  Widget build(BuildContext context) {
    _applyConstraints();

    List<Widget> childrenWidgets = [];
    for (int i = 0; i < widget.children.length; i++) {
      final size = _sizes[i];

      Widget child = SizedBox(
        height: widget.orientation == ResizableOrientation.vertical ? size : null,
        width: widget.orientation == ResizableOrientation.horizontal ? size : null,
        child: Align(
          alignment: widget.alignment,
          child: widget.children[i](context),
        ),
      );

      childrenWidgets.add(child);

      if (i < widget.children.length - 1) {
        int dividerIndex = i;

        Widget divider = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: widget.orientation == ResizableOrientation.vertical && widget.draggable
              ? (details) => _onDragUpdate(details, dividerIndex)
              : null,
          onHorizontalDragUpdate: widget.orientation == ResizableOrientation.horizontal && widget.draggable
              ? (details) => _onDragUpdate(details, dividerIndex)
              : null,
          child: MouseRegion(
            cursor: widget.draggable
                ? (widget.orientation == ResizableOrientation.horizontal
                    ? SystemMouseCursors.resizeColumn
                    : SystemMouseCursors.resizeRow)
                : MouseCursor.defer,
            child: Container(
              color: widget.dividerColor,
              width: widget.orientation == ResizableOrientation.horizontal ? widget.dividerThickness : null,
              height: widget.orientation == ResizableOrientation.vertical ? widget.dividerThickness : null,
            ),
          ),
        );

        childrenWidgets.add(divider);
      }
    }

    return widget.orientation == ResizableOrientation.vertical
        ? Column(
            crossAxisAlignment: _getCrossAxisAlignment(),
            children: childrenWidgets,
          )
        : Row(
            mainAxisAlignment: _getMainAxisAlignment(),
            children: childrenWidgets,
          );
  }

  CrossAxisAlignment _getCrossAxisAlignment() {
    if (widget.orientation == ResizableOrientation.vertical) {
      switch (widget.alignment.x) {
        case -1.0:
          return CrossAxisAlignment.start;
        case 0.0:
          return CrossAxisAlignment.center;
        case 1.0:
          return CrossAxisAlignment.end;
        default:
          return CrossAxisAlignment.center;
      }
    } else {
      return CrossAxisAlignment.stretch;
    }
  }

  MainAxisAlignment _getMainAxisAlignment() {
    if (widget.orientation == ResizableOrientation.horizontal) {
      switch (widget.alignment.y) {
        case -1.0:
          return MainAxisAlignment.start;
        case 0.0:
          return MainAxisAlignment.center;
        case 1.0:
          return MainAxisAlignment.end;
        default:
          return MainAxisAlignment.start;
      }
    } else {
      return MainAxisAlignment.start;
    }
  }

  void _onDragUpdate(DragUpdateDetails details, int dividerIndex) {
    setState(() {
      final delta = widget.orientation == ResizableOrientation.vertical ? details.delta.dy : details.delta.dx;

      final minSize = widget.minChildSize;
      final maxSize = double.infinity;

      // Adjust sizes of the affected widgets
      double newSizeCurrent = _sizes[dividerIndex] + delta;
      double newSizeNext = _sizes[dividerIndex + 1] - delta;

      // Enforce minimum and maximum sizes
      if (newSizeCurrent < minSize) {
        newSizeNext -= minSize - newSizeCurrent;
        newSizeCurrent = minSize;
      } else if (newSizeCurrent > maxSize) {
        newSizeNext -= newSizeCurrent - maxSize;
        newSizeCurrent = maxSize;
      }

      if (newSizeNext < minSize) {
        newSizeCurrent -= minSize - newSizeNext;
        newSizeNext = minSize;
      } else if (newSizeNext > maxSize) {
        newSizeCurrent -= newSizeNext - maxSize;
        newSizeNext = maxSize;
      }

      // Update sizes in the list
      _sizes[dividerIndex] = newSizeCurrent;
      _sizes[dividerIndex + 1] = newSizeNext;

      // Apply constraints to ensure total size matches available size
      _applyConstraints();
    });
  }
}
