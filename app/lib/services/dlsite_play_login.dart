part of 'dlsite_play_service.dart';

/// Handles only the provider's first-party form and authorization redirects.
class _DlsiteLogin {
  _DlsiteLogin(this.client, this.cookies);

  static final _login = Uri.https('login.dlsite.com', '/login', {
    'user': 'self',
  });
  static final _storeLogin = Uri.https(
    'www.dlsite.com',
    '/home/login/=/skip_register/1',
  );
  static final _storeFinish = Uri.https('www.dlsite.com', '/home/login/finish');
  static final _playLogin = Uri.https('play.dlsite.com', '/login/');
  static const _allowedHosts = {
    'login.dlsite.com',
    'www.dlsite.com',
    'play.dlsite.com',
  };

  final HttpClient client;
  final DefaultCookieJar cookies;

  Future<void> run(
    String id,
    String password,
    Future<String?> Function() requestOtp,
  ) async {
    const invalid = DlsitePlayException(
      'DLsite rejected the login.',
      code: 'invalidCredentials',
    );
    if (id.isEmpty || password.isEmpty) throw invalid;

    final (loginUri, loginPage) = await _follow(_login);
    final page = html.parse(loginPage.body);
    final form = _formContaining(page.querySelector('input[name="login_id"]'));
    final token = form
        ?.querySelector('input[name="_token"]')
        ?.attributes['value'];
    if (form == null || token == null || token.isEmpty) {
      throw _unrecognizedForm(loginUri, page);
    }
    final action = _formAction(loginUri, form.attributes['action']);
    final response = await _send(
      action,
      fields: {'_token': token, 'login_id': id, 'password': password},
    );
    final next = response.next;
    if (next != null && _isOtp(next)) {
      await _submitOtp(next, requestOtp);
    } else if (next == null || _isLoginPage(next)) {
      throw invalid;
    }
    await _follow(_storeLogin);
    await _follow(_storeFinish);
  }

  Future<void> connectPlay() async {
    await _follow(_playLogin);
  }

  Future<void> _submitOtp(
    Uri challenge,
    Future<String?> Function() requestOtp,
  ) async {
    final (uri, response) = await _follow(challenge);
    final page = html.parse(response.body);
    final form = _formContaining(page.querySelector('input[name="otp"]'));
    if (form == null) {
      throw _unrecognizedForm(uri, page);
    }
    final action = _formAction(uri, form.attributes['action']);
    final fields = <String, String>{};
    for (final input in form.querySelectorAll('input[type="hidden"][name]')) {
      final name = input.attributes['name']!;
      if (name != 'otp') fields[name] = input.attributes['value'] ?? '';
    }
    final code = (await requestOtp())?.trim();
    if (code == null || code.isEmpty) {
      throw const DlsitePlayException(
        'DLsite login cancelled.',
        code: 'cancelled',
      );
    }
    final result = await _send(action, fields: {...fields, 'otp': code});
    final next = result.next;
    if (next == null || _isOtp(next) || _isLoginPage(next)) {
      throw const DlsitePlayException(
        'DLsite rejected the verification code.',
        code: 'invalidOtp',
      );
    }
  }

  static bool _isOtp(Uri uri) =>
      uri.host == 'login.dlsite.com' &&
      uri.path.startsWith('/login/two-factor');

  static bool _isLoginPage(Uri uri) =>
      uri.host == 'login.dlsite.com' &&
      const {'/login', '/login/'}.contains(uri.path);

  static DlsitePlayException _unrecognizedForm(Uri uri, Document page) {
    final String code;
    if (page.querySelector('.cf-turnstile[data-sitekey]') != null) {
      code = 'turnstileRequired';
    } else if (page.querySelector('.g-recaptcha[data-sitekey]') != null) {
      code = 'recaptchaRequired';
    } else {
      code = 'unsupportedChallenge';
    }
    return DlsitePlayException(
      'DLsite did not return a recognized login form.',
      host: uri.host,
      code: code,
    );
  }

  static Element? _formContaining(Element? field) {
    for (
      var element = field?.parent;
      element != null;
      element = element.parent
    ) {
      if (element.localName == 'form') return element;
    }
    return null;
  }

  static Uri _formAction(Uri page, String? action) {
    final target = page.resolve(action ?? '');
    if (target.origin != 'https://login.dlsite.com') {
      throw const DlsitePlayException(
        'Unexpected DLsite login form destination.',
        code: 'unsupportedChallenge',
      );
    }
    return target;
  }

  Future<(Uri, _LoginResponse)> _follow(Uri start) async {
    var uri = start;
    for (var redirects = 0; redirects < 12; redirects++) {
      final response = await _send(uri);
      final next = response.next;
      if (next == null) return (uri, response);
      uri = next;
    }
    throw const DlsitePlayException(
      'DLsite did not complete authorization.',
      code: 'unsupportedChallenge',
    );
  }

  Future<_LoginResponse> _send(Uri uri, {Map<String, String>? fields}) async {
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !_allowedHosts.contains(uri.host)) {
      throw const DlsitePlayException(
        'Unexpected DLsite login redirect.',
        code: 'unsupportedChallenge',
      );
    }
    try {
      return await _exchange(uri, fields).timeout(const Duration(seconds: 30));
    } on DlsitePlayException {
      rethrow;
    } catch (_) {
      // Raw transport exceptions can contain the OAuth redirect or cookies.
      throw const DlsitePlayException(
        'Could not connect to DLsite.',
        code: 'network',
      );
    }
  }

  Future<_LoginResponse> _exchange(Uri uri, Map<String, String>? fields) async {
    final request = await client.openUrl(fields == null ? 'GET' : 'POST', uri);
    request.followRedirects = false;
    request.headers
      ..set(HttpHeaders.acceptHeader, 'text/html, application/xhtml+xml')
      ..set(HttpHeaders.acceptLanguageHeader, 'ja,en;q=0.8')
      ..set(HttpHeaders.userAgentHeader, 'Kikoeta (DLsite Play)');
    final matched = await cookies.loadForRequest(uri);
    if (matched.isNotEmpty) {
      request.headers.set(
        HttpHeaders.cookieHeader,
        matched.map((c) => '${c.name}=${c.value}').join('; '),
      );
    }
    if (fields != null) {
      request.headers
        ..contentType = ContentType('application', 'x-www-form-urlencoded')
        ..set('Origin', uri.origin)
        ..set(HttpHeaders.refererHeader, uri.toString());
      request.write(Uri(queryParameters: fields).query);
    }
    final response = await request.close();
    final status = response.statusCode;
    final failure = _dlsiteHttpFailure(uri, response, allowRedirect: true);
    if (failure != null) {
      await response.drain<void>();
      throw failure;
    }
    await cookies.saveFromResponse(uri, response.cookies);
    if (status >= 300 && status < 400) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location != null) {
        await response.drain<void>();
        return _LoginResponse(next: uri.resolve(location));
      }
    }
    if (status != 200) {
      await response.drain<void>();
      throw DlsitePlayException(
        'DLsite login request failed (HTTP $status).',
        status: status,
        code: 'network',
        host: uri.host,
      );
    }
    final body = BytesBuilder(copy: false);
    await for (final chunk in response) {
      body.add(chunk);
      if (body.length > 1024 * 1024) {
        throw const DlsitePlayException(
          'DLsite login page is too large.',
          code: 'unsupportedChallenge',
        );
      }
    }
    return _LoginResponse(
      body: utf8.decode(body.takeBytes(), allowMalformed: true),
    );
  }
}

class _LoginResponse {
  const _LoginResponse({this.body = '', this.next});
  final String body;
  final Uri? next;
}
