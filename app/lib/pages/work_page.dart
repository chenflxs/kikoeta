import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../routes.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/media_selection.dart';
import '../src/rust/api/kikoeru_api.dart';
import '../src/rust/api/textcodec.dart';
import '../src/rust/api/translate.dart';
import '../theme.dart';
import '../widgets.dart';

class WorkPage extends StatefulWidget {
  final AppState app;
  final Work work;
  final VoiceDownload? downloadItem;
  const WorkPage({
    super.key,
    required this.app,
    required this.work,
    this.downloadItem,
  });

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  static const _textEncodings = [
    'UTF-8',
    'UTF-16LE',
    'UTF-16BE',
    'GBK',
    'GB18030',
    'Big5',
    'Shift_JIS',
    'EUC-JP',
    'ISO-2022-JP',
    'Windows-1252',
  ];

  AppState get app => widget.app;
  Work get work => widget.work;
  VoiceDownload? get downloadItem => widget.downloadItem;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  List<MediaNode>? _tree;
  bool _tracksFailed = false;
  final MediaSelection _selection = MediaSelection();
  final Set<String> _expanded = {};
  List<String>? _smartTarget; // 智能路径自动进入的目录（标题链），用于「查看全部文件」
  late int _seenLoginEpoch;
  bool _translating = false;
  List<LanguageEdition> _languageEditions = const [];
  bool _openingLanguageEdition = false;

  @override
  void initState() {
    super.initState();
    _seenLoginEpoch = app.loginEpoch;
    _languageEditions = work.languageEditions;
    if (downloadItem != null) {
      _tree = downloadItem!.tree;
      _tracksFailed = false;
      _applyDownloadSmartPath();
    }
    app.addListener(_onAppChanged);
    if (downloadItem == null) _loadTracks();
    _loadLanguageEditions();
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    if (downloadItem == null && app.loginEpoch != _seenLoginEpoch) {
      _seenLoginEpoch = app.loginEpoch;
      _loadTracks();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadTracks() async {
    final id = work.apiId;
    if (id == null) return;
    try {
      final t = await ApiService.fetchTracks(app, id);
      if (mounted) {
        setState(() {
          _tree = t;
          _tracksFailed = false;
          _applySmartPath();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tracksFailed = true);
    }
  }

  void _applyDownloadSmartPath() {
    final tree = _tree;
    final item = downloadItem;
    if (tree == null || item == null || tree.isEmpty) return;
    _smartTarget = null;
    _expanded.clear();
    var current = tree;
    while (current.length == 1 && current.first.isDir) {
      _expanded.add(current.first.path);
      current = current.first.children;
    }
    final manager = DownloadManager.instance;
    List<MediaNode>? best;
    var count = 0;
    void scan(List<MediaNode> nodes, List<MediaNode> parents) {
      var local = 0;
      for (final node in nodes) {
        if (node.isDir) {
          scan(node.children, [...parents, node]);
        } else if (manager.isDownloaded(item, node)) {
          local++;
        }
      }
      if (local > count && parents.isNotEmpty) {
        count = local;
        best = parents;
      }
    }

    scan(current, []);
    if (best != null) {
      for (final node in best!) {
        _expanded.add(node.path);
      }
    }
  }

  Future<void> _loadLanguageEditions() async {
    final id = work.apiId;
    if (id == null) return;
    try {
      final details = await ApiService.fetchWork(app, id);
      if (details.hasReview != null) {
        app.syncFavoriteFromServer(work, details.hasReview!);
      }
      if (mounted) {
        setState(() => _languageEditions = details.languageEditions);
      }
    } catch (_) {
      // 作品仍可正常浏览；多语言入口仅在详情接口可用时显示。
    }
  }

  Future<void> _openLanguageEdition(LanguageEdition edition) async {
    if (_openingLanguageEdition) return;
    setState(() => _openingLanguageEdition = true);
    try {
      final target = await ApiService.fetchWork(app, edition.id);
      if (!mounted) return;
      if (app.sfwMode && target.age != Age.all) {
        _toast('SFW 模式下不能打开非全年龄作品');
        return;
      }
      await Navigator.of(context).push(buildWorkRoute(app, target));
    } catch (_) {
      if (mounted) _toast('无法加载该语言版本');
    } finally {
      if (mounted) setState(() => _openingLanguageEdition = false);
    }
  }

  void _showLanguageEditions() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: _languageEditions.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: p.line),
                  itemBuilder: (_, index) {
                    final edition = _languageEditions[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(dialogContext).pop();
                        _openLanguageEdition(edition);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Text(
                          edition.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.text),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 智能路径（对齐 asmr.one Auto initial path） ----------

  /// 树加载完成后应用智能路径：展开到最佳目录并记录目标（供「查看全部文件」）
  void _applySmartPath() {
    _smartTarget = null;
    if (app.initialPathBehavior != 'auto') return;
    final t = _tree;
    if (t == null || t.isEmpty) return;
    final target = _smartInitialPath();
    if (target.isEmpty) return;
    // 展开目标目录的整条祖先链（含唯一子文件夹自动下沉）
    _expanded.clear();
    var cur = t;
    for (final part in target) {
      final node = cur.where((n) => n.isDir && n.title == part).firstOrNull;
      if (node == null) break;
      _expanded.add(node.path);
      cur = node.children;
    }
    _smartTarget = List.of(target);
  }

  /// 回根目录（「查看全部文件」）
  void _showAllFiles() {
    setState(() {
      _smartTarget = null;
      _expanded.clear();
    });
  }

  /// 计算智能路径：返回要进入的目录标题链（空 = 根目录）
  List<String> _smartInitialPath() {
    final tree = _tree ?? [];
    // 1) 沿「唯一子文件夹」链一路下沉
    var cur = List<MediaNode>.from(tree);
    final path = <String>[];
    while (cur.length == 1 && cur[0].isDir) {
      path.add(cur[0].title);
      if (cur[0].children.isEmpty) break;
      cur = cur[0].children;
    }
    if (app.initialPathBehavior != 'auto' || tree.isEmpty) return path;

    // 2) 递归统计每个文件夹：音频总时长 / 各扩展名文件数 / 是否无效果音
    final stats = <_DirStat>[];
    void walk(List<MediaNode> nodes, List<String> folderPath) {
      for (final n in nodes) {
        if (n.isDir) {
          walk(n.children, [...folderPath, n.title]);
        } else if (_isAudio(n) && n.url != null && n.url!.isNotEmpty) {
          final key = folderPath.join('/');
          final hit = stats.where((x) => x.path.join('/') == key).firstOrNull;
          if (hit != null) {
            hit.duration += n.duration;
            final ext = _ext(n.title);
            hit.byExt[ext] = (hit.byExt[ext] ?? 0) + 1;
          } else {
            stats.add(
              _DirStat(
                path: List.of(folderPath),
                duration: n.duration,
                byExt: {_ext(n.title): 1},
                se: _notNoSe(folderPath.join('/')),
              ),
            );
          }
        }
      }
    }

    walk(cur, path);

    // 3) 过滤附带/杂谈类目录
    const excludeWords = ['おまけ', '特典', '附赠', '杂谈', 'freetalk'];
    stats.removeWhere(
      (x) => excludeWords.any((w) => x.path.join('/').contains(w)),
    );

    if (stats.isEmpty || stats.length > 6) return path;

    // 4) 时长最长 → 300 秒容差
    stats.sort((a, b) => b.duration - a.duration);
    var chosen = stats.first;
    final candidates = stats
        .where((x) => x.duration >= chosen.duration - 300)
        .toList();

    // 5) 效果音偏好过滤
    final seMatched = candidates
        .where((x) => x.se == app.sePreference)
        .toList();
    if (seMatched.isNotEmpty) {
      // 6) 按音频类型偏好顺序 + 文件数排序
      final byType = <_DirStat>[];
      for (final t in app.audioTypePreference) {
        final list = seMatched.where((x) => (x.byExt[t] ?? 0) > 0).toList()
          ..sort((a, b) => (b.byExt[t] ?? 0) - (a.byExt[t] ?? 0));
        byType.addAll(list);
      }
      if (byType.isNotEmpty) chosen = byType.first;
    }
    return chosen.path;
  }

  /// 提取小写扩展名；无扩展名返回空串
  String _ext(String name) {
    final t = name.split('.').last.toLowerCase();
    return t == name.toLowerCase() ? '' : t;
  }

  /// 路径同时含「无/カット/no/cut…」与「se/效果音/音效/効果音…」→ 判为无效果音目录
  bool _notNoSe(String path) {
    const noWords = ['no', 'cut', '无', '無', 'なし', 'less', 'カット'];
    const seWords = ['se', '效果音', '音效', '効果音'];
    final lower = path.toLowerCase();
    return !noWords.any(
      (w) => lower.contains(w) && seWords.any((s) => lower.contains(s)),
    );
  }

  bool _isAudio(MediaNode n) =>
      !n.isDir &&
      n.title.toLowerCase().contains(
        RegExp(r'\.(mp3|ogg|opus|wav|aac|flac|webm|mp4|m4a|mka|aiff|wma|ape)$'),
      );

  List<MediaNode> _collectAudio(Iterable<MediaNode> nodes) {
    final out = <MediaNode>[];
    void walk(List<MediaNode> list) {
      for (final n in list) {
        if (n.isDir) {
          walk(n.children);
        } else if (_isAudio(n)) {
          out.add(n);
        }
      }
    }

    walk(nodes.toList());
    return out;
  }

  void _playFiles(Iterable<MediaNode> files, {MediaNode? selected}) {
    if (app.sfwMode && work.age != Age.all) {
      _toast('SFW 模式下不能播放非全年龄作品');
      return;
    }
    final audio = _collectAudio(files);
    if (audio.isEmpty) {
      _toast('暂无音频文件（文件流需登录后可用）');
      return;
    }
    final selectedIndex = selected == null
        ? 0
        : audio.indexWhere((item) => item.path == selected.path);
    app.startPlayback(
      work,
      audio,
      initialTrackIndex: selectedIndex < 0 ? 0 : selectedIndex,
    );
    Navigator.of(context).pushNamed('/player');
  }

  void _playAsAudio(MediaNode n) {
    if (app.sfwMode && work.age != Age.all) {
      _toast('SFW 模式下不能播放非全年龄作品');
      return;
    }
    app.startPlayback(work, [n]);
    Navigator.of(context).pushNamed('/player');
  }

  Future<void> _downloadSelected() async {
    final tree = _tree;
    if (tree == null) {
      _toast('曲目列表尚未加载');
      return;
    }
    final selected = Set<String>.of(_selection.projects);
    if (selected.isEmpty) {
      _toast('请先勾选要下载的项目或文件夹');
      return;
    }
    try {
      await DownloadManager.instance.enqueue(
        app: app,
        work: work,
        tree: tree,
        selectedPaths: selected,
      );
      if (mounted) _toast('已加入下载队列');
    } catch (e) {
      if (mounted) _toast('加入下载失败：$e');
    }
  }

  Future<void> _copyRj() async {
    await Clipboard.setData(ClipboardData(text: work.rj));
    if (mounted) _toast('已复制 ${work.rj}');
  }

  bool _isImage(MediaNode n) => n.title.toLowerCase().contains(
    RegExp(r'\.(jpg|jpeg|png|webp|gif|bmp|avif)$'),
  );

  bool _isText(MediaNode n) => n.title.toLowerCase().contains(
    RegExp(r'\.(txt|lrc|srt|json|md|log|vtt)$'),
  );

  bool _isVideo(MediaNode n) => n.title.toLowerCase().contains(
    RegExp(r'\.(mp4|mkv|webm|avi|mov|wmv|flv|ts|m4v)$'),
  );

  void _openFile(MediaNode n) {
    if (_isImage(n)) {
      _showImage(n.url);
    } else if (_isText(n)) {
      _showTextViewer(n);
    } else if (_isVideo(n)) {
      _openVideoChooser(n);
    } else {
      _toast('暂不支持查看该类型：${n.title}');
    }
  }

  void _showImage(String? url) {
    if (url == null) {
      _toast('文件流需登录后可用');
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image(
                image: ResizeImage.resizeIfNeeded(
                  // 按屏幕宽度解码，上限 1600px：避免超大图片全尺寸解码（内存/卡顿）
                  (MediaQuery.sizeOf(ctx).width *
                          MediaQuery.devicePixelRatioOf(ctx))
                      .round()
                      .clamp(128, 1600),
                  null,
                  RustImageProvider(url),
                ),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTextViewer(MediaNode n) async {
    if (n.url == null) {
      _toast('文件流需登录后可用');
      return;
    }
    final bytes = await apiGetBytes(url: n.url!);
    String text;
    String encoding;
    try {
      final r = apiDecodeText(bytes: bytes, encoding: '');
      text = r.text;
      encoding = r.encoding;
    } catch (e) {
      text = utf8.decode(bytes, allowMalformed: true);
      encoding = 'UTF-8';
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: p.surface,
        insetPadding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 600,
          height: 500,
          child: StatefulBuilder(
            builder: (ctx2, setState) {
              void applyEncoding(String enc) {
                try {
                  final r = apiDecodeText(bytes: bytes, encoding: enc);
                  setState(() {
                    encoding = r.encoding;
                    text = r.text;
                  });
                } catch (e) {
                  _toast('解码失败：$e');
                }
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          initialValue: encoding,
                          tooltip: '切换编码',
                          onSelected: applyEncoding,
                          itemBuilder: (_) => _textEncodings.map((e) {
                            final active = e == encoding;
                            return PopupMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  Icon(
                                    active ? Icons.check : Icons.text_fields,
                                    size: 15,
                                    color: active ? p.accent : p.dim,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    e,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.text,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: p.surface2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.translate,
                                  size: 14,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  encoding,
                                  style: TextStyle(fontSize: 12, color: p.text),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: p.dim,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        text,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openVideoChooser(MediaNode n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: const Text('选择打开方式'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launchExternal(n);
            },
            child: const Text('外部播放器打开'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _playAsAudio(n);
            },
            child: const Text('音频方式打开'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternal(MediaNode n) async {
    final url = n.url;
    if (url == null) {
      _toast('文件流需登录后可用');
      return;
    }
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _toast('打开失败');
  }

  List<PlaylistTrack> _selectedAudioTracks() {
    final tree = _tree;
    if (tree == null) return const [];
    final byPath = <String, PlaylistTrack>{};

    void collect(Iterable<MediaNode> nodes) {
      for (final n in nodes) {
        if (n.isDir) {
          collect(n.children);
        } else if (_isAudio(n)) {
          byPath[n.path] = PlaylistTrack(
            title: n.title,
            path: n.path,
            url: n.url,
            duration: n.duration,
          );
        }
      }
    }

    void walk(Iterable<MediaNode> nodes) {
      for (final n in nodes) {
        if (_selection.paths.contains(n.path)) {
          if (n.isDir) {
            collect(n.children);
          } else if (_isAudio(n) && n.url != null && n.url!.isNotEmpty) {
            byPath[n.path] = PlaylistTrack(
              title: n.title,
              path: n.path,
              url: n.url,
              duration: n.duration,
            );
          }
        }
        if (n.isDir) walk(n.children);
      }
    }

    walk(tree);
    return byPath.values.toList();
  }

  void _addToPlaylist() {
    if (_selection.paths.isEmpty) {
      _toast('请先勾选文件或文件夹');
      return;
    }
    final tracks = _selectedAudioTracks();
    if (tracks.isEmpty) {
      _toast('所选项目中没有可播放的音频文件');
      return;
    }
    final existing = app.playlists.keys.toList();
    var newMode = existing.isEmpty;
    var chosen = existing.isEmpty ? '' : existing.first;
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '添加到歌单',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已选择 ${tracks.length} 个音频文件',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                  const SizedBox(height: 10),
                  ...existing.map(
                    (pl) => InkWell(
                      onTap: () => setSheet(() {
                        newMode = false;
                        chosen = pl;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              chosen == pl
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: chosen == pl ? p.accent : p.dim,
                            ),
                            const SizedBox(width: 10),
                            Text(pl, style: const TextStyle(fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setSheet(() => newMode = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            newMode
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 20,
                            color: newMode ? p.accent : p.dim,
                          ),
                          const SizedBox(width: 10),
                          const Text('新建歌单', style: TextStyle(fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ),
                  if (newMode)
                    TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: TextStyle(fontSize: 13, color: p.text),
                      decoration: InputDecoration(
                        hintText: '歌单名称',
                        hintStyle: TextStyle(fontSize: 13, color: p.dim),
                        filled: true,
                        fillColor: p.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide(color: p.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: BorderSide(color: p.accent),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      final name = newMode ? nameCtrl.text.trim() : chosen;
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('请输入歌单名称')),
                        );
                        return;
                      }
                      app.addWorkToPlaylist(name, work, tracks);
                      Navigator.pop(ctx);
                      _selection.clear();
                      setState(() {});
                      _toast('已添加到「$name」');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '确认添加',
                      style: TextStyle(fontWeight: FontWeight.w600),
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

  IconData _mediaIcon(MediaNode n, bool open) {
    if (n.isDir) return open ? Icons.folder_open : Icons.folder;
    if (_isAudio(n)) return Icons.music_note;
    if (_isVideo(n)) return Icons.movie_outlined;
    if (_isText(n)) return Icons.description_outlined;
    if (_isImage(n)) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Widget _treeView(List<MediaNode> nodes, int depth) {
    return Column(
      children: nodes.map((n) => _nodeRow(n, depth, nodes)).toList(),
    );
  }

  bool _hasDownloadedContent(MediaNode node) {
    if (downloadItem == null) return true;
    final manager = DownloadManager.instance;
    for (final child in node.children) {
      if (child.isDir) {
        if (_hasDownloadedContent(child)) return true;
      } else if (manager.isDownloaded(downloadItem!, child)) {
        return true;
      }
    }
    return false;
  }

  Widget _nodeRow(MediaNode n, int depth, List<MediaNode> siblings) {
    final checked = _selection.state(n);
    final open = _expanded.contains(n.path);
    final translatedName = app.translatedTrack(work.rj, n.path);
    final downloaded = downloadItem == null
        ? true
        : DownloadManager.instance.isDownloaded(downloadItem!, n);
    final hasDownloadedContent = n.isDir
        ? _hasDownloadedContent(n)
        : downloaded;
    final fileStyle = TextStyle(
      fontSize: 12.5,
      color: hasDownloadedContent ? p.text : p.dim,
      decoration: hasDownloadedContent
          ? TextDecoration.none
          : TextDecoration.lineThrough,
      decorationColor: p.dim,
    );
    return Column(
      children: [
        InkWell(
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: n.title));
            if (mounted) _toast('已复制文件名：${n.title}');
          },
          onTap: () {
            if (n.isDir) {
              setState(() {
                open ? _expanded.remove(n.path) : _expanded.add(n.path);
              });
            } else {
              if (_isAudio(n)) {
                _playFiles(siblings, selected: n);
              } else {
                _openFile(n);
              }
            }
          },
          child: Container(
            padding: EdgeInsets.only(
              left: 6 + depth * 16,
              right: 4,
              top: 9,
              bottom: 9,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            ),
            child: Row(
              children: [
                Icon(
                  _mediaIcon(n, open),
                  size: 17,
                  color: n.isDir ? p.accent : p.dim,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: fileStyle,
                      ),
                      if (translatedName != null && translatedName != n.title)
                        Text(
                          translatedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: p.accent,
                            decoration: hasDownloadedContent
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                            decorationColor: p.dim,
                          ),
                        ),
                    ],
                  ),
                ),
                Checkbox(
                  tristate: n.isDir,
                  value: checked,
                  activeColor: p.accent,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) =>
                      setState(() => _selection.toggle(n, _tree ?? const [])),
                ),
              ],
            ),
          ),
        ),
        if (n.isDir && open)
          ...n.children.map((c) => _nodeRow(c, depth + 1, n.children)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fav = app.isFavorited(work);
    final zhTitle = app.translatedTitle(work.rj);
    final miniVisible = app.playing || app.hasQueue;
    return Scaffold(
      appBar: AppBar(title: const Text('作品详情'), leading: const BackButton()),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, miniVisible ? 100 : 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _showCover,
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: CoverArt(
                        work: work,
                        radius: 18,
                        showBadges: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          work.title,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                        if (zhTitle != null && zhTitle != work.title)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              zhTitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: p.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            InkWell(
                              onTap: _copyRj,
                              borderRadius: BorderRadius.circular(7),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: p.surface2,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  work.rj,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: p.muted,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AgeBadge(age: work.age),
                            if (work.releaseDate.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _releaseDateChip(work.releaseDate),
                            ],
                            if (_languageEditions.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 26,
                                child: OutlinedButton(
                                  onPressed: _openingLanguageEdition
                                      ? null
                                      : _showLanguageEditions,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: p.muted,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(color: p.line),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                  child: const Text(
                                    '多语言',
                                    style: TextStyle(fontSize: 11.5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _linkChip(
                              Icons.storefront_outlined,
                              work.circle,
                              () => _searchAndBack(work.circle),
                            ),
                            if (work.va.replaceFirst('CV. ', '').isNotEmpty)
                              _linkChip(
                                Icons.person_outline,
                                work.va.replaceFirst('CV. ', ''),
                                () => _searchAndBack(
                                  work.va.replaceFirst('CV. ', ''),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '时长 ${work.dur}',
                          style: TextStyle(fontSize: 11.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ApiService.toggleFavorite(app, work);
                          if (mounted) {
                            setState(() {});
                          }
                        } catch (e) {
                          if (mounted) _toast('收藏操作失败：$e');
                        }
                      },
                      icon: Icon(
                        fav ? Icons.favorite : Icons.favorite_border,
                        size: 17,
                      ),
                      label: Text(
                        fav ? '已收藏' : '收藏',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.text,
                        side: BorderSide(color: p.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: _pickEngine,
                      child: OutlinedButton.icon(
                        onPressed: _translating ? null : _translateTitles,
                        icon: _translating
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.translate, size: 17),
                        label: Text(
                          _translating
                              ? '翻译中'
                              : app.translated.containsKey(work.rj)
                              ? '取消翻译'
                              : '翻译',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: p.text,
                          side: BorderSide(color: p.line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addToPlaylist,
                      icon: const Icon(Icons.playlist_add, size: 17),
                      label: const Text(
                        '添加至歌单',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.text,
                        side: BorderSide(color: p.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _downloadSelected,
                      icon: const Icon(Icons.download_outlined, size: 17),
                      label: const Text(
                        '下载选中项目',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.text,
                        side: BorderSide(color: p.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ...work.tags.map(
                    (t) => _tagChip(
                      t,
                      gray: work.grayTags.contains(t),
                      onTap: () => _searchAndBack(t),
                      onLongPress: () => _blacklistTag(t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _tree == null ? '曲目列表' : '曲目列表（文件夹结构）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.muted,
                ),
              ),
              const SizedBox(height: 6),
              if (_tree != null && _tree!.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.line),
                  ),
                  child: Column(
                    children: [
                      // 智能路径自动进入目录后，顶部提供「查看全部文件」占位
                      if (_smartTarget != null)
                        InkWell(
                          onTap: _showAllFiles,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: p.line)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  size: 16,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '查看全部文件',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: p.accent,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: p.dim,
                                ),
                              ],
                            ),
                          ),
                        ),
                      _treeView(_tree!, 0),
                    ],
                  ),
                )
              else if (_tree == null && !_tracksFailed)
                Pulse(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.line),
                    ),
                    child: Column(
                      children: List.generate(6, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              SkeletonBox(width: 20, height: 20, radius: 6),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SkeletonBox(height: 12, radius: 6),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.line),
                  ),
                  child: Center(
                    child: Text(
                      _tracksFailed ? '无网络连接，无法获取曲目列表' : '该作品暂无曲目',
                      style: TextStyle(fontSize: 12.5, color: p.dim),
                    ),
                  ),
                ),
            ],
          ),
          // 迷你播放器浮窗（与首页一致），底部预留空白避免遮挡内容
          if (miniVisible)
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: MiniPlayer(app: app),
            ),
        ],
      ),
    );
  }

  void _showCover() {
    _showImage(work.coverUrl);
  }

  /// 跳回首页并搜索
  void _searchAndBack(String q) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.requestSearch(q);
  }

  Widget _linkChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: p.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: p.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _releaseDateChip(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: p.line),
      ),
      child: Text(date, style: TextStyle(fontSize: 11.5, color: p.muted)),
    );
  }

  /// 作品标签 chip：灰色标签为低愿力样式；点击搜索、长按加入黑名单
  Widget _tagChip(
    String t, {
    required bool gray,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: gray ? p.surface2 : p.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: gray ? p.dim : p.line),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 12,
            color: gray ? p.dim : p.text,
            fontStyle: gray ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  /// 长按翻译键：快速切换翻译引擎
  Future<void> _pickEngine() async {
    const engines = [
      ('google', 'Google（免费，无需 Key）'),
      ('microsoft', 'Microsoft（免费，无需 Key）'),
      ('deepl', 'DeepL（免费版 Key）'),
      ('openai', 'OpenAI 兼容（可配置）'),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 14),
              Text(
                '切换翻译引擎',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...engines.map((e) {
                final on = app.engine == e.$1;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(ctx, e.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: on
                          ? p.accent.withValues(alpha: .08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          on
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 19,
                          color: on ? p.accent : p.dim,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.$2,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: on ? p.accent : p.text,
                              fontWeight: on
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != app.engine) {
      app.setEngine(selected);
    }
  }

  /// 长按标签：确认加入黑名单
  Future<void> _blacklistTag(String t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: const Text('加入黑名单'),
        content: Text(
          '将标签「$t」加入黑名单？\n加入后，含该标签的作品将从首页与搜索中过滤。',
          style: TextStyle(fontSize: 13.5, color: p.text, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定', style: TextStyle(color: p.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      app.toggleBlacklist('tag', t);
    }
  }

  Future<void> _translateTitles() async {
    // 已翻译：再次点击取消翻译（恢复原文）
    if (app.translated.containsKey(work.rj)) {
      app.removeTranslated(work.rj);
      if (mounted) setState(() {});
      _toast('已取消翻译');
      return;
    }
    if (app.engine == 'openai') {
      final cfg = app.aiConfig;
      if ((cfg['base'] ?? '').trim().isEmpty ||
          (cfg['model'] ?? '').trim().isEmpty) {
        _toast('请先在设置中配置 API 地址与模型名');
        return;
      }
    } else if (app.engine == 'deepl') {
      if (app.deeplKey.trim().isEmpty) {
        _toast('请先在设置中填写 DeepL 免费版 API Key');
        return;
      }
    } else if (app.engine != 'google' && app.engine != 'microsoft') {
      _toast('未知翻译引擎');
      return;
    }
    if (_tree == null) {
      _toast(_tracksFailed ? '无网络连接，无法获取曲目列表' : '曲目列表加载中，请稍候');
      return;
    }
    final audio = _collectAudio(_tree!);
    final lines = [work.title, ...audio.map((n) => n.title)];
    _toast('正在翻译 ${lines.length} 行标题…');
    setState(() => _translating = true);
    try {
      final joined = lines.join('\n');
      final zh = switch (app.engine) {
        'google' => await apiTranslateGoogle(
          text: joined,
          src: 'ja',
          dst: app.translationTarget,
        ),
        'microsoft' => await apiTranslateMicrosoft(
          text: joined,
          src: 'ja',
          dst: app.translationTarget,
        ),
        'deepl' => await apiTranslateDeepl(
          text: joined,
          src: 'ja',
          dst: app.translationTarget,
          apiKey: app.deeplKey,
        ),
        _ => await apiTranslateOpenai(
          baseUrl: app.aiConfig['base']!,
          model: app.aiConfig['model']!,
          apiKey: app.aiConfig['key'] ?? '',
          text: '[[KIKOETA_TARGET:${app.translationTarget}]]\n$joined',
          temperature: 0.2,
        ),
      };
      // 保留空行位置，避免兼容模型漏译某一行后把后续曲目错位映射。
      final parts = zh.replaceAll('\r\n', '\n').split('\n');
      if (parts.every((part) => part.trim().isEmpty)) {
        throw const FormatException('翻译结果为空');
      }
      final trackZh = <String, String>{};
      for (var i = 0; i < audio.length; i++) {
        final translation = i + 1 < parts.length ? parts[i + 1].trim() : '';
        if (translation.isNotEmpty) {
          trackZh[audio[i].path] = translation;
        }
      }
      app.saveTranslated(
        work.rj,
        parts.first.trim().isNotEmpty ? parts.first.trim() : work.title,
        trackZh,
      );
      if (mounted) setState(() {});
      _toast('翻译完成（标题 + ${trackZh.length} 个曲目）');
    } catch (e) {
      _toast('翻译失败：$e');
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }
}

/// 智能路径统计项：某目录下音频总时长 / 各扩展名文件数 / 是否含效果音
class _DirStat {
  final List<String> path;
  int duration;
  final Map<String, int> byExt;
  final bool se;

  _DirStat({
    required this.path,
    required this.duration,
    required this.byExt,
    required this.se,
  });
}
