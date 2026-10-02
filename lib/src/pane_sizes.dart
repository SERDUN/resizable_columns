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

/// Moves the divider after the pane at [index] by [delta], taking the space
/// from one neighbour and giving it to the other.
///
/// The move stops where a neighbour would drop below [minSize]. A neighbour
/// that is already below it is not shrunk any further.
List<double> movePaneDivider(
  List<double> sizes, {
  required int index,
  required double delta,
  required double minSize,
}) {
  final lower = -math.max(0.0, sizes[index] - minSize);
  final upper = math.max(0.0, sizes[index + 1] - minSize);
  final applied = delta.clamp(lower, upper);

  return List<double>.of(sizes)
    ..[index] += applied
    ..[index + 1] -= applied;
}

double _sanitize(double weight) => weight.isFinite && weight > 0 ? weight : 0.0;
