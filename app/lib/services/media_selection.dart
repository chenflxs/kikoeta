import '../data.dart';

/// Maintains checked states for a hierarchical media tree.
class MediaSelection {
  final Set<String> paths = {};

  /// Returns true, false, or null for a partially checked folder.
  bool? state(MediaNode node) {
    if (!node.isDir || node.children.isEmpty) {
      return paths.contains(node.path);
    }

    final childStates = node.children.map(state);
    if (childStates.every((value) => value == true)) return true;
    if (childStates.every((value) => value == false)) return false;
    return null;
  }

  /// Toggles a node and keeps all ancestor folder states consistent.
  void toggle(MediaNode node, Iterable<MediaNode> roots) {
    _setSubtree(node, state(node) != true);
    _syncFolders(roots);
  }

  void clear() => paths.clear();

  void _setSubtree(MediaNode node, bool selected) {
    if (selected) {
      paths.add(node.path);
    } else {
      paths.remove(node.path);
    }
    for (final child in node.children) {
      _setSubtree(child, selected);
    }
  }

  void _syncFolders(Iterable<MediaNode> nodes) {
    for (final node in nodes) {
      if (!node.isDir) continue;
      _syncFolders(node.children);
      if (node.children.isEmpty) continue;

      final childStates = node.children.map(state);
      if (childStates.every((value) => value == true)) {
        paths.add(node.path);
      } else {
        paths.remove(node.path);
      }
    }
  }
}
