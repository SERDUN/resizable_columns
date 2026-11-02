import 'package:flutter/foundation.dart';

/// Collapses and expands the panes of a `ResizableColumns`.
///
/// A collapsed pane shrinks to its entry in `ResizableColumns.collapsedSizes`
/// and gives the rest of its space to the panes that stay expanded. When it is
/// expanded again it gets back the size it had before.
///
/// ```dart
/// final controller = ResizableColumnsController(collapsed: {2});
///
/// // In a toolbar button:
/// controller.toggle(2);
/// ```
///
/// The controller knows indexes, not panes, so the same one can be kept while
/// the panes change. An index with no pane behind it is ignored by the layout.
class ResizableColumnsController extends ChangeNotifier {
  /// Creates a controller with the panes at the [collapsed] indexes collapsed.
  ResizableColumnsController({Iterable<int> collapsed = const []}) : _collapsed = {...collapsed} {
    assert(_collapsed.every((index) => index >= 0), 'Pane indexes cannot be negative');
  }

  final Set<int> _collapsed;

  /// The indexes of the collapsed panes.
  Set<int> get collapsed => Set<int>.unmodifiable(_collapsed);

  /// Whether the pane at [index] is collapsed.
  bool isCollapsed(int index) => _collapsed.contains(index);

  /// Collapses the pane at [index].
  void collapse(int index) => setCollapsed(index, true);

  /// Expands the pane at [index] to the size it had before it was collapsed.
  void expand(int index) => setCollapsed(index, false);

  /// Collapses the pane at [index] if it is expanded, and expands it otherwise.
  void toggle(int index) => setCollapsed(index, !isCollapsed(index));

  /// Collapses or expands the pane at [index]. Listeners are notified only
  /// when this changes something.
  void setCollapsed(int index, bool collapsed) {
    assert(index >= 0, 'Pane indexes cannot be negative');
    final changed = collapsed ? _collapsed.add(index) : _collapsed.remove(index);
    if (changed) notifyListeners();
  }
}
