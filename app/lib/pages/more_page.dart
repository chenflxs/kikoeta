import 'package:flutter/material.dart';

import '../data.dart';
import 'history_page.dart';
import 'playlists_page.dart';
import 'blacklist_page.dart';
import 'downloads_page.dart';
import 'lyrics_library_page.dart';
import 'dictation_translation_page.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../smooth_scroll.dart';
import '../theme.dart';
import '../l10n/strings.dart';

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
    final l10n = context.l10n;
    if (_randomLoading) return;
    setState(() => _randomLoading = true);
    try {
      final work = await ApiService.fetchRandomWork(app);
      if (!mounted) return;
      if (work == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.morePageOpenRandomWorkText)),
        );
        return;
      }
      Navigator.of(context).push(buildWorkRoute(app, work));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.morePageOpenRandomWorkText2)));
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
        final server = app.isDlsite
            ? 'DLsite Play'
            : app.customServer
            ? (app.customSites.isNotEmpty
                  ? app.customSites[app.customServerIdx].alias
                  : context.l10n.homePageServerLabelText)
            : 'asmr.one';
        return SmoothListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
          children: [
            Text(
              context.l10n.more,
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
                          context.l10n.morePageBuildText((server).toString()),
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
                context.l10n.playHistory,
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HistoryPage(app: app)),
                ),
              ),
              _row(
                context,
                Icons.queue_music,
                context.l10n.morePageBuildRow,
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PlaylistsPage(app: app)),
                ),
              ),
              _row(
                context,
                Icons.block_outlined,
                context.l10n.blacklist,
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BlacklistPage(app: app)),
                ),
              ),
              _row(
                context,
                Icons.shuffle,
                context.l10n.morePageBuildRow2,
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
                Icons.download_outlined,
                context.l10n.downloads,
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DownloadPage(app: app)),
                ),
              ),
              _row(
                context,
                Icons.lyrics_outlined,
                context.l10n.lyricsLibrary,
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LyricsLibraryPage()),
                ),
              ),
              _row(
                context,
                Icons.graphic_eq,
                context.l10n.dictationTranslationPageBuildText,
                null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DictationTranslationPage(app: app),
                  ),
                ),
              ),
              _row(
                context,
                Icons.settings_outlined,
                context.l10n.settings,
                null,
                showBottomBorder: false,
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      // 卡片内的悬停高亮由最近的 Material 绘制；卡片自带墨水层才能被自己的圆角裁剪，
      // 否则画到页面级 Material 上，鼠标划过时圆角缺口处会漏出方形灰影
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: rows),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String? value, {
    VoidCallback? onTap,
    Widget? trailing,
    bool showBottomBorder = true,
  }) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: showBottomBorder
              ? Border(bottom: BorderSide(color: p.line))
              : null,
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
