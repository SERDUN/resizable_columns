import 'dart:math' as math;

/// Turns [weights] into pane sizes that add up to [available].
///
/// The panes share the space in proportion to their weights. A pane that would
/// end up smaller than [minSize] is pinned to it and the rest share what is
/// left. When the space cannot hold every pane at [minSize], it is split
/// equally instead.
///
/// With an unbounded [available] there is nothing to share, so the weights are
/// taken as sizes and only raised to [minSize].
List<double> fitPaneSizes(
  List<double> weights, {
  required double available,
  required double minSize,
}) {
  final count = weights.length;
  if (count == 0) return const [];

  if (available.isInfinite) {
    return [for (final weight in weights) math.max(_sanitize(weight), minSize)];
  }
  if (available <= 0) return List<double>.filled(count, 0.0);
  if (available <= minSize * count) return List<double>.filled(count, available / count);

  final sizes = List<double>.filled(count, 0.0);
  final free = [for (int i = 0; i < count; i++) i];
  double remaining = available;

  while (free.isNotEmpty) {
    final total = free.fold(0.0, (sum, i) => sum + _sanitize(weights[i]));
    final equalShare = remaining / free.length;
    double share(int i) => total > 0 ? _sanitize(weights[i]) / total * remaining : equalShare;

    final pinned = free.where((i) => share(i) < minSize).toList();
    if (pinned.isEmpty) {
      for (final i in free) {
        sizes[i] = share(i);
      }
      break;
    }

    for (final i in pinned) {
      sizes[i] = minSize;
      free.remove(i);
    }
    remaining -= minSize * pinned.length;
  }

  return sizes;
}

/// Moves the divider after the pane at [index] by [delta]: the pane the
/// divider moves away from grows, and the space comes from the other side.
///
/// Without [push] only the pane next to the divider gives space, and the move
/// stops when that pane reaches [minSize]. With [push] the panes behind it
/// give space as well, one after another, each down to [minSize].
///
/// A pane that is already below [minSize] is not shrunk any further.
List<double> movePaneDivider(
  List<double> sizes, {
  required int index,
  required double delta,
  required double minSize,
  bool push = false,
}) {
  final moved = List<double>.of(sizes);
  final forward = delta > 0;
  final growing = forward ? index : index + 1;
  final last = push ? (forward ? sizes.length - 1 : 0) : (forward ? index + 1 : index);
  final step = forward ? 1 : -1;

  double remaining = delta.abs();
  for (int i = forward ? index + 1 : index; remaining > 0; i += step) {
    final taken = math.min(remaining, math.max(0.0, moved[i] - minSize));
    moved[i] -= taken;
    moved[growing] += taken;
    remaining -= taken;
    if (i == last) break;
  }

  return moved;
}

/// Lays out panes some of which are [collapsed].
///
/// A collapsed pane takes its entry in [collapsedSizes] (0 when there is none),
/// and the expanded panes share what is left as [fitPaneSizes] shares it. When
/// the collapsed sizes together exceed [available], they are scaled down to
/// fit and the expanded panes get nothing. Indexes in [collapsed] that have no
/// pane are ignored. With nothing collapsed this is [fitPaneSizes].
List<double> layoutPaneSizes(
  List<double> weights, {
  required double available,
  required double minSize,
  Set<int> collapsed = const {},
  List<double>? collapsedSizes,
}) {
  final count = weights.length;
  final folded = [
    for (int i = 0; i < count; i++)
      if (collapsed.contains(i)) i
  ];
  if (folded.isEmpty) return fitPaneSizes(weights, available: available, minSize: minSize);

  double collapsedSize(int i) {
    final size = collapsedSizes != null && i < collapsedSizes.length ? collapsedSizes[i] : 0.0;
    return size.isFinite && size > 0 ? size : 0.0;
  }

  final fixed = folded.fold(0.0, (sum, i) => sum + collapsedSize(i));
  final scale = available.isFinite && fixed > available ? (available > 0 ? available / fixed : 0.0) : 1.0;

  final sizes = List<double>.filled(count, 0.0);
  for (final i in folded) {
    sizes[i] = collapsedSize(i) * scale;
  }

  final expanded = [
    for (int i = 0; i < count; i++)
      if (!collapsed.contains(i)) i
  ];
  final rest = fitPaneSizes(
    [for (final i in expanded) weights[i]],
    available: available.isFinite ? math.max(0.0, available - fixed * scale) : available,
    minSize: minSize,
  );
  for (int k = 0; k < expanded.length; k++) {
    sizes[expanded[k]] = rest[k];
  }
  return sizes;
}

double _sanitize(double weight) => weight.isFinite && weight > 0 ? weight : 0.0;
