import 'package:flutter/material.dart';

import '../data.dart';
import '../services/api_service.dart';
import '../smooth_scroll.dart';
import '../theme.dart';
import '../l10n/strings.dart';

/// 登录页：未登录 one 站且未配置自建服务器时作为应用首页显示。
/// 登录成功后 AppState.loginRequired 变为 false，自动切换进主界面。
/// 右下角「配置自建站点」会把整个页面切换为自建站配置视图（非弹窗）。
class LoginPage extends StatefulWidget {
  final AppState app;
  const LoginPage({super.key, required this.app});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  // 自建站配置视图
  bool _siteMode = false;
  int _selSite = -1;
  bool _savingSite = false;
  final _aliasCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _siteUserCtrl = TextEditingController();
  final _sitePassCtrl = TextEditingController();
  bool _sitePassObscure = true;

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _userCtrl.text = app.asmrUser;
    _passCtrl.text = app.asmrPass;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _aliasCtrl.dispose();
    _urlCtrl.dispose();
    _siteUserCtrl.dispose();
    _sitePassCtrl.dispose();
    super.dispose();
  }

  void _toast(String s) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  // ---------------- one 站登录 ----------------
  Future<void> _login() async {
    final l10n = context.l10n;
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) {
      _toast(l10n.loginPageLoginToast);
      return;
    }
    setState(() => _busy = true);
    try {
      // 真实登录：向 one 站获取 token 校验账密
      await ApiService.login(app, 'https://api.asmr.one', user, pass);
      app.saveAsmr(user, pass); // notify → loginRequired=false → 自动进入主界面
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '').trim();
      _toast(
        l10n.loginPageLoginToast3(
          (msg.isEmpty ? l10n.loginPageLoginToast2 : msg).toString(),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 「我没有账号」免责声明
  void _showNoAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.loginPageShowNoAccountText),
        content: Text(
          context.l10n.loginPageShowNoAccountText3,
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.loginPageShowNoAccountText2),
          ),
        ],
      ),
    );
  }

  Future<void> _showProxyDialog() async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: app.httpProxyUrl);
    var enabled = app.httpProxyEnabled;
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: p.surface,
            title: Text(
              l10n.loginPageShowProxyDialogText,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_lock_outlined, size: 20, color: p.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.loginPageShowProxyDialogText2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: enabled,
                        activeTrackColor: p.accent,
                        onChanged: (value) {
                          setDialogState(() => enabled = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    enabled: enabled,
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? p.text : p.dim,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.loginPageShowProxyDialogLabelText,
                      labelStyle: TextStyle(fontSize: 12, color: p.muted),
                      hintText: l10n.loginPageShowProxyDialogHintText,
                      hintStyle: TextStyle(fontSize: 12, color: p.dim),
                      helperText: l10n.loginPageShowProxyDialogHelperText,
                      helperStyle: TextStyle(fontSize: 11, color: p.dim),
                      prefixIcon: Icon(
                        Icons.lan_outlined,
                        size: 18,
                        color: enabled ? p.accent : p.dim,
                      ),
                      filled: true,
                      fillColor: enabled ? p.surface2 : p.bg2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: p.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: p.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: p.accent, width: 1.5),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: p.line),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel, style: TextStyle(color: p.muted)),
              ),
              FilledButton(
                onPressed: () {
                  app.setHttpProxyUrl(controller.text);
                  app.setHttpProxyEnabled(enabled);
                  Navigator.pop(ctx);
                  _toast(
                    enabled
                        ? l10n.loginPageShowProxyDialogToast
                        : l10n.loginPageShowProxyDialogToast2,
                  );
                },
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _networkProxyEntry() {
    return OutlinedButton.icon(
      onPressed: _showProxyDialog,
      icon: const Icon(Icons.vpn_lock_outlined, size: 17),
      label: Text(
        context.l10n.loginPageShowProxyDialogText,
        style: TextStyle(fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: p.muted,
        side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  // ---------------- 自建站点配置 ----------------
  Future<void> _useSite(int idx) async {
    setState(() => _savingSite = true);
    final site = app.customSites[idx];
    if (site.user.isNotEmpty && site.pass.isNotEmpty) {
      try {
        await ApiService.login(app, site.url, site.user, site.pass);
      } catch (_) {}
    }
    // 使用现有站点：启用自建服务器 → loginRequired 变 false → 自动进入主界面
    app.applyServer(true, idx);
    if (mounted) setState(() => _savingSite = false);
  }

  Future<void> _saveNewSite() async {
    final l10n = context.l10n;
    final alias = _aliasCtrl.text.trim();
    final url = _urlCtrl.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final user = _siteUserCtrl.text.trim();
    final pass = _sitePassCtrl.text;
    if (alias.isEmpty || url.isEmpty || user.isEmpty || pass.isEmpty) {
      _toast(l10n.loginPageSaveNewSiteToast);
      return;
    }
    setState(() => _savingSite = true);
    try {
      try {
        await ApiService.login(app, url, user, pass);
      } catch (_) {}
      app.saveSite(CustomSite(alias: alias, url: url, user: user, pass: pass));
      // 自动启用刚添加的站点并进入主界面
      app.applyServer(true, app.customSites.length - 1);
    } finally {
      if (mounted) setState(() => _savingSite = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return _siteMode ? _buildSiteConfig() : _buildLogin();
  }

  Widget _buildLogin() {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SmoothSingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          'Kikoeta',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          context.l10n.loginPageBuildLoginText4,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _field(
                        _userCtrl,
                        hint: context.l10n.loginPageBuildLoginHint,
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                      ),
                      _field(
                        _passCtrl,
                        hint: context.l10n.password,
                        icon: Icons.lock_outline,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                            color: p.dim,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      // 密码框右下角：「我没有账号」
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showNoAccount,
                          style: TextButton.styleFrom(
                            foregroundColor: p.dim,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            context.l10n.loginPageBuildLoginText2,
                            style: TextStyle(fontSize: 12, color: p.dim),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // 登录键
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: p.accent.withValues(
                              alpha: .5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.l10n.loginPageBuildLoginText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 右下角：切换配置自建站点（整个页面切换为配置视图）
            Positioned(
              right: 14,
              bottom: 14,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _siteMode = true),
                icon: const Icon(Icons.dns_outlined, size: 17),
                label: Text(
                  context.l10n.loginPageBuildLoginText3,
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.muted,
                  side: BorderSide(color: p.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            Positioned(left: 14, bottom: 14, child: _networkProxyEntry()),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteConfig() {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 左上角返回登录视图
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: context.l10n.loginPageBuildSiteConfigTooltip,
                onPressed: () => setState(() => _siteMode = false),
              ),
            ),
            Center(
              child: SmoothSingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo（与登录页同款）
                      Center(
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [p.accent, p.accent2],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.dns_outlined,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          context.l10n.loginPageBuildLoginText3,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          context.l10n.loginPageBuildSiteConfigText5,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ),
                      if (app.customSites.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          context.l10n.loginPageBuildSiteConfigText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: p.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...app.customSites.asMap().entries.map((e) {
                          final s = e.value;
                          final i = e.key;
                          final on = _selSite == i;
                          return GestureDetector(
                            onTap: () => setState(() => _selSite = on ? -1 : i),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: on
                                    ? p.accent.withValues(alpha: .08)
                                    : p.surface2,
                                border: Border.all(
                                  color: on ? p.accent : p.line,
                                ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: p.dim,
                                          ),
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
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: (_selSite < 0 || _savingSite)
                                ? null
                                : () => _useSite(_selSite),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: p.accent.withValues(
                                alpha: .5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: Text(
                              context.l10n.loginPageBuildSiteConfigText2,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(child: Divider(color: p.line)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                context.l10n.loginPageBuildSiteConfigText3,
                                style: TextStyle(fontSize: 12, color: p.dim),
                              ),
                            ),
                            Expanded(child: Divider(color: p.line)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        const SizedBox(height: 24),
                      ],
                      _field(
                        _aliasCtrl,
                        hint: context.l10n.loginPageBuildSiteConfigHint3,
                        icon: Icons.label_outline,
                      ),
                      _field(
                        _urlCtrl,
                        hint: 'http://192.168.1.100:3000',
                        icon: Icons.dns_outlined,
                      ),
                      _field(
                        _siteUserCtrl,
                        hint: context.l10n.loginPageBuildSiteConfigHint2,
                        icon: Icons.person_outline,
                      ),
                      _field(
                        _sitePassCtrl,
                        hint: context.l10n.loginPageBuildSiteConfigHint,
                        icon: Icons.lock_outline,
                        obscure: _sitePassObscure,
                        suffix: IconButton(
                          icon: Icon(
                            _sitePassObscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                            color: p.dim,
                          ),
                          onPressed: () => setState(
                            () => _sitePassObscure = !_sitePassObscure,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 保存键（与登录键同款）
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _savingSite ? null : _saveNewSite,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: p.accent.withValues(
                              alpha: .5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: _savingSite
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.l10n.loginPageBuildSiteConfigText4,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(left: 14, bottom: 14, child: _networkProxyEntry()),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl, {
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(fontSize: 14, color: p.text),
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13.5, color: p.dim),
          prefixIcon: Icon(icon, size: 19, color: p.dim),
          suffixIcon: suffix,
          filled: true,
          fillColor: p.surface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: p.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: p.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: p.accent, width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
