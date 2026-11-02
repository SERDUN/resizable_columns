import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resizable_columns/resizable_columns.dart';
import 'package:resizable_columns/src/pane_sizes.dart';

Widget _host(Widget child, {Size size = const Size(600, 300)}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: size, child: child),
    ),
  );
}

ResizableColumns _columns(
  int count, {
  ResizableColumnsController? controller,
  List<double>? collapsedSizes,
  List<double>? initialProportions,
  List<double>? initialSizes,
  ResizableOrientation orientation = ResizableOrientation.horizontal,
  ResizableDragMode dragMode = ResizableDragMode.adjacent,
  ValueChanged<List<double>>? onSizesChanged,
  List<WidgetBuilder>? children,
}) {
  return ResizableColumns(
    orientation: orientation,
    dividerThickness: 0,
    minChildSize: 50,
    controller: controller,
    collapsedSizes: collapsedSizes,
    initialProportions: initialProportions,
    initialSizes: initialSizes,
    dragMode: dragMode,
    onSizesChanged: onSizesChanged,
    children: children ?? [for (int i = 0; i < count; i++) (context) => SizedBox.expand(key: ValueKey('pane$i'))],
  );
}

Rect _pane(WidgetTester tester, int index) => tester.getRect(find.byKey(ValueKey('pane$index')));

List<double> _widths(WidgetTester tester, int count) => [for (int i = 0; i < count; i++) _pane(tester, i).width];

List<double> _heights(WidgetTester tester, int count) => [for (int i = 0; i < count; i++) _pane(tester, i).height];

Matcher _closeToAll(List<double> expected) => pairwiseCompare<double, double>(
      expected,
      (e, a) => (e - a).abs() < 1e-6,
      'close to',
    );

/// Drags the divider that ends at [x] by [dx].
Future<void> _drag(WidgetTester tester, double x, double dx) async {
  final gesture = await tester.startGesture(Offset(x, 150));
  await gesture.moveBy(Offset(dx, 0));
  await gesture.up();
  await tester.pump();
}

void main() {
  group('layoutPaneSizes', () {
    test('is fitPaneSizes when nothing is collapsed', () {
      final weights = [10.0, 60.0, 400.0];
      expect(
        layoutPaneSizes(weights, available: 300, minSize: 50),
        fitPaneSizes(weights, available: 300, minSize: 50),
      );
    });

    test('gives a collapsed pane its collapsed size and the rest to the others', () {
      expect(
        layoutPaneSizes([1, 2, 1], available: 600, minSize: 50, collapsed: {2}, collapsedSizes: [0, 0, 60]),
        _closeToAll([180, 360, 60]),
      );
    });

    test('collapses to nothing without collapsedSizes', () {
      expect(layoutPaneSizes([1, 1, 1], available: 600, minSize: 50, collapsed: {0}), _closeToAll([0, 300, 300]));
    });

    test('scales collapsed sizes that exceed the space', () {
      expect(
        layoutPaneSizes([1, 1, 1], available: 100, minSize: 50, collapsed: {0, 1}, collapsedSizes: [100, 100, 0]),
        _closeToAll([50, 50, 0]),
      );
    });

    test('ignores collapsed indexes with no pane', () {
      expect(layoutPaneSizes([1, 1], available: 600, minSize: 50, collapsed: {5}), _closeToAll([300, 300]));
    });

    test('takes weights as sizes in an unbounded space', () {
      expect(
        layoutPaneSizes([200, 300], available: double.infinity, minSize: 50, collapsed: {1}, collapsedSizes: [0, 40]),
        _closeToAll([200, 40]),
      );
    });

    test('collapses every pane', () {
      expect(
        layoutPaneSizes([1, 1], available: 600, minSize: 50, collapsed: {0, 1}, collapsedSizes: [40, 40]),
        _closeToAll([40, 40]),
      );
    });
  });

  group('ResizableColumnsController', () {
    test('starts with the given panes collapsed', () {
      final controller = ResizableColumnsController(collapsed: [1, 3]);
      expect(controller.collapsed, {1, 3});
      expect(controller.isCollapsed(1), isTrue);
      expect(controller.isCollapsed(0), isFalse);
    });

    test('notifies only when something changes', () {
      final controller = ResizableColumnsController();
      var calls = 0;
      controller.addListener(() => calls++);

      controller.collapse(0);
      controller.collapse(0);
      expect(calls, 1);

      controller.expand(0);
      controller.expand(0);
      expect(calls, 2);

      controller.setCollapsed(2, false);
      expect(calls, 2);
    });

    test('toggles a pane', () {
      final controller = ResizableColumnsController();
      controller.toggle(1);
      expect(controller.isCollapsed(1), isTrue);
      controller.toggle(1);
      expect(controller.isCollapsed(1), isFalse);
    });

    test('hands out a set that cannot be changed', () {
      final controller = ResizableColumnsController(collapsed: [0]);
      expect(() => controller.collapsed.add(1), throwsUnsupportedError);
    });
  });

  group('collapsing panes', () {
    testWidgets('starts with a collapsed pane at its collapsed size', (tester) async {
      final controller = ResizableColumnsController(collapsed: [2]);
      await tester.pumpWidget(_host(_columns(3, controller: controller, collapsedSizes: [0, 0, 60])));

      expect(_widths(tester, 3), _closeToAll([270, 270, 60]));
    });

    testWidgets('hides a pane with a collapsed size of zero', (tester) async {
      final controller = ResizableColumnsController(collapsed: [0]);
      await tester.pumpWidget(_host(_columns(2, controller: controller)));

      expect(_widths(tester, 2), _closeToAll([0, 600]));
    });

    testWidgets('gives the freed space to the other panes in proportion', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(
        _host(_columns(3, controller: controller, initialProportions: [1, 2, 3], collapsedSizes: [0, 0, 0])),
      );
      expect(_widths(tester, 3), _closeToAll([100, 200, 300]));

      controller.collapse(2);
      await tester.pump();

      expect(_widths(tester, 3), _closeToAll([200, 400, 0]));
    });

    testWidgets('expands a pane back to its size after a drag', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(3, controller: controller, collapsedSizes: [0, 0, 40])));

      await _drag(tester, 200, -50);
      expect(_widths(tester, 3), _closeToAll([150, 250, 200]));

      controller.collapse(2);
      await tester.pump();
      expect(_widths(tester, 3), _closeToAll([210, 350, 40]));

      controller.expand(2);
      await tester.pump();
      expect(_widths(tester, 3), _closeToAll([150, 250, 200]));
    });

    testWidgets('expands an initially collapsed pane to its initial share', (tester) async {
      final controller = ResizableColumnsController(collapsed: [1]);
      await tester.pumpWidget(_host(_columns(2, controller: controller, initialProportions: [2, 1])));
      expect(_widths(tester, 2), _closeToAll([600, 0]));

      controller.expand(1);
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([400, 200]));
    });

    testWidgets('keeps the size of a collapsed pane through drags of the others', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(3, controller: controller)));

      controller.collapse(0);
      await tester.pump();
      expect(_widths(tester, 3), _closeToAll([0, 300, 300]));

      await _drag(tester, 300, 100);
      expect(_widths(tester, 3), _closeToAll([0, 400, 200]));

      controller.expand(0);
      await tester.pump();
      expect(_widths(tester, 3), _closeToAll([200, 266.666667, 133.333333]));
    });

    testWidgets('does not drag a divider next to a collapsed pane', (tester) async {
      final controller = ResizableColumnsController(collapsed: [2]);
      await tester.pumpWidget(_host(_columns(3, controller: controller, collapsedSizes: [0, 0, 60])));

      await _drag(tester, 540, -100);

      expect(_widths(tester, 3), _closeToAll([270, 270, 60]));
    });

    testWidgets('pushes only expanded panes', (tester) async {
      final controller = ResizableColumnsController(collapsed: [1]);
      await tester.pumpWidget(
        _host(_columns(4, controller: controller, dragMode: ResizableDragMode.push, collapsedSizes: [0, 30, 0, 0])),
      );
      expect(_widths(tester, 4), _closeToAll([190, 30, 190, 190]));

      await _drag(tester, 410, -300);

      expect(_widths(tester, 4), _closeToAll([50, 30, 50, 470]));
    });

    testWidgets('reports sizes that restore collapsed panes', (tester) async {
      final controller = ResizableColumnsController();
      List<double>? reported;
      await tester.pumpWidget(
        _host(_columns(3, controller: controller, collapsedSizes: [0, 0, 40], onSizesChanged: (s) => reported = s)),
      );

      controller.collapse(2);
      await tester.pump();
      await _drag(tester, 280, 20);
      expect(_widths(tester, 3), _closeToAll([300, 260, 40]));
      // A collapsed pane is reported with the size it returns to.
      expect(reported, _closeToAll([300, 260, 200]));

      final restored = ResizableColumnsController(collapsed: [2]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _host(_columns(3, controller: restored, collapsedSizes: [0, 0, 40], initialSizes: reported)),
      );
      expect(_widths(tester, 3), _closeToAll([300, 260, 40]));

      restored.expand(2);
      await tester.pump();
      expect(_pane(tester, 2).width, closeTo(200, 1e-6));
    });

    testWidgets('runs the builders again when a pane collapses', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(
        _host(
          _columns(
            2,
            controller: controller,
            children: [
              (context) => const SizedBox.expand(),
              (context) => Text(controller.isCollapsed(1) ? 'rail' : 'chat'),
            ],
          ),
        ),
      );
      expect(find.text('chat'), findsOneWidget);

      controller.toggle(1);
      await tester.pump();

      expect(find.text('rail'), findsOneWidget);
    });

    testWidgets('collapses panes in a column', (tester) async {
      final controller = ResizableColumnsController(collapsed: [0]);
      await tester.pumpWidget(
        _host(
          _columns(2, controller: controller, orientation: ResizableOrientation.vertical, collapsedSizes: [40, 0]),
        ),
      );

      expect(_heights(tester, 2), _closeToAll([40, 260]));
    });

    testWidgets('follows a new controller', (tester) async {
      final first = ResizableColumnsController();
      final second = ResizableColumnsController(collapsed: [1]);
      await tester.pumpWidget(_host(_columns(2, controller: first)));
      expect(_widths(tester, 2), _closeToAll([300, 300]));

      await tester.pumpWidget(_host(_columns(2, controller: second)));
      expect(_widths(tester, 2), _closeToAll([600, 0]));

      first.collapse(0);
      await tester.pump();
      expect(_widths(tester, 2), _closeToAll([600, 0]));
    });

    testWidgets('stops listening when it is removed', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(2, controller: controller)));
      await tester.pumpWidget(const SizedBox());

      // A listener left behind would call setState on a disposed state.
      controller.collapse(0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ignores a collapsed index with no pane', (tester) async {
      final controller = ResizableColumnsController(collapsed: [3]);
      await tester.pumpWidget(_host(_columns(2, controller: controller)));

      expect(tester.takeException(), isNull);
      expect(_widths(tester, 2), _closeToAll([300, 300]));
    });

    testWidgets('expands a pane back to exactly its size when the others are pinned at the minimum', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(
        _host(_columns(3, controller: controller, initialProportions: [1, 1, 10], collapsedSizes: [0, 0, 0])),
      );
      expect(_widths(tester, 3), _closeToAll([50, 50, 500]));

      await _drag(tester, 100, 200);
      expect(_widths(tester, 3), _closeToAll([50, 250, 300]));

      controller.collapse(2);
      await tester.pump();
      controller.expand(2);
      await tester.pump();

      expect(_widths(tester, 3), _closeToAll([50, 250, 300]));
    });

    testWidgets('expands a pane to its size after the parent was resized', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(3, controller: controller)));
      controller.collapse(2);
      await tester.pump();

      await tester.pumpWidget(_host(_columns(3, controller: controller), size: const Size(780, 300)));
      expect(_widths(tester, 3), _closeToAll([390, 390, 0]));

      controller.expand(2);
      await tester.pump();

      expect(_widths(tester, 3), _closeToAll([290, 290, 200]));
    });

    testWidgets('expands a pane to what is left when its size does not fit', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(2, controller: controller, initialProportions: [1, 5])));
      controller.collapse(1);
      await tester.pump();

      await tester.pumpWidget(_host(_columns(2, controller: controller), size: const Size(300, 300)));
      controller.expand(1);
      await tester.pump();

      // It asks for 500; the other pane keeps its minimum of 50.
      expect(_widths(tester, 2), _closeToAll([50, 250]));
    });

    testWidgets('resizes the panes on either side of a collapsed middle pane', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(3, controller: controller, collapsedSizes: [0, 56, 0])));

      controller.collapse(1);
      await tester.pump();
      expect(_widths(tester, 3), _closeToAll([272, 56, 272]));

      // The divider after the first pane moves the first and the last.
      await _drag(tester, 272, 50);
      expect(_widths(tester, 3), _closeToAll([322, 56, 222]));

      // The divider after the collapsed pane takes no drag.
      await _drag(tester, 378, 50);
      expect(_widths(tester, 3), _closeToAll([322, 56, 222]));

      controller.expand(1);
      await tester.pump();
      expect(_pane(tester, 1).width, closeTo(200, 1e-6));
    });

    testWidgets('has no drag area before a leading collapsed pane', (tester) async {
      final controller = ResizableColumnsController(collapsed: [0]);
      await tester.pumpWidget(_host(_columns(3, controller: controller, collapsedSizes: [40, 0, 0])));

      await _drag(tester, 40, 100);

      expect(_widths(tester, 3), _closeToAll([40, 280, 280]));
    });

    testWidgets('drops a drag update that arrives after a collapse and before the rebuild', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(3, controller: controller)));

      final gesture = await tester.startGesture(const Offset(400, 150));
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      controller.collapse(2);
      await gesture.moveBy(const Offset(-20, 0));
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(_pane(tester, 2).width, 0);
    });

    testWidgets('keeps a drag on its divider when the draggable dividers change', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(4, controller: controller)));
      expect(_widths(tester, 4), _closeToAll([150, 150, 150, 150]));

      // The last divider, at 450.
      final gesture = await tester.startGesture(const Offset(450, 150));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();

      // The first divider loses its drag area, which shifts the others.
      controller.collapse(0);
      await tester.pump();
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final widths = _widths(tester, 4);
      expect(widths[0], 0);
      // Only the last two panes moved against each other.
      expect(widths[1], closeTo(200, 1e-6));
      expect(widths[2] + widths[3], closeTo(400, 1e-6));
      expect(widths[2], lessThan(200));
    });

    testWidgets('ignores a negative index', (tester) async {
      final controller = ResizableColumnsController();
      await tester.pumpWidget(_host(_columns(2, controller: controller)));

      expect(() => controller.collapse(-1), throwsAssertionError);
      expect(controller.collapsed, isEmpty);
    });

    testWidgets('does not rebuild when the change does not reach a pane', (tester) async {
      final controller = ResizableColumnsController();
      var builds = 0;
      await tester.pumpWidget(
        _host(
          _columns(
            2,
            controller: controller,
            children: [
              (context) {
                builds++;
                return const SizedBox.expand();
              },
              (context) => const SizedBox.expand(),
            ],
          ),
        ),
      );
      expect(builds, 1);

      controller.collapse(7);
      await tester.pump();

      expect(builds, 1);
    });

    testWidgets('rejects collapsedSizes of the wrong length', (tester) async {
      expect(() => _columns(2, collapsedSizes: [10]), throwsAssertionError);
    });
  });

  group('drag without movement', () {
    testWidgets('keeps the initial proportions when a drag does not move the divider', (tester) async {
      List<double>? reported;
      await tester.pumpWidget(
        _host(_columns(2, initialProportions: [1, 30], onSizesChanged: (sizes) => reported = sizes)),
      );
      // The first pane is pinned to the minimum of 50.
      expect(_widths(tester, 2), _closeToAll([50, 550]));

      await _drag(tester, 50, -30);
      expect(reported, isNull);

      await tester.pumpWidget(
        _host(_columns(2, initialProportions: [1, 30]), size: const Size(780, 300)),
      );
      // Still 1 to 30, so still pinned; weights rewritten to 50 and 550 would give 65.
      expect(_widths(tester, 2), _closeToAll([50, 730]));
    });
  });
}
