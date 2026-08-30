import 'package:flutter/material.dart';

import '../data.dart';
import 'history_page.dart';
import 'playlists_page.dart';
import 'blacklist_page.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../theme.dart';

class MorePage extends StatefulWidget {
  final AppState app;
  const MorePage({super.key, required this.app});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  AppState get app => widget.app;
  bool _randomLoading = false;

  Future<void> _openRandomWork() async {
    if (_randomLoading) return;
    setState(() => _randomLoading = true);
    try {
      final work = await ApiService.fetchRandomWork(app);
      if (!mounted) return;
      if (work == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前条件下没有可播放的作品')));
        return;
      }
      Navigator.of(context).push(buildWorkRoute(app, work));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('随心听加载失败，请稍后重试')));
    } finally {
      if (mounted) setState(() => _randomLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final p = Theme.of(context).brightness == Brightness.dark
            ? AppColors.dark
            : AppColors.light;
        final server = app.customServer
            ? (app.customSites.isNotEmpty
                  ? app.customSites[app.customServerIdx].alias
                  : '自建')
            : 'asmr.one';
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
          children: [
            const Text(
              '更多',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kikoeta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '服务器：$server',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(context, [
              _row(
                context,
                Icons.history,
                '播放历史',
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HistoryPage(app: app)),
                ),
              ),
              _row(
                context,
                Icons.queue_music,
                '歌单',
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlaylistsPage(app: app)),
                ),
              ),
              _row(
                context,
                Icons.block_outlined,
                '黑名单',
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BlacklistPage(app: app)),
                ),
              ),
              _row(
                context,
                Icons.shuffle,
                '随心听',
                null,
                onTap: _openRandomWork,
                trailing: _randomLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.accent,
                        ),
                      )
                    : null,
              ),
              _row(
                context,
                Icons.settings_outlined,
                '设置',
                null,
                onTap: () => Navigator.of(context).pushNamed('/settings'),
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context, List<Widget> rows) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String? value, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: p.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value != null)
              Text(value, style: TextStyle(fontSize: 12, color: p.dim))
            else if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_right, size: 18, color: p.dim),
          ],
        ),
      ),
    );
  }
}
