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
  /// A collapsed pane is reported with the size it returns to when it is
  /// expanded, not with its collapsed size. To restore a layout with collapsed
  /// panes, pass the list as [initialSizes] and the same collapsed indexes to
  /// the [controller]: the expanded panes come back as they were, and each
  /// collapsed one expands to the size reported for it.
  final ValueChanged<List<double>>? onSizesChanged;

  /// Collapses and expands the panes.
  ///
  /// When the set of collapsed panes changes, the builders in [children] run
  /// again, so a pane can read [ResizableColumnsController.isCollapsed] and
  /// show something smaller, such as a rail of icons, while it is collapsed.
  ///
  /// An expanded pane returns to the size it had when it was collapsed, and
  /// the other expanded panes shrink in proportion to make room. When the room
  /// is not there, it gets what is left once each of the others is at
  /// [minChildSize]; when even that is less than [minChildSize], the expanded
  /// panes share the space as [minChildSize] says.
  ///
  /// Between two expanded panes there is always one divider that can be
  /// dragged, even with collapsed panes between them: the one right after the
  /// first of the two. It resizes those two panes across the collapsed ones,
  /// and the other dividers next to a collapsed pane take no drag. Drags,
  /// [ResizableDragMode.push] included, move only expanded panes.
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
  // One entry per pane, in two roles that are never compared with each
  // other. An expanded pane's weight is its share: the expanded panes split
  // their space in proportion to these, so they follow a resize of the parent;
  // the initial values until a divider moves, pixels after it. A collapsed
  // pane's weight is the size in pixels it returns to when it is expanded. A
  // notifier rather than setState, so a drag lays the panes out again without
  // rebuilding them.
  late final ValueNotifier<List<double>> _weights;
  bool _laidOut = false;

  // The collapsed panes, the ones expanded since the last layout, and that
  // layout, which a collapse reads the size to remember from.
  Set<int> _collapsed = const {};
  final Set<int> _expanding = {};
  List<double>? _lastSizes;

  // Bumped when the collapsed panes change, so that a drag update arriving
  // from a layout that no longer exists is dropped.
  int _layoutGeneration = 0;

  List<double>? _dragStartSizes;
  List<double>? _dragLastMoved;
  double _dragOffset = 0.0;

  bool get _isHorizontal => widget.orientation == ResizableOrientation.horizontal;

  Set<int> _collapsedOf(ResizableColumnsController? controller) {
    if (controller == null) return const {};
    return {
      for (final index in controller.collapsed)
        if (index >= 0 && index < widget.children.length) index
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
      _laidOut = false;
      _expanding.clear();
      _lastSizes = null;
      _collapsed = _collapsedOf(widget.controller);
      _layoutGeneration++;
      _endDrag();
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onCollapsedChanged);
      widget.controller?.addListener(_onCollapsedChanged);
      _applyCollapsed(_collapsedOf(widget.controller));
    }
  }

  void _onCollapsedChanged() {
    final collapsed = _collapsedOf(widget.controller);
    if (setEquals(collapsed, _collapsed)) return;
    setState(() => _applyCollapsed(collapsed));
  }

  void _applyCollapsed(Set<int> collapsed) {
    if (setEquals(collapsed, _collapsed)) return;
    final sizes = _lastSizes;
    for (final index in collapsed.difference(_collapsed)) {
      _expanding.remove(index);
      // Remember the size it has now. Before the first layout its weight is
      // still an initial value, which the first layout turns into pixels.
      if (sizes != null && index < sizes.length) _weights.value[index] = sizes[index];
    }
    _expanding.addAll(_collapsed.difference(collapsed));
    _collapsed = collapsed;
    _layoutGeneration++;
    _endDrag();
  }

  /// Keeps the weights of collapsed panes in pixels for [available], the one
  /// place weights change outside a drag. Writes in place: it runs during
  /// layout, where the panes are about to be laid out from these weights.
  void _normalizeWeights(double available) {
    final weights = _weights.value;
    final minSize = widget.minChildSize;

    if (!_laidOut) {
      _laidOut = true;
      // A pane collapsed from the start remembers the size it would have
      // expanded, or its initialSizes entry as it is: that is a size the owner
      // chose, not a share. The expanded panes keep their initial weights. A
      // pane expanded before any layout is simply expanded.
      _expanding.clear();
      if (available.isFinite && widget.initialSizes == null && _collapsed.isNotEmpty) {
        final whole = fitPaneSizes(weights, available: available, minSize: minSize);
        for (final i in _collapsed) {
          weights[i] = whole[i];
        }
      }
      return;
    }

    _expanding.removeWhere((index) => index >= weights.length || _collapsed.contains(index));
    if (_expanding.isEmpty || !available.isFinite) {
      _expanding.clear();
      return;
    }

    // Each pane that expands asks for its remembered size. The others shrink
    // in proportion, each down to the minimum at most.
    final expanded = expandedIndexes(weights.length, _collapsed);
    final space = available -
        _collapsed.fold(0.0, (sum, i) => sum + collapsedPaneSize(widget.collapsedSizes, i)) *
            collapsedScale(widget.collapsedSizes, _collapsed, available);
    final staying = [
      for (final i in expanded)
        if (!_expanding.contains(i)) i
    ];
    final asked = _expanding.fold(0.0, (sum, i) => sum + _sanitizeSize(weights[i]));
    final room = math.max(0.0, space - minSize * staying.length);
    final scale = asked > room && asked > 0 ? room / asked : 1.0;
    for (final i in _expanding) {
      weights[i] = _sanitizeSize(weights[i]) * scale;
    }
    final given = _expanding.fold(0.0, (sum, i) => sum + weights[i]);
    final rest =
        fitPaneSizes([for (final i in staying) weights[i]], available: math.max(0.0, space - given), minSize: minSize);
    for (int k = 0; k < staying.length; k++) {
      weights[staying[k]] = rest[k];
    }
    _expanding.clear();
  }

  static double _sanitizeSize(double size) => size.isFinite && size > 0 ? size : 0.0;

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

  /// The dividers that take a drag: one after every expanded pane that has
  /// another expanded pane somewhere after it.
  List<int> _draggableDividers() {
    final expanded = expandedIndexes(widget.children.length, _collapsed);
    return [for (int k = 0; k < expanded.length - 1; k++) expanded[k]];
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
            _normalizeWeights(availableSize);
            final sizes = layoutPaneSizes(
              weights,
              available: availableSize,
              minSize: widget.minChildSize,
              collapsed: _collapsed,
              collapsedSizes: widget.collapsedSizes,
            );
            _lastSizes = sizes;

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
            // Keyed by divider, so a drag in progress stays with its divider
            // when the set of draggable dividers changes.
            return Stack(
              fit: StackFit.passthrough,
              children: [
                flex,
                for (final divider in _draggableDividers()) _buildDragArea(context, divider, sizes),
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
    final generation = _layoutGeneration;

    double dividerStart = thickness * dividerIndex;
    for (int i = 0; i <= dividerIndex; i++) {
      dividerStart += sizes[i];
    }
    final start = dividerStart + (thickness - extent) / 2;

    void onUpdate(DragUpdateDetails details) {
      final delta = _isHorizontal ? details.delta.dx : details.delta.dy;
      _onDragUpdate(isRtl ? -delta : delta, dividerIndex, sizes, generation);
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

    final key = ValueKey<int>(dividerIndex);
    return _isHorizontal
        ? PositionedDirectional(key: key, start: start, top: 0, bottom: 0, width: extent, child: area)
        : Positioned(key: key, top: start, left: 0, right: 0, height: extent, child: area);
  }

  void _onDragUpdate(double delta, int dividerIndex, List<double> sizes, int generation) {
    // An update from before the collapsed panes changed carries a layout that
    // is gone; the next one comes from the new layout.
    if (generation != _layoutGeneration || sizes.length != _weights.value.length) return;

    final expanded = expandedIndexes(sizes.length, _collapsed);
    final position = expanded.indexOf(dividerIndex);
    if (position < 0 || position + 1 >= expanded.length) {
      _endDrag();
      return;
    }

    // The move is measured from where the drag began, so a pointer that went
    // past a pane's minimum has to come back before the divider follows it.
    // Only the expanded panes take part: the divider moves the two expanded
    // panes on either side of it, across any collapsed ones between them.
    final startSizes = _dragStartSizes ??= [for (final i in expanded) sizes[i]];
    final previous = _dragLastMoved ?? startSizes;
    _dragOffset += delta;

    final moved = movePaneDivider(
      startSizes,
      index: position,
      delta: _dragOffset,
      minSize: widget.minChildSize,
      push: widget.dragMode == ResizableDragMode.push,
    );
    if (listEquals(moved, previous)) return;
    _dragLastMoved = moved;

    final weights = List<double>.of(_weights.value);
    for (int k = 0; k < expanded.length; k++) {
      weights[expanded[k]] = moved[k];
    }
    _weights.value = weights;
    widget.onSizesChanged?.call(List<double>.unmodifiable(weights));
  }

  void _endDrag() {
    _dragStartSizes = null;
    _dragLastMoved = null;
    _dragOffset = 0.0;
  }
}
