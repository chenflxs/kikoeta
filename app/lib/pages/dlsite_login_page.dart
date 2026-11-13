import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../services/dlsite_play_service.dart';
import '../smooth_scroll.dart';
import '../theme.dart';
import '../widgets.dart';
import '../widgets/form_sheet.dart';
import '../widgets/login_form.dart';

class DlsiteLoginLabels {
  static const _texts = <String, Map<String, String>>{
    'zh': {
      'title': 'DLsite Play 登录',
      'loginButton': '使用 DLsite Play 登录',
      'id': 'DLsite 账号',
      'password': '密码',
      'cookie': 'Cookie',
      'credentials': '账号密码',
      'openBrowser': '在浏览器打开 DLsite Play',
      'openTutorial': '图文教程',
      'tutorialOpenError': '无法打开图文教程。',
      'browserOpenError': '无法打开浏览器。请手动访问 play.dlsite.com。',
      'cookieHint': '粘贴来自 DLsite Play 的 Cookie 请求头',
      'cookieInstructions':
          '在已登录的 play.dlsite.com 标签页打开 Cookie-Editor，选择 Export → Header String，把导出的整行粘贴到下方。',
      'login': '登录 DLsite Play',
      'loginCookie': '使用 Cookie 登录',
      'otpTitle': '双重验证',
      'otpHint': '请输入 DLsite 发送的验证码',
      'otpCancel': '取消',
      'otpSubmit': '验证',
      'loginError': '登录失败，请检查账号、密码或 Cookie 后重试。',
      'cookieError': 'Cookie 无效或已过期，请重新粘贴后重试。',
      'otpInvalid': '验证码错误，请重新输入。',
      'challengeUnsupported': 'DLsite 返回了无法识别的登录页面。可在浏览器登录后改用 Cookie。',
      'cloudflareChallenge': 'DLsite 需要 Cloudflare 验证。请在浏览器登录后使用 Cookie 登录。',
      'rateLimited': 'DLsite 登录请求过多，请稍后重试。',
      'loginForbidden': 'DLsite 拒绝了登录请求。请在浏览器登录后使用 Cookie 登录。',
      'serviceUnavailable': 'DLsite 服务暂时不可用，请稍后重试。',
      'recaptchaRequired': 'DLsite 需要 reCAPTCHA 验证。请在浏览器登录后使用 Cookie 登录。',
      'turnstileRequired': 'DLsite 需要 Turnstile 验证。请在浏览器登录后使用 Cookie 登录。',
      'networkError': '网络连接失败，请检查网络或代理设置后重试。',
      'otpError': '验证码不能为空。',
      'connecting': '正在登录…',
    },
    'zh-Hant': {
      'title': 'DLsite Play 登入',
      'loginButton': '使用 DLsite Play 登入',
      'id': 'DLsite 帳號',
      'password': '密碼',
      'cookie': 'Cookie',
      'credentials': '帳號密碼',
      'openBrowser': '在瀏覽器開啟 DLsite Play',
      'openTutorial': '圖文教學',
      'tutorialOpenError': '無法開啟圖文教學。',
      'browserOpenError': '無法開啟瀏覽器。請手動造訪 play.dlsite.com。',
      'cookieHint': '貼上來自 DLsite Play 的 Cookie 請求標頭',
      'cookieInstructions':
          '在已登入的 play.dlsite.com 分頁開啟 Cookie-Editor，選擇 Export → Header String，再將匯出的整行貼到下方。',
      'login': '登入 DLsite Play',
      'loginCookie': '使用 Cookie 登入',
      'otpTitle': '雙重驗證',
      'otpHint': '請輸入 DLsite 傳送的驗證碼',
      'otpCancel': '取消',
      'otpSubmit': '驗證',
      'loginError': '登入失敗，請檢查帳號、密碼或 Cookie 後重試。',
      'cookieError': 'Cookie 無效或已過期，請重新貼上後重試。',
      'otpInvalid': '驗證碼錯誤，請重新輸入。',
      'challengeUnsupported': 'DLsite 回傳了無法辨識的登入頁面。可在瀏覽器登入後改用 Cookie。',
      'cloudflareChallenge': 'DLsite 需要 Cloudflare 驗證。請在瀏覽器登入後使用 Cookie 登入。',
      'rateLimited': 'DLsite 登入請求過多，請稍後重試。',
      'loginForbidden': 'DLsite 拒絕了登入請求。請在瀏覽器登入後使用 Cookie 登入。',
      'serviceUnavailable': 'DLsite 服務暫時無法使用，請稍後重試。',
      'recaptchaRequired': 'DLsite 需要 reCAPTCHA 驗證。請在瀏覽器登入後使用 Cookie 登入。',
      'turnstileRequired': 'DLsite 需要 Turnstile 驗證。請在瀏覽器登入後使用 Cookie 登入。',
      'networkError': '網路連線失敗，請檢查網路或代理設定後重試。',
      'otpError': '驗證碼不可為空。',
      'connecting': '正在登入…',
    },
    'en': {
      'title': 'Sign in to DLsite Play',
      'loginButton': 'Sign in with DLsite Play',
      'id': 'DLsite account',
      'password': 'Password',
      'cookie': 'Cookie',
      'credentials': 'Account and password',
      'openBrowser': 'Open DLsite Play in browser',
      'openTutorial': 'Illustrated guide',
      'tutorialOpenError': 'Could not open the illustrated guide.',
      'browserOpenError':
          'Could not open your browser. Visit play.dlsite.com directly.',
      'cookieHint': 'Paste the Cookie header from DLsite Play',
      'cookieInstructions':
          'Open Cookie-Editor in your signed-in play.dlsite.com tab. Choose Export → Header String and paste the entire exported line below.',
      'login': 'Sign in to DLsite Play',
      'loginCookie': 'Sign in with Cookie',
      'otpTitle': 'Two-factor verification',
      'otpHint': 'Enter the verification code from DLsite',
      'otpCancel': 'Cancel',
      'otpSubmit': 'Verify',
      'loginError':
          'Sign-in failed. Check your account, password, or Cookie and retry.',
      'cookieError':
          'The Cookie is invalid or expired. Paste a current value and retry.',
      'otpInvalid': 'The verification code was rejected. Try again.',
      'challengeUnsupported':
          'DLsite returned an unrecognized sign-in page. Sign in in your browser, then use Cookie sign-in.',
      'cloudflareChallenge':
          'DLsite requires Cloudflare verification. Sign in in your browser, then use Cookie sign-in.',
      'rateLimited': 'Too many DLsite sign-in attempts. Try again later.',
      'loginForbidden':
          'DLsite rejected the sign-in request. Sign in in your browser, then use Cookie sign-in.',
      'serviceUnavailable':
          'DLsite is temporarily unavailable. Try again later.',
      'recaptchaRequired':
          'DLsite requires reCAPTCHA. Sign in in your browser, then use Cookie sign-in.',
      'turnstileRequired':
          'DLsite requires Turnstile. Sign in in your browser, then use Cookie sign-in.',
      'networkError':
          'Network request failed. Check your connection or proxy and retry.',
      'otpError': 'Enter a verification code.',
      'connecting': 'Signing in…',
    },
    'ja': {
      'title': 'DLsite Play にログイン',
      'loginButton': 'DLsite Play でログイン',
      'id': 'DLsite アカウント',
      'password': 'パスワード',
      'cookie': 'Cookie',
      'credentials': 'アカウントとパスワード',
      'openBrowser': 'ブラウザーで DLsite Play を開く',
      'openTutorial': '図解ガイド',
      'tutorialOpenError': '図解ガイドを開けませんでした。',
      'browserOpenError': 'ブラウザーを開けません。play.dlsite.com に直接アクセスしてください。',
      'cookieHint': 'DLsite Play の Cookie ヘッダーを貼り付け',
      'cookieInstructions':
          'ログイン済みの play.dlsite.com タブで Cookie-Editor を開き、Export → Header String を選びます。出力された行全体を下の欄に貼り付けてください。',
      'login': 'DLsite Play にログイン',
      'loginCookie': 'Cookie でログイン',
      'otpTitle': '二段階認証',
      'otpHint': 'DLsite から届いた確認コードを入力',
      'otpCancel': 'キャンセル',
      'otpSubmit': '確認',
      'loginError': 'ログインできません。アカウント、パスワード、Cookie を確認して再試行してください。',
      'cookieError': 'Cookie が無効か期限切れです。最新の値を貼り付けて再試行してください。',
      'otpInvalid': '確認コードが違います。もう一度入力してください。',
      'challengeUnsupported':
          'DLsite のログインページを認識できません。ブラウザーでログインしてから Cookie でログインしてください。',
      'cloudflareChallenge':
          'DLsite で Cloudflare 認証が必要です。ブラウザーでログインしてから Cookie でログインしてください。',
      'rateLimited': 'DLsite のログイン試行が多すぎます。時間をおいて再試行してください。',
      'loginForbidden':
          'DLsite がログインを拒否しました。ブラウザーでログインしてから Cookie でログインしてください。',
      'serviceUnavailable': 'DLsite は一時的に利用できません。後でもう一度お試しください。',
      'recaptchaRequired':
          'DLsite で reCAPTCHA が必要です。ブラウザーでログインしてから Cookie でログインしてください。',
      'turnstileRequired':
          'DLsite で Turnstile が必要です。ブラウザーでログインしてから Cookie でログインしてください。',
      'networkError': '通信に失敗しました。ネットワークまたはプロキシを確認してください。',
      'otpError': '確認コードを入力してください。',
      'connecting': 'ログイン中…',
    },
    'ru': {
      'title': 'Вход в DLsite Play',
      'loginButton': 'Войти через DLsite Play',
      'id': 'Аккаунт DLsite',
      'password': 'Пароль',
      'cookie': 'Cookie',
      'credentials': 'Аккаунт и пароль',
      'openBrowser': 'Открыть DLsite Play в браузере',
      'openTutorial': 'Инструкция с иллюстрациями',
      'tutorialOpenError': 'Не удалось открыть инструкцию.',
      'browserOpenError':
          'Не удалось открыть браузер. Перейдите на play.dlsite.com вручную.',
      'cookieHint': 'Вставьте заголовок Cookie из DLsite Play',
      'cookieInstructions':
          'Откройте Cookie-Editor на вкладке play.dlsite.com, где выполнен вход. Выберите Export → Header String и вставьте всю полученную строку ниже.',
      'login': 'Войти в DLsite Play',
      'loginCookie': 'Войти с Cookie',
      'otpTitle': 'Двухфакторная проверка',
      'otpHint': 'Введите код подтверждения от DLsite',
      'otpCancel': 'Отмена',
      'otpSubmit': 'Проверить',
      'loginError':
          'Не удалось войти. Проверьте аккаунт, пароль или Cookie и повторите попытку.',
      'cookieError':
          'Cookie недействителен или истёк. Вставьте актуальное значение и повторите попытку.',
      'otpInvalid': 'Код подтверждения отклонён. Попробуйте ещё раз.',
      'challengeUnsupported':
          'Не удалось распознать страницу входа DLsite. Войдите в браузере, затем используйте Cookie.',
      'cloudflareChallenge':
          'DLsite требует проверку Cloudflare. Войдите в браузере, затем используйте Cookie.',
      'rateLimited': 'Слишком много попыток входа в DLsite. Попробуйте позже.',
      'loginForbidden':
          'DLsite отклонил вход. Войдите в браузере, затем используйте Cookie.',
      'serviceUnavailable': 'DLsite временно недоступен. Попробуйте позже.',
      'recaptchaRequired':
          'DLsite требует reCAPTCHA. Войдите в браузере, затем используйте Cookie.',
      'turnstileRequired':
          'DLsite требует Turnstile. Войдите в браузере, затем используйте Cookie.',
      'networkError':
          'Ошибка сети. Проверьте подключение или прокси и повторите попытку.',
      'otpError': 'Введите код подтверждения.',
      'connecting': 'Вход…',
    },
  };

  static String get(BuildContext context, String key) {
    final locale = Localizations.localeOf(context);
    final code = locale.languageCode == 'zh' && locale.scriptCode == 'Hant'
        ? 'zh-Hant'
        : locale.languageCode;
    return (_texts[code] ?? _texts['en']!)[key]!;
  }
}

class DlsiteLoginPage extends StatefulWidget {
  final AppState app;
  final bool activateOnSignIn;

  const DlsiteLoginPage({
    super.key,
    required this.app,
    this.activateOnSignIn = true,
  });

  static Future<bool?> showAccountSettings(BuildContext context, AppState app) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DlsiteLoginPage(app: app, activateOnSignIn: false),
    );
  }

  @override
  State<DlsiteLoginPage> createState() => _DlsiteLoginPageState();
}

class _DlsiteLoginPageState extends State<DlsiteLoginPage> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  final _cookie = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  bool _cookieLogin = false;
  String? _sheetError;
  SnackBarAction? _sheetErrorAction;

  AppState get app => widget.app;
  Palette get p => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    _cookie.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    final id = _id.text.trim();
    final password = _password.text;
    final cookie = _cookie.text.trim();
    if (_cookieLogin && cookie.isEmpty) {
      _showError(DlsiteLoginLabels.get(context, 'cookieError'));
      return;
    }
    if (!_cookieLogin && (id.isEmpty || password.isEmpty)) {
      _showError(DlsiteLoginLabels.get(context, 'loginError'));
      return;
    }
    setState(() {
      _busy = true;
      _sheetError = null;
      _sheetErrorAction = null;
    });
    DlsitePlaySession? session;
    var handedOff = false;
    try {
      final proxy = app.httpProxyEnabled ? app.httpProxyUrl : null;
      session = _cookieLogin
          ? await DlsitePlaySession.authenticate(cookie, proxy: proxy)
          : await DlsitePlaySession.login(
              id,
              password,
              proxy: proxy,
              requestOtp: _requestOtp,
            );
      if (!mounted) {
        session.close();
        return;
      }
      await app.signInDlsite(session, activate: widget.activateOnSignIn);
      handedOff = true;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!handedOff) session?.close();
      if (!mounted) return;
      if (error is DlsitePlayException && error.code == 'cancelled') return;
      final key = error is DlsitePlayException
          ? switch (error.code) {
              'invalidCredentials' => 'loginError',
              'invalidCookie' => 'cookieError',
              'invalidOtp' => 'otpInvalid',
              'cloudflareChallenge' => 'cloudflareChallenge',
              'rateLimited' => 'rateLimited',
              'loginForbidden' => 'loginForbidden',
              'serviceUnavailable' => 'serviceUnavailable',
              'recaptchaRequired' => 'recaptchaRequired',
              'turnstileRequired' => 'turnstileRequired',
              'unsupportedChallenge' => 'challengeUnsupported',
              'network' => 'networkError',
              _ => 'loginError',
            }
          : 'loginError';
      final message = DlsiteLoginLabels.get(context, key);
      final details =
          error is DlsitePlayException &&
              error.host != null &&
              error.status != null
          ? ' (${error.host}, HTTP ${error.status})'
          : '';
      final browserVerification = const {
        'cloudflareChallenge',
        'recaptchaRequired',
        'turnstileRequired',
      }.contains(key);
      _showError(
        '$message$details',
        action: browserVerification
            ? SnackBarAction(
                label: DlsiteLoginLabels.get(context, 'openBrowser'),
                onPressed: _openBrowser,
              )
            : null,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _requestOtp() async {
    if (!mounted) return null;
    var input = '';
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(DlsiteLoginLabels.get(context, 'otpTitle')),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onChanged: (value) => input = value,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          decoration: InputDecoration(
            hintText: DlsiteLoginLabels.get(context, 'otpHint'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(DlsiteLoginLabels.get(context, 'otpCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(input),
            child: Text(DlsiteLoginLabels.get(context, 'otpSubmit')),
          ),
        ],
      ),
    );
    if (!mounted || code == null) return null;
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      _showError(DlsiteLoginLabels.get(context, 'otpError'));
      return null;
    }
    return trimmed;
  }

  Future<bool> _openExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _openBrowser() async {
    if (_busy) return;
    final opened = await _openExternal(Uri.parse(DlsitePlaySession.origin));
    if (!mounted) return;
    if (opened) {
      _selectMode(true);
    } else {
      _showError(DlsiteLoginLabels.get(context, 'browserOpenError'));
    }
  }

  Future<void> _openTutorial() async {
    final opened = await _openExternal(
      Uri.https(
        'github.com',
        '/chenflxs/kikoeta/blob/main/docs/dlsite play登录指引.md',
      ),
    );
    if (mounted && !opened) {
      _showError(DlsiteLoginLabels.get(context, 'tutorialOpenError'));
    }
  }

  void _showError(String message, {SnackBarAction? action}) {
    if (!widget.activateOnSignIn) {
      setState(() {
        _sheetError = message;
        _sheetErrorAction = action;
      });
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  String _label(String key) => DlsiteLoginLabels.get(context, key);

  void _selectMode(bool cookieLogin) {
    if (_busy || _cookieLogin == cookieLogin) return;
    setState(() {
      _cookieLogin = cookieLogin;
      _sheetError = null;
      _sheetErrorAction = null;
    });
  }

  List<Widget> _form({required bool inSheet}) {
    final passwordToggle = IconButton(
      onPressed: _busy
          ? null
          : () => setState(() => _obscurePassword = !_obscurePassword),
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        size: 19,
        color: p.dim,
      ),
    );

    Widget field(
      TextEditingController controller, {
      required String label,
      String? hint,
      required IconData icon,
      bool obscure = false,
      Widget? suffix,
      bool last = false,
    }) {
      final action = last ? TextInputAction.done : TextInputAction.next;
      return inSheet
          ? sheetField(
              context,
              label,
              controller,
              hint: hint,
              enabled: !_busy,
              obscure: obscure,
              suffix: suffix,
              textInputAction: action,
              onSubmitted: last ? (_) => _login() : null,
            )
          : LoginField(
              controller,
              hint: hint ?? label,
              icon: icon,
              enabled: !_busy,
              obscure: obscure,
              suffix: suffix,
              textInputAction: action,
              onSubmitted: last ? (_) => _login() : null,
            );
    }

    final submitLabel = _label(_cookieLogin ? 'loginCookie' : 'login');
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: inSheet ? WrapAlignment.start : WrapAlignment.center,
        children: [
          Pill(
            label: _label('credentials'),
            selected: !_cookieLogin,
            wrapLabel: true,
            onTap: () => _selectMode(false),
          ),
          Pill(
            label: _label('cookie'),
            selected: _cookieLogin,
            wrapLabel: true,
            onTap: () => _selectMode(true),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (!_cookieLogin) ...[
        field(_id, label: _label('id'), icon: Icons.person_outline),
        field(
          _password,
          label: _label('password'),
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffix: passwordToggle,
          last: true,
        ),
      ] else ...[
        Text(
          _label('cookieInstructions'),
          style: TextStyle(fontSize: 12, color: p.muted),
        ),
        const SizedBox(height: 10),
        field(
          _cookie,
          label: _label('cookie'),
          hint: _label('cookieHint'),
          icon: Icons.cookie_outlined,
          obscure: true,
          last: true,
        ),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _secondaryAction(
              _label('openBrowser'),
              _busy ? null : _openBrowser,
            ),
            _secondaryAction(_label('openTutorial'), _openTutorial),
          ],
        ),
      ],
      if (inSheet) ...[
        if (_sheetError case final message?) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(message, style: TextStyle(fontSize: 12, color: p.red)),
          ),
          if (_sheetErrorAction case final action?)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _secondaryAction(action.label, action.onPressed),
            ),
        ],
        ElevatedButton(
          onPressed: _busy ? null : _login,
          style: formSheetActionStyle(p),
          child: Text(_busy ? _label('connecting') : submitLabel),
        ),
      ] else ...[
        const SizedBox(height: 6),
        LoginSubmitButton(label: submitLabel, busy: _busy, onPressed: _login),
      ],
    ];
  }

  Widget _secondaryAction(String label, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: p.dim,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      minimumSize: const Size(0, 30),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12),
    ),
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    if (!widget.activateOnSignIn) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: formSheet(
          context: context,
          title: _label('title'),
          children: _form(inSheet: true),
        ),
      );
    }

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
                      Center(
                        child: Text(
                          _label('title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      ..._form(inSheet: false),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(top: 8, left: 8, child: BackButton()),
          ],
        ),
      ),
    );
  }
}
