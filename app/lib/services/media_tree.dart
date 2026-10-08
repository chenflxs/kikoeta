import '../data.dart';

/// A single preorder row, with subtree bounds for iteration and lazy rendering.
class MediaTreeRow {
  final MediaNode node;
  final int depth;
  final List<MediaNode> siblings;
  final bool isLast;
  final int index;
  final int? parentIndex;
  final int subtreeEnd;
  final int fileStart;
  final int fileEnd;

  const MediaTreeRow({
    required this.node,
    required this.depth,
    required this.siblings,
    required this.isLast,
    required this.index,
    required this.parentIndex,
    required this.subtreeEnd,
    required this.fileStart,
    required this.fileEnd,
  });
}

/// Index once for each tree snapshot; queries reuse its flattened nodes.
class MediaTreeIndex {
  final List<MediaNode> roots;
  late final List<MediaTreeRow> rows;
  late final List<MediaNode> files;
  late final Map<String, MediaTreeRow> byPath;

  MediaTreeIndex(this.roots) {
    final building = <_MediaRowBuilder>[];
    final leaves = <MediaNode>[];
    final stack = <_MediaVisit>[];
    void push(List<MediaNode> nodes, int depth, int? parent) {
      for (var i = nodes.length - 1; i >= 0; i--) {
        stack.add(_MediaVisit(nodes[i], nodes, i, depth, parent));
      }
    }

    push(roots, 0, null);
    while (stack.isNotEmpty) {
      final visit = stack.removeLast();
      if (visit.exitIndex != null) {
        final row = building[visit.exitIndex!];
        row.subtreeEnd = building.length;
        row.fileEnd = leaves.length;
        continue;
      }
      final index = building.length;
      final row = _MediaRowBuilder(visit, index, leaves.length);
      building.add(row);
      if (visit.node!.isDir) {
        stack.add(_MediaVisit.exit(index));
        push(visit.node!.children, visit.depth + 1, index);
      } else {
        leaves.add(visit.node!);
        row.subtreeEnd = index + 1;
        row.fileEnd = leaves.length;
      }
    }
    rows = List.unmodifiable(building.map((row) => row.finish()));
    files = List.unmodifiable(leaves);
    byPath = Map.unmodifiable({for (final row in rows) row.node.path: row});
  }

  List<MediaTreeRow> visibleRows(Set<String> expanded) {
    final visible = <MediaTreeRow>[];
    var index = 0;
    while (index < rows.length) {
      final row = rows[index];
      visible.add(row);
      index = row.node.isDir && !expanded.contains(row.node.path)
          ? row.subtreeEnd
          : index + 1;
    }
    return List.unmodifiable(visible);
  }

  List<MediaNode> filesAtPaths(Set<String> selectedPaths) {
    if (selectedPaths.isEmpty) return const [];
    if (selectedPaths.contains('')) return files;
    return List.unmodifiable(
      files.where((node) => mediaPathIsSelected(selectedPaths, node.path)),
    );
  }
}

/// Root selection is represented by ''. Exact paths and directory prefixes
/// retain the persisted selection contract without scanning every selection.
bool mediaPathIsSelected(Set<String> selectedPaths, String path) {
  if (selectedPaths.contains('')) return true;
  var current = path;
  while (true) {
    if (selectedPaths.contains(current)) return true;
    final separator = current.lastIndexOf('/');
    if (separator < 0) return false;
    current = current.substring(0, separator);
  }
}

class _MediaVisit {
  final MediaNode? node;
  final List<MediaNode> siblings;
  final int siblingIndex;
  final int depth;
  final int? parentIndex;
  final int? exitIndex;
  _MediaVisit(
    this.node,
    this.siblings,
    this.siblingIndex,
    this.depth,
    this.parentIndex,
  ) : exitIndex = null;
  _MediaVisit.exit(int index)
    : node = null,
      siblings = const [],
      siblingIndex = 0,
      depth = 0,
      parentIndex = null,
      exitIndex = index;
}

class _MediaRowBuilder {
  final _MediaVisit visit;
  final int index;
  final int fileStart;
  int subtreeEnd = 0;
  int fileEnd = 0;
  _MediaRowBuilder(this.visit, this.index, this.fileStart);
  MediaTreeRow finish() => MediaTreeRow(
    node: visit.node!,
    depth: visit.depth,
    siblings: visit.siblings,
    isLast: visit.siblingIndex == visit.siblings.length - 1,
    index: index,
    parentIndex: visit.parentIndex,
    subtreeEnd: subtreeEnd,
    fileStart: fileStart,
    fileEnd: fileEnd,
  );
}
