import 'package:flutter/material.dart';

import '../data.dart';
import 'history_page.dart';
import 'playlists_page.dart';
import 'blacklist_page.dart';
import '../theme.dart';

class MorePage extends StatelessWidget {
  final AppState app;
  const MorePage({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
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
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => HistoryPage(app: app))),
          ),
          _row(
            context,
            Icons.queue_music,
            '播放列表',
            null,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PlaylistsPage(app: app))),
          ),
          _row(
            context,
            Icons.block_outlined,
            '黑名单',
            null,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => BlacklistPage(app: app))),
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
            else
              Icon(Icons.chevron_right, size: 18, color: p.dim),
          ],
        ),
      ),
    );
  }
}
