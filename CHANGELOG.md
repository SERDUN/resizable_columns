## 0.2.1

- The README opens with what the widget is for and lists its features; the installation snippet names 0.2.0.
- Topics on pub.dev: layout, split-view, resizable, panels, desktop.

## 0.2.0

### Added

- Collapsible panes. A `ResizableColumnsController` collapses a pane and expands it again; `collapsedSizes` sets how
  much space each one keeps while collapsed, from nothing to a rail. The other panes share the space a collapsed pane
  leaves in their proportions. An expanded pane gets back exactly the size it had, the others shrinking in proportion;
  when that does not fit, it gets what is left once the others are at `minChildSize`.
- The builders run again when the set of collapsed panes changes, so a pane can draw itself differently while
  collapsed.
- Between two expanded panes one divider stays draggable across collapsed panes and resizes the two; the other
  dividers next to a collapsed pane take no drag. Drags, push mode included, move only expanded panes.
- `onSizesChanged` reports a collapsed pane with the size it returns to, so `initialSizes` and the controller restore
  a layout with collapsed panes.

## 0.1.0

### Added

- `onSizesChanged` reports the size of every pane while a divider is dragged, so a layout can be saved and restored
  through `initialSizes`.
- `dragMode` with `ResizableDragMode.push`: a divider goes past a pane that is at its minimum size and shrinks the
  panes further along. Dragging back within the same gesture gives them their space again. The default,
  `ResizableDragMode.adjacent`, is the previous behavior.
- `dividerHitSize`: a divider can be dragged by a 12 px area centered on it. The area lies over the edges of the panes
  and does not change the layout, and a tap inside it still reaches the pane. Before, only the divider itself could be
  dragged, which also means a divider with a thickness of 0 can now be dragged.
- Doc comments for the whole public API.
- Tests.
- The example runs on the web out of the box and shows fixed, scrolling, nested and oversized content.

### Changed

- **Breaking in debug builds:** `initialSizes` must have one entry per child and cannot be combined with
  `initialProportions`. Both are asserts; in release an `initialSizes` list of the wrong length gives an equal split.
- Panes keep their proportions when the parent is resized, including after it shrinks and grows back.
- Panes are no longer rebuilt while a divider is dragged or when the parent is resized. The builders run when the
  widget itself is rebuilt or when something a pane depends on changes.
- Changing the number of children resets the sizes to the initial ones.
- `alignment` sets the cross-axis alignment in both orientations.
- A single child is allowed and fills the space.
- With `draggable: false` the dividers no longer change the mouse cursor.
- Requires Flutter 3.24 or later.
- The README is rewritten for the current API.

### Fixed

- `minChildSize` was broken when the parent shrank.
- Adding a child crashed, and removing one left a gap.
- The divider moved against the pointer in right-to-left layouts.
- The divider drifted away from the pointer after it passed the minimum size of a pane.
- `initialProportions` that add up to zero crashed the layout.
- An unbounded parent crashed the layout. `initialSizes` are used there as they are, and an assert asks for them when
  they are missing.

## 0.0.2

- Added `dividerColor` to change the color of the divider.

## 0.0.1

- Initial release.
