/// What a dragged divider does once the pane next to it cannot shrink.
enum ResizableDragMode {
  /// Only the two panes next to the divider change. The divider stops when
  /// one of them reaches the minimum size.
  adjacent,

  /// The divider keeps going and takes the space from the panes further
  /// along, one after another, until each is at the minimum size. Dragging
  /// back gives them their space again.
  push,
}
