## 0.1.0

- Added `onSizesChanged` to report the pane sizes while a divider is dragged, so a layout can be saved and restored
  through `initialSizes`.
- Added `dividerHitSize`. A divider can now be dragged by a 12 px area centered on it, which lies over the edges of
  the panes and does not change the layout. Before, only the divider itself could be dragged.
- Panes are no longer rebuilt while a divider is dragged or when the parent is resized.
- Panes keep their proportions when the parent is resized, including after it shrinks and grows back.
- Fixed `minChildSize` being broken when the parent shrinks.
- Fixed a crash when a child is added and a gap when one is removed. Changing the number of children now resets the
  sizes to the initial ones.
- Fixed the divider moving against the pointer in right-to-left layouts.
- Fixed the divider drifting away from the pointer after it passed the minimum size of a pane.
- Fixed a crash when `initialProportions` add up to zero.
- Fixed a crash in an unbounded parent. `initialSizes` are used as they are there, and an assert asks for them when
  they are missing.
- `alignment` now sets the cross-axis alignment in both orientations.
- A single child is allowed and fills the space.
- **Breaking in debug builds:** `initialSizes` must have one entry per child and cannot be combined with
  `initialProportions`.
- Requires Flutter 3.24 or later.
- Documented the public API and rewrote the README.
- Added tests.

## 0.0.2

- Added `dividerColor` to change the color of the divider.

## 0.0.1

- Initial release.
