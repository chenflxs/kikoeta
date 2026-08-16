import 'package:flutter/material.dart';

import '../data.dart';
import '../routes.dart';
import '../theme.dart';
import '../widgets.dart';

class HistoryPage extends StatelessWidget {
  final AppState app;
  const HistoryPage({super.key, required this.app});

  Work _entryWork(Map<String, dynamic> e) => Work(
    rj: e['rj'] as String? ?? '',
    title: e['title'] as String? ?? '未知作品',
    circle: e['circle'] as String? ?? '',
    va: '',
    age: Age.all,
    dur: '',
    tags: List<String>.from((e['tags'] as List?) ?? const []),
    grayTags: List<String>.from((e['grayTags'] as List?) ?? const []),
    grad: 0,
    coverUrl: e['coverUrl'] as String?,
  );

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    final list = app.playHistory;
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史'),
        leading: const BackButton(),
        actions: [
          if (list.isNotEmpty)
            TextButton(
              onPressed: () {
                app.clearPlayHistory();
              },
              child: Text(
                '清空',
                style: TextStyle(fontSize: 13, color: p.accent),
              ),
            ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Text(
                '暂无播放历史',
                style: TextStyle(fontSize: 13, color: p.dim),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final e = list[i];
                final rj = e['rj'] as String? ?? '';
                final title = e['title'] as String? ?? '';
                final circle = e['circle'] as String? ?? '';
                final at = e['at'] as int? ?? 0;
                final w = _entryWork(e);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Work? found;
                    for (final x in app.remoteWorks) {
                      if (x.rj == rj) {
                        found = x;
                        break;
                      }
                    }
                    if (found == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            '该作品不在当前列表，请先在首页加载',
                            style: TextStyle(fontSize: 12.5, color: p.text),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: p.toast,
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).push(buildWorkRoute(app, found));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: CoverArt(
                            work: w,
                            radius: 10,
                            showBadges: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$rj · $circle · ${_fmtTime(at)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: p.dim),
                              ),
                              if (w.tags.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: w.tags
                                      .map(
                                        (t) => _tagChip(
                                          ctx,
                                          t,
                                          gray: w.grayTags.contains(t),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: p.dim,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _tagChip(BuildContext context, String t, {required bool gray}) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: gray ? p.dim : p.line),
      ),
      child: Text(
        t,
        style: TextStyle(
          fontSize: 9.5,
          color: gray ? p.dim : p.muted,
          fontStyle: gray ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  String _fmtTime(int ms) {
    if (ms <= 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    if (sameDay) {
      return '今天 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}月${t.day}日 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
