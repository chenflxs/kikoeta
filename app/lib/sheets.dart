import 'package:flutter/material.dart';

import 'data.dart';
import 'services/player_service.dart';
import 'theme.dart';
import 'widgets.dart';

Palette _p(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? AppColors.dark
    : AppColors.light;

Widget _sheetScaffold({
  required BuildContext context,
  required String title,
  required String sub,
  required List<Widget> children,
}) {
  final p = _p(context);
  return SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 12, color: p.muted)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

// ---------------- 服务器 ----------------
Future<void> showServerSheet(BuildContext context, AppState app) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ServerSheet(app: app),
  );
}

class _ServerSheet extends StatefulWidget {
  final AppState app;
  const _ServerSheet({required this.app});

  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  late bool _custom;
  late int _idx;

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _custom = app.customServer;
    _idx = app.customServerIdx;
  }

  @override
  Widget build(BuildContext context) {
    return _sheetScaffold(
      context: context,
      title: '选择服务器',
      sub: '官方服务或自建 Kikoeru 站点',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pill(
              label: 'asmr.one',
              selected: !_custom,
              onTap: () => setState(() => _custom = false),
            ),
            Pill(
              label: '自定义配置（${app.customSites.length}）',
              selected: _custom,
              onTap: () => setState(() => _custom = true),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_custom) ...[
          Text(
            '选择自建站点',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: p.dim,
            ),
          ),
          const SizedBox(height: 8),
          if (app.customSites.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('暂无自建站点', style: TextStyle(fontSize: 12, color: p.dim)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await showSiteSheet(context, app);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('添加自建站点', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.accent,
                    side: BorderSide(color: p.accent.withValues(alpha: .5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ],
            )
          else
            ...app.customSites.asMap().entries.map((e) {
              final s = e.value;
              final i = e.key;
              final on = i == _idx;
              return GestureDetector(
                onTap: () => setState(() => _idx = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: on ? p.accent.withValues(alpha: .08) : p.surface2,
                    border: Border.all(color: on ? p.accent : p.line),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        on
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: on ? p.accent : p.dim,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.alias,
                              style: TextStyle(
                                fontSize: 13,
                                color: p.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.url,
                              style: TextStyle(fontSize: 11, color: p.dim),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/settings');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: p.muted,
              side: BorderSide(color: p.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('管理自建站点', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 6),
        ],
        ElevatedButton(
          onPressed: () {
            if (_custom && app.customSites.isEmpty) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('请先添加自建站点')));
              return;
            }
            app.applyServer(_custom, _idx);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            '应用',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ---------------- 自建站点编辑 ----------------
Future<void> showSiteSheet(
  BuildContext context,
  AppState app, {
  int? editIndex,
}) {
  final p = _p(context);
  final isEdit = editIndex != null;
  final aliasCtrl = TextEditingController(
    text: isEdit ? app.customSites[editIndex].alias : '',
  );
  final urlCtrl = TextEditingController(
    text: isEdit ? app.customSites[editIndex].url : '',
  );
  final userCtrl = TextEditingController(
    text: isEdit ? app.customSites[editIndex].user : '',
  );
  final passCtrl = TextEditingController(
    text: isEdit ? app.customSites[editIndex].pass : '',
  );
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _sheetScaffold(
        context: ctx,
        title: isEdit ? '编辑自建站点' : '添加自建站点',
        sub: '支持 IP+端口，如 http://192.168.1.100:3000',
        children: [
          _field(ctx, '别名', aliasCtrl, hint: '如：家庭 NAS'),
          _field(ctx, '地址', urlCtrl, hint: 'http://192.168.1.100:3000'),
          _field(ctx, '账号', userCtrl, hint: '站点登录账号'),
          _field(ctx, '密码', passCtrl, hint: '站点密码', obscure: true),
          ElevatedButton(
            onPressed: () {
              final alias = aliasCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final user = userCtrl.text.trim();
              final pass = passCtrl.text;
              if (alias.isEmpty ||
                  url.isEmpty ||
                  user.isEmpty ||
                  pass.isEmpty) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('请填写别名、地址、账号和密码')));
                return;
              }
              if (isEdit) {
                app.saveSite(
                  CustomSite(
                    alias: alias,
                    url: url,
                    user: userCtrl.text.trim(),
                    pass: passCtrl.text,
                  ),
                  index: editIndex,
                );
              } else {
                app.saveSite(
                  CustomSite(
                    alias: alias,
                    url: url,
                    user: userCtrl.text.trim(),
                    pass: passCtrl.text,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              '保存',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------- ASMR.ONE 账号 ----------------
Future<void> showOneConfigSheet(BuildContext context, AppState app) {
  final p = _p(context);
  final userCtrl = TextEditingController(text: app.asmrUser);
  final passCtrl = TextEditingController(text: app.asmrPass);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _sheetScaffold(
        context: ctx,
        title: 'ASMR.ONE 账号',
        sub: '账号信息仅保存在本地（演示）',
        children: [
          _field(ctx, '账号', userCtrl, hint: 'asmr.one 账号'),
          _field(ctx, '密码', passCtrl, hint: '密码', obscure: true),
          ElevatedButton(
            onPressed: () {
              app.saveAsmr(userCtrl.text.trim(), passCtrl.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              '保存',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------- 均衡器 ----------------
Future<void> showEqSheet(BuildContext context, AppState app) {
  final p = _p(context);
  const hz = ['31', '62', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];
  const presets = {
    '平直': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    '流行': [1, 2, 4, 5, 4, 2, 0, -1, 2, 3],
    '摇滚': [4, 3, 1, 2, 3, 1, 0, 2, 3, 5],
    '低音': [7, 6, 4, 2, 1, 0, 0, 0, 0, 0],
    '人声': [-1, 0, 1, 3, 5, 4, 2, 0, -1, -2],
  };
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => _sheetScaffold(
        context: ctx,
        title: '均衡器',
        sub: '真 10 段 · ±12 dB · 全平台',
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq, size: 17, color: p.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '启用均衡器',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: app.eqOn,
                activeTrackColor: p.accent,
                onChanged: (v) {
                  app.setEqOn(v);
                  AppPlayer.instance.applyEqualizer(
                    enabled: app.eqOn,
                    gains: app.eqGains,
                  );
                  setSheet(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: presets.entries.map((e) {
              return ActionChip(
                label: Text(e.key, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  app.setEqGains(
                    List.generate(10, (i) => e.value[i].toDouble()),
                  );
                  AppPlayer.instance.applyEqualizer(
                    enabled: app.eqOn,
                    gains: app.eqGains,
                  );
                  setSheet(() {});
                },
                backgroundColor: p.surface2,
                side: BorderSide(color: p.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: Row(
              children: List.generate(10, (i) {
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${app.eqGains[i] > 0 ? '+' : ''}${app.eqGains[i].toStringAsFixed(1)}',
                        style: TextStyle(fontSize: 9.5, color: p.muted),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: app.eqGains[i],
                            min: -12,
                            max: 12,
                            divisions: 48,
                            activeColor: p.accent,
                            inactiveColor: p.surface3,
                            onChanged: (v) {
                              app.eqGains[i] = v;
                              app.notify();
                              AppPlayer.instance.applyEqualizer(
                                enabled: app.eqOn,
                                gains: app.eqGains,
                              );
                              setSheet(() {});
                            },
                            onChangeEnd: (_) => app.setEqGains(app.eqGains),
                          ),
                        ),
                      ),
                      Text(
                        hz[i],
                        style: TextStyle(fontSize: 9.5, color: p.dim),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Row(
            children: [
              Text(
                '31Hz — 16kHz',
                style: TextStyle(fontSize: 11, color: p.dim),
              ),
              const Spacer(),
              Text(
                app.eqOn ? '已应用' : '未启用',
                style: TextStyle(
                  fontSize: 11,
                  color: app.eqOn ? p.green : p.dim,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ---------------- 定时关闭 ----------------
Future<void> showSleepSheet(BuildContext context, AppState app) {
  final p = _p(context);
  final minCtrl = TextEditingController();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final remain = app.sleepEndAt?.difference(DateTime.now()).inSeconds;
        return _sheetScaffold(
          context: ctx,
          title: '定时关闭',
          sub: '到点后停止播放并释放系统接口（锁屏卡片 / 通知全部清除）',
          children: [
            if (app.sleepEndAt != null || app.sleepPlayEndArmed) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.accent),
                ),
                child: Column(
                  children: [
                    if (app.sleepEndAt != null && remain != null) ...[
                      Text(
                        '${remain ~/ 60}:${(remain % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: p.accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '剩余时间 · 到点后自动停止并退出',
                        style: TextStyle(fontSize: 11, color: p.dim),
                      ),
                    ] else ...[
                      Text(
                        '播放完毕',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: p.accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '当前播放列表播完后自动停止并关闭',
                        style: TextStyle(fontSize: 11, color: p.dim),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              children: [
                Pill(
                  label: 'N 分钟后',
                  selected: app.sleepMode == 'after',
                  onTap: () {
                    app.setSleepMode('after');
                    setSheet(() {});
                  },
                ),
                Pill(
                  label: '指定时间',
                  selected: app.sleepMode == 'at',
                  onTap: () {
                    app.setSleepMode('at');
                    setSheet(() {});
                  },
                ),
                Pill(
                  label: '播放完毕',
                  selected: app.sleepMode == 'end',
                  onTap: () {
                    app.setSleepMode('end');
                    setSheet(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (app.sleepMode == 'after') ...[
              Wrap(
                spacing: 8,
                children: [10, 15, 30, 60].map((m) {
                  return Pill(
                    label: '$m 分钟',
                    selected: app.sleepMin == m,
                    onTap: () {
                      app.sleepMin = m;
                      app.notify();
                      setSheet(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 13, color: p.text),
                      decoration: InputDecoration(
                        hintText: '自定义分钟数',
                        hintStyle: TextStyle(fontSize: 12, color: p.dim),
                        isDense: true,
                        filled: true,
                        fillColor: p.surface2,
                        suffixText: '分钟',
                        suffixStyle: TextStyle(fontSize: 12, color: p.dim),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: p.line),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) {
                        final v = int.tryParse(minCtrl.text.trim());
                        if (v == null || v <= 0) return;
                        app.sleepMin = v.clamp(1, 1440);
                        app.notify();
                        setSheet(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      final v = int.tryParse(minCtrl.text.trim());
                      if (v == null || v <= 0) return;
                      app.sleepMin = v.clamp(1, 1440);
                      app.notify();
                      setSheet(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(color: p.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('确定', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ] else if (app.sleepMode == 'at')
              _timePicker(ctx, app, setSheet)
            else ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '当前播放列表的内容播放完毕后自动停止并关闭',
                  style: TextStyle(fontSize: 12.5, color: p.dim),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                if (app.sleepMode == 'end') {
                  app.armPlayEnd();
                  Navigator.pop(ctx);
                  return;
                }
                final typed = int.tryParse(minCtrl.text.trim());
                if (typed != null && typed > 0) {
                  app.sleepMin = typed.clamp(1, 1440);
                }
                final now = DateTime.now();
                DateTime end;
                if (app.sleepMode == 'after') {
                  end = now.add(Duration(minutes: app.sleepMin));
                } else {
                  final t =
                      app.sleepTime ?? const TimeOfDay(hour: 23, minute: 59);
                  end = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    t.hour,
                    t.minute,
                  );
                  if (!end.isAfter(now)) end = end.add(const Duration(days: 1));
                }
                app.armSleep(end);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                '开始定时',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                app.clearSleep();
                app.disarmPlayEnd();
                Navigator.pop(ctx);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: p.muted,
                side: BorderSide(color: p.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('取消定时', style: TextStyle(fontSize: 13)),
            ),
          ],
        );
      },
    ),
  ).whenComplete(minCtrl.dispose);
}

Widget _timePicker(BuildContext context, AppState app, StateSetter setSheet) {
  final p = _p(context);
  return Row(
    children: [
      Text('关闭时间', style: TextStyle(fontSize: 12, color: p.muted)),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            final t = await showTimePicker(
              context: context,
              initialTime:
                  app.sleepTime ?? const TimeOfDay(hour: 23, minute: 59),
            );
            if (t != null) {
              app.sleepTime = t;
              app.notify();
              setSheet(() {});
            }
          },
          icon: const Icon(Icons.schedule, size: 16),
          label: Text(
            (app.sleepTime ?? const TimeOfDay(hour: 23, minute: 59)).format(
              context,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: p.muted,
            side: BorderSide(color: p.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _field(
  BuildContext context,
  String label,
  TextEditingController ctrl, {
  String? hint,
  bool obscure = false,
}) {
  final p = _p(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: p.muted,
            ),
          ),
        ),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: TextStyle(fontSize: 13, color: p.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: p.dim),
            filled: true,
            fillColor: p.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: p.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: p.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide(color: p.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
          ),
        ),
      ],
    ),
  );
}
