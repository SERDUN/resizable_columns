import 'package:flutter/material.dart';

import 'package:resizable_columns/resizable_columns.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resizable Columns Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Resizable Columns')),
        body: ResizableColumns(
          orientation: ResizableOrientation.horizontal,
          dividerThickness: 8.0,
          initialProportions: const [1, 1, 1, 1],
          minChildSize: 100.0,
          children: [
            // Fixed width and height.
            (context) => Container(
                  color: Colors.red,
                  alignment: Alignment.center,
                  child: const SizedBox(width: 90, height: 90, child: _Tile('90 x 90')),
                ),
            (context) => ResizableColumns(
                  orientation: ResizableOrientation.vertical,
                  dividerThickness: 8.0,
                  initialProportions: const [2, 1],
                  minChildSize: 100.0,
                  children: [
                    // Fills the pane and scrolls vertically.
                    (context) => Container(
                          color: Colors.blue,
                          child: const _Tiles(direction: Axis.vertical),
                        ),
                    // Fixed height, scrolls horizontally.
                    (context) => Container(
                          color: Colors.orange,
                          alignment: Alignment.center,
                          child: const SizedBox(height: 60, child: _Tiles(direction: Axis.horizontal)),
                        ),
                  ],
                ),
            // Fixed width, scrolls vertically.
            (context) => Container(
                  color: Colors.green,
                  alignment: Alignment.center,
                  child: const SizedBox(width: 90, child: _Tiles(direction: Axis.vertical)),
                ),
            // Larger than the pane in both directions: keeps its size and is clipped.
            (context) => Container(
                  color: Colors.purple,
                  child: const ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 500,
                      maxWidth: 500,
                      minHeight: 900,
                      maxHeight: 900,
                      child: _Tile('500 x 900'),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.direction});

  final Axis direction;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: direction,
      itemCount: 30,
      itemBuilder: (context, index) => SizedBox(
        width: direction == Axis.horizontal ? 80 : null,
        height: direction == Axis.vertical ? 44 : null,
        child: _Tile('Item ${index + 1}'),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      color: Colors.black26,
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
