ResizableColumns

[![pub package](https://img.shields.io/pub/v/resizable_columns.svg)](https://pub.dev/packages/resizable_columns)

A Flutter widget that provides a flexible, resizable layout with draggable dividers. It allows you to create multi-pane
layouts where users can resize the panes by dragging the dividers between them. Suitable for building responsive and
interactive UIs that require adjustable panel sizes.

Features

    •   Resizable Panes: Allow users to adjust the size of child widgets by dragging dividers.
    •   Horizontal and Vertical Orientations: Supports both horizontal and vertical layouts.
    •   Initial Sizes and Proportions: Set initial sizes or proportions for each pane.
    •   Minimum and Maximum Pane Sizes: Enforce constraints to prevent panes from becoming too small or too large.
    •   Customizable Dividers: Adjust the thickness of dividers between panes.
    •   Alignment Options: Align child widgets within their allocated space.
    •   Responsive Design: Adjusts pane sizes proportionally when the window is resized.

Installation

Add the following line to your pubspec.yaml under dependencies:

    dependencies:
      resizable_columns: ^0.0.1

Then, run:

    flutter pub get

Import the package in your Dart code:

    import 'package:resizable_columns/resizable_columns.dart';

Usage

Basic Example

Here’s a simple example of using FlexibleResizableLayout with three panes in a horizontal orientation:

    ResizableColumns(  
      orientation: ResizableOrientation.horizontal,  
      dividerThickness: 8.0,  
      minChildSize: 100.0,  
      children: [  
        (context) => Container(color: Colors.red),  
        (context) => Container(color: Colors.blue),  
      ],  
    );

Setting Initial Proportions

You can set initial proportions to control the initial sizes of the panes:

    ResizableColumns(  
      orientation: ResizableOrientation.horizontal,  
      dividerThickness: 8.0,  
      initialProportions: const [1, 1, 1],  
      minChildSize: 100.0,  
      children: [  
        (context) => Container(color: Colors.red),  
        (context) => Container(color: Colors.blue),  
        (context) => Container(color: Colors.green),  
      ],  
    );

API Reference

FlexibleResizableLayout

A widget that displays multiple resizable child widgets separated by draggable dividers.

Constructors

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
    })

Parameters

    •   children: A list of functions that build the child widgets. Each function receives the BuildContext and the size allocated to that child.
    •   orientation: The orientation of the layout (ResizableOrientation.horizontal or ResizableOrientation.vertical).
    •   dividerThickness: The thickness of the dividers between panes.
    •   dividerColor: The color of the dividers between panes.
    •   initialProportions: The initial proportions for each pane. The list length must match the number of children.
    •   initialSizes: The initial sizes for each pane. The list length must match the number of children.
    •   draggable: Whether the dividers are draggable.
    •   alignment: Alignment of the child widgets within their allocated space.
    •   minChildSize: The minimum size each pane can shrink to.

ResizableOrientation

An enum specifying the orientation of the layout.

    enum ResizableOrientation {  
      vertical,  
      horizontal,  
    }

Example

Here’s a complete example demonstrating a resizable layout with initial proportions and custom settings:

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
              dividerColor: Colors.grey,
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

Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please open an issue or
submit a pull request on [GitHub](https://github.com/SERDUN/resizable_columns).

License

This project is licensed under the MIT License - see
the [LICENSE](https://github.com/SERDUN/resizable_columns/blob/master/LICENSE) file for details.
