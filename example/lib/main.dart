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
          initialProportions: const [1, 1, 1],
          minChildSize: 100.0,
          children: [
            (context) => Container(color: Colors.red),
            (context) => Container(color: Colors.blue),
            (context) => Container(color: Colors.green),
          ],
        ),
      ),
    );
  }
}
