import 'dart:async';
import 'dart:collection';

import 'api_service.dart';

/// Keeps up to two fetched pages ahead of the last page shown by the caller.
/// A demand request can share an in-flight prefetch for the same page.
class WorksPageBuffer {
  WorksPageBuffer(this._load, {this._nextPage = 1});

  final Future<WorksPage> Function(int page) _load;
  final Queue<WorksPage> _ready = Queue();
  int _nextPage;
  bool _hasMore = true;
  bool _closed = false;
  bool _prefetching = false;
  Future<void>? _pending;

  bool get hasReadyPage => _ready.isNotEmpty;

  Future<WorksPage?> takeNext() async {
    if (_closed) return null;
    if (_ready.isEmpty && _hasMore) await _fetchNext();
    return _ready.isEmpty ? null : _ready.removeFirst();
  }

  Future<void> prefetch() async {
    if (_prefetching || _closed) return;
    _prefetching = true;
    try {
      while (!_closed && _hasMore && _ready.length < 2) {
        await _fetchNext();
      }
    } catch (_) {
      // Leave the cursor on the failed page. The next demand can retry it.
    } finally {
      _prefetching = false;
    }
  }

  Future<void> _fetchNext() => _pending ??= _fetch();

  Future<void> _fetch() async {
    try {
      final page = await Future.sync(() => _load(_nextPage));
      if (_closed) return;
      _ready.addLast(page);
      _nextPage++;
      _hasMore = page.hasMore;
    } finally {
      _pending = null;
    }
  }

  void close() {
    _closed = true;
    _ready.clear();
  }
}
