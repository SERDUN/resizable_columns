# ResizableColumns

[![pub package](https://img.shields.io/pub/v/resizable_columns.svg)](https://pub.dev/packages/resizable_columns)

A Flutter widget that provides a flexible, resizable layout with draggable dividers. It allows you to create multi-pane
layouts where users can resize the panes by dragging the dividers between them. Suitable for building responsive and
interactive UIs that require adjustable panel sizes.

## Features

- **Resizable panes:** users adjust the size of child widgets by dragging the dividers.
- **Horizontal and vertical orientations:** panes sit side by side or on top of each other, and can be nested.
- **Initial sizes and proportions:** set the starting size of each pane in pixels or as a share of the space.
- **Minimum pane size:** a pane never shrinks below `minChildSize` while the space allows it.
- **Customizable dividers:** set the thickness and the color of the dividers.
- **Easy to grab:** a divider can be dragged by an area wider than the divider itself.
- **Alignment:** align each child within its pane.
- **Responsive:** panes keep their proportions when the parent is resized.
- **Saving and restoring:** `onSizesChanged` reports the pane sizes while a divider is dragged.
- **Right-to-left aware:** dividers follow the pointer in right-to-left layouts.

## Installation

Add the following line to your `pubspec.yaml` under dependencies:

```yaml
dependencies:
  resizable_columns: ^0.1.0
```

Then, run:

```sh
flutter pub get
```

Import the package in your Dart code:

```dart
import 'package:resizable_columns/resizable_columns.dart';
```

## Usage

### Basic example

Two panes in a horizontal orientation, split equally:

```dart
ResizableColumns(
  orientation: ResizableOrientation.horizontal,
  dividerThickness: 8.0,
  minChildSize: 100.0,
  children: [
    (context) => Container(color: Colors.red),
    (context) => Container(color: Colors.blue),
  ],
);
```

### Setting initial proportions

`initialProportions` splits the space by share. Here the middle pane starts twice as wide as the others:

```dart
ResizableColumns(
  orientation: ResizableOrientation.horizontal,
  dividerThickness: 8.0,
  initialProportions: const [1, 2, 1],
  minChildSize: 100.0,
  children: [
    (context) => Container(color: Colors.red),
    (context) => Container(color: Colors.blue),
    (context) => Container(color: Colors.green),
  ],
);
```

### Nesting

A pane can hold another `ResizableColumns` with the other orientation:

```dart
ResizableColumns(
  orientation: ResizableOrientation.horizontal,
  children: [
    (context) => Container(color: Colors.red),
    (context) => ResizableColumns(
          orientation: ResizableOrientation.vertical,
          children: [
            (context) => Container(color: Colors.blue),
            (context) => Container(color: Colors.orange),
          ],
        ),
  ],
);
```

### Saving and restoring sizes

`onSizesChanged` reports the size of every pane in pixels while a divider is dragged. Keep the last value and pass it
back as `initialSizes` to restore the layout:

```dart
ResizableColumns(
  orientation: ResizableOrientation.horizontal,
  initialSizes: savedSizes,
  onSizesChanged: (sizes) => savedSizes = sizes,
  children: [
    (context) => Container(color: Colors.red),
    (context) => Container(color: Colors.blue),
  ],
);
```

The callback is not called for the initial layout or when the parent is resized. Restored sizes are scaled to the
space available, so the layout keeps its proportions in a window of a different size.

## API reference

### ResizableColumns

A widget that displays multiple resizable child widgets separated by draggable dividers.

```dart
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
  this.alignment = Alignment.topLeft,
  this.minChildSize = 50.0,
  this.onSizesChanged,
})
```

| Parameter | Description |
| --- | --- |
| `children` | Functions that build the child widgets. Each one receives a `BuildContext`. |
| `orientation` | `ResizableOrientation.horizontal` or `ResizableOrientation.vertical`. |
| `dividerThickness` | The thickness of the dividers between panes. |
| `dividerColor` | The color of the dividers. Transparent by default. |
| `dividerHitSize` | The size of the area a divider can be dragged by. Never smaller than `dividerThickness`. |
| `initialProportions` | The initial share of the space for each pane. The length must match the number of children. |
| `initialSizes` | The initial size of each pane in pixels. The length must match the number of children. Cannot be combined with `initialProportions`. |
| `draggable` | Whether the dividers can be dragged. |
| `alignment` | Alignment of each child within its pane. |
| `minChildSize` | The minimum size a pane can shrink to. |
| `onSizesChanged` | Called while a divider is dragged, with the size of every pane in pixels. |

### Behavior

- **Sizes are proportions.** `initialSizes` that do not add up to the available space are scaled to fill it, and panes
  keep their proportions when the parent is resized.
- **The minimum yields when it cannot fit.** If the space is smaller than `minChildSize` times the number of panes, the
  panes share it equally.
- **The drag area lies over the panes.** It is `dividerHitSize` wide, centered on the divider, and takes no space in
  the layout. A drag that starts there moves the divider, and a tap still reaches the pane under it.
- **A child gets the constraints of its pane.** A child larger than its pane is shrunk to fit. To keep its size and
  clip it instead, wrap it in `ClipRect` and `OverflowBox`, or make it scrollable.
- **Panes are not rebuilt while dragging.** The builders run when `ResizableColumns` itself is rebuilt or when
  something a pane depends on changes.
- **Initial values are read once.** A later change of `initialSizes` or `initialProportions` does not move the panes.
- **Changing the number of children** resets the sizes to the initial ones.
- **An unbounded parent needs `initialSizes`.** Inside a scroll view along the orientation there is no space to share,
  so the sizes are taken from `initialSizes` as they are.

### ResizableOrientation

```dart
enum ResizableOrientation {
  vertical,
  horizontal,
}
```

## Example

The [example](https://github.com/SERDUN/resizable_columns/tree/master/example) app shows four columns with different
content: a fixed-size box, a nested vertical layout with scrolling lists, a fixed-width list, and a child larger than
its pane. Run it in Chrome:

```sh
cd example
flutter run -d chrome
```

## Contributing

Contributions are welcome! If you encounter any issues or have suggestions for improvements, please open an issue or
submit a pull request on [GitHub](https://github.com/SERDUN/resizable_columns).

## License

This project is licensed under the MIT License - see
the [LICENSE](https://github.com/SERDUN/resizable_columns/blob/master/LICENSE) file for details.
