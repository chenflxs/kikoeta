import 'package:flutter/material.dart';

import '../data.dart';
import '../l10n/strings.dart';
import '../smooth_scroll.dart';
import '../theme.dart';

class PlaybackQueueSheet extends StatelessWidget {
  const PlaybackQueueSheet({
    super.key,
    required this.app,
    required this.onSelectTrack,
  });

  final AppState app;
  final ValueChanged<int> onSelectTrack;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final queue = app.queue;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.surface3,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                child: Row(
                  children: [
                    Icon(Icons.queue_music, size: 18, color: p.accent),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.playerPageShowQueueText2('${queue.length}'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: p.text,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: 18, color: p.dim),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.line),
              Expanded(
                child: queue.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.playerPageShowQueueText,
                          style: TextStyle(fontSize: 13, color: p.dim),
                        ),
                      )
                    : _buildQueue(queue, p),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQueue(List<MediaNode> queue, Palette p) {
    return SmoothCustomScrollView(
      key: ObjectKey(queue),
      semanticChildCount: queue.length,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          sliver: SliverReorderableList(
            itemCount: queue.length,
            proxyDecorator: (child, index, animation) =>
                Material(color: p.surface, elevation: 6, child: child),
            onReorderItem: (oldIndex, newIndex) {
              if (!identical(queue, app.queue)) return;
              app.reorderPlaybackTrack(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final node = queue[index];
              final current = index == app.trackIdx;
              return ReorderableDelayedDragStartListener(
                key: ObjectKey(node),
                index: index,
                enabled: queue.length > 1,
                child: InkWell(
                  onTap: current
                      ? null
                      : () {
                          if (!identical(queue, app.queue) ||
                              !identical(queue[index], node)) {
                            return;
                          }
                          onSelectTrack(index);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          current
                              ? Icons.graphic_eq
                              : Icons.music_note_outlined,
                          size: 18,
                          color: current ? p.accent : p.dim,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            node.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: current ? p.accent : p.text,
                              fontWeight: current
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (current)
                          Text(
                            context.l10n.playerPageTopBarText,
                            style: TextStyle(fontSize: 11, color: p.accent),
                          ),
                        if (queue.length > 1) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: context.l10n.playlistsPageRowMessage,
                            triggerMode: TooltipTriggerMode.manual,
                            child: Icon(
                              Icons.drag_indicator,
                              size: 15,
                              color: p.dim,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
