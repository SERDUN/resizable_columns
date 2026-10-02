import 'package:flutter_test/flutter_test.dart';
import 'package:resizable_columns/src/pane_sizes.dart';

Matcher closeToAll(List<double> expected) => pairwiseCompare<double, double>(
      expected,
      (e, a) => (e - a).abs() < 1e-9,
      'close to',
    );

void main() {
  group('fitPaneSizes', () {
    test('returns nothing for no panes', () {
      expect(fitPaneSizes([], available: 600, minSize: 50), isEmpty);
    });

    test('splits the space in proportion to the weights', () {
      expect(fitPaneSizes([1, 2, 1], available: 600, minSize: 50), closeToAll([150, 300, 150]));
    });

    test('keeps weights that already add up to the space', () {
      expect(fitPaneSizes([100, 500], available: 600, minSize: 50), closeToAll([100, 500]));
    });

    test('pins a pane to the minimum and gives the rest to the others', () {
      expect(fitPaneSizes([100, 500], available: 300, minSize: 100), closeToAll([100, 200]));
    });

    test('pins panes in several rounds', () {
      // 60 fits the first round, then drops below the minimum once 10 is pinned.
      final sizes = fitPaneSizes([10, 60, 400], available: 300, minSize: 50);

      expect(sizes, closeToAll([50, 50, 200]));
    });

    test('adds up to the available space', () {
      final sizes = fitPaneSizes([3, 7, 11, 1], available: 777, minSize: 40);

      expect(sizes.reduce((a, b) => a + b), closeTo(777, 1e-9));
      expect(sizes.every((size) => size >= 40), isTrue);
    });

    test('splits equally when the minimum does not fit', () {
      expect(fitPaneSizes([1, 5, 2], available: 240, minSize: 100), closeToAll([80, 80, 80]));
    });

    test('splits equally when the minimum fits exactly', () {
      expect(fitPaneSizes([1, 5], available: 200, minSize: 100), closeToAll([100, 100]));
    });

    test('gives every pane nothing when there is no space', () {
      expect(fitPaneSizes([1, 2], available: 0, minSize: 50), [0, 0]);
      expect(fitPaneSizes([1, 2], available: -20, minSize: 50), [0, 0]);
    });

    test('splits equally when every weight is zero', () {
      expect(fitPaneSizes([0, 0], available: 600, minSize: 50), closeToAll([300, 300]));
    });

    test('treats a negative, infinite or NaN weight as zero', () {
      final sizes = fitPaneSizes([-5, double.infinity, double.nan, 1], available: 600, minSize: 50);

      expect(sizes, closeToAll([50, 50, 50, 450]));
    });

    test('takes the weights as sizes when the space is unbounded', () {
      final sizes = fitPaneSizes([150, 20, 250], available: double.infinity, minSize: 50);

      expect(sizes, [150, 50, 250]);
    });

    test('does not change the weights it was given', () {
      final weights = [100.0, 500.0];
      fitPaneSizes(weights, available: 300, minSize: 100);

      expect(weights, [100, 500]);
    });
  });

  group('movePaneDivider', () {
    test('moves space from the next pane to the current one', () {
      expect(movePaneDivider([300, 300], index: 0, delta: 60, minSize: 50), [360, 240]);
    });

    test('moves space from the current pane to the next one', () {
      expect(movePaneDivider([300, 300], index: 0, delta: -60, minSize: 50), [240, 360]);
    });

    test('touches only the two panes next to the divider', () {
      expect(movePaneDivider([200, 200, 200], index: 1, delta: 30, minSize: 50), [200, 230, 170]);
    });

    test('stops when the next pane reaches the minimum', () {
      expect(movePaneDivider([300, 300], index: 0, delta: 500, minSize: 100), [500, 100]);
    });

    test('stops when the current pane reaches the minimum', () {
      expect(movePaneDivider([300, 300], index: 0, delta: -500, minSize: 100), [100, 500]);
    });

    test('does not shrink a pane that is already below the minimum', () {
      expect(movePaneDivider([80, 80], index: 0, delta: 30, minSize: 100), [80, 80]);
      expect(movePaneDivider([80, 80], index: 0, delta: -30, minSize: 100), [80, 80]);
    });

    test('does not change the sizes it was given', () {
      final sizes = [300.0, 300.0];
      movePaneDivider(sizes, index: 0, delta: 60, minSize: 50);

      expect(sizes, [300, 300]);
    });
  });
}
