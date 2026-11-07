import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/dictation_queue.dart';
import '../smooth_scroll.dart';
import '../theme.dart';

class DictationQueueList extends StatefulWidget {
  final DictationQueue queue;
  final ValueChanged<DictationQueueEntry> onDelete;
  final ValueChanged<DictationQueueEntry>? onJump;
  final ValueChanged<DictationQueueEntry>? onRetry;
  final ValueChanged<DictationQueueEntry>? onRetryWriteback;

  const DictationQueueList({
    super.key,
    required this.queue,
    required this.onDelete,
    this.onJump,
    this.onRetry,
    this.onRetryWriteback,
  });

  @override
  State<DictationQueueList> createState() => _DictationQueueListState();
}

class _DictationQueueListState extends State<DictationQueueList> {
  final _reorderKey = GlobalKey<SliverReorderableListState>();
  late int _pendingRevision;
  DictationQueue get queue => widget.queue;

  @override
  void initState() {
    super.initState();
    _pendingRevision = queue.pendingRevision;
  }

  @override
  void didUpdateWidget(covariant DictationQueueList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue != queue || _pendingRevision != queue.pendingRevision) {
      // Flutter requires cancelling an active drag before changing its items.
      // Progress/log updates leave the drag alone.
      _reorderKey.currentState?.cancelReorder();
      _pendingRevision = queue.pendingRevision;
    }
  }

  Future<void> _showActions(
    BuildContext context,
    DictationQueueEntry entry,
  ) async {
    final l10n = context.l10n;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surface,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 480),
        scrollable: true,
        title: Text(l10n.dictationQueueActions(entry.label)),
        content: Text(
          entry.work.title,
          style: TextStyle(fontSize: 13.5, color: p.text, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: widget.onJump != null && queue.canJump(entry)
                ? () => Navigator.pop(dialogContext, 'jump')
                : null,
            child: Text(l10n.dictationQueueJump),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'delete'),
            child: Text(l10n.delete, style: TextStyle(color: p.red)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'delete') widget.onDelete(entry);
    if (action == 'jump') widget.onJump?.call(entry);
  }

  String _status(BuildContext context, DictationQueueStatus status) =>
      switch (status) {
        DictationQueueStatus.pending => context.l10n.dictationQueuePending,
        DictationQueueStatus.running => context.l10n.dictationQueueRunning,
        DictationQueueStatus.completed => context.l10n.dictationQueueCompleted,
        DictationQueueStatus.failed => context.l10n.dictationQueueFailed,
        DictationQueueStatus.cancelled => context.l10n.dictationQueueCancelled,
      };

  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  Color _statusColor(DictationQueueStatus status) => switch (status) {
    DictationQueueStatus.pending => p.muted,
    DictationQueueStatus.running => p.accent,
    DictationQueueStatus.completed => p.green,
    DictationQueueStatus.failed => p.red,
    DictationQueueStatus.cancelled => p.dim,
  };

  Widget _track(DictationQueueEntry entry, int index) {
    final track = entry.tracks[index];
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      minLeadingWidth: 24,
      horizontalTitleGap: 10,
      leading: Icon(Icons.audio_file_outlined, color: p.dim, size: 17),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: kAppFontFamily,
          color: p.text,
          fontSize: 12.5,
        ),
      ),
      subtitle: track.path == track.title
          ? null
          : Text(
              track.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kAppFontFamily,
                color: p.dim,
                fontSize: 11,
              ),
            ),
    );
  }

  Widget _tracks(BuildContext context, DictationQueueEntry entry) {
    if (queue.entries.length == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 230),
        child: SmoothListView.builder(
          key: PageStorageKey('dictation-tracks-${entry.label}'),
          primary: false,
          shrinkWrap: true,
          itemCount: entry.tracks.length,
          itemBuilder: (_, index) => _track(entry, index),
        ),
      );
    }
    // The queue owns scrolling for expanded batches. Build these rows only
    // when ExpansionTile mounts its children, without a second viewport/bar.
    return Builder(
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < entry.tracks.length; index++)
            _track(entry, index),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    DictationQueueEntry entry, {
    int? dragIndex,
  }) {
    final color = _statusColor(entry.status);
    final active = entry.status == DictationQueueStatus.running;
    final single = queue.entries.length == 1;
    final title = Row(
      children: [
        Expanded(
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kAppFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _status(context, entry.status),
            style: TextStyle(
              fontFamily: kAppFontFamily,
              fontSize: 10.5,
              color: color,
            ),
          ),
        ),
        if (entry.status == DictationQueueStatus.completed &&
            entry.pendingWritebackPaths.isNotEmpty)
          TextButton(
            onPressed:
                entry.retryingWriteback || widget.onRetryWriteback == null
                ? null
                : () => widget.onRetryWriteback!(entry),
            style: TextButton.styleFrom(
              foregroundColor: p.muted,
              textStyle: const TextStyle(
                fontFamily: kAppFontFamily,
                fontSize: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text(context.l10n.writebackRetry),
          ),
        if (entry.status == DictationQueueStatus.failed)
          TextButton(
            onPressed: widget.onRetry == null
                ? null
                : () => widget.onRetry!(entry),
            style: TextButton.styleFrom(
              foregroundColor: p.muted,
              textStyle: const TextStyle(
                fontFamily: kAppFontFamily,
                fontSize: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: Text(context.l10n.retry),
          ),
      ],
    );
    final subtitle = Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              entry.work.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kAppFontFamily,
                color: p.muted,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.dictationQueueTracks(entry.tracks.length.toString()),
            style: TextStyle(
              fontFamily: kAppFontFamily,
              color: p.dim,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
    final leading = dragIndex != null
        ? ReorderableDragStartListener(
            index: dragIndex,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Semantics(
                label: context.l10n.dictationQueueDrag,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                  child: Icon(Icons.drag_handle, color: p.dim, size: 20),
                ),
              ),
            ),
          )
        : Icon(
            switch (entry.status) {
              DictationQueueStatus.completed => Icons.check_circle_outline,
              DictationQueueStatus.failed => Icons.error_outline,
              DictationQueueStatus.cancelled => Icons.stop_circle_outlined,
              _ => Icons.graphic_eq,
            },
            color: color,
            size: 20,
          );
    final body = single
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                dense: true,
                minTileHeight: 72,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: leading,
                title: title,
                subtitle: subtitle,
                onLongPress: () => _showActions(context, entry),
              ),
              Divider(height: 1, indent: 12, endIndent: 12, color: p.line),
              _tracks(context, entry),
            ],
          )
        : GestureDetector(
            onLongPress: () => _showActions(context, entry),
            child: ExpansionTile(
              key: PageStorageKey(entry),
              dense: true,
              minTileHeight: 72,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 3,
              ),
              childrenPadding: const EdgeInsets.only(bottom: 6),
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: p.muted,
              collapsedIconColor: p.dim,
              leading: leading,
              title: title,
              subtitle: subtitle,
              children: [
                Divider(height: 1, indent: 12, endIndent: 12, color: p.line),
                _tracks(context, entry),
              ],
            ),
          );
    return Padding(
      key: ObjectKey(entry),
      padding: EdgeInsets.only(bottom: single ? 0 : 8),
      child: Material(
        color: active ? p.accent.withValues(alpha: 0.06) : p.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: active ? p.accent.withValues(alpha: 0.35) : p.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme(
          data: const ListTileThemeData(
            horizontalTitleGap: 10,
            minLeadingWidth: 32,
          ),
          child: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (queue.entries.length == 1) return _entry(context, queue.entries.single);
    final pending = queue.entries
        .where((e) => e.status == DictationQueueStatus.pending)
        .toList();
    final started = queue.entries
        .where((e) => e.status != DictationQueueStatus.pending)
        .toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: SmoothCustomScrollView(
        primary: false,
        // Small queues size to their contents; larger queues keep a lazy viewport.
        shrinkWrap: queue.entries.length <= 3,
        slivers: [
          SliverReorderableList(
            key: _reorderKey,
            itemCount: pending.length,
            itemBuilder: (context, index) =>
                _entry(context, pending[index], dragIndex: index),
            onReorderItem: (oldIndex, newIndex) =>
                queue.reorder(pending[oldIndex], pending[newIndex]),
          ),
          SliverList.builder(
            itemCount: started.length,
            itemBuilder: (context, index) => _entry(context, started[index]),
          ),
        ],
      ),
    );
  }
}
