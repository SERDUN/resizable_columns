import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resizable_columns/resizable_columns.dart';

const _dividerColor = Color(0xFF123456);

Widget _host(
  Widget child, {
  Size size = const Size(600, 300),
  TextDirection textDirection = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: textDirection,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(size: size, child: child),
    ),
  );
}

List<WidgetBuilder> _panes(int count) {
  return [for (int i = 0; i < count; i++) (context) => SizedBox.expand(key: ValueKey('pane$i'))];
}

ResizableColumns _columns(
  int count, {
  ResizableOrientation orientation = ResizableOrientation.horizontal,
  double dividerThickness = 10.0,
  List<double>? initialProportions,
  List<double>? initialSizes,
  bool draggable = true,
  double minChildSize = 100.0,
}) {
  return ResizableColumns(
    orientation: orientation,
    dividerThickness: dividerThickness,
    dividerColor: _dividerColor,
    initialProportions: initialProportions,
    initialSizes: initialSizes,
    draggable: draggable,
    minChildSize: minChildSize,
    children: _panes(count),
  );
}

Rect _pane(WidgetTester tester, int index) => tester.getRect(find.byKey(ValueKey('pane$index')));

List<double> _widths(WidgetTester tester, int count) => [for (int i = 0; i < count; i++) _pane(tester, i).width];

List<double> _heights(WidgetTester tester, int count) => [for (int i = 0; i < count; i++) _pane(tester, i).height];

Finder _dividers() => find.byWidgetPredicate((widget) => widget is Container && widget.color == _dividerColor);

Matcher _closeToAll(List<double> expected) => pairwiseCompare<double, double>(
      expected,
      (e, a) => (e - a).abs() < 1e-6,
      'close to',
    );

void main() {
  group('initial layout', () {
    testWidgets('splits the space equally by default', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      expect(_widths(tester, 2), _closeToAll([295, 295]));
      expect(_pane(tester, 0).left, 0);
      expect(_pane(tester, 1).left, 305);
    });

    testWidgets('fills the cross axis', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      expect(_heights(tester, 2), [300, 300]);
    });

    testWidgets('follows initialProportions', (tester) async {
      await tester.pumpWidget(_host(_columns(3, dividerThickness: 0, initialProportions: [1, 2, 1])));

      expect(_widths(tester, 3), _closeToAll([150, 300, 150]));
    });

    testWidgets('splits equally when the proportions add up to zero', (tester) async {
      await tester.pumpWidget(_host(_columns(2, dividerThickness: 0, initialProportions: [0, 0])));

      expect(tester.takeException(), isNull);
      expect(_widths(tester, 2), _closeToAll([300, 300]));
    });

    testWidgets('follows initialSizes', (tester) async {
      await tester.pumpWidget(_host(_columns(2, initialSizes: [100, 500]), size: const Size(610, 300)));

      expect(_widths(tester, 2), _closeToAll([100, 500]));
    });

    testWidgets('scales initialSizes that do not add up to the space', (tester) async {
      await tester.pumpWidget(_host(_columns(2, dividerThickness: 0, initialSizes: [100, 200])));

      expect(_widths(tester, 2), _closeToAll([200, 400]));
    });

    Matcher throwsAssertionMentioning(String text) {
      return throwsA(isAssertionError.having((e) => e.message, 'message', contains(text)));
    }

    testWidgets('rejects initialProportions of the wrong length', (tester) async {
      expect(() => _columns(2, initialProportions: [1, 2, 3]), throwsAssertionMentioning('initialProportions length'));
      expect(() => _columns(2, initialProportions: [1]), throwsAssertionMentioning('initialProportions length'));
    });

    testWidgets('rejects initialSizes of the wrong length', (tester) async {
      expect(() => _columns(2, initialSizes: [100, 200, 300]), throwsAssertionMentioning('initialSizes length'));
      expect(() => _columns(2, initialSizes: [100]), throwsAssertionMentioning('initialSizes length'));
    });

    testWidgets('rejects initialSizes together with initialProportions', (tester) async {
      expect(
        () => _columns(2, initialSizes: [150, 450], initialProportions: [1, 1]),
        throwsAssertionMentioning('either initialSizes or initialProportions'),
      );
    });

    testWidgets('accepts empty initial lists for no children', (tester) async {
      await tester.pumpWidget(_host(_columns(0, initialSizes: [])));

      expect(tester.takeException(), isNull);
    });

    testWidgets('raises a pane to minChildSize', (tester) async {
      await tester.pumpWidget(_host(_columns(2, dividerThickness: 0, initialProportions: [1, 9])));

      expect(_widths(tester, 2), _closeToAll([100, 500]));
    });

    testWidgets('splits equally when minChildSize does not fit', (tester) async {
      await tester.pumpWidget(_host(_columns(3, dividerThickness: 0, minChildSize: 300)));

      expect(tester.takeException(), isNull);
      expect(_widths(tester, 3), _closeToAll([200, 200, 200]));
    });

    testWidgets('lays a single child out without a divider', (tester) async {
      await tester.pumpWidget(_host(_columns(1)));

      expect(_widths(tester, 1), [600]);
      expect(_dividers(), findsNothing);
    });

    testWidgets('stacks the panes in vertical orientation', (tester) async {
      await tester.pumpWidget(
        _host(
          _columns(2, orientation: ResizableOrientation.vertical, initialProportions: [1, 3]),
          size: const Size(300, 410),
        ),
      );

      expect(_heights(tester, 2), _closeToAll([100, 300]));
      expect(_widths(tester, 2), [300, 300]);
      expect(_pane(tester, 1).top, 110);
    });

    testWidgets('passes a context to the builders', (tester) async {
      final contexts = <BuildContext>[];
      await tester.pumpWidget(
        _host(
          ResizableColumns(
            orientation: ResizableOrientation.horizontal,
            children: [
              (context) {
                contexts.add(context);
                return const SizedBox();
              },
              (context) {
                contexts.add(context);
                return const SizedBox();
              },
            ],
          ),
        ),
      );

      expect(contexts, hasLength(2));
      expect(Directionality.of(contexts.first), TextDirection.ltr);
    });
  });

  group('alignment', () {
    Future<Rect> pumpAligned(WidgetTester tester, Alignment alignment, ResizableOrientation orientation) async {
      await tester.pumpWidget(
        _host(
          ResizableColumns(
            orientation: orientation,
            dividerThickness: 0,
            alignment: alignment,
            children: [
              (context) => const SizedBox(key: ValueKey('child'), width: 50, height: 40),
              (context) => const SizedBox(),
            ],
          ),
        ),
      );
      return tester.getRect(find.byKey(const ValueKey('child')));
    }

    testWidgets('puts a child at the top left by default', (tester) async {
      await tester.pumpWidget(
        _host(
          ResizableColumns(
            orientation: ResizableOrientation.horizontal,
            children: [
              (context) => const SizedBox(key: ValueKey('child'), width: 50, height: 40),
              (context) => const SizedBox(),
            ],
          ),
        ),
      );

      expect(tester.getRect(find.byKey(const ValueKey('child'))), const Rect.fromLTWH(0, 0, 50, 40));
    });

    testWidgets('centers a child in its pane', (tester) async {
      final rect = await pumpAligned(tester, Alignment.center, ResizableOrientation.horizontal);

      expect(rect, const Rect.fromLTWH(125, 130, 50, 40));
    });

    testWidgets('puts a child at the bottom right of its pane', (tester) async {
      final rect = await pumpAligned(tester, Alignment.bottomRight, ResizableOrientation.horizontal);

      expect(rect, const Rect.fromLTWH(250, 260, 50, 40));
    });

    testWidgets('aligns a child in vertical orientation', (tester) async {
      final center = await pumpAligned(tester, Alignment.center, ResizableOrientation.vertical);
      expect(center, const Rect.fromLTWH(275, 55, 50, 40));

      final bottomRight = await pumpAligned(tester, Alignment.bottomRight, ResizableOrientation.vertical);
      expect(bottomRight, const Rect.fromLTWH(550, 110, 50, 40));
    });
  });

  group('dividers', () {
    testWidgets('places one divider between every two panes', (tester) async {
      await tester.pumpWidget(_host(_columns(3)));

      expect(_dividers(), findsNWidgets(2));
      final divider = tester.getRect(_dividers().first);
      expect(divider.left, closeTo(580 / 3, 1e-6));
      expect(divider.size, const Size(10, 300));
    });

    testWidgets('lays a divider across in vertical orientation', (tester) async {
      await tester.pumpWidget(_host(_columns(2, orientation: ResizableOrientation.vertical)));

      expect(tester.getRect(_dividers()), const Rect.fromLTWH(0, 145, 600, 10));
    });

    testWidgets('is transparent and 2 px thick by default', (tester) async {
      await tester.pumpWidget(
        _host(ResizableColumns(orientation: ResizableOrientation.horizontal, children: _panes(2))),
      );

      final divider =
          find.byWidgetPredicate((widget) => widget is Container && widget.color == const Color(0x00000000));
      expect(tester.getSize(divider), const Size(2, 300));
      expect(_widths(tester, 2), _closeToAll([299, 299]));
    });

    MouseCursor cursor(WidgetTester tester) {
      return tester.widget<MouseRegion>(find.byType(MouseRegion)).cursor;
    }

    testWidgets('shows a column resize cursor in horizontal orientation', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      expect(cursor(tester), SystemMouseCursors.resizeColumn);
    });

    testWidgets('shows a row resize cursor in vertical orientation', (tester) async {
      await tester.pumpWidget(_host(_columns(2, orientation: ResizableOrientation.vertical)));

      expect(cursor(tester), SystemMouseCursors.resizeRow);
    });

    testWidgets('shows no resize cursor when not draggable', (tester) async {
      await tester.pumpWidget(_host(_columns(2, draggable: false)));

      expect(find.byType(MouseRegion), findsNothing);
    });
  });

  group('drag area', () {
    ResizableColumns thin({
      double dividerThickness = 2,
      double? dividerHitSize,
      ResizableOrientation orientation = ResizableOrientation.horizontal,
      List<double>? initialProportions,
    }) {
      if (dividerHitSize == null) {
        return ResizableColumns(
          orientation: orientation,
          dividerThickness: dividerThickness,
          minChildSize: 100,
          initialProportions: initialProportions,
          children: _panes(2),
        );
      }
      return ResizableColumns(
        orientation: orientation,
        dividerThickness: dividerThickness,
        dividerHitSize: dividerHitSize,
        minChildSize: 100,
        initialProportions: initialProportions,
        children: _panes(2),
      );
    }

    // A 2 px divider between two 299 px panes sits at 299..301.
    Future<bool> movesWhenDraggedFrom(WidgetTester tester, Offset start, {Offset by = const Offset(40, 0)}) async {
      final before = _pane(tester, 0).size;
      await tester.dragFrom(start, by);
      await tester.pump();
      return _pane(tester, 0).size != before;
    }

    testWidgets('is 12 px wide by default', (tester) async {
      await tester.pumpWidget(_host(thin()));

      expect(await movesWhenDraggedFrom(tester, const Offset(293, 150)), isFalse);
      expect(await movesWhenDraggedFrom(tester, const Offset(295, 150)), isTrue);
    });

    testWidgets('reaches the same distance into both panes', (tester) async {
      await tester.pumpWidget(_host(thin()));
      expect(await movesWhenDraggedFrom(tester, const Offset(305, 150), by: const Offset(-40, 0)), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(thin()));
      expect(await movesWhenDraggedFrom(tester, const Offset(307, 150), by: const Offset(-40, 0)), isFalse);
    });

    testWidgets('does not change the layout', (tester) async {
      await tester.pumpWidget(_host(thin(dividerHitSize: 60)));

      expect(_widths(tester, 2), _closeToAll([299, 299]));
      expect(_pane(tester, 1).left, 301);
    });

    testWidgets('follows dividerHitSize', (tester) async {
      await tester.pumpWidget(_host(thin(dividerHitSize: 60)));

      expect(await movesWhenDraggedFrom(tester, const Offset(269, 150)), isFalse);
      expect(await movesWhenDraggedFrom(tester, const Offset(271, 150)), isTrue);
    });

    testWidgets('is never narrower than the divider', (tester) async {
      await tester.pumpWidget(_host(thin(dividerThickness: 40, dividerHitSize: 0)));

      // The divider sits at 280..320.
      expect(await movesWhenDraggedFrom(tester, const Offset(279, 150)), isFalse);
      expect(await movesWhenDraggedFrom(tester, const Offset(281, 150)), isTrue);
    });

    testWidgets('lets a divider of no thickness be dragged', (tester) async {
      await tester.pumpWidget(_host(thin(dividerThickness: 0)));

      await tester.dragFrom(const Offset(300, 150), const Offset(40, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([340, 260]));
    });

    testWidgets('moves with the divider', (tester) async {
      await tester.pumpWidget(_host(thin()));
      await tester.dragFrom(const Offset(300, 150), const Offset(100, 0));
      await tester.pump();

      expect(await movesWhenDraggedFrom(tester, const Offset(300, 150)), isFalse);
      expect(await movesWhenDraggedFrom(tester, const Offset(396, 150)), isTrue);
    });

    testWidgets('lies across in vertical orientation', (tester) async {
      await tester.pumpWidget(_host(thin(orientation: ResizableOrientation.vertical), size: const Size(300, 600)));

      expect(await movesWhenDraggedFrom(tester, const Offset(150, 293), by: const Offset(0, 40)), isFalse);
      expect(await movesWhenDraggedFrom(tester, const Offset(150, 295), by: const Offset(0, 40)), isTrue);
    });

    testWidgets('is mirrored in a right-to-left layout', (tester) async {
      // The first pane is 200 px wide on the right, so the divider sits at 398..400.
      await tester.pumpWidget(_host(thin(initialProportions: [200, 398]), textDirection: TextDirection.rtl));
      expect(_pane(tester, 0).left, closeTo(400, 1e-6));

      expect(await movesWhenDraggedFrom(tester, const Offset(201, 150)), isFalse);
      expect(await movesWhenDraggedFrom(tester, const Offset(395, 150), by: const Offset(-40, 0)), isTrue);
    });

    testWidgets('lets a tap through to the pane under it', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
          ResizableColumns(
            orientation: ResizableOrientation.horizontal,
            minChildSize: 100,
            children: [
              (context) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox.expand(key: ValueKey('pane0')),
                  ),
              (context) => const SizedBox.expand(key: ValueKey('pane1')),
            ],
          ),
        ),
      );

      await tester.tapAt(const Offset(296, 150));
      expect(taps, 1);

      // The same spot still starts a drag.
      await tester.dragFrom(const Offset(296, 150), const Offset(40, 0));
      await tester.pump();
      expect(_pane(tester, 0).width, closeTo(339, 1e-6));
    });

    testWidgets('is absent when not draggable', (tester) async {
      await tester.pumpWidget(
        _host(
          ResizableColumns(
            orientation: ResizableOrientation.horizontal,
            draggable: false,
            dividerHitSize: 60,
            children: _panes(2),
          ),
        ),
      );

      expect(find.byType(Stack), findsNothing);
      expect(await movesWhenDraggedFrom(tester, const Offset(300, 150)), isFalse);
    });
  });

  group('dragging', () {
    testWidgets('moves the divider with the pointer', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([355, 235]));
    });

    testWidgets('moves the divider back', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(-60, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([235, 355]));
    });

    testWidgets('resizes only the panes next to the dragged divider', (tester) async {
      await tester.pumpWidget(_host(_columns(3, minChildSize: 50)));

      await tester.dragFrom(const Offset(400, 150), const Offset(40, 0));
      await tester.pump();

      expect(_widths(tester, 3), _closeToAll([580 / 3, 580 / 3 + 40, 580 / 3 - 40]));
    });

    testWidgets('stops at minChildSize of the next pane', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(280, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([490, 100]));
    });

    testWidgets('stops at minChildSize of the current pane', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(-280, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([100, 490]));
    });

    testWidgets('follows the pointer back only after it returns past the limit', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      final gesture = await tester.startGesture(const Offset(300, 150));
      await gesture.moveBy(const Offset(250, 0));
      await tester.pump();
      expect(_widths(tester, 2), _closeToAll([490, 100]));

      // The pointer is still 5 px past the limit, so the divider stays.
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(_widths(tester, 2), _closeToAll([490, 100]));

      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(_widths(tester, 2), _closeToAll([445, 145]));

      await gesture.up();
    });

    testWidgets('starts a new drag from where the last one ended', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(250, 0));
      await tester.pump();
      await tester.dragFrom(const Offset(495, 150), const Offset(-40, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([450, 140]));
    });

    testWidgets('starts a new drag cleanly after a cancelled one', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      final gesture = await tester.startGesture(const Offset(300, 150));
      await gesture.moveBy(const Offset(250, 0));
      await gesture.cancel();
      await tester.pump();
      await tester.dragFrom(const Offset(495, 150), const Offset(-40, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([450, 140]));
    });

    testWidgets('moves the divider in vertical orientation', (tester) async {
      await tester.pumpWidget(
        _host(_columns(2, orientation: ResizableOrientation.vertical), size: const Size(300, 600)),
      );

      await tester.dragFrom(const Offset(150, 300), const Offset(0, 60));
      await tester.pump();

      expect(_heights(tester, 2), _closeToAll([355, 235]));
    });

    testWidgets('ignores a drag across the orientation', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(0, 60));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([295, 295]));
    });

    testWidgets('does nothing when not draggable', (tester) async {
      await tester.pumpWidget(_host(_columns(2, draggable: false)));

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([295, 295]));
    });

    testWidgets('does nothing in vertical orientation when not draggable', (tester) async {
      await tester.pumpWidget(
        _host(_columns(2, orientation: ResizableOrientation.vertical, draggable: false), size: const Size(300, 600)),
      );

      await tester.dragFrom(const Offset(150, 300), const Offset(0, 60));
      await tester.pump();

      expect(_heights(tester, 2), _closeToAll([295, 295]));
    });

    testWidgets('follows the pointer in a right-to-left layout', (tester) async {
      await tester.pumpWidget(_host(_columns(2), textDirection: TextDirection.rtl));
      expect(_pane(tester, 0).left, 305);

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([235, 355]));
      expect(_pane(tester, 0).left, closeTo(365, 1e-6));
    });

    testWidgets('responds to a mouse drag', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0), kind: PointerDeviceKind.mouse);
      await tester.pump();

      expect(_widths(tester, 2), _closeToAll([355, 235]));
    });
  });

  group('onSizesChanged', () {
    late List<List<double>> reported;

    ResizableColumns observed(
      int count, {
      ResizableOrientation orientation = ResizableOrientation.horizontal,
      bool draggable = true,
      List<double>? initialSizes,
    }) {
      return ResizableColumns(
        orientation: orientation,
        dividerThickness: 10,
        minChildSize: 100,
        draggable: draggable,
        initialSizes: initialSizes,
        onSizesChanged: reported.add,
        children: _panes(count),
      );
    }

    setUp(() => reported = []);

    testWidgets('reports the size of every pane after a drag', (tester) async {
      await tester.pumpWidget(_host(observed(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(reported.last, _closeToAll([355, 235]));
      expect(reported.last, _closeToAll(_widths(tester, 2)));
    });

    testWidgets('reports every move of a drag', (tester) async {
      await tester.pumpWidget(_host(observed(2)));

      final gesture = await tester.startGesture(const Offset(300, 150));
      await gesture.moveBy(const Offset(10, 0));
      await gesture.moveBy(const Offset(10, 0));
      await gesture.moveBy(const Offset(-5, 0));
      await gesture.up();

      expect(reported, hasLength(3));
      expect(reported[0], _closeToAll([305, 285]));
      expect(reported[1], _closeToAll([315, 275]));
      expect(reported[2], _closeToAll([310, 280]));
    });

    testWidgets('reports all panes in the order of children', (tester) async {
      await tester.pumpWidget(_host(observed(3)));

      await tester.dragFrom(const Offset(400, 150), const Offset(40, 0));
      await tester.pump();

      expect(reported.last, _closeToAll([580 / 3, 580 / 3 + 40, 580 / 3 - 40]));
    });

    testWidgets('keeps the order of children in a right-to-left layout', (tester) async {
      await tester.pumpWidget(_host(observed(2), textDirection: TextDirection.rtl));

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(reported.last, _closeToAll([235, 355]));
    });

    testWidgets('reports heights in vertical orientation', (tester) async {
      await tester.pumpWidget(
        _host(observed(2, orientation: ResizableOrientation.vertical), size: const Size(300, 600)),
      );

      await tester.dragFrom(const Offset(150, 300), const Offset(0, 60));
      await tester.pump();

      expect(reported.last, _closeToAll([355, 235]));
    });

    testWidgets('is silent while the divider rests against a limit', (tester) async {
      await tester.pumpWidget(_host(observed(2)));

      final gesture = await tester.startGesture(const Offset(300, 150));
      await gesture.moveBy(const Offset(250, 0));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.up();

      expect(reported, hasLength(1));
      expect(reported.single, _closeToAll([490, 100]));
    });

    testWidgets('is silent when a drag cannot move the divider at all', (tester) async {
      await tester.pumpWidget(_host(observed(2, initialSizes: [100, 490])));

      await tester.dragFrom(const Offset(105, 150), const Offset(-40, 0));
      await tester.pump();

      expect(reported, isEmpty);
    });

    testWidgets('is silent for the initial layout and a resize of the parent', (tester) async {
      final columns = observed(2);
      await tester.pumpWidget(_host(columns));
      await tester.pumpWidget(_host(columns, size: const Size(400, 300)));

      expect(reported, isEmpty);
    });

    testWidgets('is silent when not draggable', (tester) async {
      await tester.pumpWidget(_host(observed(2, draggable: false)));

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(reported, isEmpty);
    });

    testWidgets('reports a list that cannot be modified', (tester) async {
      await tester.pumpWidget(_host(observed(2)));

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(() => reported.last[0] = 0, throwsUnsupportedError);
      expect(_widths(tester, 2), _closeToAll([355, 235]));
    });

    testWidgets('restores the layout through initialSizes', (tester) async {
      await tester.pumpWidget(_host(observed(3)));
      await tester.dragFrom(const Offset(400, 150), const Offset(40, 0));
      await tester.pump();
      final saved = reported.last;

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(observed(3, initialSizes: saved)));

      expect(_widths(tester, 3), _closeToAll(saved));
    });

    testWidgets('can rebuild the parent from the callback', (tester) async {
      List<double>? sizes;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => ResizableColumns(
              orientation: ResizableOrientation.horizontal,
              dividerThickness: 10,
              minChildSize: 100,
              onSizesChanged: (value) => setState(() => sizes = value),
              children: [
                (context) => Text('${sizes?.first.round()}', textDirection: TextDirection.ltr),
                (context) => const SizedBox.expand(key: ValueKey('pane1')),
              ],
            ),
          ),
        ),
      );

      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('355'), findsOneWidget);
      expect(_pane(tester, 1).width, closeTo(235, 1e-6));
    });
  });

  group('pane rebuilds', () {
    late int builds;

    ResizableColumns counted() {
      Widget pane(BuildContext context) {
        builds++;
        return const SizedBox.expand();
      }

      return ResizableColumns(
        orientation: ResizableOrientation.horizontal,
        dividerThickness: 10,
        children: [pane, pane, pane],
      );
    }

    setUp(() => builds = 0);

    testWidgets('builds every pane once', (tester) async {
      await tester.pumpWidget(_host(counted()));

      expect(builds, 3);
    });

    testWidgets('does not rebuild the panes during a drag', (tester) async {
      await tester.pumpWidget(_host(counted()));
      builds = 0;

      final gesture = await tester.startGesture(const Offset(198, 150));
      for (int i = 0; i < 20; i++) {
        await gesture.moveBy(const Offset(2, 0));
        await tester.pump();
      }
      await gesture.up();

      expect(builds, 0);
    });

    testWidgets('does not rebuild the panes when the space changes', (tester) async {
      final columns = counted();
      await tester.pumpWidget(_host(columns));
      builds = 0;

      await tester.pumpWidget(_host(columns, size: const Size(400, 300)));

      expect(builds, 0);
    });

    testWidgets('rebuilds the panes when the widget is rebuilt', (tester) async {
      await tester.pumpWidget(_host(counted()));
      builds = 0;

      await tester.pumpWidget(_host(counted()));

      expect(builds, 3);
    });

    testWidgets('rebuilds a pane when something it depends on changes', (tester) async {
      final columns = ResizableColumns(
        orientation: ResizableOrientation.horizontal,
        children: [
          (context) => Text('${Directionality.of(context)}', textDirection: TextDirection.ltr),
          (context) => const SizedBox(),
        ],
      );
      await tester.pumpWidget(_host(columns));
      expect(find.text('TextDirection.ltr'), findsOneWidget);

      await tester.pumpWidget(_host(columns, textDirection: TextDirection.rtl));

      expect(find.text('TextDirection.rtl'), findsOneWidget);
    });
  });

  group('parent changes', () {
    testWidgets('keeps minChildSize when the space shrinks', (tester) async {
      await tester.pumpWidget(_host(_columns(2, initialSizes: [100, 500]), size: const Size(610, 300)));
      await tester.pumpWidget(_host(_columns(2, initialSizes: [100, 500]), size: const Size(310, 300)));

      expect(_widths(tester, 2), _closeToAll([100, 200]));
    });

    testWidgets('restores the proportions when the space grows back', (tester) async {
      await tester.pumpWidget(_host(_columns(2, initialSizes: [200, 400]), size: const Size(610, 300)));
      await tester.pumpWidget(_host(_columns(2, initialSizes: [200, 400]), size: const Size(310, 300)));
      expect(_widths(tester, 2), _closeToAll([100, 200]));

      await tester.pumpWidget(_host(_columns(2, initialSizes: [200, 400]), size: const Size(610, 300)));
      expect(_widths(tester, 2), _closeToAll([200, 400]));
    });

    testWidgets('keeps dragged proportions when the space grows', (tester) async {
      await tester.pumpWidget(_host(_columns(2), size: const Size(400, 300)));
      await tester.dragFrom(const Offset(200, 150), const Offset(39, 0));
      await tester.pump();
      expect(_widths(tester, 2), _closeToAll([234, 156]));

      await tester.pumpWidget(_host(_columns(2), size: const Size(790, 300)));

      expect(_widths(tester, 2), _closeToAll([468, 312]));
    });

    testWidgets('does not reset the sizes when initialProportions change', (tester) async {
      await tester.pumpWidget(_host(_columns(2, dividerThickness: 0, initialProportions: [1, 1])));
      await tester.pumpWidget(_host(_columns(2, dividerThickness: 0, initialProportions: [1, 2])));

      expect(_widths(tester, 2), _closeToAll([300, 300]));
    });

    testWidgets('lays out an added child', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));
      await tester.pumpWidget(_host(_columns(3)));

      expect(tester.takeException(), isNull);
      expect(_widths(tester, 3), _closeToAll([580 / 3, 580 / 3, 580 / 3]));
    });

    testWidgets('fills the space after a child is removed', (tester) async {
      await tester.pumpWidget(_host(_columns(3)));
      await tester.pumpWidget(_host(_columns(2)));

      expect(tester.takeException(), isNull);
      expect(_widths(tester, 2), _closeToAll([295, 295]));
    });

    testWidgets('drops the dragged sizes when the number of children changes', (tester) async {
      await tester.pumpWidget(_host(_columns(2)));
      await tester.dragFrom(const Offset(300, 150), const Offset(60, 0));
      await tester.pump();

      await tester.pumpWidget(_host(_columns(3, initialProportions: [2, 1, 1], dividerThickness: 0)));

      expect(_widths(tester, 3), _closeToAll([300, 150, 150]));
    });

    testWidgets('switches orientation with the same proportions', (tester) async {
      await tester.pumpWidget(
        _host(_columns(2, dividerThickness: 0, initialProportions: [1, 2]), size: const Size(600, 300)),
      );
      await tester.pumpWidget(
        _host(
          _columns(2, dividerThickness: 0, initialProportions: [1, 2], orientation: ResizableOrientation.vertical),
          size: const Size(600, 300),
        ),
      );

      expect(_heights(tester, 2), _closeToAll([100, 200]));
    });
  });

  group('unbounded space', () {
    Widget scrollable(Widget child) {
      return _host(SingleChildScrollView(scrollDirection: Axis.horizontal, child: child));
    }

    testWidgets('uses initialSizes as they are', (tester) async {
      await tester.pumpWidget(scrollable(_columns(2, initialSizes: [150, 700])));

      expect(tester.takeException(), isNull);
      expect(_widths(tester, 2), [150, 700]);
    });

    testWidgets('raises initialSizes to minChildSize', (tester) async {
      await tester.pumpWidget(scrollable(_columns(2, initialSizes: [20, 700])));

      expect(_widths(tester, 2), [100, 700]);
    });

    testWidgets('can be dragged', (tester) async {
      await tester.pumpWidget(scrollable(_columns(2, initialSizes: [150, 300])));

      final gesture = await tester.startGesture(const Offset(155, 150));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.up();
      await tester.pump();

      expect(_widths(tester, 2), [210, 240]);
    });

    testWidgets('asks for a bounded size or initialSizes', (tester) async {
      await tester.pumpWidget(scrollable(_columns(2)));

      expect(
        tester.takeException(),
        isAssertionError.having((e) => e.message, 'message', contains('initialSizes')),
      );
    });
  });
}
