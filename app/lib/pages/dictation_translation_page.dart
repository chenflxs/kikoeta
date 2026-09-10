import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data.dart';
import '../services/api_service.dart';
import '../services/kt_service.dart';
import '../services/lyrics_library_service.dart';
import '../services/settings_store.dart';
import '../theme.dart';

class DictationTranslationPage extends StatefulWidget {
  final AppState app;
  final Work? work;
  final List<MediaNode> tracks;

  const DictationTranslationPage({
    super.key,
    required this.app,
    this.work,
    this.tracks = const [],
  });

  @override
  State<DictationTranslationPage> createState() =>
      _DictationTranslationPageState();
}

class _DictationTranslationPageState extends State<DictationTranslationPage> {
  static const _localEndpoint = '127.0.0.1:2370';
  late final TextEditingController _networkController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late bool _useLocal;
  late final Set<int> _selected;
  final List<String> _logs = [];
  bool _testing = false;
  bool _obscurePassword = true;
  bool _running = false;
  bool _cancelling = false;
  String _stage = '等待开始';
  String? _jobId;
  KtService? _activeService;
  int _finishedFiles = 0;
  double _stageFraction = 0;
  int _savedFiles = 0;

  AppState get app => widget.app;
  Work? get work => widget.work;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _useLocal =
        !Platform.isAndroid &&
        SettingsStore.get('kt_connection_mode') != 'network';
    _networkController = TextEditingController(
      text: SettingsStore.get('kt_network_endpoint') ?? '',
    );
    _usernameController = TextEditingController(
      text: SettingsStore.get('kt_username') ?? KtService.defaultUsername,
    );
    _passwordController = TextEditingController(
      text: SettingsStore.get('kt_password') ?? KtService.defaultPassword,
    );
    _selected = Set<int>.from(List.generate(widget.tracks.length, (i) => i));
  }

  @override
  void dispose() {
    _networkController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _endpoint => _useLocal ? _localEndpoint : _networkController.text;
  List<int> get _selectedIndices => _selected.toList()..sort();
  double get _progress {
    if (_selected.isEmpty) return 0;
    return ((_finishedFiles + _stageFraction) / _selected.length).clamp(
      0.0,
      1.0,
    );
  }

  void _persistConnection() {
    SettingsStore.set('kt_connection_mode', _useLocal ? 'local' : 'network');
    SettingsStore.set('kt_network_endpoint', _networkController.text.trim());
    SettingsStore.set('kt_username', _usernameController.text.trim());
    SettingsStore.set('kt_password', _passwordController.text);
  }

  KtService _service() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      throw const FormatException('请输入 kt 用户名和密码');
    }
    if (username.contains(':')) {
      throw const FormatException('kt 用户名不能包含冒号');
    }
    return KtService(_endpoint, username: username, password: password);
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    setState(() => _testing = true);
    KtService? service;
    try {
      service = _service();
      final result = await service.health();
      if (result['ok'] != true) throw const FormatException('kt 服务未就绪');
      _persistConnection();
      _toast('连接成功');
    } catch (error) {
      _toast('连接失败：$error');
    } finally {
      service?.close();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _start() async {
    if (_running) return;
    final currentWork = work;
    if (currentWork == null) {
      _toast('请从作品详情页的更多选项进入并启动听写翻译');
      return;
    }
    if (_selected.isEmpty) {
      _toast('请至少选择一个音频文件');
      return;
    }
    final tracks = _selectedIndices.map((i) => widget.tracks[i]).toList();
    final missing = tracks.where((track) {
      final url = track.downloadUrl ?? track.url;
      return url == null || url.isEmpty;
    }).length;
    if (missing > 0) {
      _toast('有 $missing 个音频缺少可下载地址，请登录作品服务器后重试');
      return;
    }

    KtService? service;
    try {
      service = _service();
      _activeService = service;
      _persistConnection();
      setState(() {
        _running = true;
        _cancelling = false;
        _logs.clear();
        _jobId = null;
        _stage = '正在连接 kt';
        _finishedFiles = 0;
        _stageFraction = 0;
        _savedFiles = 0;
      });
      await service.health();
      final token = ApiService.tokenFor(app, ApiService.resolveBase(app));
      final sources = <KtSourceFile>[];
      for (var i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        sources.add(
          KtSourceFile(
            url: track.downloadUrl ?? track.url!,
            name: ktUploadName(i, track.title),
            headers: token == null || token.isEmpty
                ? const {}
                : {'Authorization': 'Bearer $token'},
          ),
        );
      }
      final created = await service.createJob(sources);
      final jobId = created['job_id']?.toString() ?? '';
      if (jobId.isEmpty) throw const FormatException('kt 未返回任务编号');
      _jobId = jobId;
      _appendLog('任务 $jobId 已创建，共 ${tracks.length} 个音频');
      if (mounted) setState(() => _stage = '任务已排队');

      var cursor = 0;
      var closed = false;
      while (!closed) {
        final batch = await service.events(jobId, cursor);
        cursor = batch.cursor;
        closed = batch.closed;
        for (final event in batch.events) {
          _applyEvent(event);
        }
      }

      final job = await service.job(jobId);
      final status = job['status']?.toString() ?? 'failed';
      if (status == 'completed' ||
          status == 'failed' ||
          status == 'cancelled') {
        if (mounted) {
          setState(() {
            _stage = '正在写入歌词库';
            if (status == 'completed') {
              _finishedFiles = tracks.length;
            }
            _stageFraction = 0;
          });
        }
        _savedFiles = await _saveOutputs(service, job, currentWork, tracks);
        if (_savedFiles > 0) {
          _appendLog('已按 ${currentWork.rj} 写入 $_savedFiles 个歌词文件');
        }
      }
      if (status == 'completed') {
        if (_savedFiles == 0) {
          throw const FormatException('kt 没有返回可用的 LRC 文件');
        }
        if (mounted) setState(() => _stage = '听写翻译完成');
        _toast('完成：$_savedFiles 个歌词已写入 ${currentWork.rj} 歌词库');
      } else if (status == 'cancelled') {
        if (mounted) setState(() => _stage = '任务已取消');
      } else {
        throw Exception(
          job['error']?.toString().trim().isNotEmpty == true
              ? job['error'].toString()
              : 'kt 任务失败',
        );
      }
    } catch (error) {
      _appendLog('错误：$error');
      if (mounted) setState(() => _stage = '任务失败');
      _toast('听写翻译失败：$error');
    } finally {
      service?.close();
      _activeService = null;
      if (mounted) {
        setState(() {
          _running = false;
          _cancelling = false;
        });
      }
    }
  }

  Future<int> _saveOutputs(
    KtService service,
    Map<String, dynamic> job,
    Work currentWork,
    List<MediaNode> tracks,
  ) async {
    final rawResults = job['results'];
    if (rawResults is! List) return 0;
    var saved = 0;
    for (
      var index = 0;
      index < rawResults.length && index < tracks.length;
      index++
    ) {
      final raw = rawResults[index];
      if (raw is! Map || raw['status'] != 'done') continue;
      final urls = raw['download_urls'];
      if (urls is! List || urls.isEmpty) continue;
      String? lrcUrl;
      final outputs = raw['outputs'];
      if (outputs is List) {
        for (var i = 0; i < outputs.length && i < urls.length; i++) {
          if (outputs[i].toString().toLowerCase().endsWith('.lrc')) {
            lrcUrl = urls[i].toString();
            break;
          }
        }
      }
      lrcUrl ??= urls.first.toString();
      final bytes = await service.download(lrcUrl);
      final content = utf8.decode(bytes, allowMalformed: true);
      await LyricsLibraryService.instance.saveTranslatedLyrics(
        workId: currentWork.rj,
        relativePath: ktLyricsRelativePath(currentWork.rj, tracks[index].path),
        content: content,
      );
      saved++;
    }
    return saved;
  }

  void _applyEvent(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final message = event['message']?.toString() ?? '';
    if (message.isNotEmpty) _appendLog(message);
    if (!mounted) return;
    setState(() {
      if (type == 'status') {
        final stage = event['stage']?.toString() ?? '';
        _stage = message.isEmpty ? stage : message;
        _stageFraction = switch (stage) {
          'running' => 0.02,
          'transcoding' => 0.12,
          'asr' => 0.38,
          'correcting' => 0.62,
          'translating' => 0.74,
          'exporting' => 0.92,
          _ => _stageFraction,
        };
      } else if (type == 'file_done' || type == 'file_error') {
        _finishedFiles = (_finishedFiles + 1).clamp(0, _selected.length);
        _stageFraction = 0;
      }
    });
  }

  void _appendLog(String message) {
    if (message.trim().isEmpty) return;
    _logs.add(message.trim());
    if (_logs.length > 500) _logs.removeRange(0, _logs.length - 500);
    if (mounted) setState(() {});
  }

  Future<void> _cancel() async {
    final service = _activeService;
    final jobId = _jobId;
    if (service == null || jobId == null || _cancelling) return;
    setState(() => _cancelling = true);
    try {
      await service.cancel(jobId);
      _appendLog('已向 kt 发送取消请求');
    } catch (error) {
      _toast('取消失败：$error');
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('听写翻译')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _connectionCard(),
          const SizedBox(height: 12),
          _workCard(),
          const SizedBox(height: 12),
          _progressCard(),
          const SizedBox(height: 12),
          _logCard(),
        ],
      ),
    );
  }

  Widget _connectionCard() => _card(
    title: '连接方式',
    icon: Icons.cable_outlined,
    children: [
      if (!Platform.isAndroid)
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('本地')),
            ButtonSegment(value: false, label: Text('网络')),
          ],
          selected: {_useLocal},
          onSelectionChanged: _running
              ? null
              : (value) => setState(() => _useLocal = value.first),
        ),
      if (!Platform.isAndroid) const SizedBox(height: 12),
      if (_useLocal)
        TextFormField(
          initialValue: _localEndpoint,
          enabled: false,
          decoration: const InputDecoration(
            labelText: '本地 kt 地址（固定）',
            prefixIcon: Icon(Icons.dns_outlined),
          ),
        )
      else
        TextField(
          controller: _networkController,
          enabled: !_running,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'kt 地址',
            hintText: '192.168.1.20:2370',
            prefixIcon: Icon(Icons.dns_outlined),
          ),
        ),
      if (Platform.isAndroid)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '安卓设备仅支持网络连接',
            style: TextStyle(color: p.muted, fontSize: 12),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _usernameController,
        enabled: !_running,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(
          labelText: 'kt 用户名',
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _passwordController,
        enabled: !_running,
        obscureText: _obscurePassword,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: 'kt 密码',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _running
              ? null
              : () => setState(() {
                  _usernameController.text = KtService.defaultUsername;
                  _passwordController.text = KtService.defaultPassword;
                }),
          child: const Text('使用默认账密'),
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: _testing || _running ? null : _testConnection,
          icon: _testing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering, size: 18),
          label: const Text('测试连接'),
        ),
      ),
    ],
  );

  Widget _workCard() {
    if (work == null) {
      return _card(
        title: '作品',
        icon: Icons.library_music_outlined,
        children: [
          Text(
            '连接设置已可在此管理。要创建任务，请打开作品详情页，在右上角“更多”中选择“听写翻译”。',
            style: TextStyle(color: p.muted, height: 1.5),
          ),
        ],
      );
    }
    return _card(
      title: '${work!.rj} · ${work!.title}',
      icon: Icons.library_music_outlined,
      children: [
        Row(
          children: [
            Text('音频 ${widget.tracks.length} 个，已选 ${_selected.length} 个'),
            const Spacer(),
            TextButton(
              onPressed: _running
                  ? null
                  : () => setState(() {
                      if (_selected.length == widget.tracks.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll(
                          List.generate(widget.tracks.length, (i) => i),
                        );
                      }
                    }),
              child: Text(
                _selected.length == widget.tracks.length ? '取消全选' : '全选',
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 230),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.tracks.length,
            itemBuilder: (_, index) {
              final track = widget.tracks[index];
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(index),
                onChanged: _running
                    ? null
                    : (value) => setState(() {
                        if (value == true) {
                          _selected.add(index);
                        } else {
                          _selected.remove(index);
                        }
                      }),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  track.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _running ? _cancel : _start,
            icon: Icon(
              _running ? Icons.stop_circle_outlined : Icons.graphic_eq,
            ),
            label: Text(_running ? (_cancelling ? '正在取消…' : '取消任务') : '开始听写翻译'),
          ),
        ),
      ],
    );
  }

  Widget _progressCard() => _card(
    title: '听写进度',
    icon: Icons.timeline,
    children: [
      LinearProgressIndicator(
        value: _running || _savedFiles > 0 ? _progress : 0,
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(
              _stage,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${(_progress * 100).round()}%',
            style: TextStyle(color: p.muted),
          ),
        ],
      ),
      if (_selected.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          '已处理 $_finishedFiles / ${_selected.length}${_savedFiles > 0 ? ' · 已入库 $_savedFiles' : ''}',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ],
    ],
  );

  Widget _logCard() => _card(
    title: 'kt 日志',
    icon: Icons.terminal,
    children: [
      Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 140, maxHeight: 280),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.line),
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: SelectableText(
            _logs.isEmpty ? '等待 kt 日志…' : _logs.join('\n'),
            style: TextStyle(
              color: _logs.isEmpty ? p.dim : p.text,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _card({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: p.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
