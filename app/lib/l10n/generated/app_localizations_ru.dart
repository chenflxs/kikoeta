// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get cacheWritebackSourceMissing =>
      'Часть текстов импортирована только локально: исходный сервер не настроен.';

  @override
  String get cacheWritebackLegacyTitle => 'Сервер для записи старого кеша';

  @override
  String get cacheWritebackLegacyHint =>
      'В старом кеше не указан исходный сервер. После выбора будут проверены произведение и пути треков. При несовпадении тексты сохранятся только локально.';

  @override
  String get cacheWritebackLocalOnly => 'Импортировать только локально';

  @override
  String cacheWritebackSummary(String written, String skipped) {
    return 'Записано текстов из кеша: $written; не записано: $skipped.';
  }

  @override
  String get writebackCheck => 'Проверить право записи текстов';

  @override
  String get writebackChecking => 'Проверка права записи текстов…';

  @override
  String get writebackUnknown => 'Право записи текстов не проверено';

  @override
  String get writebackReady => 'Запись текстов разрешена';

  @override
  String get writebackDisabled => 'Запись текстов отключена на сервере';

  @override
  String get writebackUnsupported => 'Сервер не поддерживает запись текстов';

  @override
  String get writebackLoginRequired =>
      'Войдите на этот сервер или обновите учётные данные';

  @override
  String get writebackRoleForbidden => 'У аккаунта нет права записи текстов';

  @override
  String get writebackKeyRequired => 'Введите ключ записи текстов';

  @override
  String get writebackKeyInvalid => 'Неверный ключ записи текстов';

  @override
  String get writebackUnconfigured =>
      'На сервере не настроен ключ записи текстов';

  @override
  String get writebackSourceUnavailable => 'Исходный трек или папка недоступны';

  @override
  String get writebackDirectoryUnwritable =>
      'Невозможно записать файл в папку трека';

  @override
  String get writebackConflict => 'Уже существует текст с другим содержимым';

  @override
  String get writebackNetworkError =>
      'Не удалось подключиться к службе записи текстов';

  @override
  String get writebackFailed => 'Ошибка проверки доступа или записи текстов';

  @override
  String get writebackRetry => 'Повторить запись текстов';

  @override
  String get webdavUploadOverwrite =>
      'Загрузить локальные данные поверх облачных';

  @override
  String get webdavDownloadOverwrite => 'Заменить локальные данные облачными';

  @override
  String get webdavMergeData => 'Объединить локальные и облачные данные';

  @override
  String get webdavMergeHint =>
      'Объединяет избранное, чёрный список, плейлисты и историю. При конфликтах сохраняет локальные настройки.';

  @override
  String get dataExport => 'Экспорт данных';

  @override
  String get logCapture => 'Включить журнал';

  @override
  String get logCaptureHint => 'Хранит последние 1 МБ журнала за текущий сеанс';

  @override
  String get logExport => 'Экспорт журнала';

  @override
  String get logEmpty => 'Нет записей для экспорта';

  @override
  String get logExportDone => 'Журнал экспортирован';

  @override
  String get dataImport => 'Импорт данных';

  @override
  String get dataScope =>
      'Избранное, плейлисты, чёрный список, история и настройки. Без загрузок, библиотеки текстов, паролей и ключей.';

  @override
  String get dataImportConfirm =>
      'Заменить локальные данные, входящие в резервную копию? Сначала будет сохранена копия для восстановления. Воспроизведение продолжится.';

  @override
  String get dataExportDone => 'Данные экспортированы';

  @override
  String get dataImportDone => 'Данные импортированы';

  @override
  String get dataOperationFailed =>
      'Не удалось выполнить операцию. Повторите попытку.';

  @override
  String get backupInvalid =>
      'Недопустимая, несовместимая или повреждённая резервная копия';

  @override
  String get backupTooLarge => 'Размер резервной копии превышает 16 МБ';

  @override
  String get webdavTitle => 'Синхронизация WebDAV';

  @override
  String get webdavUrl => 'URL сервера';

  @override
  String get webdavUsername => 'Учётная запись';

  @override
  String get webdavPassword => 'Пароль приложения';

  @override
  String get webdavFolder => 'Папка синхронизации';

  @override
  String get webdavAuto => 'Синхронизировать каждый час';

  @override
  String get webdavAutoHint =>
      'Проверяет каждый час во время работы приложения и при возобновлении, если срок проверки наступил. Загружает только изменения.';

  @override
  String get webdavTest => 'Проверить соединение';

  @override
  String get webdavTestDone => 'Соединение установлено. Тестовый файл удалён.';

  @override
  String get webdavSyncNow => 'Синхронизировать';

  @override
  String get webdavSyncDone => 'Синхронизация завершена';

  @override
  String get webdavNever => 'Ещё не синхронизировано';

  @override
  String get webdavSyncing => 'Синхронизация…';

  @override
  String get webdavConflict =>
      'Локальные и облачные данные изменены. Выберите, какую версию сохранить.';

  @override
  String get webdavUseLocal => 'Сохранить локальные';

  @override
  String get webdavUseCloud => 'Использовать облачные';

  @override
  String get webdavConflictConfirm =>
      'Выбранная версия заменит другую. Перед применением облачных данных будет сохранена локальная копия для восстановления.';

  @override
  String get webdavInvalidConfig =>
      'Введите HTTPS URL, учётную запись, пароль приложения и имя одной папки.';

  @override
  String get webdavAuthError =>
      'Ошибка авторизации. Проверьте учётную запись и пароль приложения.';

  @override
  String get webdavTimeout =>
      'Время ожидания соединения истекло. Повторите попытку позже.';

  @override
  String get webdavNetworkError =>
      'Ошибка соединения. Проверьте сеть и URL сервера.';

  @override
  String get webdavRateLimited =>
      'Достигнут лимит запросов к серверу. Повторите попытку позже.';

  @override
  String get webdavRequestFailed =>
      'Ошибка синхронизации. Проверьте настройки сервера и повторите попытку.';

  @override
  String get webdavNoEtag =>
      'Сервер не предоставляет пригодный ETag для безопасной замены облачных данных.';

  @override
  String get webdavNoBackup => 'В облаке нет резервной копии';

  @override
  String get webdavCleanupFailed =>
      'Не удалось удалить тестовый файл. Проверьте соединение с сервером.';

  @override
  String get webdavBusy => 'Выполняется операция с данными. Подождите.';

  @override
  String get appName => 'Kikoeta';

  @override
  String get playbackShortcuts => 'Горячие клавиши';

  @override
  String get dictationQueueTitle => 'Очередь расшифровки и перевода';

  @override
  String get dictationQueueClear => 'Очистить очередь';

  @override
  String get dictationQueueEmpty => 'Нет задач';

  @override
  String dictationQueueTracks(String count) {
    return 'Аудиофайлов: $count';
  }

  @override
  String dictationQueueActions(String name) {
    return 'Действия для $name';
  }

  @override
  String get dictationQueueJump => 'В начало очереди';

  @override
  String get dictationQueuePending => 'Ожидает';

  @override
  String get dictationQueueRunning => 'Обработка';

  @override
  String get dictationQueueCompleted => 'Завершено';

  @override
  String get dictationQueueFailed => 'Ошибка';

  @override
  String get dictationQueueCancelled => 'Отменено';

  @override
  String get dictationQueueDrag =>
      'Перетащите для изменения порядка ожидающих задач';

  @override
  String dictationQueueProcessing(String name) {
    return 'Обработка пакета из очереди: $name';
  }

  @override
  String get invertSelection => 'Инвертировать выбор';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get home => 'Главная';

  @override
  String get favorites => 'Избранное';

  @override
  String get more => 'Ещё';

  @override
  String get voiceActor => 'Актёр озвучивания';

  @override
  String get circle => 'Кружок';

  @override
  String get tag => 'Тег';

  @override
  String get retry => 'Повторить';

  @override
  String get advancedFilterPageBuildText => 'Расширенные фильтры';

  @override
  String get advancedFilterPageBuildContentText => 'Нет данных';

  @override
  String get advancedFilterPageBuildContentText2 => 'Нет подходящих вариантов';

  @override
  String advancedFilterPageBuildSearchFieldHintText(String placeholder) {
    return 'Поиск: $placeholder…';
  }

  @override
  String get add => 'Добавить';

  @override
  String get cancel => 'Отмена';

  @override
  String get blacklistPageTypeLabelsTypeLabels => 'RJ ID';

  @override
  String get blacklist => 'Чёрный список';

  @override
  String get blacklistPageResultText => 'В чёрный список';

  @override
  String get blacklistPageResultHintText => 'RJ ID / имя для блокировки';

  @override
  String get blacklistPageBuildText =>
      'Чёрный список пуст\nЗаблокированные произведения скрыты на главной и в поиске';

  @override
  String get local => 'Локально';

  @override
  String get network => 'Сеть';

  @override
  String get password => 'Пароль';

  @override
  String get dictationTranslationPageWorkCardTitle => 'Произведение';

  @override
  String get username => 'Имя пользователя';

  @override
  String get dictationTranslationPageWorkCardText => 'Отменить задачу';

  @override
  String get dictationTranslationPageInitStateText => 'Готово к запуску';

  @override
  String get dictationTranslationPageTestConnectionToast =>
      'Соединение установлено';

  @override
  String get dictationTranslationPageLogCardTitle => 'Журнал';

  @override
  String get dictationTranslationPageStartUpdate => 'Ошибка задачи';

  @override
  String get dictationTranslationPageBuildText => 'Расшифровка и перевод';

  @override
  String get dictationTranslationPageConnectionCardTitle =>
      'Подключение к сервису';

  @override
  String get dictationTranslationPageConnectionCardInputDecoration =>
      'URL сервиса';

  @override
  String get dictationTranslationPageConnectionCardTooltip => 'Показать пароль';

  @override
  String get dictationTranslationPageConnectionCardTooltip2 => 'Скрыть пароль';

  @override
  String get testConnection => 'Проверить соединение';

  @override
  String get dictationTranslationPageProgressCardTitle => 'Ход расшифровки';

  @override
  String get dictationTranslationPageStartUpdate2 =>
      'Задача добавлена в очередь';

  @override
  String get dictationTranslationPageStartUpdate3 => 'Задача отменена';

  @override
  String get dictationTranslationPageWorkCardTitle2 => 'Аудио для обработки';

  @override
  String get dictationTranslationPageWorkCardText2 => 'Отмена…';

  @override
  String get dictationTranslationPageStartUpdate4 =>
      'Расшифровка и перевод завершены';

  @override
  String get dictationTranslationPageSyncCachedResultsUpdate =>
      'Синхронизация кэша завершена';

  @override
  String get dictationTranslationPageConnectionCardText =>
      'Использовать стандартные учётные данные';

  @override
  String get dictationTranslationPageWorkCardText3 =>
      'Начать расшифровку и перевод';

  @override
  String get dictationTranslationPageStartUpdate5 =>
      'Сохранение в библиотеку текстов';

  @override
  String get dictationSourceWritebackFailed =>
      'Некоторые тексты не удалось записать рядом с аудио. Они сохранены в локальной библиотеке текстов.';

  @override
  String get sheetsLyricsWritebackKey => 'Ключ записи текстов';

  @override
  String get sheetsLyricsWritebackKeyHint =>
      '16 латинских букв или цифр с учётом регистра';

  @override
  String dictationTranslationPageStartAppendLog(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get dictationTranslationPageConnectionCardInputDecoration2 =>
      'URL локального сервиса (фиксированный)';

  @override
  String get dictationTranslationPageConnectionCardText2 =>
      'На Android доступно только сетевое подключение';

  @override
  String dictationTranslationPageTestConnectionToast2(String error) {
    return 'Ошибка соединения: $error';
  }

  @override
  String dictationTranslationPageCancelToast(String error) {
    return 'Не удалось отменить: $error';
  }

  @override
  String get dictationTranslationPageConnectionCardText3 => 'Скачать с GitHub';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog(String error) {
    return 'Ошибка синхронизации кэша: $error';
  }

  @override
  String dictationTranslationPageStartToast(String error) {
    return 'Ошибка расшифровки и перевода: $error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast(String skipped) {
    return ', пропущено дубликатов: $skipped';
  }

  @override
  String get dictationTranslationPageStartUpdate6 =>
      'Подключение к kikoeta-transl';

  @override
  String get dictationTranslationPageStartException =>
      'Ошибка задачи kikoeta-transl';

  @override
  String get dictationTranslationPageBuildTooltip =>
      'Синхронизировать кэш kikoeta-transl';

  @override
  String get dictationTranslationPageConnectionCardText4 =>
      'Нужно установить kikoeta-transl?';

  @override
  String get dictationTranslationPageTestConnectionFormatException =>
      'Сервис kikoeta-transl не готов';

  @override
  String get dictationTranslationPageLogCardSelectableText =>
      'Ожидание журнала kikoeta-transl…';

  @override
  String get dictationTranslationPageStartToast2 =>
      'Запустите расшифровку и перевод через меню «Ещё» на странице произведения';

  @override
  String get dictationTranslationPageStartToast3 =>
      'Вернитесь на страницу произведения и выберите медиафайлы для расшифровки и перевода';

  @override
  String get dictationTranslationPageStartFormatException =>
      'kikoeta-transl не вернул ID задачи';

  @override
  String get dictationTranslationPageOpenKikoetaTranslDownloadToast =>
      'Не удалось открыть страницу проекта kikoeta-transl';

  @override
  String get dictationTranslationPageServiceFormatException =>
      'Имя пользователя kikoeta-transl не может содержать двоеточие';

  @override
  String get dictationTranslationPageCancelAppendLog =>
      'Запрос отмены отправлен в kikoeta-transl';

  @override
  String get dictationTranslationPageServiceFormatException2 =>
      'Введите имя пользователя и пароль kikoeta-transl';

  @override
  String get dictationTranslationPageSyncCachedResultsToast2 =>
      'Нет кэшированных результатов kikoeta-transl для синхронизации';

  @override
  String get dictationTranslationPageStartFormatException2 =>
      'kikoeta-transl не вернул пригодных файлов LRC';

  @override
  String dictationTranslationPageProgressCardText(String savedFiles) {
    return ' · Сохранено: $savedFiles';
  }

  @override
  String dictationTranslationPageStartToast4(String missing) {
    return 'Аудиофайлов без URL загрузки: $missing. Войдите на сервер произведения и повторите попытку';
  }

  @override
  String dictationTranslationPageStartAppendLog2(String jobId, String length) {
    return 'Создана задача $jobId; аудиофайлов: $length';
  }

  @override
  String get dictationTranslationPageConnectionCardText5 =>
      'Скачайте и запустите kikoeta-transl для расшифровки и перевода локально или по сети.';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog2(
    String jobId,
    String name,
    String error,
  ) {
    return 'Не удалось синхронизировать $jobId/$name: $error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog3(
    String saved,
    String skipped,
    String failed,
  ) {
    return 'Синхронизация кэша завершена: сохранено $saved, пропущено дубликатов $skipped, ошибок $failed';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog4(String length) {
    return 'Синхронизация кэшированных задач kikoeta-transl: $length';
  }

  @override
  String get dictationTranslationPageWorkCardText4 =>
      'Откройте страницу произведения и выберите «Расшифровка и перевод» в меню «Ещё» справа вверху. Если файлы не выбраны, они подбираются автоматически: предпочтение отдаётся версиям без звуковых эффектов, отдельные бонусные треки сохраняются. Можно заранее выбрать файлы вручную.';

  @override
  String get dictationAutoSelectionHint =>
      'Файлы подобраны автоматически: предпочтение отдано версиям без звуковых эффектов, отдельные бонусные треки сохранены. Проверьте список; для изменений вернитесь на страницу произведения и выберите файлы вручную.';

  @override
  String dictationTranslationPageStartAppendLog3(String rj, String savedFiles) {
    return 'Сохранено файлов текстов в $rj: $savedFiles';
  }

  @override
  String dictationTranslationPageWorkCardText5(String rj, String length) {
    return '$rj · Медиафайлов выбрано на странице произведения: $length';
  }

  @override
  String dictationTranslationPageStartToast5(String savedFiles, String rj) {
    return 'Готово: файлов текстов сохранено в библиотеку $rj: $savedFiles';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast3(
    String saved,
    String value,
  ) {
    return 'Синхронизация завершена: сохранено файлов текстов $saved$value';
  }

  @override
  String dictationTranslationPageProgressCardText2(
    String finishedFiles,
    String length,
    String value,
  ) {
    return 'Обработано $finishedFiles / $length$value';
  }

  @override
  String get selectMultiple => 'Выбрать несколько';

  @override
  String get selectAll => 'Выбрать всё';

  @override
  String get downloads => 'Загрузки';

  @override
  String get downloading => 'Загрузка';

  @override
  String get downloadsPageStatusStatus => 'Ожидание';

  @override
  String get downloadsPageStatusStatus2 => 'Завершено';

  @override
  String get downloadsPageStatusStatus3 => 'Приостановлено';

  @override
  String get exitSelection => 'Завершить выбор';

  @override
  String get downloadsPageBuildTooltip => 'Закрыть поиск';

  @override
  String get downloadsPageStatusStatus4 => 'Ошибка загрузки';

  @override
  String get downloadsPageStatusStatus5 => 'В очереди';

  @override
  String get deselectAll => 'Снять выделение';

  @override
  String get downloadsPageBuildText => 'Скачать файлы';

  @override
  String get downloadsPageBuildText2 => 'Нет скачанных аудиопроизведений';

  @override
  String get downloadsPageBuildText3 => 'Полное дерево файлов';

  @override
  String get downloadsPageBuildTooltip2 => 'Удалить выбранные произведения';

  @override
  String get downloadsPageBuildText4 => 'Нет скачанных файлов';

  @override
  String get downloadsPageBuildTooltip3 => 'Поиск скачанных произведений';

  @override
  String get downloadsPageBuildTooltip4 => 'Запустить / приостановить всё';

  @override
  String get downloadsPageBuildTooltip5 => 'Удалить выбранные записи загрузок';

  @override
  String get downloadsPageFileNameFileName => 'Нет текущих загрузок';

  @override
  String downloadsPageProgressTextText(String percent) {
    return 'Загрузка $percent%';
  }

  @override
  String downloadsPageBuildText5(String value) {
    return 'Загрузить ещё ($value)';
  }

  @override
  String downloadsPageBuildText6(String rj, String downloaded, String length) {
    return '$rj  Скачано файлов: $downloaded/$length';
  }

  @override
  String downloadsPageStatusStatus6(String round) {
    return 'Загрузка $round%';
  }

  @override
  String get postponed => 'Отложено';

  @override
  String get remove => 'Удалить';

  @override
  String get all => 'Все';

  @override
  String get wantToListen => 'Хочу послушать';

  @override
  String get listening => 'Слушаю';

  @override
  String get listened => 'Прослушано';

  @override
  String get replay => 'Послушать снова';

  @override
  String get favoritesPageReviewFilterButtonTooltip => 'Фильтр по прогрессу';

  @override
  String get favoritesPageLabelLabel => 'Убрать из избранного';

  @override
  String get loading => 'Загрузка…';

  @override
  String get favoritesPageReviewSortDropdownTooltip => 'Сортировка';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels => 'Число отзывов';

  @override
  String get favoritesPageBodyText => 'Нажмите для повтора';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels2 => 'Продажи';

  @override
  String get favoritesPageBuildTooltip => 'Сменить плейлист';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels3 => 'Дата выхода';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels4 => 'Моя оценка';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels5 => 'Дата отметки';

  @override
  String get ageRating => 'Возрастной рейтинг';

  @override
  String get favoritesPageInputText => 'Добавить произведения';

  @override
  String get favoritesPageBodyText2 => 'Показаны все элементы';

  @override
  String get favoritesPageLabelLabel2 => 'Убрать из плейлиста';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip => 'Копировать ссылку';

  @override
  String favoritesPageAddWorksByRjToast(String e) {
    return 'Не удалось добавить: $e';
  }

  @override
  String get shareLinkCopied => 'Ссылка скопирована';

  @override
  String get favoritesPageRemoveSelectedWorksToast =>
      'Не удалось получить ID произведения';

  @override
  String get favoritesPageBodyText3 => 'В избранном пока пусто';

  @override
  String favoritesPageRemoveCurrentLikedPlaylistToast(String e) {
    return 'Не удалось убрать из избранного: $e';
  }

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip2 =>
      'Убрать плейлист из избранного';

  @override
  String get favoritesPageBodyText4 => 'В плейлисте пока нет произведений';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip3 => 'Добавить по RJ ID';

  @override
  String get favoritesPageAddWorksByRjToast2 => 'RJ ID не найдены';

  @override
  String favoritesPageSelectionBarText(String count) {
    return 'Выбрано: $count';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast2(String label, String e) {
    return 'Не удалось выполнить «$label»: $e';
  }

  @override
  String get favoritesPageBodyText5 => 'Избранное скрыто в режиме SFW';

  @override
  String get favoritesPageBodyText6 =>
      'Ошибка загрузки. Проверьте в настройках, выполнен ли вход';

  @override
  String get favoritesPageOkText => 'Убрать этот плейлист из моих плейлистов?';

  @override
  String favoritesPageAddWorksByRjToast3(String length) {
    return 'Добавлено произведений: $length';
  }

  @override
  String favoritesPageOkText2(String count, String label) {
    return 'Применить «$label» к произведениям ($count)?';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast3(String label, String length) {
    return '$label: произведений $length';
  }

  @override
  String get favoritesPageInputHintText =>
      'Введите один или несколько RJ ID\nНапример: RJ01367541 RJ01417842\nРазделяйте переносами строк, пробелами или запятыми';

  @override
  String get clear => 'Очистить';

  @override
  String get historyPageEntryWorkTitle => 'Неизвестное произведение';

  @override
  String get playHistory => 'История прослушивания';

  @override
  String get historyPageBuildText => 'История пуста';

  @override
  String get historyPageBuildText2 => 'История скрыта в режиме SFW';

  @override
  String historyPageFmtTimeText(String padLeft, String padLeft2) {
    return 'Сегодня $padLeft:$padLeft2';
  }

  @override
  String historyPageFmtTimeText2(
    String month,
    String day,
    String padLeft,
    String padLeft2,
  ) {
    return '$month/$day $padLeft:$padLeft2';
  }

  @override
  String get homePageServerLabelText => 'Свой сервер';

  @override
  String get homePageLabelsLabels => 'Популярное';

  @override
  String get homePageLabelsLabels2 => 'Рекомендуемое';

  @override
  String get homePageSortLabelsSortLabels => 'Общий рейтинг';

  @override
  String get homePageSortLabelsSortLabels2 => 'Дата добавления';

  @override
  String get homePageSortLabelsSortLabels3 => 'Цена';

  @override
  String get homePageEmptyHintText => 'Нет произведений';

  @override
  String get homePageSearchResultsViewText => 'Поиск…';

  @override
  String get homePageEmptyHintText2 => 'Загрузка…';

  @override
  String get homePageGridText => 'Показаны все произведения';

  @override
  String get homePageEmptyHintText3 => 'Нажмите в любом месте для повтора';

  @override
  String get homePageSearchResultsViewText2 =>
      'Подходящие произведения не найдены';

  @override
  String get homePageSearchResultsViewText3 => 'Показаны все результаты поиска';

  @override
  String get homePageEmptyHintText4 =>
      'Нет произведений, соответствующих фильтрам';

  @override
  String get homePageEmptyHintText5 =>
      'Нет соединения. Проверьте сеть или настройки сервера';

  @override
  String get homePageHeaderTooltip =>
      'Режим SFW включён: только контент для всех возрастов';

  @override
  String get homePageHeaderTooltip2 =>
      'Включить SFW (только для всех возрастов)';

  @override
  String get save => 'Сохранить';

  @override
  String get loginPageBuildLoginText => 'Войти';

  @override
  String get loginPageShowNoAccountText => 'Об учётных записях';

  @override
  String get loginPageShowNoAccountText2 => 'Понятно';

  @override
  String get loginPageBuildSiteConfigTooltip => 'Назад ко входу';

  @override
  String get loginPageBuildSiteConfigText => 'Сохранённые сайты';

  @override
  String get loginPageBuildSiteConfigHint => 'Пароль сайта';

  @override
  String get loginPageShowProxyDialogLabelText => 'Прокси-сервер';

  @override
  String get loginPageBuildLoginText2 => 'У меня нет учётной записи';

  @override
  String get loginPageBuildSiteConfigText2 => 'Использовать этот сайт';

  @override
  String get loginPageBuildSiteConfigText3 => 'Добавить сайт';

  @override
  String get loginPageBuildSiteConfigText4 => 'Сохранить и продолжить';

  @override
  String get loginPageShowProxyDialogText => 'Настроить прокси';

  @override
  String get loginPageBuildLoginText3 => 'Настроить свой сайт';

  @override
  String get loginPageBuildSiteConfigHint2 => 'Имя пользователя сайта';

  @override
  String get loginPageShowProxyDialogToast => 'Прокси включён';

  @override
  String get loginPageShowProxyDialogToast2 => 'Прокси отключён';

  @override
  String get loginPageBuildLoginHint => 'Учётная запись сайта one';

  @override
  String get loginPageLoginToast => 'Введите имя пользователя и пароль';

  @override
  String get loginPageLoginToast2 => 'Проверьте сеть или учётные данные';

  @override
  String get loginPageShowProxyDialogText2 => 'Использовать HTTP-прокси';

  @override
  String get loginPageBuildLoginText4 => 'Войти на сайт one';

  @override
  String get loginPageShowProxyDialogHelperText =>
      'Поддерживаются только HTTP-прокси';

  @override
  String get loginPageBuildSiteConfigHint3 =>
      'Название, например «Домашний NAS»';

  @override
  String get loginPageSaveNewSiteToast =>
      'Введите название и URL. Имя пользователя и пароль можно оставить пустыми.';

  @override
  String get loginPageShowProxyDialogHintText =>
      'Например: http://proxy-address:port';

  @override
  String get loginPageBuildSiteConfigText5 =>
      'Поддерживаются IP и порт, например http://192.168.1.100:3000';

  @override
  String loginPageLoginToast3(String value) {
    return 'Ошибка входа: $value';
  }

  @override
  String get loginPageShowNoAccountText3 =>
      'Этот проект не предоставляет регистрацию учётных записей.\n\nИмя пользователя и пароль необходимо получить самостоятельно. Проект не предоставляет способов их получения.\n\nПрава на контент, доступный или воспроизводимый через вашу учётную запись в приложении, и ответственность за него остаются у поставщика контента и владельца учётной записи. Проект не несёт ответственности за этот контент.\n\nУчётные данные хранятся только на вашем устройстве и не передаются сторонним серверам.';

  @override
  String get close => 'Закрыть';

  @override
  String get delete => 'Удалить';

  @override
  String get remote => 'Удалённо';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get online => 'Онлайн';

  @override
  String get importAction => 'Импорт';

  @override
  String get lyricsLibraryPageBuildNavItem => 'Удалённые библиотеки';

  @override
  String get lyricsLibrary => 'Библиотека текстов';

  @override
  String get lyricsLibraryPageBuildNavItem2 => 'Локальные файлы';

  @override
  String get lyricsLibraryPageProceedText => 'Продолжить импорт';

  @override
  String get lyricsLibraryPageImportText => 'Отменить импорт';

  @override
  String get lyricsLibraryPageProgressPhase => 'Подготовка импорта';

  @override
  String get lyricsLibraryPageOkText => 'Полное обновление';

  @override
  String get lyricsLibraryPageOkText2 => 'Удалить текст';

  @override
  String get lyricsLibraryPageSectionContentText => 'Выбрать папку';

  @override
  String get lyricsLibraryPageConfirmedText => 'Удалить удалённую библиотеку';

  @override
  String get lyricsLibraryPageSectionContentText2 =>
      'Импорт удалённой библиотеки';

  @override
  String get lyricsLibraryPageBuildText => 'Импорт библиотеки текстов';

  @override
  String get lyricsLibraryPageBuildLabel => 'Обновить библиотеку текстов';

  @override
  String get lyricsLibraryPageBuildTooltip => 'Поиск в библиотеке текстов';

  @override
  String get lyricsLibraryPageBuildText2 => 'Импорт текстов';

  @override
  String get lyricsLibraryPageImportText2 => 'Пропустить существующие';

  @override
  String get lyricsLibraryPageImportText3 => 'Перезаписать существующие';

  @override
  String get lyricsLibraryPageOkText3 => 'Удалить удалённое произведение';

  @override
  String get lyricsLibraryPageProceedText2 => 'Большой объём импорта';

  @override
  String get lyricsLibraryPageImportText4 => 'Конфликты при импорте';

  @override
  String get lyricsLibraryPageRemoteSourceListTooltip =>
      'Обновить только эту удалённую библиотеку';

  @override
  String get lyricsLibraryPageOkText4 =>
      'Удалить произведение из библиотеки текстов';

  @override
  String get lyricsLibraryPageBuildLabel2 =>
      'Обновить все удалённые библиотеки';

  @override
  String get lyricsLibraryPageBuildText3 => 'Подготовка файлов…';

  @override
  String get lyricsLibraryPageSelectionDialogTitle =>
      'Выбрать папку с текстами';

  @override
  String get lyricsLibraryPageSectionContentText3 =>
      'Подключение и синхронизация';

  @override
  String get lyricsLibraryPageSearchFieldHintText => 'Поиск по ID произведения';

  @override
  String lyricsLibraryPageImportText5(String e) {
    return 'Ошибка импорта: $e';
  }

  @override
  String get lyricsLibraryPageRemoteSourceListText =>
      'Нет импортированных удалённых библиотек';

  @override
  String get lyricsLibraryPageBuildHint => 'Удерживайте для полного обновления';

  @override
  String get lyricsLibraryPageBuildText4 => 'Подсчёт файлов текстов';

  @override
  String get lyricsLibraryPageScanProgressPhase => 'Проверка конфликтов файлов';

  @override
  String get lyricsLibraryPageResultDialogTitle => 'Выбрать ZIP-файл';

  @override
  String get lyricsLibraryPageSectionContentText4 => 'Выбрать ZIP-архив';

  @override
  String get lyricsLibraryPageBuildText5 =>
      'Число файлов текстов сейчас недоступно';

  @override
  String lyricsLibraryPageRefreshText(String error) {
    return 'Ошибка обновления: $error';
  }

  @override
  String get lyricsLibraryPageShowFilesText =>
      'Нет файлов текстов или субтитров';

  @override
  String get lyricsLibraryPageBuildText6 =>
      'Нет данных. Нажмите «Импорт» справа вверху';

  @override
  String get lyricsLibraryPageShowFilesText2 =>
      'Не удалось загрузить файлы текстов. Повторите попытку';

  @override
  String lyricsLibraryPageReorderSetState(String error) {
    return 'Не удалось изменить приоритет: $error';
  }

  @override
  String get lyricsLibraryPageSectionContentLabelText => 'HTTP / HTTPS URL';

  @override
  String get lyricsLibraryPageBuildHint2 =>
      'Синхронизировать индексы произведений всех импортированных удалённых библиотек';

  @override
  String get lyricsLibraryPageImportText6 =>
      'В выбранной папке нет файлов текстов или субтитров';

  @override
  String get lyricsLibraryPageSectionContentText5 =>
      'Выберите файлы текстов или архив для импорта.';

  @override
  String get lyricsLibraryPageSectionContentText6 =>
      'Введите адрес устройства, предоставляющего доступ к библиотеке текстов.';

  @override
  String lyricsLibraryPageRefreshOneSetState(String url, String error) {
    return 'Не удалось обновить $url: $error';
  }

  @override
  String lyricsLibraryPageRemoveRemoteLibrarySetState(
    String url,
    String error,
  ) {
    return 'Не удалось удалить $url: $error';
  }

  @override
  String lyricsLibraryPageBuildText7(String directoryCount) {
    return 'Папок: $directoryCount';
  }

  @override
  String lyricsLibraryPageBuildText8(String length) {
    return 'Элементов: $length';
  }

  @override
  String get lyricsLibraryPageBuildText9 =>
      'Нет удалённых произведений. Нажмите «Импорт» справа вверху для подключения библиотеки';

  @override
  String lyricsLibraryPageOkText5(String workId) {
    return 'Удалить индекс удалённого произведения $workId?';
  }

  @override
  String lyricsLibraryPageOkText6(String workId) {
    return 'Удалить все файлы текстов для $workId?';
  }

  @override
  String get lyricsLibraryPageOkText7 =>
      'Папки произведений без текстов или субтитров будут удалены. Продолжить?';

  @override
  String get lyricsLibraryPageSectionContentText7 =>
      'Импортированные удалённые библиотеки (по приоритету; перетащите для сортировки)';

  @override
  String lyricsLibraryPageRemoteSourceListText2(String value) {
    return 'Приоритет $value · Удерживайте для удаления';
  }

  @override
  String lyricsLibraryPageConfirmedText2(String url) {
    return 'Удалить удалённую библиотеку $url и её синхронизированный индекс произведений?';
  }

  @override
  String get lyricsLibraryPageSectionContentText8 =>
      'При импорте синхронизируется только индекс. Все тексты произведения скачиваются при его воспроизведении.';

  @override
  String get lyricsLibraryPageProceedText3 =>
      'Обнаружен большой архив или папка. Импорт может занять некоторое время.';

  @override
  String lyricsLibraryPageOkText8(String length) {
    return 'Удалить выбранные папки произведений ($length)?';
  }

  @override
  String lyricsLibraryPageImportText7(String length) {
    return 'Найдено существующих файлов: $length. Как с ними поступить?';
  }

  @override
  String lyricsLibraryPageOkText9(String length) {
    return 'Удалить выбранные индексы удалённых произведений ($length)?';
  }

  @override
  String lyricsLibraryPageBuildText10(String fileCount, String value) {
    return 'Файлов текстов/субтитров: $fileCount · $value';
  }

  @override
  String get morePageBuildRow => 'Плейлисты';

  @override
  String get settings => 'Настройки';

  @override
  String get morePageBuildRow2 => 'Случайное воспроизведение';

  @override
  String morePageBuildText(String server) {
    return 'Сервер: $server';
  }

  @override
  String get morePageOpenRandomWorkText =>
      'Нет доступных для воспроизведения произведений, соответствующих фильтрам';

  @override
  String get morePageOpenRandomWorkText2 =>
      'Не удалось загрузить случайное произведение. Повторите попытку позже';

  @override
  String get playerPageShowLyricSettingsText => 'Сбросить';

  @override
  String get back => 'Назад';

  @override
  String get seekBackward => 'Назад по треку';

  @override
  String get seekForward => 'Вперёд по треку';

  @override
  String get playerPageUtilsUtil => 'Таймер';

  @override
  String get equalizer => 'Эквалайзер';

  @override
  String get playerPageUtilsUtil2 => 'Таймер включён';

  @override
  String get playerPageShowLyricSettingsText2 => 'Китайская письменность';

  @override
  String get autoMatch => 'Автоподбор';

  @override
  String get workDetails => 'О произведении';

  @override
  String get playlist => 'Плейлист';

  @override
  String get sleepTimer => 'Таймер сна';

  @override
  String get playerPageWideLyricsPanelText => 'Нет текста';

  @override
  String get playerPageTopBarText => 'Сейчас играет';

  @override
  String get desktopLyrics => 'Текст поверх окон';

  @override
  String get playerPagePlayModeLabelText => 'Повторять всё';

  @override
  String get playerPagePlayModeLabelText2 => 'Повторять трек';

  @override
  String get playerPagePlayModeLabelText3 => 'По порядку';

  @override
  String get playerPageShowLyricSettingsText3 => 'Настройки текста';

  @override
  String get playerPageShowLyricSettingsText4 => 'Сдвиг субтитров';

  @override
  String get simplifiedToTraditional => 'Упрощённая → Традиционная';

  @override
  String get traditionalToSimplified => 'Традиционная → Упрощённая';

  @override
  String get playerPageShowQueueText => 'Плейлист пуст';

  @override
  String get playerPageResDialogTitle => 'Выбрать файл текста';

  @override
  String get playerPagePickOnlineLyricText => 'Выбрать текст онлайн';

  @override
  String get playerPageBuildText => 'Ничего не играет';

  @override
  String get playerPageShowLyricSettingsTitle => 'Выбрать офлайн-текст';

  @override
  String get playerPagePickOnlineLyricToast => 'Тексты онлайн не найдены';

  @override
  String get playerPageShowLyricSettingsTitle2 => 'Выбрать текст из библиотеки';

  @override
  String get playerPageLoadOnlineLyricToast => 'Не удалось разобрать текст';

  @override
  String get playerPageLyricsPanelText => 'Загрузка текста…';

  @override
  String get playerAlreadyFirstTrack => 'Это первый трек';

  @override
  String get playerAlreadyLastTrack => 'Это последний трек';

  @override
  String get playerPageNextToast => 'Достигнут конец плейлиста';

  @override
  String get playerPageOpenCurrentToast => 'Войдите для доступа к потоку файла';

  @override
  String get playerPageShowLyricSettingsSub =>
      'Произведения нет в библиотеке текстов';

  @override
  String get playerPageOpenMediaToast =>
      'Время открытия медиа истекло. Повторите попытку';

  @override
  String get playerPageLibraryAutoTileText => 'Автоподбор текста из библиотеки';

  @override
  String get playerPageOpenMediaToast2 =>
      'Не удалось открыть. Повторная попытка…';

  @override
  String get playerPageFriendlyPlayErrorText =>
      'Ошибка прокси медиапотока. Повторите попытку';

  @override
  String get playerLoudnessBoostLabel => 'Усиление';

  @override
  String get playerPageVolumeControlTooltip => 'Усиление громкости (до 120)';

  @override
  String get playerPageShowLyricSettingsSub2 =>
      'Выберите локальный файл текста или субтитров';

  @override
  String get playerPageInitStateToast =>
      'Соединение прервано. Переподключение…';

  @override
  String get playerPagePickLibraryLyricToast =>
      'В библиотеке нет текстов этого произведения';

  @override
  String get playerPageOpenMediaToast3 =>
      'Время открытия медиа истекло. Повторная попытка…';

  @override
  String get playerPageShowLyricSettingsSub3 =>
      'Показывать тексты только текущего произведения';

  @override
  String get playerPageCheckSleepToast =>
      'Воспроизведение остановлено, системные ресурсы освобождены';

  @override
  String get playerPagePickOnlineLyricSub =>
      'Автоподбор по имени трека с предпочтением китайского';

  @override
  String get playerPageFriendlyPlayErrorText2 =>
      'Ошибка сервера. Повторите попытку позже';

  @override
  String get playerPageVolumeControlTooltip2 =>
      'Включить усиление громкости (до 120)';

  @override
  String get playerPageFriendlyPlayErrorText3 =>
      'Сеанс истёк. Войдите снова и повторите попытку';

  @override
  String get playerPagePickOfflineLyricToast =>
      'В файле нет читаемого текста с временными метками';

  @override
  String get playerPageFriendlyPlayErrorText4 =>
      'Не удалось подключиться к медиапотоку. Проверьте сеть и повторите попытку';

  @override
  String get playerPageVolumeControlTooltip3 =>
      'Усиление громкости Plus (до 200)';

  @override
  String get playerPageToggleDesktopLyricsToast =>
      'Для текста поверх окон требуется разрешение на наложение';

  @override
  String playerPageSeekCircleMessage(String label, String seconds) {
    return '$label $seconds с';
  }

  @override
  String get playerPageLibraryAutoTileText2 =>
      'Предпочитать локальные тексты; при их отсутствии искать онлайн';

  @override
  String playerPageShowQueueText2(String length) {
    return 'Плейлист ($length)';
  }

  @override
  String playerPageInitStateToast2(String friendlyPlayError) {
    return 'Ошибка воспроизведения: $friendlyPlayError';
  }

  @override
  String playerPageOpenMediaToast4(String friendlyPlayError) {
    return 'Не удалось открыть медиапоток: $friendlyPlayError';
  }

  @override
  String get playlistsPageNameText => 'Создать';

  @override
  String get playlistsPageBuildText => 'Переименовать';

  @override
  String get playlistsPageBuildText2 => 'Новый плейлист';

  @override
  String get playlistsPageNameHintText => 'Название плейлиста';

  @override
  String get playlistsPageBuildText3 => 'Плейлист пуст';

  @override
  String get playlistsPageHeaderTooltip => 'Удалить произведение';

  @override
  String get playlistsPageNameText2 => 'Переименовать плейлист';

  @override
  String get playlistsPageHeaderMessage =>
      'Перетащите для сортировки произведений';

  @override
  String get playlistsPageRowMessage => 'Перетащите для сортировки треков';

  @override
  String get playlistsPagePlayTrackText => 'В плейлисте нет доступного аудио';

  @override
  String get playlistsPageBuildText4 => 'Плейлисты скрыты в режиме SFW';

  @override
  String get playlistsPageBuildText5 =>
      'Плейлистов пока нет. Нажмите «Новый» справа внизу';

  @override
  String get playlistsPageBuildText6 =>
      'Содержимое плейлиста скрыто в режиме SFW';

  @override
  String playlistsPageBuildText7(String length) {
    return 'Элементов: $length';
  }

  @override
  String get playlistsPagePlayTrackText2 =>
      'У этого аудио нет пригодного потока. Добавьте его снова со страницы произведения';

  @override
  String get playlistsPageBuildText8 =>
      'Перетаскивайте заголовки для сортировки произведений, медиа — для сортировки треков';

  @override
  String get playlistsPageBuildText9 =>
      'Удерживайте заголовки для сортировки произведений, медиа — для сортировки треков';

  @override
  String playlistsPageHeaderText(String length) {
    return 'Аудиофайлов: $length';
  }

  @override
  String get traditionalChineseShort => 'Китайский (трад.)';

  @override
  String get englishLanguage => 'Английский';

  @override
  String get simplifiedChineseShort => 'Китайский (упр.)';

  @override
  String get settingsPageHealthBadgeStartsWith => 'OK';

  @override
  String get settingsPageSectionsMiniBtn => 'Проверить';

  @override
  String get settingsPageSectionsMiniBtn2 => 'Настроить';

  @override
  String get settingsPageLockRowText => 'Разблокировать';

  @override
  String get play => 'Воспроизвести';

  @override
  String get lyrics => 'Текст';

  @override
  String get settingsPageSectionsSection => 'Треки';

  @override
  String get settingsPageOnVersionTapText => 'OK';

  @override
  String get settingsPageSectionsSection2 => 'Данные и сеть';

  @override
  String get settingsPageSectionsSection3 => 'Внешний вид';

  @override
  String get settingsPageSectionsText => 'Тема';

  @override
  String get settingsPageSectionsText2 => 'Светлая';

  @override
  String get settingsPageSectionsText3 => 'Тёмная';

  @override
  String get settingsPageSectionsText4 => 'Сбросить';

  @override
  String get settingsPageSectionsSection4 => 'О приложении';

  @override
  String get settingsPageSectionTitleText => 'Конфиденциальность';

  @override
  String get settingsPageSectionsTitle => 'Версия';

  @override
  String get settingsPageSectionsTitle2 => 'Репозиторий';

  @override
  String get settingsPageLockRowSub => 'Разблокировано';

  @override
  String get settingsPageSectionsMiniBtn3 => 'Отключить';

  @override
  String get settingsPageShortcutConflictText => 'Следующий трек';

  @override
  String get settingsPageShortcutConflictText2 => 'Предыдущий трек';

  @override
  String get settingsPageSectionsLockRow => 'Компьютер';

  @override
  String get settingsPageSectionsMiniBtn4 => 'Отключено';

  @override
  String get settingsPageShortcutLabelText => 'Не задано';

  @override
  String get translationEngine => 'Сервис перевода';

  @override
  String get settingsPageSectionsLabel => 'Цвет текста';

  @override
  String get settingsPageSectionsLabel2 => 'Цвет обводки';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get settingsPageAutoCheckSetState => 'Проверка…';

  @override
  String get settingsPageSectionsTitle3 => 'Шаг назад, секунды';

  @override
  String get interfaceLanguage => 'Язык интерфейса';

  @override
  String get settingsPageSectionsTitle4 => 'Шаг вперёд, секунды';

  @override
  String get settingsPageAiModelInputLabelText => 'Имя модели';

  @override
  String get settingsPageShortcutLabelText2 => 'Стрелка вправо';

  @override
  String get chineseConversion => 'Китайская письменность';

  @override
  String get settingsPageSectionsText5 => 'Толщина обводки';

  @override
  String get settingsPageSectionsSection5 => 'Учётные записи';

  @override
  String get settingsPageSectionsText6 => 'Размер шрифта';

  @override
  String get settingsPageShortcutLabelText3 => 'Стрелка влево';

  @override
  String get settingsPageBuildText => 'Сбросить все данные';

  @override
  String get settingsPageSectionsSwitchRow => 'Умная навигация';

  @override
  String get settingsPageAutoCheckSetState2 => 'Ошибка соединения';

  @override
  String get followSystem => 'Как в системе';

  @override
  String get settingsPageOpenRepoToast => 'Не удалось открыть';

  @override
  String get settingsPageEditAudioTypePreferenceText => 'По умолчанию';

  @override
  String get settingsPageSectionsText7 => 'Масштаб интерфейса';

  @override
  String get settingsPageBuildText2 => 'Подтвердить сброс';

  @override
  String get settingsPageSectionsTitle5 => 'Проверить обновления';

  @override
  String get targetLanguage => 'Язык перевода';

  @override
  String get languageAndTranslation => 'Язык и перевод';

  @override
  String get settingsPageSectionsSwitchRow2 =>
      'Открыть доступ к библиотеке текстов';

  @override
  String get settingsPageSectionsSwitchRow3 => 'Проверять буфер обмена';

  @override
  String get settingsPageShortcutConflictText3 => 'Воспроизведение / пауза';

  @override
  String get settingsPageSectionsTitle6 => 'Клавиша перемотки назад';

  @override
  String get settingsPageSectionsSwitchRow4 => 'Предпочтение звуковых эффектов';

  @override
  String get settingsPageSectionsTitle7 => 'Клавиша перемотки вперёд';

  @override
  String get settingsPageOnVersionTapText2 => 'Режим разработчика';

  @override
  String get settingsPageSectionsSub => 'Учётная запись не настроена';

  @override
  String get settingsPageRowSub => 'Открыть настройки';

  @override
  String get settingsPageSectionsTitle8 => 'Приоритет аудиоформатов';

  @override
  String get settingsPageSectionsText8 => 'Получить список моделей';

  @override
  String get settingsPageProxySettingsTooltip => 'Очистить URL прокси';

  @override
  String get settingsPageSectionsTitle9 => 'Клавиша предыдущего трека';

  @override
  String get settingsPageSectionsTitle10 => 'Отключить оптимизацию батареи';

  @override
  String get settingsPageSectionsSwitchRow5 => 'Игнорировать аудиофокус';

  @override
  String get settingsPageSectionsSwitchRow6 => 'Автопроверка обновлений';

  @override
  String get settingsPageMediaCacheLimitRowText => 'Лимит медиакэша';

  @override
  String get settingsPageSectionsTitle11 => 'Клавиша следующего трека';

  @override
  String get translationTargetLanguage => 'Язык перевода';

  @override
  String get followInterfaceLanguage => 'Как в интерфейсе';

  @override
  String get followInterfaceLanguageShort => 'Как в UI';

  @override
  String get translationTargetSimplifiedChinese => 'Китайский (упрощённый)';

  @override
  String get translationTargetTraditionalChinese => 'Китайский (традиционный)';

  @override
  String get settingsPageSectionsText9 => 'Добавить свой сайт';

  @override
  String get settingsPageSectionsTitle12 => 'Сбросить приложение';

  @override
  String get settingsPageProxySettingsSwitchRow => 'HTTP-прокси';

  @override
  String get settingsPageAiModelInputTooltip => 'Выбрать обнаруженную модель';

  @override
  String get settingsPageSectionsTitle13 => 'Сбросить горячие клавиши';

  @override
  String get settingsPageSectionsSwitchRow7 => 'Не запоминать позицию';

  @override
  String get settingsPageSectionsSection6 => 'Текст и текст поверх окон';

  @override
  String settingsPageSectionsToast(String e) {
    return 'Ошибка соединения: $e';
  }

  @override
  String get settingsPageSectionsToast2 => 'Проверка соединения…';

  @override
  String get settingsPageSectionsSwitchRow8 => 'Пауза при отключении наушников';

  @override
  String get settingsPageSectionsTitle14 => 'Клавиша воспроизведения / паузы';

  @override
  String get settingsPageSectionsSub2 => 'Проверить сервис обновлений вручную';

  @override
  String get settingsPageSectionsSwitchRow9 => 'Текст всегда поверх окон';

  @override
  String get settingsPageAiModelInputTooltip2 =>
      'Сначала получите список моделей';

  @override
  String get settingsPageProxySettingsHelperText =>
      'Оставьте пустым для работы без прокси';

  @override
  String get settingsPageLabelsLabels => 'Совместимый с OpenAI';

  @override
  String get settingsPageSectionsSwitchRow10 =>
      'Сворачивать в трей при закрытии';

  @override
  String get settingsPageDetectOpenAiModelsToast => 'Получение списка моделей…';

  @override
  String get settingsPageSectionsSwitchRow11 =>
      'Скрыть управление в уведомлениях';

  @override
  String get settingsPageSectionsSub3 =>
      'Автоматически преобразовывать китайский текст';

  @override
  String get sourceAndTargetLanguage => 'Исходный язык / язык перевода';

  @override
  String get settingsPageDetectOpenAiModelsToast2 => 'Сначала введите URL API';

  @override
  String get settingsPageSectionsSwitchRow12 =>
      'Освобождать ресурсы по таймеру';

  @override
  String get settingsPagePlaybackShortcutRowSub =>
      'Работает, когда страница плеера в фокусе';

  @override
  String get settingsPageAiModelInputHintText =>
      'Введите имя модели или выберите из списка';

  @override
  String get settingsPageSectionsSub4 =>
      'Не давать системе прерывать фоновое воспроизведение';

  @override
  String get settingsPageStatusStatus =>
      'URL сохранён; применяется после включения';

  @override
  String settingsPageLockRowTitle(String label) {
    return 'Блокировка текста: $label';
  }

  @override
  String settingsPageDetectOpenAiModelsToast3(String e) {
    return 'Не удалось получить список моделей: $e';
  }

  @override
  String get settingsPageSectionsToast3 => 'Проверка DeepL…';

  @override
  String get settingsPageSectionsSwitchRow13 =>
      'Предпочитать папки со звуковыми эффектами';

  @override
  String settingsPageSectionsToast4(String e) {
    return 'Не удалось закрыть доступ к библиотеке текстов: $e';
  }

  @override
  String settingsPageSectionsToast5(String e) {
    return 'Не удалось открыть доступ к библиотеке текстов: $e';
  }

  @override
  String get settingsPageSectionsSwitchRow14 =>
      'Автоматически открывать наиболее подходящую папку';

  @override
  String settingsPageSectionsToast6(String e) {
    return 'Ошибка соединения с DeepL: $e';
  }

  @override
  String get settingsPageSectionsSwitchRow15 =>
      'Автоматически распознавать скопированные RJ-ссылки';

  @override
  String get settingsPageSectionsSwitchRow16 =>
      'По таймеру убирать управление с экрана блокировки и уведомления';

  @override
  String get settingsPageSectionsSwitchRow17 =>
      'Проверять обновления через 3 секунды после запуска';

  @override
  String settingsPageSectionsToast7(String r) {
    return 'Соединение с DeepL установлено: $r';
  }

  @override
  String get settingsPageOnVersionTapText3 =>
      'Вы правда думали, что здесь есть режим разработчика?';

  @override
  String get settingsPageProxySettingsHelperText2 =>
      'Для редактирования включите HTTP-прокси';

  @override
  String get settingsPageSectionsSwitchRow18 =>
      'Автопауза при отключении проводных или Bluetooth-наушников';

  @override
  String get settingsPageSectionsSwitchRow19 =>
      'Воспроизводить одновременно с другими приложениями без прерываний';

  @override
  String get settingsPageSectionsSwitchRow20 =>
      'Не показывать управление воспроизведением в уведомлениях';

  @override
  String get settingsPageAiModelInputHintText2 => 'Например: gpt-4o-mini';

  @override
  String get settingsPageSectionsSwitchRow21 =>
      'Логотип проекта в медиауведомлениях';

  @override
  String settingsPageBuildText3(String count) {
    return 'Подтвердить сброс ($count с)';
  }

  @override
  String get settingsPageSectionsSub5 =>
      'Удалить все локальные данные и восстановить исходные настройки';

  @override
  String get settingsPageSectionsSub6 => '5–60 секунд, шаг 5';

  @override
  String settingsPageEditPlaybackShortcutToast(String conflict) {
    return 'Эта клавиша уже назначена для действия «$conflict»';
  }

  @override
  String get settingsPageDetectOpenAiModelsFormatException =>
      'В ответе нет data[].id';

  @override
  String get settingsPageSectionsInput =>
      'Ключ API (необязателен для локальных сервисов)';

  @override
  String get settingsPageConfirmResetText =>
      'Сброс завершён: учётные записи и все локальные данные удалены';

  @override
  String get settingsPageRequestBatteryIgnoreToast =>
      'Разрешите приложению игнорировать оптимизацию батареи в системных настройках';

  @override
  String get settingsPageStatusStatus2 => 'Включено; введите URL HTTP-прокси';

  @override
  String get settingsPageMediaCacheLimitRowText2 =>
      'Ограничивает только буфер онлайн-воспроизведения; не влияет на скачивание';

  @override
  String get settingsPageSectionsSwitchRow22 =>
      'Закрытие окна останавливает фоновые операции и завершает приложение';

  @override
  String get settingsPageSectionsSub7 =>
      'Оптимизация батареи отключена для фонового воспроизведения';

  @override
  String get settingsPageSectionsInput2 => 'Базовый URL API';

  @override
  String get settingsPageSectionsInput3 => 'Ключ DeepL Free API';

  @override
  String settingsPageSectionsSub8(String asmrUser) {
    return 'Учётная запись: $asmrUser';
  }

  @override
  String get settingsPageSectionsSwitchRow23 =>
      'Продолжать воспроизведение в фоне; окно можно восстановить из трея';

  @override
  String get settingsPageSectionsSwitchRow24 =>
      'После перезапуска восстанавливать последний трек, но играть с начала';

  @override
  String get settingsPageSectionsSwitchRow25 =>
      'API только для чтения · Порт 2377';

  @override
  String get settingsPageLockRowSub2 =>
      'Заблокировано: текст не реагирует на нажатия. Разблокируйте в настройках';

  @override
  String get settingsPageStatusStatus3 =>
      'Только HTTP-прокси; применяется ко всем сетевым запросам';

  @override
  String get settingsPageSectionsSwitchRow26 =>
      'Показывать логотип проекта вместо обложки';

  @override
  String settingsPageDetectOpenAiModelsToast4(String length) {
    return 'Найдено моделей: $length';
  }

  @override
  String settingsPageOnVersionTapToast(String value) {
    return 'До режима разработчика осталось нажатий: $value';
  }

  @override
  String settingsPageStatusStatus4(String trim) {
    return 'Включено: $trim';
  }

  @override
  String get settingsPageSectionsInput4 =>
      'Бесплатный ключ на deepl.com (api-free)';

  @override
  String get settingsPageSectionsSub9 =>
      'Пробел / PageUp / PageDown / стрелки влево и вправо';

  @override
  String settingsPageAiModelInputHelperText(String length) {
    return 'Обнаружено моделей: $length';
  }

  @override
  String get settingsPageSectionsSub10 =>
      'Google / Microsoft: бесплатно · DeepL: бесплатный ключ · Совместимый с OpenAI';

  @override
  String get settingsPageSectionsInput5 =>
      'https://api.openai.com/v1 или http://127.0.0.1:11434/v1';

  @override
  String settingsPageSectionsSub11(
    String translationSourceLabel,
    String translationTargetLabel,
  ) {
    return '$translationSourceLabel → $translationTargetLabel';
  }

  @override
  String settingsPageNextKeyIdText(String shortcutLabel) {
    return 'Текущая клавиша: $shortcutLabel\n\nНажмите одну новую клавишу';
  }

  @override
  String get settingsPageBuildText4 =>
      'Все локальные данные будут удалены безвозвратно:\n\n· Учётная запись ASMR.ONE и настройки своих сайтов\n· Избранное / история / плейлисты / чёрный список\n· Все настройки, включая перевод, эквалайзер, текст поверх окон и таймер сна\n\nПродолжить?';

  @override
  String get mark => 'Отметить';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get refresh => 'Обновить';

  @override
  String get workPageBuildLabel => 'Отзывы';

  @override
  String get translate => 'Перевести';

  @override
  String get workPageRefreshWorkToast => 'Обновлено';

  @override
  String get workPageBuildTooltip => 'Предыдущее изображение';

  @override
  String get workPageBuildText => 'В избранном';

  @override
  String get workPageBuildText2 => 'Перевод';

  @override
  String get workPageBuildTooltip2 => 'Следующее изображение';

  @override
  String get workPageLanguageEditionsButtonText => 'Языки';

  @override
  String get workPageSimilarWorksSliversText => 'Похожие произведения';

  @override
  String get workPageBuildText3 => 'Треки';

  @override
  String get workPageConfirmedText => 'Убрать отметку прогресса';

  @override
  String get workPageConfirmedText2 => 'Удалить произведение';

  @override
  String get workPageRefreshWorkToast2 => 'Ошибка обновления';

  @override
  String get workPageShowTextViewerTooltip => 'Сменить кодировку';

  @override
  String get workPageBuildText4 => 'Мой отзыв';

  @override
  String get workPageAddToPlaylistText => 'Подтвердить';

  @override
  String get workPageBuildHintText => 'Напишите отзыв…';

  @override
  String get workPageBuildText5 => 'Отменить перевод';

  @override
  String get workPageOkText => 'В чёрный список';

  @override
  String get workPageAddToPlaylistText2 => 'В плейлист';

  @override
  String get workPageTranslateTitlesToast => 'Перевод отменён';

  @override
  String get workPageSelectedText => 'Выбрать актёра озвучивания';

  @override
  String get workPageBuildText6 => 'В плейлист';

  @override
  String get workPageBuildText7 => 'Скачать выбранное';

  @override
  String get workPageOpenVideoChooserText => 'Выбрать способ открытия';

  @override
  String get workPageOpenVideoChooserText2 => 'Воспроизвести как аудио';

  @override
  String get workPageSelectedText2 => 'Сменить сервис перевода';

  @override
  String get workPageTranslateTitlesToast2 => 'Неизвестный сервис перевода';

  @override
  String get workPageTranslateTitlesFormatException =>
      'Результат перевода пуст';

  @override
  String get workPageAllFilesRowText => 'Показать все файлы';

  @override
  String get workPageDownloadSelectedToast => 'Добавлено в очередь загрузки';

  @override
  String get workPageAddToPlaylistText3 => 'Введите название плейлиста';

  @override
  String get workPageOpenVideoChooserText3 => 'Открыть во внешнем плеере';

  @override
  String workPageDeleteNotify(String e) {
    return 'Ошибка удаления: $e';
  }

  @override
  String get workPageBuildLabel2 => 'В очередь воспроизведения';

  @override
  String workPageSetProgressToast(String e) {
    return 'Не удалось отметить прогресс: $e';
  }

  @override
  String get workPageBuildLabel3 => 'Только медиафайлы';

  @override
  String get workPageTreePlaceholderText => 'В произведении пока нет треков';

  @override
  String workPageTranslateTitlesToast3(String e) {
    return 'Ошибка перевода: $e';
  }

  @override
  String workPageRateWorkToast(String e) {
    return 'Не удалось поставить оценку: $e';
  }

  @override
  String workPageApplyEncodingToast(String e) {
    return 'Ошибка декодирования: $e';
  }

  @override
  String workPageSubmitNotify(String e) {
    return 'Не удалось сохранить: $e';
  }

  @override
  String get workPageSimilarWorksSliversText2 =>
      'Загрузить ещё похожие произведения';

  @override
  String get workPageDownloadSelectedToast2 => 'Треки ещё не загружены';

  @override
  String workPageClearRatingToast(String e) {
    return 'Не удалось удалить оценку: $e';
  }

  @override
  String get workPageRefreshWorkToast3 => 'Локальные записи загрузок обновлены';

  @override
  String workPageDownloadSelectedToast3(String e) {
    return 'Не удалось добавить загрузку в очередь: $e';
  }

  @override
  String get workPageSimilarWorksSliversText3 =>
      'Показаны все похожие произведения';

  @override
  String get workPageOpenLanguageEditionToast =>
      'Не удалось загрузить эту языковую версию';

  @override
  String workPageBuildToast(String e) {
    return 'Ошибка действия с избранным: $e';
  }

  @override
  String get workPageConfirmedText3 => 'Убрать эту отметку прогресса?';

  @override
  String workPageSetProgressToast2(String e) {
    return 'Не удалось убрать отметку прогресса: $e';
  }

  @override
  String get workPageBuildLabel4 => 'Открыть DLsite';

  @override
  String get workPageAddToPlaylistToast => 'Сначала выберите файлы или папки';

  @override
  String get workPageBuildText8 => 'Треки (дерево папок)';

  @override
  String get workPageBuildLabel5 => 'Открыть asmr.one';

  @override
  String workPageAddToPlaylistToast2(String name) {
    return 'Добавлено в «$name»';
  }

  @override
  String get workPageAddToServerPlaylistToast =>
      'Добавлять произведения можно только в свои плейлисты';

  @override
  String get workPageOnMoreActionToast => 'Треки загружаются. Подождите';

  @override
  String get workPageTreePlaceholderText2 =>
      'В произведении нет аудио- или видеофайлов';

  @override
  String get workPageAddToServerPlaylistToast2 =>
      'У произведения нет ID, добавление невозможно';

  @override
  String get workPageOpenReviewDialogToast =>
      'У произведения нет ID, оставить отзыв невозможно';

  @override
  String get workPageDeleteSelectedLocalFilesToast =>
      'Среди выбранного нет скачанных файлов';

  @override
  String get workPageDeleteSelectedLocalFilesToast2 =>
      'Сначала выберите локальные файлы для удаления';

  @override
  String get workPageOnMoreActionToast2 =>
      'Не удалось загрузить треки. Обновите и повторите попытку';

  @override
  String get workPageTreePlaceholderText3 =>
      'Нет соединения. Не удалось загрузить треки';

  @override
  String workPageBuildText9(String dur) {
    return 'Длительность $dur';
  }

  @override
  String get workPageEnginesEngines => 'DeepL (ключ Free API)';

  @override
  String get workPageEnginesEngines2 => 'Совместимый с OpenAI (настраиваемый)';

  @override
  String workPageCopyRjToast(String rj) {
    return 'Скопировано: $rj';
  }

  @override
  String get workPageDownloadSelectedToast4 =>
      'Сначала выберите файлы или папки для скачивания';

  @override
  String get workPageAddToPlaylistToast3 =>
      'Среди выбранного нет доступного для воспроизведения аудио';

  @override
  String get workPageOnMoreActionToast3 =>
      'Сначала выберите медиафайлы для расшифровки и перевода';

  @override
  String get workPagePlayAsAudioToast =>
      'В режиме SFW можно слушать только произведения для всех возрастов';

  @override
  String get workPageOpenLanguageEditionToast2 =>
      'В режиме SFW можно открывать только произведения для всех возрастов';

  @override
  String get workPagePlayFilesToast =>
      'Нет аудиофайлов (войдите для доступа к потокам файлов)';

  @override
  String get workPageEnginesEngines3 => 'Google (бесплатно, без ключа)';

  @override
  String workPageNodeRowToast(String title) {
    return 'Имя файла скопировано: $title';
  }

  @override
  String workPageDeleteSelectedLocalFilesToast3(String deleted) {
    return 'Удалено локальных файлов: $deleted';
  }

  @override
  String get workPageTranslateTitlesToast4 =>
      'Сначала задайте URL API и имя модели в настройках';

  @override
  String get workPageEnginesEngines4 => 'Microsoft (бесплатно, без ключа)';

  @override
  String workPageOpenFileToast(String title) {
    return 'Просмотр этого типа файлов не поддерживается: $title';
  }

  @override
  String get workPageEnginesEngines5 => 'Index-Translate (официальный API)';

  @override
  String get workPageConfirmDeleteWorkToast =>
      'Не удалось удалить. Закройте программы, использующие это произведение, и повторите попытку';

  @override
  String workPageTranslateTitlesToast5(String length) {
    return 'Перевод строк названий: $length…';
  }

  @override
  String get workPageTranslateTitlesToast6 =>
      'Сначала введите ключ DeepL Free API в настройках';

  @override
  String workPageAddToPlaylistText4(String length) {
    return 'Выбрано аудиофайлов: $length';
  }

  @override
  String get workPageOnMoreActionToast4 =>
      'Среди выбранного нет медиафайлов, пригодных для отправки в kikoeta-transl';

  @override
  String workPageTranslateTitlesToast7(String length) {
    return 'Перевод завершён (название + треки: $length)';
  }

  @override
  String workPageOkText2(String t) {
    return 'Заблокировать тег «$t»?\nПроизведения с этим тегом будут скрыты на главной и в поиске.';
  }

  @override
  String workPageConfirmedText4(String title) {
    return 'Удалить все локальные файлы «$title»? Это действие нельзя отменить.';
  }

  @override
  String get liked => 'В избранном';

  @override
  String get privatePlaylist => 'Личный';

  @override
  String get publicPlaylist => 'Публичный';

  @override
  String get sharedByLink => 'Доступ по ссылке';

  @override
  String get apiServiceMapPlaylistName => 'Плейлист без названия';

  @override
  String get apiServiceMapWorkVa => 'Озвучивание: неизвестно';

  @override
  String get apiServiceFetchWorkFormatException =>
      'Неверный формат сведений о произведении';

  @override
  String get apiServiceFetchPlaylistMetadataFormatException =>
      'Неверный формат сведений о плейлисте';

  @override
  String get apiServiceFetchAdvancedFilterEntriesValue =>
      'Неподдерживаемый тип расширенного фильтра';

  @override
  String get apiServiceFetchAdvancedFilterEntriesFormatException =>
      'Неверный формат данных расширенного фильтра';

  @override
  String get apiServiceToggleFavoriteException =>
      'У произведения нет ID, добавление в избранное невозможно';

  @override
  String get apiServiceClearReviewRatingException =>
      'У произведения нет ID, удаление оценки невозможно';

  @override
  String get apiServiceClearReviewProgressException =>
      'У произведения нет ID, снятие отметки прогресса невозможно';

  @override
  String get apiServiceDeleteReviewException =>
      'У произведения нет ID, удаление отметки прогресса невозможно';

  @override
  String get search => 'Поиск';

  @override
  String clipboardWatcherCheckText(String rj) {
    return 'Обнаружен $rj. Нажмите для поиска';
  }

  @override
  String get desktopLyricsOverlayEnsureWindowToNativeUtf16 =>
      'Kikoeta — текст поверх окон';

  @override
  String get downloadServiceDownloadFileHttpException => 'Скачанный файл пуст';

  @override
  String get downloadServiceRunStateError =>
      'Нет доступных для скачивания файлов';

  @override
  String get downloadServiceRunStateError2 => 'URL загрузки пуст';

  @override
  String get downloadTransferDownloadToFileHttpException =>
      'Неполный ответ при загрузке';

  @override
  String get downloadTransferDownloadToFileHttpException2 =>
      'Длина блока загрузки изменилась';

  @override
  String get downloadTransferDownloadToFileHttpException3 =>
      'Проверка длины скачанного файла не пройдена';

  @override
  String get downloadTransferDownloadToFileHttpException4 =>
      'Диапазон байтов в ответе загрузки не совпадает';

  @override
  String get downloadTransferDownloadToFileHttpException5 =>
      'Ответ загрузки превышает заявленную длину файла';

  @override
  String get downloadTransferDownloadToFileHttpException6 =>
      'В ответе загрузки используется кодирование содержимого, отличное от identity';

  @override
  String downloadTransferDownloadToFileHttpException7(String status) {
    return 'Ошибка загрузки: HTTP $status';
  }

  @override
  String get ktServiceNormalizeEndpointFormatException =>
      'Используйте формат IP/домен:порт';

  @override
  String get ktServiceDecodeFormatException =>
      'kikoeta-transl вернул неверный ответ';

  @override
  String get ktServiceNormalizeEndpointFormatException2 =>
      'Введите IP/домен и порт kikoeta-transl';

  @override
  String ktServiceErrorMessageText(String statusCode) {
    return 'Ошибка запроса kikoeta-transl (HTTP $statusCode)';
  }

  @override
  String get lyricsLibraryRemoteClientValidateWorkIdFormatException =>
      'Неверный ID произведения';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException =>
      'Неверный курсор страниц удалённой библиотеки текстов';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException2 =>
      'Удалённая библиотека текстов не предоставила список произведений';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException =>
      'У удалённого произведения нет списка файлов текстов';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException2 =>
      'У удалённого произведения нет пригодных файлов текстов';

  @override
  String get lyricsLibraryRemoteClientGetJsonFormatException =>
      'Удалённая библиотека текстов вернула данные неверного формата';

  @override
  String get lyricsLibraryRemoteClientNormalizeBaseUrlFormatException =>
      'Введите корректный HTTP или HTTPS URL';

  @override
  String lyricsLibraryRemoteClientGetJsonHttpException(String statusCode) {
    return 'Удалённая библиотека текстов вернула HTTP $statusCode';
  }

  @override
  String get lyricsLibraryServiceExtractArchivePhase => 'Распаковка';

  @override
  String get lyricsLibraryServiceCopyTreePhase => 'Копирование';

  @override
  String get lyricsLibraryServiceRemoveRemoteLibraryStateError =>
      'Эта удалённая библиотека не импортирована';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError =>
      'Неподдерживаемый формат текста';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError2 =>
      'В файле нет корректных временных меток';

  @override
  String get lyricsLibraryServiceImportRemoteWorkFormatException =>
      'У удалённого произведения нет корректных файлов текстов';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError3 =>
      'Целевой файл должен находиться в папке произведения';

  @override
  String get lyricsLibraryServiceSetRemoteLibraryOrderArgumentError =>
      'Список удалённых библиотек изменился. Откройте окно импорта заново';

  @override
  String lyricsLibraryServiceSubscriptionStateError(String message) {
    return 'Ошибка обработчика импорта текстов: $message';
  }

  @override
  String get updateServiceShowUpdateDialogText => 'Больше не показывать';

  @override
  String get updateServiceShowUpdateDialogText2 => 'Скачать';

  @override
  String get updateServiceShowUpdateDialogText3 => 'Доступна новая версия';

  @override
  String get updateServiceCheckManuallyText => 'Проверка обновлений…';

  @override
  String get updateServiceCheckError =>
      'Не удалось подключиться к сервису обновлений';

  @override
  String get updateServiceCheckManuallyToast => 'Установлена последняя версия';

  @override
  String get updateServiceShowUpdateDialogToast =>
      'Не удалось открыть страницу загрузки';

  @override
  String get updateServiceGetUpdateResponseStateError =>
      'Запрос к сервису обновлений не был выполнен';

  @override
  String get updateServiceParseReleaseResponseFormatException =>
      'В ответе обновления нет сведений о версии';

  @override
  String get updateServiceCheckError2 =>
      'Сервис обновлений не вернул корректные сведения о версии';

  @override
  String get updateServiceCheckError3 =>
      'Не удалось подключиться к сервису обновлений или GitHub';

  @override
  String updateServiceShowUpdateDialogText4(
    String version,
    String currentVersion,
  ) {
    return 'Последняя версия: $version\nТекущая версия: $currentVersion';
  }

  @override
  String get pause => 'Пауза';

  @override
  String get quit => 'Выход';

  @override
  String get windowsTrayServiceSetContextMenuLabel => 'Показать главную';

  @override
  String get sheetsShowSleepSheetSuffixText => 'мин';

  @override
  String get sheetsBuildText => 'Применить';

  @override
  String get sheetsShowSiteSheetField => 'Название';

  @override
  String get sheetsShowSiteSheetField2 => 'URL';

  @override
  String get account => 'Учётная запись';

  @override
  String get sheetsPresetsPresets => 'Вокал';

  @override
  String get sheetsPresetsPresets2 => 'Бас';

  @override
  String get sheetsPresetsPresets3 => 'Ровный';

  @override
  String get sheetsPresetsPresets4 => 'Поп';

  @override
  String get sheetsPresetsPresets5 => 'Рок';

  @override
  String get sheetsShowEqSheetText => 'Отключено';

  @override
  String get sheetsShowEqSheetText2 => 'Применено';

  @override
  String get sheetsShowSleepSheetText => 'Отменить таймер';

  @override
  String get sheetsShowSleepSheetText2 => 'Запустить таймер';

  @override
  String get playbackComplete => 'Воспроизведение завершено';

  @override
  String get sheetsTimePickerText => 'Время остановки';

  @override
  String get sheetsShowSleepSheetLabel => 'В заданное время';

  @override
  String sheetsShowSleepSheetLabel2(String m) {
    return '$m мин';
  }

  @override
  String get sheetsShowSleepSheetLabel3 => 'Через N минут';

  @override
  String get sheetsBuildTitle => 'Выбрать сервер';

  @override
  String get sheetsShowEqSheetText3 => 'Включить эквалайзер';

  @override
  String get sheetsShowSiteSheetTitle => 'Изменить свой сайт';

  @override
  String get sheetsBuildText2 => 'Управление своими сайтами';

  @override
  String get sheetsShowSleepSheetHintText => 'Число минут';

  @override
  String get sheetsBuildText3 => 'Нет своих сайтов';

  @override
  String get sheetsBuildText4 => 'Выбрать свой сайт';

  @override
  String get sheetsShowSiteSheetHint => 'Например: Домашний NAS';

  @override
  String get sheetsBuildText5 => 'Сначала добавьте свой сайт';

  @override
  String get sheetsShowOneConfigSheetTitle => 'Учётная запись ASMR.ONE';

  @override
  String get sheetsShowOneConfigSheetHint => 'Учётная запись asmr.one';

  @override
  String get sheetsShowOneConfigSheetSub =>
      'Учётные данные хранятся только локально (демо)';

  @override
  String get sheetsShowSleepSheetText3 =>
      'Остановить воспроизведение и закрыть по окончании текущего плейлиста';

  @override
  String get sheetsShowSleepSheetText4 =>
      'Осталось времени · Остановить воспроизведение и выйти по таймеру';

  @override
  String get sheetsBuildSub => 'Официальный сервис или свой сайт Kikoeru';

  @override
  String get sheetsShowEqSheetSub => '10 полос · ±12 дБ · Все платформы';

  @override
  String get sheetsShowSleepSheetText5 =>
      'Остановить воспроизведение и закрыть после всех элементов текущего плейлиста';

  @override
  String get sheetsShowSleepSheetSub =>
      'По таймеру остановить воспроизведение и освободить ресурсы (убрать управление с экрана блокировки и уведомления)';

  @override
  String sheetsBuildLabel(String length) {
    return 'Свои конфигурации ($length)';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip(String label) {
    return 'Уменьшить число секунд: $label';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip2(String label) {
    return 'Увеличить число секунд: $label';
  }

  @override
  String get name => 'Название';

  @override
  String get description => 'Описание';

  @override
  String get playlistPickerRowsMapEntry => 'Видимость';

  @override
  String get language => 'Язык';

  @override
  String get confirmAction => 'Подтвердить';

  @override
  String get create => 'Создать';

  @override
  String get playlistPickerShowEditorLabelText => 'Тип';

  @override
  String get playlistPickerRowsMapEntry2 => 'Автор';

  @override
  String get playlistPickerRowsMapEntry3 => 'Обновлён';

  @override
  String get playlistPickerReviewsItemName => 'Моё избранное';

  @override
  String get playlistPickerRowsMapEntry4 => 'Число прослушиваний';

  @override
  String get playlistPickerRowsMapEntry5 => 'Число произведений';

  @override
  String get playlistPickerCopyText => 'О плейлисте';

  @override
  String get playlistPickerLinkLabelText => 'Ссылка для доступа';

  @override
  String get playlistPickerCopyText2 => 'Копировать ссылку';

  @override
  String get playlistPickerRowsMapEntry6 => 'Создан';

  @override
  String get playlistPickerBuildText => 'Сменить плейлист';

  @override
  String get playlistPickerPlaylistItemTooltip => 'Удалить плейлист';

  @override
  String get playlistPickerPlaylistItemTooltip2 => 'Изменить плейлист';

  @override
  String get playlistPickerShowEditorText => 'Создать плейлист';

  @override
  String get playlistPickerLinkText => 'Импорт плейлиста';

  @override
  String get playlistPickerOkText => 'Удалить плейлист';

  @override
  String playlistPickerRemoveLikedToast(String e) {
    return 'Ошибка удаления: $e';
  }

  @override
  String playlistPickerCreatePlaylistToast(String e) {
    return 'Ошибка создания: $e';
  }

  @override
  String get playlistPickerLoadSetState => 'Не удалось загрузить плейлисты';

  @override
  String get playlistPickerImportPlaylistToast =>
      'Неизвестная ссылка на плейлист';

  @override
  String get playlistPickerReviewsItemSubtitle =>
      'Мои отзывы / избранное (все произведения)';

  @override
  String get playlistPickerCreatePlaylistToast2 =>
      'Создано, но плейлист не найден в списке';

  @override
  String get playlistPickerImportPlaylistToast2 =>
      'Добавлено, но плейлиста пока нет в списке';

  @override
  String playlistPickerSubtitleSubtitle(String worksCount) {
    return 'Произведений: $worksCount';
  }

  @override
  String get playlistPickerLinkText2 =>
      'Вставьте ссылку на общий плейлист, чтобы добавить его в свои плейлисты.';

  @override
  String playlistPickerOkText2(String name) {
    return 'Удалить «$name»? Это действие нельзя отменить.';
  }

  @override
  String playlistPickerOkText3(String name) {
    return 'Убрать «$name» из моих плейлистов?';
  }

  @override
  String playlistPickerSubtitleSubtitle2(String worksCount, String replaceAll) {
    return 'Произведений: $worksCount · $replaceAll';
  }

  @override
  String get widgetsFilterButtonTooltip => 'Фильтр';

  @override
  String get widgetsFilterButtonLabel => 'Только с субтитрами';

  @override
  String get allAges => 'Для всех возрастов';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter =>
      'Исключить язык';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter2 =>
      'Поиск кружков';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter3 =>
      'Поиск актёров озвучивания';

  @override
  String get widgetsBuildBuilder => 'Текст от ИИ';

  @override
  String get widgetsBuildBuilder2 => 'Удалённый текст';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter4 =>
      'Фильтр по языку';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter5 =>
      'Исключить тег';

  @override
  String get widgetsBuildBuilder3 => 'Локальный текст';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter6 =>
      'Исключить кружок';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter7 =>
      'Исключить актёра озвучивания';

  @override
  String get widgetsInputRowMessage => 'Расширенный поиск';

  @override
  String get widgetsHistoryPanelText => 'История поиска';

  @override
  String get widgetsBuildBuilder4 => 'Текст онлайн';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter8 =>
      'Поиск тегов';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter9 =>
      'Фильтр по возрастному рейтингу';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter10 =>
      'Исключить возрастной рейтинг';

  @override
  String get widgetsBuildText => 'Параметры расширенного поиска';

  @override
  String get widgetsHistoryPanelText2 => 'История поиска пуста';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter11 =>
      'Включить теги с малым числом голосов';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter12 =>
      'Исключить теги с малым числом голосов';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter13 =>
      'Рейтинг выше';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter14 =>
      'Продажи больше';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter15 =>
      'Цена выше';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter16 =>
      'Длительность меньше';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter17 =>
      'Длительность больше';

  @override
  String widgetsHistoryPanelText3(String value) {
    return 'Удалено: «$value»';
  }

  @override
  String get playbackSpeed => 'Скорость';

  @override
  String get playbackSpeedDescription =>
      'Изменять скорость, сохраняя высоту тона';

  @override
  String get playbackSpeedEntry => 'Показывать настройку скорости';

  @override
  String get playbackSpeedEntryDescription =>
      'Показывать настройку скорости в плеере; отключение восстанавливает 1×';

  @override
  String get audioChannels => 'Каналы';

  @override
  String get audioChannelsDescription =>
      'Поменять левый и правый каналы местами или объединить их для одинакового звука в обоих ушах';

  @override
  String get audioChannelsOriginal => 'Исходные';

  @override
  String get audioChannelsSwap => 'Поменять местами';

  @override
  String get audioChannelsMerge => 'Объединить';

  @override
  String get widgetsInputRowHintText =>
      'Поиск по RJ ID, названию, озвучиванию…';

  @override
  String get batchTranslation => 'Пакетный перевод';

  @override
  String get batchTranslationPreparing =>
      'Сопоставление треков и существующих текстов…';

  @override
  String batchTranslationFailed(String error) {
    return 'Ошибка подготовки: $error';
  }

  @override
  String batchTranslationSummary(String added, String skipped, String failed) {
    return 'Треков в очереди: $added, пропущено: $skipped; ошибок по произведениям: $failed';
  }

  @override
  String batchTranslationExistingLyrics(String count) {
    return 'У треков ($count) уже есть тексты. Как поступить?';
  }

  @override
  String get batchTranslationSkipExisting => 'Пропустить с текстом';

  @override
  String get batchTranslationRetranslate => 'Перевести заново';

  @override
  String get translationSourceLanguage => 'Исходный язык';

  @override
  String get translationSourceAuto => 'Авто';

  @override
  String get translationSourceJapanese => 'JA';

  @override
  String get translationSourceChinese => 'ZH';

  @override
  String get translationSourceEnglish => 'EN';

  @override
  String get lyricsSkipEmpty => 'Пропускать пустые строки';

  @override
  String get lyricsSkipEmptyDescription =>
      'Показывать предыдущую строку до следующей';

  @override
  String get androidLyricsHideWhenPaused => 'Скрывать текст при паузе';

  @override
  String get androidLyricsHideWhenPausedDescription =>
      'Скрывать при паузе или остановке и показывать при продолжении';

  @override
  String get lockDesktopLyrics => 'Заблокировать текст';

  @override
  String get unlockDesktopLyrics => 'Разблокировать текст';

  @override
  String get showDesktopLyrics => 'Показать текст';

  @override
  String get hideDesktopLyrics => 'Скрыть текст';

  @override
  String get androidLyricsLockDescription =>
      'При блокировке касания проходят сквозь текст; одинаково для обеих ориентаций';

  @override
  String get homeRandomSort => 'Случайный порядок';

  @override
  String get favoritesSearch => 'Поиск в избранном';

  @override
  String get favoritesSearchHint => 'Поиск по названию или номеру RJ';

  @override
  String get lyricsTranslate => 'Перевести субтитры';

  @override
  String get lyricsOpacity => 'Непрозрачность';

  @override
  String get lyricsFollowSystemFont => 'Использовать системный шрифт';

  @override
  String get translatedSubtitleBadge => 'Перевод';

  @override
  String get lyricsTranslateDescription =>
      'Сохранить в библиотеку субтитров по языку перевода';

  @override
  String lyricsTranslationProgress(int completed, int total) {
    return 'Переведено строк: $completed/$total';
  }

  @override
  String lyricsTranslationSaved(String path) {
    return 'Перевод сохранён: $path';
  }

  @override
  String get lyricsTranslationInvalidResponse =>
      'В переводе есть пропущенные или пустые строки. Повторите попытку или смените движок перевода.';
}
