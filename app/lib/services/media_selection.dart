import '../data.dart';
import 'media_tree.dart';

/// Maintains checked states without recursively reevaluating descendants.
class MediaSelection {
  final Set<String> paths = {};
  final Set<String> selectedProjects = {};
  MediaTreeIndex? _index;
  final Map<MediaNode, bool?> _alternateStates = {};
  List<int> _leafCounts = const [];
  List<int> _selectedCounts = const [];

  /// Complete selected subtrees, without duplicate descendants.
  Set<String> get projects => Set.unmodifiable(selectedProjects);

  /// Reconcile cached states when a newly loaded tree replaces the old tree.
  void bindTree(List<MediaNode> roots) {
    if (identical(_index?.roots, roots)) return;
    final index = MediaTreeIndex(roots);
    _index = index;
    _alternateStates.clear();
    _leafCounts = List.filled(index.rows.length, 0);
    _selectedCounts = List.filled(index.rows.length, 0);
    for (var i = index.rows.length - 1; i >= 0; i--) {
      final row = index.rows[i];
      if (!row.node.isDir || row.node.children.isEmpty) {
        _leafCounts[i] = 1;
        _selectedCounts[i] = paths.contains(row.node.path) ? 1 : 0;
      }
      final parent = row.parentIndex;
      if (parent != null) {
        _leafCounts[parent] += _leafCounts[i];
        _selectedCounts[parent] += _selectedCounts[i];
      }
    }
    for (final row in index.rows) {
      if (!row.node.isDir || row.node.children.isEmpty) continue;
      _syncFolderPath(row.index);
    }
    _rebuildProjects();
  }

  /// Returns true, false, or null for a partially checked folder.
  bool? state(MediaNode node) {
    final row = _index?.byPath[node.path];
    if (row != null && identical(row.node, node)) return _stateAt(row.index);
    if (!node.isDir || node.children.isEmpty) return paths.contains(node.path);
    if (_alternateStates.containsKey(node)) return _alternateStates[node];
    // A filtered folder has its own visible descendants. Cache their states in
    // one postorder pass so sibling checkboxes do not rescan its subtree.
    final subtree = MediaTreeIndex([node]);
    final totals = List<int>.filled(subtree.rows.length, 0);
    final selected = List<int>.filled(subtree.rows.length, 0);
    for (var i = subtree.rows.length - 1; i >= 0; i--) {
      final current = subtree.rows[i];
      if (!current.node.isDir || current.node.children.isEmpty) {
        totals[i] = 1;
        selected[i] = paths.contains(current.node.path) ? 1 : 0;
      }
      _alternateStates[current.node] = selected[i] == totals[i]
          ? true
          : (selected[i] == 0 ? false : null);
      final parent = current.parentIndex;
      if (parent != null) {
        totals[parent] += totals[i];
        selected[parent] += selected[i];
      }
    }
    return _alternateStates[node];
  }

  bool? _stateAt(int index) {
    final selected = _selectedCounts[index];
    return selected == _leafCounts[index]
        ? true
        : (selected == 0 ? false : null);
  }

  /// Touch the selected subtree once and update only its ancestor counts.
  void toggle(MediaNode node, Iterable<MediaNode> roots) {
    bindTree(roots is List<MediaNode> ? roots : roots.toList());
    final index = _index!;
    final row = index.byPath[node.path];
    if (row == null) return;
    final select = state(node) != true;
    _alternateStates.clear();
    if (!identical(row.node, node)) {
      _toggleFiltered(node, select);
      _rebuildProjects();
      return;
    }
    final previousCount = _selectedCounts[row.index];
    for (var i = row.index; i < row.subtreeEnd; i++) {
      final path = index.rows[i].node.path;
      select ? paths.add(path) : paths.remove(path);
      _selectedCounts[i] = select ? _leafCounts[i] : 0;
    }
    final delta = _selectedCounts[row.index] - previousCount;
    var parent = row.parentIndex;
    while (parent != null) {
      _selectedCounts[parent] += delta;
      _syncFolderPath(parent);
      parent = index.rows[parent].parentIndex;
    }
    _rebuildProjects();
  }

  void _toggleFiltered(MediaNode node, bool select) {
    final index = _index!;
    final deltas = <int, int>{};
    for (final visible in MediaTreeIndex([node]).rows) {
      if (visible.node.isDir && visible.node.children.isNotEmpty) continue;
      final row = index.byPath[visible.node.path];
      if (row == null) continue;
      final next = select ? _leafCounts[row.index] : 0;
      deltas[row.index] = next - _selectedCounts[row.index];
      select ? paths.add(row.node.path) : paths.remove(row.node.path);
    }
    // Aggregate once in postorder: deep folders with many visible leaves must
    // not update the same ancestor separately for every selected file.
    for (var i = index.rows.length - 1; i >= 0; i--) {
      final delta = deltas[i] ?? 0;
      if (delta == 0) continue;
      _selectedCounts[i] += delta;
      final row = index.rows[i];
      if (row.node.isDir && row.node.children.isNotEmpty) _syncFolderPath(i);
      final parent = row.parentIndex;
      if (parent != null) {
        deltas.update(parent, (value) => value + delta, ifAbsent: () => delta);
      }
    }
  }

  void _syncFolderPath(int index) {
    final path = _index!.rows[index].node.path;
    if (_stateAt(index) == true) {
      paths.add(path);
    } else {
      paths.remove(path);
    }
  }

  void _rebuildProjects() {
    selectedProjects.clear();
    final rows = _index!.rows;
    for (var i = 0; i < rows.length;) {
      final state = _stateAt(i);
      if (state == true) selectedProjects.add(rows[i].node.path);
      i = state == null ? i + 1 : rows[i].subtreeEnd;
    }
  }

  void clear() {
    _alternateStates.clear();
    paths.clear();
    selectedProjects.clear();
    _selectedCounts = List.filled(_selectedCounts.length, 0);
  }
}
