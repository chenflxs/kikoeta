import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' as html;

import '../data.dart';
import '../l10n/app_language.dart';

part 'dlsite_play_login.dart';

/// One authenticated DLsite Play library. Media references stay independent of
/// the session cookie and signed URL lifetime.
class DlsitePlaySession {
  DlsitePlaySession._([this._playCookie = '', this._downloadCookie = '']);

  static const origin = 'https://play.dlsite.com';
  static const downloadOrigin = 'https://play.dl.dlsite.com';
  static const hiddenList = 'dlsite:hidden';
  static const favoritesList = 'dlsite:favorites';
  static const mediaScheme = 'dlsite-play';
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'dlsite_play_session';
  static final _workNumber = RegExp(r'^(RJ|VJ|BJ)(\d{6}|\d{8})$');
  static const _idBlock = 100000000;

  static DlsitePlaySession? active;

  String _playCookie;
  String _downloadCookie;
  final _cookies = DefaultCookieJar();
  bool _closed = false;
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final _manifests = <String, Future<List<MediaNode>>>{};
  final _signatures = <String, Future<_MediaSignature>>{};
  Future<List<_Purchase>>? _library;
  Future<Set<String>>? _hidden;
  Future<List<_MyList>>? _lists;
  Future<_MyList>? _favorites;
  DateTime? _libraryAt;
  DateTime? _hiddenAt;
  DateTime? _listsAt;
  Future<void> _libraryChanges = Future.value();

  static Future<DlsitePlaySession> login(
    String id,
    String password, {
    String? proxy,
    required Future<String?> Function() requestOtp,
  }) async {
    final session = DlsitePlaySession._()..setProxy(proxy);
    try {
      final login = _DlsiteLogin(session._http, session._cookies);
      await login.run(id.trim(), password, requestOtp);
      try {
        await session._verifyAuthorization('invalidCredentials');
      } on DlsitePlayException catch (error) {
        if (error.code != 'invalidCredentials') rethrow;
        await login.connectPlay();
        await session._verifyAuthorization('invalidCredentials');
      }
      return session;
    } catch (_) {
      session.close();
      rethrow;
    }
  }

  static Future<DlsitePlaySession> authenticate(
    String cookieHeader, {
    String downloadCookieHeader = '',
    String? proxy,
  }) async {
    final play = _parseCookieHeader(cookieHeader);
    final download = downloadCookieHeader.trim().isEmpty
        ? ''
        : _parseCookieHeader(downloadCookieHeader);
    final session = DlsitePlaySession._(play, download);
    session.setProxy(proxy);
    try {
      await session._verifyAuthorization('invalidCookie');
      return session;
    } catch (_) {
      session.close();
      rethrow;
    }
  }

  Future<void> _verifyAuthorization(String invalidCode) async {
    final invalid = DlsitePlayException(
      'DLsite Play did not authorize the session.',
      code: invalidCode,
    );
    try {
      final result = await _request(origin, '/api/authorize');
      if (result is! Map || result['customer_id'] == null) throw invalid;
    } on DlsitePlayException catch (error) {
      if (error.status == HttpStatus.unauthorized &&
          error.code != 'cloudflareChallenge') {
        throw invalid;
      }
      rethrow;
    }
  }

  static Future<DlsitePlaySession?> restore() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;
    final json = jsonDecode(raw);
    if (json is! Map || json['play'] is! String) return null;
    return DlsitePlaySession._(
      json['play'] as String,
      json['download'] as String? ?? '',
    );
  }

  Future<void> save() async {
    final play = await _cookieHeader(Uri.parse('$origin/api/authorize'));
    final download = await _cookieHeader(
      Uri.parse('$downloadOrigin/api/v3/download/sign/cookie'),
    );
    await _storage.write(
      key: _storageKey,
      value: jsonEncode({'play': play, 'download': download}),
    );
  }

  Future<String> _cookieHeader(
    Uri uri, [
    Map<String, String> overrides = const {},
  ]) async {
    final manual = uri.origin == origin ? _playCookie : _downloadCookie;
    final cookies = <String, String>{
      ..._cookiePairs(manual),
      for (final cookie in await _cookies.loadForRequest(uri))
        cookie.name: cookie.value,
      ...overrides,
    };
    return cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  static String _parseCookieHeader(String input) {
    final value = input.trim().replaceFirst(
      RegExp(r'^cookie:\s*', caseSensitive: false),
      '',
    );
    final pairs = _cookiePairs(value);
    if (value.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        pairs.isEmpty ||
        value.split(';').where((part) => part.trim().isNotEmpty).length !=
            pairs.length) {
      throw const DlsitePlayException(
        'Paste a DLsite Play Cookie header.',
        code: 'invalidCookie',
      );
    }
    return pairs.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }

  static Map<String, String> _cookiePairs(String value) {
    final pairs = <String, String>{};
    final namePattern = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
    for (final raw in value.split(';')) {
      final part = raw.trim();
      final separator = part.indexOf('=');
      if (separator < 1) continue;
      final name = part.substring(0, separator);
      if (namePattern.hasMatch(name)) {
        pairs[name] = part.substring(separator + 1);
      }
    }
    return pairs;
  }

  static Future<void> forget() => _storage.delete(key: _storageKey);

  void setProxy(String? proxy) {
    final uri = Uri.tryParse(proxy ?? '');
    _http.findProxy = uri != null && uri.host.isNotEmpty && uri.scheme == 'http'
        ? (_) => 'PROXY ${uri.host}:${uri.port}'
        : HttpClient.findProxyFromEnvironment;
  }

  void close() {
    _closed = true;
    _http.close(force: true);
    _playCookie = '';
    _downloadCookie = '';
    _cookies.deleteAll();
    _library = null;
    _hidden = null;
    _lists = null;
    _favorites = null;
    _manifests.clear();
    _signatures.clear();
  }

  Future<dynamic> _request(
    String base,
    String path, {
    String method = 'GET',
    Map<String, String>? query,
    Object? body,
    Map<String, String>? signedCookies,
  }) => _json(
    Uri.parse(base).replace(path: path, queryParameters: query),
    method: method,
    body: body,
    signedCookies: signedCookies,
  );

  Future<dynamic> _json(
    Uri uri, {
    String method = 'GET',
    Object? body,
    Map<String, String>? signedCookies,
    Map<String, String> cookieOverride = const {},
  }) async {
    if (_closed) throw const DlsitePlayException('DLsite Play session closed.');
    final host = uri.origin;
    if (host != origin && host != downloadOrigin) {
      throw const FormatException('Unexpected DLsite Play host.');
    }
    try {
      return await (() async {
        final request = await _http.openUrl(method, uri);
        request.followRedirects = false;
        request.headers
          ..set(HttpHeaders.acceptHeader, 'application/json')
          ..set(HttpHeaders.refererHeader, '$origin/')
          ..set('Origin', origin);
        final cookie = await _cookieHeader(uri, cookieOverride);
        if (cookie.isNotEmpty) {
          request.headers.set(HttpHeaders.cookieHeader, cookie);
        }
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        final failure = _dlsiteHttpFailure(uri, response);
        if (failure != null) {
          await response.drain<void>();
          throw failure;
        }
        final text = await utf8.decoder.bind(response).join();
        if (signedCookies != null) {
          for (final cookie in response.cookies) {
            signedCookies[cookie.name] = cookie.value;
          }
        }
        // CDN signatures can be scoped to a single work, so keep them on the
        // manifest request that obtained them.
        if (host == origin) {
          await _cookies.saveFromResponse(uri, response.cookies);
        }
        final data = text.isEmpty ? null : jsonDecode(text);
        if (data is Map && data['success'] == false) {
          throw const DlsitePlayException('DLsite Play rejected the change.');
        }
        return data;
      })().timeout(const Duration(seconds: 45));
    } on DlsitePlayException {
      rethrow;
    } catch (_) {
      // HTTP exceptions can include the full signed URL.
      throw const DlsitePlayException(
        'Could not read the DLsite Play response.',
        code: 'network',
      );
    }
  }

  Future<List<_Purchase>> _purchases() async {
    final cached = _library;
    if (cached != null && _recent(_libraryAt, const Duration(minutes: 2))) {
      return cached;
    }
    final future = _loadPurchases();
    _library = future;
    _libraryAt = DateTime.now();
    try {
      return await future;
    } catch (_) {
      if (identical(_library, future)) _library = null;
      rethrow;
    }
  }

  Future<List<_Purchase>> _loadPurchases() async {
    final count = _map(
      await _request(origin, '/api/v4/content/count', query: {'last': '0'}),
    );
    final batchSize = (_integer(count['page_limit']) ?? 100).clamp(1, 100);
    final purchases = <String, _Purchase>{};
    if ((_integer(count['user']) ?? 0) > 0) {
      final sales = _array(
        await _request(origin, '/api/v4/content/sales', query: {'last': '0'}),
      );
      final dates = <String, String>{
        for (final item in sales.map(_map))
          if (item['workno'] is String)
            item['workno'] as String: _string(item['sales_date']),
      };
      final ids = dates.keys.toList();
      for (var offset = 0; offset < ids.length; offset += batchSize) {
        final response = _map(
          await _request(
            origin,
            '/api/v4/content/works',
            method: 'POST',
            body: {'worknos': ids.skip(offset).take(batchSize).toList()},
          ),
        );
        for (final raw in _array(response['works']).map(_map)) {
          final number = _string(raw['workno']);
          final work = _audioWork(raw, purchasedAt: dates[number] ?? '');
          if (work != null) purchases[number] = work;
        }
      }
    }
    final production = _integer(count['production']) ?? 0;
    for (var offset = 0; offset < production; offset += batchSize) {
      final response = _map(
        await _request(
          origin,
          '/api/v4/content/products',
          query: {'page': '${offset ~/ batchSize + 1}', 'last': '0'},
        ),
      );
      for (final raw in _array(response['works']).map(_map)) {
        final work = _audioWork(raw, purchasedAt: _string(raw['sales_date']));
        if (work != null) purchases.putIfAbsent(work.work.rj, () => work);
      }
    }
    return purchases.values.toList();
  }

  Future<Set<String>> _hiddenWorks() async {
    final cached = _hidden;
    if (cached != null && _recent(_hiddenAt, const Duration(seconds: 30))) {
      return cached;
    }
    final future = _loadHiddenWorks();
    _hidden = future;
    _hiddenAt = DateTime.now();
    try {
      return await future;
    } catch (_) {
      if (identical(_hidden, future)) _hidden = null;
      rethrow;
    }
  }

  Future<Set<String>> _loadHiddenWorks() async {
    final result = _map(await _request(origin, '/api/ignore'));
    return _array(result['works']).whereType<String>().toSet();
  }

  Future<List<_MyList>> _myLists() async {
    final cached = _lists;
    if (cached != null && _recent(_listsAt, const Duration(seconds: 30))) {
      return cached;
    }
    final future = _loadLists();
    _lists = future;
    _listsAt = DateTime.now();
    try {
      return await future;
    } catch (_) {
      if (identical(_lists, future)) _lists = null;
      rethrow;
    }
  }

  Future<List<_MyList>> _loadLists() async {
    final response = _map(await _request(origin, '/api/mylists'));
    return [
      for (final raw in _array(response['mylists']).map(_map))
        if (raw['id'] != null)
          _MyList(
            raw['id'].toString(),
            _string(raw['title']),
            _array(raw['data']).whereType<String>().toSet(),
          ),
    ];
  }

  Future<_MyList> _favoriteList() async {
    final pending = _favorites;
    if (pending != null) return pending;
    final future = _findOrCreateFavorites();
    _favorites = future;
    try {
      return await future;
    } finally {
      if (identical(_favorites, future)) _favorites = null;
    }
  }

  Future<_MyList> _findOrCreateFavorites() async {
    final existing = (await _myLists())
        .where((list) => list.title == 'Favorites')
        .firstOrNull;
    if (existing != null) return existing;
    try {
      final id = await createList('Favorites');
      return _MyList(id, 'Favorites', {});
    } on DlsitePlayException {
      _lists = null;
      final created = (await _myLists())
          .where((list) => list.title == 'Favorites')
          .firstOrNull;
      if (created != null) return created;
      rethrow;
    }
  }

  Future<List<Work>> works({
    String? listId,
    String query = '',
    String order = 'collect',
    bool ascending = false,
    int seed = 0,
    Set<int> ages = const {},
    bool sfw = false,
  }) async {
    final (purchases, hidden) = await (_purchases(), _hiddenWorks()).wait;
    final Set<String>? members;
    if (listId == hiddenList) {
      members = hidden;
    } else if (listId != null) {
      members = (await _findList(listId)).members;
    } else {
      members = null;
    }
    final terms = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'[\s,，]+'))
        .where((term) => term.isNotEmpty);
    final filtered = purchases.where((purchase) {
      final work = purchase.work;
      if (listId != hiddenList && hidden.contains(work.rj)) return false;
      if (members != null && !members.contains(work.rj)) return false;
      if (sfw && (!work.ageKnown || work.age != Age.all)) return false;
      if (ages.isNotEmpty &&
          (!work.ageKnown || !ages.contains(work.age.index))) {
        return false;
      }
      return terms.every(purchase.searchText.contains);
    }).toList();
    if (members != null && listId != hiddenList) {
      final byNumber = {
        for (final purchase in filtered) purchase.work.rj: purchase.work,
      };
      return [for (final id in members) ?byNumber[id]];
    }
    filtered.sort((a, b) {
      final value = switch (order) {
        'date' => a.work.releaseDate.compareTo(b.work.releaseDate),
        'rj' => a.work.apiId!.compareTo(b.work.apiId!),
        'random' => _shuffleKey(
          a.work.rj,
          seed,
        ).compareTo(_shuffleKey(b.work.rj, seed)),
        _ => a.purchasedAt.compareTo(b.purchasedAt),
      };
      final compared = value == 0 ? a.work.rj.compareTo(b.work.rj) : value;
      return ascending ? compared : -compared;
    });
    return [for (final purchase in filtered) purchase.work];
  }

  static int _shuffleKey(String number, int seed) {
    var value = seed & 0x7fffffff;
    for (final code in number.codeUnits) {
      value = ((value ^ code) * 16777619) & 0x7fffffff;
    }
    return value;
  }

  Future<Work> work(int id) async {
    final number = numberForId(id);
    final (raw, hidden) = await (
      _request(origin, '/api/v4/work/$number'),
      _hiddenWorks(),
    ).wait;
    final status = hidden.contains(number)
        ? 'hidden'
        : await _viewingProgress(number);
    final mapped = _audioWork(
      _map(raw),
      progress: status,
      favorite: await _readFavorite(number),
    );
    if (mapped == null) {
      throw const DlsitePlayException('This work has no supported audio.');
    }
    return mapped.work;
  }

  Future<bool?> _readFavorite(String number) async {
    try {
      final lists = await _myLists();
      final favorites = lists
          .where((list) => list.title == 'Favorites')
          .firstOrNull;
      return favorites?.members.contains(number) ?? false;
    } on DlsitePlayException {
      return null;
    }
  }

  Future<String> _viewingProgress(String number) async {
    try {
      final raw = _map(
        await _request(origin, '/api/reading_activities/$number'),
      );
      return _integer(raw['progress_status']) == 2 ? 'listened' : 'unwatched';
    } on DlsitePlayException catch (error) {
      if (error.status == 404) return 'unwatched';
      rethrow;
    }
  }

  Future<T> _changeLibrary<T>(Future<T> Function() operation) {
    final result = _libraryChanges.then((_) => operation());
    _libraryChanges = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> setProgress(String number, String progress) =>
      _changeLibrary(() => _setProgress(number, progress));

  Future<void> _setProgress(String number, String progress) async {
    if (!_workNumber.hasMatch(number)) {
      throw const FormatException('Invalid DLsite work number.');
    }
    if (progress == 'hidden') {
      _hidden = null;
      final hidden = await _hiddenWorks();
      if (hidden.contains(number)) return;
      await _request(
        origin,
        '/api/ignore',
        method: 'POST',
        body: {
          'works': {...hidden, number}.toList(),
        },
      );
      _hidden = null;
      return;
    }
    if (progress != 'listened' && progress != 'unwatched') {
      throw ArgumentError.value(progress, 'progress');
    }
    await _request(
      origin,
      '/api/reading_activities/status',
      method: 'PUT',
      body: {
        'worknos': [number],
        'progress_status': progress == 'listened' ? 2 : 0,
      },
    );
    if ((await _hiddenWorks()).contains(number)) await _restoreWorks([number]);
  }

  Future<void> _restoreWorks(List<String> numbers) async {
    final works = numbers.map(_normalizeNumber).toSet().toList();
    await _request(
      origin,
      '/api/ignore',
      method: 'DELETE',
      body: {'works': works},
    );
    _hidden = null;
  }

  Future<_MyList> _findList(String id) async {
    if (id == favoritesList) return _favoriteList();
    final list = (await _myLists()).where((list) => list.id == id).firstOrNull;
    if (list == null) {
      throw const DlsitePlayException('DLsite Play list unavailable.');
    }
    return list;
  }

  Future<List<PlaylistInfo>> playlists(String hiddenLabel) async {
    final (purchases, hidden, lists) = await (
      _purchases(),
      _hiddenWorks(),
      _myLists(),
    ).wait;
    final works = {
      for (final purchase in purchases) purchase.work.rj: purchase.work,
    };
    return [
      PlaylistInfo(
        id: hiddenList,
        name: hiddenLabel,
        worksCount: hidden.where(works.containsKey).length,
        isSystem: true,
      ),
      for (final list in lists)
        if (list.title != 'Favorites')
          PlaylistInfo(
            id: list.id,
            name: list.title,
            isOwned: true,
            worksCount: list.members
                .where((id) => works.containsKey(id) && !hidden.contains(id))
                .length,
            coverUrl: list.members
                .where((id) => !hidden.contains(id))
                .map((id) => works[id]?.coverUrl)
                .whereType<String>()
                .firstOrNull,
          ),
    ];
  }

  Future<String> createList(String title) async {
    final response = _map(
      await _request(
        origin,
        '/api/mylists',
        method: 'POST',
        body: {'title': title},
      ),
    );
    _lists = null;
    return response['mylist_id']?.toString() ??
        (throw const FormatException('Missing DLsite Play list ID.'));
  }

  Future<void> renameList(String id, String title) async {
    await _request(
      origin,
      '/api/mylists/${_listId(id)}',
      method: 'PUT',
      body: {'title': title},
    );
    _lists = null;
  }

  Future<void> deleteList(String id) async {
    await _request(origin, '/api/mylists/${_listId(id)}', method: 'DELETE');
    _lists = null;
  }

  Future<bool> toggleFavorite(String number) => _changeLibrary(() async {
    final list = await _favoriteList();
    final add = !list.members.contains(number);
    await _changeListWorks(list, [number], add: add);
    return add;
  });

  Future<void> changeList(
    String id,
    List<String> numbers, {
    required bool add,
  }) => _changeLibrary(() async {
    if (id == hiddenList && !add) return _restoreWorks(numbers);
    await _changeListWorks(await _findList(id), numbers, add: add);
  });

  Future<void> _changeListWorks(
    _MyList list,
    List<String> numbers, {
    required bool add,
  }) async {
    final path = '/api/mylists/${_listId(list.id)}/works';
    final unique = numbers.map(_normalizeNumber).toSet();
    try {
      for (final number in unique) {
        if (list.members.contains(number) == add) continue;
        if (add) {
          await _request(
            origin,
            path,
            method: 'POST',
            body: {'workno': number},
          );
        } else {
          await _request(origin, '$path/$number', method: 'DELETE');
        }
      }
    } finally {
      _lists = null;
    }
  }

  Future<List<MediaNode>> tracks(int id, {bool forceRefresh = false}) async {
    final number = numberForId(id);
    if (forceRefresh) _manifests.remove(number);
    if (_manifests.length >= 10 && !_manifests.containsKey(number)) {
      _manifests.remove(_manifests.keys.first);
    }
    final pending = _manifests.putIfAbsent(number, () => _loadTracks(number));
    try {
      return await pending;
    } catch (_) {
      if (identical(_manifests[number], pending)) _manifests.remove(number);
      rethrow;
    }
  }

  Future<List<MediaNode>> _loadTracks(String number) async {
    final signature = await _signature(number);
    Map<String, dynamic> manifest;
    try {
      manifest = _map(
        await _json(_mediaUri(number, ['ziptree.json'], signature.params)),
      );
    } on DlsitePlayException {
      // The manifest may require the Play CDN's separate signed cookie.
      final cookies = <String, String>{};
      final response = _map(
        await _request(
          downloadOrigin,
          '/api/v3/download/sign/cookie',
          query: {'workno': number},
          signedCookies: cookies,
        ),
      );
      final url = Uri.tryParse(_string(response['url']));
      final source = url != null && url.origin == downloadOrigin
          ? url.resolve('ziptree.json')
          : _mediaUri(number, ['ziptree.json'], const {});
      manifest = _map(await _json(source, cookieOverride: cookies));
    }
    if (manifest['workno'] case final String actual when actual != number) {
      throw const FormatException(
        'DLsite Play manifest belongs to another work.',
      );
    }
    final files = _map(manifest['playfile']);
    final revision = _string(manifest['revision']);
    List<MediaNode> parse(List<dynamic> nodes, String parent) => [
      for (final item in nodes.map(_map))
        ?_mediaNode(number, item, files, parent, revision, parse),
    ];
    return parse(_array(manifest['tree']), '');
  }

  static MediaNode? _mediaNode(
    String number,
    Map<String, dynamic> raw,
    Map<String, dynamic> files,
    String parent,
    String revision,
    List<MediaNode> Function(List<dynamic>, String) parse,
  ) {
    final name = _string(raw['name']);
    if (name.isEmpty) return null;
    final path = parent.isEmpty ? name : '$parent/$name';
    if (raw['type'] == 'folder') {
      final children = parse(_array(raw['children']), path);
      return children.isEmpty
          ? null
          : MediaNode(
              title: name,
              type: 'folder',
              path: path,
              children: children,
            );
    }
    final audio = _map(_map(files[raw['hashname']])['audio']);
    final optimized = _map(audio['optimized']);
    final file = _string(optimized['name']);
    if (raw['type'] != 'file' || !_safeMediaName(file)) return null;
    final url = Uri(
      scheme: mediaScheme,
      host: number.toLowerCase(),
      pathSegments: [file],
      queryParameters: revision.isEmpty ? null : {'v': revision},
    ).toString();
    return MediaNode(
      title: name,
      type: 'file',
      path: path,
      url: url,
      downloadUrl: url,
      duration: _integer(optimized['duration']) ?? 0,
    );
  }

  Future<String> resolveMedia(String url) async {
    final ref = Uri.parse(url);
    final number = ref.host.toUpperCase();
    if (ref.scheme != mediaScheme ||
        !_workNumber.hasMatch(number) ||
        ref.pathSegments.length != 1 ||
        !_safeMediaName(ref.pathSegments.single)) {
      throw const FormatException('Invalid DLsite Play audio reference.');
    }
    final signature = await _signature(number);
    final version = ref.queryParameters['v'];
    return _mediaUri(
      number,
      ['optimized', ref.pathSegments.single],
      {'v': ?version, ...signature.params},
    ).toString();
  }

  Future<_MediaSignature> _signature(String number) async {
    final cached = _signatures[number];
    if (cached != null) {
      final signature = await cached;
      if (signature.expires.isAfter(
        DateTime.now().add(const Duration(minutes: 1)),
      )) {
        return signature;
      }
      if (identical(_signatures[number], cached)) _signatures.remove(number);
    }
    if (_signatures.length >= 10 && !_signatures.containsKey(number)) {
      _signatures.remove(_signatures.keys.first);
    }
    final pending = _signatures.putIfAbsent(number, () async {
      final raw = _map(
        await _request(
          origin,
          '/api/v4/download/sign/url',
          query: {'workno': number},
        ),
      );
      final params = _map(
        raw['params'],
      ).map((key, value) => MapEntry(key, value.toString()));
      if (params.isEmpty) {
        throw const FormatException('Missing DLsite Play media signature.');
      }
      return _MediaSignature(
        params,
        DateTime.tryParse(_string(raw['expires'])) ?? DateTime.now(),
      );
    });
    try {
      return await pending;
    } catch (_) {
      if (identical(_signatures[number], pending)) _signatures.remove(number);
      rethrow;
    }
  }

  static Uri _mediaUri(
    String number,
    List<String> path,
    Map<String, String> params,
  ) {
    final prefix = number.substring(0, 2);
    final digits = number.substring(2);
    final batch = ((int.parse(digits) + 999) ~/ 1000 * 1000).toString().padLeft(
      digits.length,
      '0',
    );
    final section = switch (prefix) {
      'RJ' => 'doujin',
      'VJ' => 'professional',
      _ => 'books',
    };
    return Uri.parse(downloadOrigin).replace(
      pathSegments: [
        'content',
        'work',
        section,
        '$prefix$batch',
        number,
        ...path,
      ],
      queryParameters: params,
    );
  }

  static _Purchase? _audioWork(
    Map<String, dynamic> raw, {
    String purchasedAt = '',
    String? progress,
    bool? favorite,
  }) {
    if (!const {'SOU', 'MUS'}.contains(raw['work_type'])) return null;
    final number = _string(raw['workno']);
    final id = idForNumber(number);
    if (id == null) return null;
    final title = _localized(raw['name']);
    final maker = _map(raw['original_maker'] ?? raw['maker']);
    final circle = _localized(maker['name']);
    final tags = <String>[];
    final voices = <String>[];
    for (final tag in _array(raw['tags']).map(_map)) {
      final label = _localized(tag['name']);
      if (label.isEmpty) continue;
      if (tag['class'] == 'voice_by') {
        voices.add(label);
      } else {
        tags.add(label);
      }
    }
    final category = _string(raw['age'] ?? raw['age_category']).toLowerCase();
    final age = switch (category) {
      'r18' || 'adult' => Age.r18,
      'r15' => Age.r15,
      _ => Age.all,
    };
    final image = _string(_map(raw['images'])['main']);
    final cover = Uri.tryParse(image.startsWith('//') ? 'https:$image' : image);
    final release = _string(raw['release_date'] ?? raw['regist_date']);
    final work = Work(
      rj: number,
      apiId: id,
      title: title.isEmpty ? number : title,
      circle: circle,
      va: voices.isEmpty ? '' : 'CV. ${voices.join(' / ')}',
      age: age,
      ageKnown: const {
        'r18',
        'adult',
        'r15',
        'all',
        'general',
      }.contains(category),
      dur: '',
      releaseDate: release.split('T').first,
      tags: tags,
      grad: id % 8,
      coverUrl: cover?.scheme == 'https' ? cover.toString() : null,
      progress: progress,
      hasReview: favorite,
    );
    return _Purchase(
      work,
      purchasedAt,
      [
        number,
        title,
        circle,
        ...voices,
        ...tags,
        ..._map(raw['name']).values.whereType<String>(),
        ..._map(maker['name']).values.whereType<String>(),
      ].join('\n').toLowerCase(),
    );
  }

  // Preserve the original work number, including older 6-digit releases and
  // distinct product prefixes, in the app's existing numeric API ID field.
  static int? idForNumber(String number) {
    if (!_workNumber.hasMatch(number)) return null;
    final prefix = const ['RJ', 'VJ', 'BJ'].indexOf(number.substring(0, 2));
    final digits = number.substring(2);
    return (prefix * 2 + (digits.length == 8 ? 1 : 0)) * _idBlock +
        int.parse(digits);
  }

  static String numberForId(int id) {
    final format = id ~/ _idBlock;
    if (id < 0 || format >= 6) {
      throw const FormatException('Invalid DLsite work ID.');
    }
    final prefix = const ['RJ', 'VJ', 'BJ'][format ~/ 2];
    return prefix +
        (id % _idBlock).toString().padLeft(format.isOdd ? 8 : 6, '0');
  }

  static String _listId(String id) => int.parse(id).toString();
  static String _normalizeNumber(String value) {
    final id = int.tryParse(value);
    final number = id == null ? value.toUpperCase() : numberForId(id);
    if (!_workNumber.hasMatch(number)) {
      throw const FormatException('Invalid DLsite work number.');
    }
    return number;
  }

  static bool _recent(DateTime? time, Duration ttl) =>
      time != null && DateTime.now().difference(time) < ttl;
  static bool _safeMediaName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains('/') &&
      !name.contains('\\');
  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};
  static List<dynamic> _array(Object? value) =>
      value is List ? value : const [];
  static String _string(Object? value) => value is String ? value : '';
  static int? _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value.toString());

  static String _localized(Object? value) {
    if (value is String) return value;
    final names = _map(value);
    final locale = AppLanguage.resolvedLocale;
    final key = switch (locale.languageCode) {
      'zh' => locale.scriptCode == 'Hant' ? 'zh_TW' : 'zh_CN',
      'en' => 'en_US',
      _ => 'ja_JP',
    };
    return _string(names[key] ?? names['ja_JP'] ?? names.values.firstOrNull);
  }
}

class DlsitePlayException implements Exception {
  const DlsitePlayException(this.message, {this.status, this.code, this.host});
  final String message;
  final int? status;
  final String? code;
  final String? host;
  @override
  String toString() => message;
}

DlsitePlayException? _dlsiteHttpFailure(
  Uri uri,
  HttpClientResponse response, {
  bool allowRedirect = false,
}) {
  final status = response.statusCode;
  final challenged =
      response.headers.value('cf-mitigated')?.trim().toLowerCase() ==
      'challenge';
  final code = switch (status) {
    _ when challenged => 'cloudflareChallenge',
    HttpStatus.forbidden => 'loginForbidden',
    HttpStatus.tooManyRequests => 'rateLimited',
    >= 500 && < 600 => 'serviceUnavailable',
    >= 200 && < 300 => null,
    >= 300 && < 400 when allowRedirect => null,
    _ => 'network',
  };
  if (code == null) return null;
  return DlsitePlayException(
    'DLsite request failed (${uri.host}, HTTP $status).',
    status: status,
    code: code,
    host: uri.host,
  );
}

class _Purchase {
  const _Purchase(this.work, this.purchasedAt, this.searchText);
  final Work work;
  final String purchasedAt;
  final String searchText;
}

class _MyList {
  const _MyList(this.id, this.title, this.members);
  final String id;
  final String title;
  final Set<String> members;
}

class _MediaSignature {
  const _MediaSignature(this.params, this.expires);
  final Map<String, String> params;
  final DateTime expires;
}
