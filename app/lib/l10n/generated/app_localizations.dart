import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh', 'CN'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @dataExport.
  ///
  /// In zh, this message translates to:
  /// **'导出本地数据'**
  String get dataExport;

  /// No description provided for @dataImport.
  ///
  /// In zh, this message translates to:
  /// **'导入本地数据'**
  String get dataImport;

  /// No description provided for @dataScope.
  ///
  /// In zh, this message translates to:
  /// **'收藏、歌单、黑名单、历史与偏好；不含下载、歌词库、账号密码和密钥。'**
  String get dataScope;

  /// No description provided for @dataImportConfirm.
  ///
  /// In zh, this message translates to:
  /// **'将覆盖备份范围内的本地数据。导入前会保留一份本地副本，当前播放不受影响。'**
  String get dataImportConfirm;

  /// No description provided for @dataExportDone.
  ///
  /// In zh, this message translates to:
  /// **'数据已导出'**
  String get dataExportDone;

  /// No description provided for @dataImportDone.
  ///
  /// In zh, this message translates to:
  /// **'数据已导入'**
  String get dataImportDone;

  /// No description provided for @dataOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请重试'**
  String get dataOperationFailed;

  /// No description provided for @backupInvalid.
  ///
  /// In zh, this message translates to:
  /// **'备份格式无效、版本不兼容或文件已损坏'**
  String get backupInvalid;

  /// No description provided for @backupTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'备份超过 16 MB 上限'**
  String get backupTooLarge;

  /// No description provided for @webdavTitle.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 云同步'**
  String get webdavTitle;

  /// No description provided for @webdavUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get webdavUrl;

  /// No description provided for @webdavUsername.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get webdavUsername;

  /// No description provided for @webdavPassword.
  ///
  /// In zh, this message translates to:
  /// **'应用密码'**
  String get webdavPassword;

  /// No description provided for @webdavFolder.
  ///
  /// In zh, this message translates to:
  /// **'同步文件夹'**
  String get webdavFolder;

  /// No description provided for @webdavAuto.
  ///
  /// In zh, this message translates to:
  /// **'每小时自动同步'**
  String get webdavAuto;

  /// No description provided for @webdavAutoHint.
  ///
  /// In zh, this message translates to:
  /// **'应用运行期间每小时检查；回到前台时补查。无变化不上传。'**
  String get webdavAutoHint;

  /// No description provided for @webdavTest.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get webdavTest;

  /// No description provided for @webdavTestDone.
  ///
  /// In zh, this message translates to:
  /// **'连接正常，测试文件已删除'**
  String get webdavTestDone;

  /// No description provided for @webdavSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get webdavSyncNow;

  /// 上传本地数据覆盖云端
  String get webdavUploadOverwrite;

  /// 使用云端数据覆盖本地
  String get webdavDownloadOverwrite;

  /// 合并本地与云端数据
  String get webdavMergeData;

  /// 收藏、黑名单、歌单和历史去重合并，设置冲突保留本地。
  String get webdavMergeHint;

  /// No description provided for @webdavSyncDone.
  ///
  /// In zh, this message translates to:
  /// **'同步完成'**
  String get webdavSyncDone;

  /// No description provided for @webdavNever.
  ///
  /// In zh, this message translates to:
  /// **'尚未同步'**
  String get webdavNever;

  /// No description provided for @webdavSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步…'**
  String get webdavSyncing;

  /// No description provided for @webdavConflict.
  ///
  /// In zh, this message translates to:
  /// **'本地和云端都有更改，请选择保留的版本'**
  String get webdavConflict;

  /// No description provided for @webdavUseLocal.
  ///
  /// In zh, this message translates to:
  /// **'保留本地'**
  String get webdavUseLocal;

  /// No description provided for @webdavUseCloud.
  ///
  /// In zh, this message translates to:
  /// **'使用云端'**
  String get webdavUseCloud;

  /// No description provided for @webdavConflictConfirm.
  ///
  /// In zh, this message translates to:
  /// **'所选版本将覆盖另一端的数据。使用云端前会保留本地副本。'**
  String get webdavConflictConfirm;

  /// No description provided for @webdavInvalidConfig.
  ///
  /// In zh, this message translates to:
  /// **'请填写 HTTPS 地址、账号、应用密码及单层文件夹名称'**
  String get webdavInvalidConfig;

  /// No description provided for @webdavAuthError.
  ///
  /// In zh, this message translates to:
  /// **'认证失败，请检查账号和应用密码'**
  String get webdavAuthError;

  /// No description provided for @webdavTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时，请稍后重试'**
  String get webdavTimeout;

  /// No description provided for @webdavNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络及服务器地址'**
  String get webdavNetworkError;

  /// No description provided for @webdavRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'服务器请求限流，请稍后重试'**
  String get webdavRateLimited;

  /// No description provided for @webdavRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败，请检查服务器配置后重试'**
  String get webdavRequestFailed;

  /// No description provided for @webdavNoEtag.
  ///
  /// In zh, this message translates to:
  /// **'服务器未提供可用的 ETag，无法安全覆盖云端文件'**
  String get webdavNoEtag;

  /// No description provided for @webdavNoBackup.
  ///
  /// In zh, this message translates to:
  /// **'云端暂无备份'**
  String get webdavNoBackup;

  /// No description provided for @webdavCleanupFailed.
  ///
  /// In zh, this message translates to:
  /// **'测试文件清理失败，请重试测试以检查连接'**
  String get webdavCleanupFailed;

  /// No description provided for @webdavBusy.
  ///
  /// In zh, this message translates to:
  /// **'正在处理数据，请稍候'**
  String get webdavBusy;

  /// 应用名称，保留品牌原文。
  ///
  /// In zh, this message translates to:
  /// **'Kikoeta'**
  String get appName;

  /// 播放设置中的快捷键子页面入口与标题
  ///
  /// In zh, this message translates to:
  /// **'快捷键设置'**
  String get playbackShortcuts;

  /// No description provided for @dictationQueueTitle.
  ///
  /// In zh, this message translates to:
  /// **'听写翻译队列'**
  String get dictationQueueTitle;

  /// No description provided for @dictationQueueClear.
  ///
  /// In zh, this message translates to:
  /// **'清空列表'**
  String get dictationQueueClear;

  /// No description provided for @dictationQueueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无任务'**
  String get dictationQueueEmpty;

  /// No description provided for @dictationQueueTracks.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个音频'**
  String dictationQueueTracks(String count);

  /// No description provided for @dictationQueueActions.
  ///
  /// In zh, this message translates to:
  /// **'你想对 {name} 执行的操作'**
  String dictationQueueActions(String name);

  /// No description provided for @dictationQueueJump.
  ///
  /// In zh, this message translates to:
  /// **'插队'**
  String get dictationQueueJump;

  /// No description provided for @dictationQueuePending.
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get dictationQueuePending;

  /// No description provided for @dictationQueueRunning.
  ///
  /// In zh, this message translates to:
  /// **'处理中'**
  String get dictationQueueRunning;

  /// No description provided for @dictationQueueCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get dictationQueueCompleted;

  /// No description provided for @dictationQueueFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get dictationQueueFailed;

  /// No description provided for @dictationQueueCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get dictationQueueCancelled;

  /// No description provided for @dictationQueueDrag.
  ///
  /// In zh, this message translates to:
  /// **'拖动调整待处理顺序'**
  String get dictationQueueDrag;

  /// No description provided for @dictationQueueProcessing.
  ///
  /// In zh, this message translates to:
  /// **'开始处理队列批次：{name}'**
  String dictationQueueProcessing(String name);

  /// 作品详情页：反转当前文件筛选范围内的勾选状态。
  ///
  /// In zh, this message translates to:
  /// **'反选'**
  String get invertSelection;

  /// 界面语言列表中的繁体中文选项，目前不可选。
  ///
  /// In zh, this message translates to:
  /// **'繁體中文'**
  String get traditionalChinese;

  /// main.dart: scaffold
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// main.dart: scaffold
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorites;

  /// main.dart: scaffold
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// pages/advanced_filter_page.dart: _tabs
  ///
  /// In zh, this message translates to:
  /// **'声优'**
  String get voiceActor;

  /// pages/advanced_filter_page.dart: _tabs
  ///
  /// In zh, this message translates to:
  /// **'社团'**
  String get circle;

  /// pages/advanced_filter_page.dart: _tabs
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tag;

  /// pages/advanced_filter_page.dart: _buildContent
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// pages/advanced_filter_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'高级筛选'**
  String get advancedFilterPageBuildText;

  /// pages/advanced_filter_page.dart: _buildContent
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get advancedFilterPageBuildContentText;

  /// pages/advanced_filter_page.dart: _buildContent
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的参数'**
  String get advancedFilterPageBuildContentText2;

  /// pages/advanced_filter_page.dart: _buildSearchField
  ///
  /// In zh, this message translates to:
  /// **'搜索{placeholder}…'**
  String advancedFilterPageBuildSearchFieldHintText(String placeholder);

  /// pages/blacklist_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// pages/blacklist_page.dart: result
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// pages/blacklist_page.dart: _typeLabels
  ///
  /// In zh, this message translates to:
  /// **'RJ号'**
  String get blacklistPageTypeLabelsTypeLabels;

  /// pages/blacklist_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'黑名单'**
  String get blacklist;

  /// pages/blacklist_page.dart: result
  ///
  /// In zh, this message translates to:
  /// **'添加黑名单'**
  String get blacklistPageResultText;

  /// pages/blacklist_page.dart: result
  ///
  /// In zh, this message translates to:
  /// **'要屏蔽的 RJ 号 / 名称'**
  String get blacklistPageResultHintText;

  /// pages/blacklist_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无黑名单条目\n黑名单中的作品不会出现在首页与搜索'**
  String get blacklistPageBuildText;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get local;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'网络'**
  String get network;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// pages/dictation_translation_page.dart: _workCard
  ///
  /// In zh, this message translates to:
  /// **'作品'**
  String get dictationTranslationPageWorkCardTitle;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// pages/dictation_translation_page.dart: _workCard
  ///
  /// In zh, this message translates to:
  /// **'取消任务'**
  String get dictationTranslationPageWorkCardText;

  /// pages/dictation_translation_page.dart: initState
  ///
  /// In zh, this message translates to:
  /// **'等待开始'**
  String get dictationTranslationPageInitStateText;

  /// pages/dictation_translation_page.dart: _testConnection
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get dictationTranslationPageTestConnectionToast;

  /// pages/dictation_translation_page.dart: _logCard
  ///
  /// In zh, this message translates to:
  /// **'运行日志'**
  String get dictationTranslationPageLogCardTitle;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'任务失败'**
  String get dictationTranslationPageStartUpdate;

  /// pages/dictation_translation_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'听写翻译'**
  String get dictationTranslationPageBuildText;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'服务连接'**
  String get dictationTranslationPageConnectionCardTitle;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'服务地址'**
  String get dictationTranslationPageConnectionCardInputDecoration;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get dictationTranslationPageConnectionCardTooltip;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get dictationTranslationPageConnectionCardTooltip2;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// pages/dictation_translation_page.dart: _progressCard
  ///
  /// In zh, this message translates to:
  /// **'听写进度'**
  String get dictationTranslationPageProgressCardTitle;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'任务已排队'**
  String get dictationTranslationPageStartUpdate2;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'任务已取消'**
  String get dictationTranslationPageStartUpdate3;

  /// pages/dictation_translation_page.dart: _workCard
  ///
  /// In zh, this message translates to:
  /// **'待处理音频'**
  String get dictationTranslationPageWorkCardTitle2;

  /// pages/dictation_translation_page.dart: _workCard
  ///
  /// In zh, this message translates to:
  /// **'正在取消…'**
  String get dictationTranslationPageWorkCardText2;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'听写翻译完成'**
  String get dictationTranslationPageStartUpdate4;

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'缓存同步完成'**
  String get dictationTranslationPageSyncCachedResultsUpdate;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'使用默认账密'**
  String get dictationTranslationPageConnectionCardText;

  /// pages/dictation_translation_page.dart: _workCard
  ///
  /// In zh, this message translates to:
  /// **'开始听写翻译'**
  String get dictationTranslationPageWorkCardText3;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'正在写入歌词库'**
  String get dictationTranslationPageStartUpdate5;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'错误：{error}'**
  String dictationTranslationPageStartAppendLog(String error);

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'本地服务地址（固定）'**
  String get dictationTranslationPageConnectionCardInputDecoration2;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'安卓设备仅支持网络连接'**
  String get dictationTranslationPageConnectionCardText2;

  /// pages/dictation_translation_page.dart: _testConnection
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{error}'**
  String dictationTranslationPageTestConnectionToast2(String error);

  /// pages/dictation_translation_page.dart: _cancel
  ///
  /// In zh, this message translates to:
  /// **'取消失败：{error}'**
  String dictationTranslationPageCancelToast(String error);

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'前往 GitHub 下载'**
  String get dictationTranslationPageConnectionCardText3;

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'缓存同步失败：{error}'**
  String dictationTranslationPageSyncCachedResultsAppendLog(String error);

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'听写翻译失败：{error}'**
  String dictationTranslationPageStartToast(String error);

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'，去重 {skipped} 个'**
  String dictationTranslationPageSyncCachedResultsToast(String skipped);

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'正在连接 kikoeta-transl'**
  String get dictationTranslationPageStartUpdate6;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 任务失败'**
  String get dictationTranslationPageStartException;

  /// pages/dictation_translation_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'同步 kikoeta-transl 缓存'**
  String get dictationTranslationPageBuildTooltip;

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'尚未安装 kikoeta-transl？'**
  String get dictationTranslationPageConnectionCardText4;

  /// pages/dictation_translation_page.dart: _testConnection
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 服务未就绪'**
  String get dictationTranslationPageTestConnectionFormatException;

  /// pages/dictation_translation_page.dart: _logCard
  ///
  /// In zh, this message translates to:
  /// **'等待 kikoeta-transl 日志…'**
  String get dictationTranslationPageLogCardSelectableText;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'请从作品详情页的更多选项进入并启动听写翻译'**
  String get dictationTranslationPageStartToast2;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'请返回作品详情页勾选需要听写翻译的媒体文件'**
  String get dictationTranslationPageStartToast3;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 未返回任务编号'**
  String get dictationTranslationPageStartFormatException;

  /// pages/dictation_translation_page.dart: _openKikoetaTranslDownload
  ///
  /// In zh, this message translates to:
  /// **'无法打开 kikoeta-transl 项目页面'**
  String get dictationTranslationPageOpenKikoetaTranslDownloadToast;

  /// pages/dictation_translation_page.dart: _service
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 用户名不能包含冒号'**
  String get dictationTranslationPageServiceFormatException;

  /// pages/dictation_translation_page.dart: _cancel
  ///
  /// In zh, this message translates to:
  /// **'已向 kikoeta-transl 发送取消请求'**
  String get dictationTranslationPageCancelAppendLog;

  /// pages/dictation_translation_page.dart: _service
  ///
  /// In zh, this message translates to:
  /// **'请输入 kikoeta-transl 用户名和密码'**
  String get dictationTranslationPageServiceFormatException2;

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 没有可同步的缓存结果'**
  String get dictationTranslationPageSyncCachedResultsToast2;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 没有返回可用的 LRC 文件'**
  String get dictationTranslationPageStartFormatException2;

  /// pages/dictation_translation_page.dart: _progressCard
  ///
  /// In zh, this message translates to:
  /// **' · 已入库 {savedFiles}'**
  String dictationTranslationPageProgressCardText(String savedFiles);

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'有 {missing} 个音频缺少可下载地址，请登录作品服务器后重试'**
  String dictationTranslationPageStartToast4(String missing);

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'任务 {jobId} 已创建，共 {length} 个音频'**
  String dictationTranslationPageStartAppendLog2(String jobId, String length);

  /// pages/dictation_translation_page.dart: _connectionCard
  ///
  /// In zh, this message translates to:
  /// **'下载并启动 kikoeta-transl 后，即可使用本地或网络听写翻译。'**
  String get dictationTranslationPageConnectionCardText5;

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'同步 {jobId}/{name} 失败：{error}'**
  String dictationTranslationPageSyncCachedResultsAppendLog2(
    String jobId,
    String name,
    String error,
  );

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'缓存同步完成：写入 {saved}，去重跳过 {skipped}，失败 {failed}'**
  String dictationTranslationPageSyncCachedResultsAppendLog3(
    String saved,
    String skipped,
    String failed,
  );

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'开始同步 {length} 条 kikoeta-transl 缓存任务'**
  String dictationTranslationPageSyncCachedResultsAppendLog4(String length);

  /// pages/dictation_translation_page.dart: _workCard
  ///
  /// In zh, this message translates to:
  /// **'要创建任务，请打开作品详情页，在右上角“更多”中选择“听写翻译”。未勾选文件时会自动匹配，优先选择无效果音版本并保留独立特典；也可先手动勾选指定文件。'**
  String get dictationTranslationPageWorkCardText4;

  /// No description provided for @dictationAutoSelectionHint.
  ///
  /// In zh, this message translates to:
  /// **'已自动匹配：优先无效果音，保留独立特典。请检查媒体列表；需要调整时，可返回作品页手动勾选。'**
  String get dictationAutoSelectionHint;

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'已按 {rj} 写入 {savedFiles} 个歌词文件'**
  String dictationTranslationPageStartAppendLog3(String rj, String savedFiles);

  /// pages/dictation_translation_page.dart: _workCard
  ///
  /// In zh, this message translates to:
  /// **'{rj} · 已从作品详情页勾选 {length} 个媒体文件'**
  String dictationTranslationPageWorkCardText5(String rj, String length);

  /// pages/dictation_translation_page.dart: _start
  ///
  /// In zh, this message translates to:
  /// **'完成：{savedFiles} 个歌词已写入 {rj} 歌词库'**
  String dictationTranslationPageStartToast5(String savedFiles, String rj);

  /// pages/dictation_translation_page.dart: _syncCachedResults
  ///
  /// In zh, this message translates to:
  /// **'同步完成：写入 {saved} 个歌词{value}'**
  String dictationTranslationPageSyncCachedResultsToast3(
    String saved,
    String value,
  );

  /// pages/dictation_translation_page.dart: _progressCard
  ///
  /// In zh, this message translates to:
  /// **'已处理 {finishedFiles} / {length}{value}'**
  String dictationTranslationPageProgressCardText2(
    String finishedFiles,
    String length,
    String value,
  );

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'多选'**
  String get selectMultiple;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get downloads;

  /// pages/downloads_page.dart: _progressText
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloading;

  /// pages/downloads_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get downloadsPageStatusStatus;

  /// pages/downloads_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get downloadsPageStatusStatus2;

  /// pages/downloads_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get downloadsPageStatusStatus3;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'退出多选'**
  String get exitSelection;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get downloadsPageBuildTooltip;

  /// pages/downloads_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get downloadsPageStatusStatus4;

  /// pages/downloads_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'等待下载'**
  String get downloadsPageStatusStatus5;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get deselectAll;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'下载文件'**
  String get downloadsPageBuildText;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无下载音声'**
  String get downloadsPageBuildText2;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'完整文件结构'**
  String get downloadsPageBuildText3;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'删除选中作品'**
  String get downloadsPageBuildTooltip2;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无下载文件'**
  String get downloadsPageBuildText4;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'搜索已下载作品'**
  String get downloadsPageBuildTooltip3;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'开始/暂停全部'**
  String get downloadsPageBuildTooltip4;

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'删除选中下载记录'**
  String get downloadsPageBuildTooltip5;

  /// pages/downloads_page.dart: fileName
  ///
  /// In zh, this message translates to:
  /// **'暂无正在下载的文件'**
  String get downloadsPageFileNameFileName;

  /// pages/downloads_page.dart: _progressText
  ///
  /// In zh, this message translates to:
  /// **'下载中 {percent}%'**
  String downloadsPageProgressTextText(String percent);

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'加载更多（{value}）'**
  String downloadsPageBuildText5(String value);

  /// pages/downloads_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'{rj}  {downloaded}/{length} 个文件已下载'**
  String downloadsPageBuildText6(String rj, String downloaded, String length);

  /// pages/downloads_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'下载中 {round}%'**
  String downloadsPageStatusStatus6(String round);

  /// pages/favorites_page.dart: _reviewFilterLabels
  ///
  /// In zh, this message translates to:
  /// **'搁置'**
  String get postponed;

  /// pages/favorites_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// pages/favorites_page.dart: _reviewFilterLabels
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// pages/favorites_page.dart: _reviewFilterLabels
  ///
  /// In zh, this message translates to:
  /// **'想听'**
  String get wantToListen;

  /// pages/favorites_page.dart: _reviewFilterLabels
  ///
  /// In zh, this message translates to:
  /// **'在听'**
  String get listening;

  /// pages/favorites_page.dart: _reviewFilterLabels
  ///
  /// In zh, this message translates to:
  /// **'听过'**
  String get listened;

  /// pages/favorites_page.dart: _reviewFilterLabels
  ///
  /// In zh, this message translates to:
  /// **'重听'**
  String get replay;

  /// pages/favorites_page.dart: _reviewFilterButton
  ///
  /// In zh, this message translates to:
  /// **'进度筛选'**
  String get favoritesPageReviewFilterButtonTooltip;

  /// pages/favorites_page.dart: label
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get favoritesPageLabelLabel;

  /// pages/favorites_page.dart: _body
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loading;

  /// pages/favorites_page.dart: _reviewSortDropdown
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get favoritesPageReviewSortDropdownTooltip;

  /// pages/favorites_page.dart: _reviewSortLabels
  ///
  /// In zh, this message translates to:
  /// **'评论数量'**
  String get favoritesPageReviewSortLabelsReviewSortLabels;

  /// pages/favorites_page.dart: _body
  ///
  /// In zh, this message translates to:
  /// **'点击重试'**
  String get favoritesPageBodyText;

  /// pages/favorites_page.dart: _reviewSortLabels
  ///
  /// In zh, this message translates to:
  /// **'销售数量'**
  String get favoritesPageReviewSortLabelsReviewSortLabels2;

  /// pages/favorites_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'切换歌单'**
  String get favoritesPageBuildTooltip;

  /// pages/favorites_page.dart: _reviewSortLabels
  ///
  /// In zh, this message translates to:
  /// **'发布时间'**
  String get favoritesPageReviewSortLabelsReviewSortLabels3;

  /// pages/favorites_page.dart: _reviewSortLabels
  ///
  /// In zh, this message translates to:
  /// **'我的评价'**
  String get favoritesPageReviewSortLabelsReviewSortLabels4;

  /// pages/favorites_page.dart: _reviewSortLabels
  ///
  /// In zh, this message translates to:
  /// **'标记时间'**
  String get favoritesPageReviewSortLabelsReviewSortLabels5;

  /// pages/favorites_page.dart: _reviewSortLabels
  ///
  /// In zh, this message translates to:
  /// **'年龄分级'**
  String get ageRating;

  /// pages/favorites_page.dart: input
  ///
  /// In zh, this message translates to:
  /// **'添加作品'**
  String get favoritesPageInputText;

  /// pages/favorites_page.dart: _body
  ///
  /// In zh, this message translates to:
  /// **'已显示全部'**
  String get favoritesPageBodyText2;

  /// pages/favorites_page.dart: label
  ///
  /// In zh, this message translates to:
  /// **'移出播放列表'**
  String get favoritesPageLabelLabel2;

  /// pages/favorites_page.dart: _playlistHeaderActions
  ///
  /// In zh, this message translates to:
  /// **'复制分享链接'**
  String get favoritesPagePlaylistHeaderActionsTooltip;

  /// pages/favorites_page.dart: _addWorksByRj
  ///
  /// In zh, this message translates to:
  /// **'添加失败：{e}'**
  String favoritesPageAddWorksByRjToast(String e);

  /// pages/favorites_page.dart: _copyCurrentShareLink
  ///
  /// In zh, this message translates to:
  /// **'已复制分享链接'**
  String get shareLinkCopied;

  /// pages/favorites_page.dart: _removeSelectedWorks
  ///
  /// In zh, this message translates to:
  /// **'无法获取作品编号'**
  String get favoritesPageRemoveSelectedWorksToast;

  /// pages/favorites_page.dart: _body
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏的作品'**
  String get favoritesPageBodyText3;

  /// pages/favorites_page.dart: _removeCurrentLikedPlaylist
  ///
  /// In zh, this message translates to:
  /// **'取消收藏失败：{e}'**
  String favoritesPageRemoveCurrentLikedPlaylistToast(String e);

  /// pages/favorites_page.dart: _playlistHeaderActions
  ///
  /// In zh, this message translates to:
  /// **'取消收藏该播放列表'**
  String get favoritesPagePlaylistHeaderActionsTooltip2;

  /// pages/favorites_page.dart: _body
  ///
  /// In zh, this message translates to:
  /// **'该播放列表还没有作品'**
  String get favoritesPageBodyText4;

  /// pages/favorites_page.dart: _playlistHeaderActions
  ///
  /// In zh, this message translates to:
  /// **'按 RJ 号添加作品'**
  String get favoritesPagePlaylistHeaderActionsTooltip3;

  /// pages/favorites_page.dart: _addWorksByRj
  ///
  /// In zh, this message translates to:
  /// **'没有识别到 RJ 号'**
  String get favoritesPageAddWorksByRjToast2;

  /// pages/favorites_page.dart: _selectionBar
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 项'**
  String favoritesPageSelectionBarText(String count);

  /// pages/favorites_page.dart: _removeSelectedWorks
  ///
  /// In zh, this message translates to:
  /// **'{label}失败：{e}'**
  String favoritesPageRemoveSelectedWorksToast2(String label, String e);

  /// pages/favorites_page.dart: _body
  ///
  /// In zh, this message translates to:
  /// **'SFW 模式下不显示收藏内容'**
  String get favoritesPageBodyText5;

  /// pages/favorites_page.dart: _body
  ///
  /// In zh, this message translates to:
  /// **'加载失败，请确认已在设置中登录'**
  String get favoritesPageBodyText6;

  /// pages/favorites_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定从我的播放列表中移除该歌单吗？'**
  String get favoritesPageOkText;

  /// pages/favorites_page.dart: _addWorksByRj
  ///
  /// In zh, this message translates to:
  /// **'已添加 {length} 个作品'**
  String favoritesPageAddWorksByRjToast3(String length);

  /// pages/favorites_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定将 {count} 个作品{label}吗？'**
  String favoritesPageOkText2(String count, String label);

  /// pages/favorites_page.dart: _removeSelectedWorks
  ///
  /// In zh, this message translates to:
  /// **'已{label} {length} 个作品'**
  String favoritesPageRemoveSelectedWorksToast3(String label, String length);

  /// pages/favorites_page.dart: input
  ///
  /// In zh, this message translates to:
  /// **'输入 RJ 号，可一次填多个\n例如：RJ01367541 RJ01417842\n支持换行、空格或逗号分隔'**
  String get favoritesPageInputHintText;

  /// pages/history_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// pages/history_page.dart: _entryWork
  ///
  /// In zh, this message translates to:
  /// **'未知作品'**
  String get historyPageEntryWorkTitle;

  /// pages/history_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'播放历史'**
  String get playHistory;

  /// pages/history_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无播放历史'**
  String get historyPageBuildText;

  /// pages/history_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'SFW 模式下不显示播放历史'**
  String get historyPageBuildText2;

  /// pages/history_page.dart: _fmtTime
  ///
  /// In zh, this message translates to:
  /// **'今天 {padLeft}:{padLeft2}'**
  String historyPageFmtTimeText(String padLeft, String padLeft2);

  /// pages/history_page.dart: _fmtTime
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日 {padLeft}:{padLeft2}'**
  String historyPageFmtTimeText2(
    String month,
    String day,
    String padLeft,
    String padLeft2,
  );

  /// pages/home_page.dart: serverLabel
  ///
  /// In zh, this message translates to:
  /// **'自建'**
  String get homePageServerLabelText;

  /// pages/home_page.dart: labels
  ///
  /// In zh, this message translates to:
  /// **'热门'**
  String get homePageLabelsLabels;

  /// pages/home_page.dart: labels
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get homePageLabelsLabels2;

  /// pages/home_page.dart: sortLabels
  ///
  /// In zh, this message translates to:
  /// **'总评价'**
  String get homePageSortLabelsSortLabels;

  /// pages/home_page.dart: sortLabels
  ///
  /// In zh, this message translates to:
  /// **'收录时间'**
  String get homePageSortLabelsSortLabels2;

  /// pages/home_page.dart: sortLabels
  ///
  /// In zh, this message translates to:
  /// **'销售价格'**
  String get homePageSortLabelsSortLabels3;

  /// pages/home_page.dart: _emptyHint
  ///
  /// In zh, this message translates to:
  /// **'暂无作品'**
  String get homePageEmptyHintText;

  /// pages/home_page.dart: _searchResultsView
  ///
  /// In zh, this message translates to:
  /// **'搜索中…'**
  String get homePageSearchResultsViewText;

  /// pages/home_page.dart: _emptyHint
  ///
  /// In zh, this message translates to:
  /// **'正在加载…'**
  String get homePageEmptyHintText2;

  /// pages/home_page.dart: _grid
  ///
  /// In zh, this message translates to:
  /// **'已显示全部作品'**
  String get homePageGridText;

  /// pages/home_page.dart: _emptyHint
  ///
  /// In zh, this message translates to:
  /// **'点击任意处重试'**
  String get homePageEmptyHintText3;

  /// pages/home_page.dart: _searchResultsView
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关作品'**
  String get homePageSearchResultsViewText2;

  /// pages/home_page.dart: _searchResultsView
  ///
  /// In zh, this message translates to:
  /// **'已显示全部搜索结果'**
  String get homePageSearchResultsViewText3;

  /// pages/home_page.dart: _emptyHint
  ///
  /// In zh, this message translates to:
  /// **'当前筛选条件下暂无作品'**
  String get homePageEmptyHintText4;

  /// pages/home_page.dart: _emptyHint
  ///
  /// In zh, this message translates to:
  /// **'无网络连接，请检查网络或服务器设置'**
  String get homePageEmptyHintText5;

  /// pages/home_page.dart: _header
  ///
  /// In zh, this message translates to:
  /// **'SFW 模式已开启：仅显示全年龄内容'**
  String get homePageHeaderTooltip;

  /// pages/home_page.dart: _header
  ///
  /// In zh, this message translates to:
  /// **'开启 SFW 模式（仅显示全年龄内容）'**
  String get homePageHeaderTooltip2;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// pages/login_page.dart: _buildLogin
  ///
  /// In zh, this message translates to:
  /// **'登 录'**
  String get loginPageBuildLoginText;

  /// pages/login_page.dart: _showNoAccount
  ///
  /// In zh, this message translates to:
  /// **'关于账号'**
  String get loginPageShowNoAccountText;

  /// pages/login_page.dart: _showNoAccount
  ///
  /// In zh, this message translates to:
  /// **'我知道了'**
  String get loginPageShowNoAccountText2;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'返回登录'**
  String get loginPageBuildSiteConfigTooltip;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'已有站点'**
  String get loginPageBuildSiteConfigText;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'站点密码'**
  String get loginPageBuildSiteConfigHint;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'代理服务器'**
  String get loginPageShowProxyDialogLabelText;

  /// pages/login_page.dart: _buildLogin
  ///
  /// In zh, this message translates to:
  /// **'我没有账号'**
  String get loginPageBuildLoginText2;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'使用该站点'**
  String get loginPageBuildSiteConfigText2;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'添加新站点'**
  String get loginPageBuildSiteConfigText3;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'保存并进入'**
  String get loginPageBuildSiteConfigText4;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'配置网络代理'**
  String get loginPageShowProxyDialogText;

  /// pages/login_page.dart: _buildLogin
  ///
  /// In zh, this message translates to:
  /// **'配置自建站点'**
  String get loginPageBuildLoginText3;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'站点登录账号'**
  String get loginPageBuildSiteConfigHint2;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'网络代理已启用'**
  String get loginPageShowProxyDialogToast;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'网络代理已关闭'**
  String get loginPageShowProxyDialogToast2;

  /// pages/login_page.dart: _buildLogin
  ///
  /// In zh, this message translates to:
  /// **'one 站账号'**
  String get loginPageBuildLoginHint;

  /// pages/login_page.dart: _login
  ///
  /// In zh, this message translates to:
  /// **'请输入账号和密码'**
  String get loginPageLoginToast;

  /// pages/login_page.dart: _login
  ///
  /// In zh, this message translates to:
  /// **'请检查网络或账号密码'**
  String get loginPageLoginToast2;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'使用 HTTP 代理'**
  String get loginPageShowProxyDialogText2;

  /// pages/login_page.dart: _buildLogin
  ///
  /// In zh, this message translates to:
  /// **'登录 one 站账号'**
  String get loginPageBuildLoginText4;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'仅支持 HTTP 代理'**
  String get loginPageShowProxyDialogHelperText;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'别名，如：家庭 NAS'**
  String get loginPageBuildSiteConfigHint3;

  /// pages/login_page.dart: _saveNewSite
  ///
  /// In zh, this message translates to:
  /// **'请填写别名、地址、账号和密码'**
  String get loginPageSaveNewSiteToast;

  /// pages/login_page.dart: _showProxyDialog
  ///
  /// In zh, this message translates to:
  /// **'例如 http://代理地址:端口'**
  String get loginPageShowProxyDialogHintText;

  /// pages/login_page.dart: _buildSiteConfig
  ///
  /// In zh, this message translates to:
  /// **'支持 IP+端口，如 http://192.168.1.100:3000'**
  String get loginPageBuildSiteConfigText5;

  /// pages/login_page.dart: _login
  ///
  /// In zh, this message translates to:
  /// **'登录失败：{value}'**
  String loginPageLoginToast3(String value);

  /// pages/login_page.dart: _showNoAccount
  ///
  /// In zh, this message translates to:
  /// **'本项目不提供任何注册服务。\n\n账号与密码需要您自行获取，本项目不提供任何获取渠道。\n\n您使用该账号在本应用中获取、播放的任何内容，其所有权与责任均归属内容提供方与账号持有人，本项目对此不承担任何责任。\n\n账号信息仅保存在本地设备，不会上传到任何第三方服务器。'**
  String get loginPageShowNoAccountText3;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'远程'**
  String get remote;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueAction;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importAction;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'远程库'**
  String get lyricsLibraryPageBuildNavItem;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'歌词库'**
  String get lyricsLibrary;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'本地文件'**
  String get lyricsLibraryPageBuildNavItem2;

  /// pages/lyrics_library_page.dart: proceed
  ///
  /// In zh, this message translates to:
  /// **'继续导入'**
  String get lyricsLibraryPageProceedText;

  /// pages/lyrics_library_page.dart: _import
  ///
  /// In zh, this message translates to:
  /// **'取消导入'**
  String get lyricsLibraryPageImportText;

  /// pages/lyrics_library_page.dart: progress
  ///
  /// In zh, this message translates to:
  /// **'准备导入'**
  String get lyricsLibraryPageProgressPhase;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'深度刷新'**
  String get lyricsLibraryPageOkText;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'删除歌词'**
  String get lyricsLibraryPageOkText2;

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'选择文件夹'**
  String get lyricsLibraryPageSectionContentText;

  /// pages/lyrics_library_page.dart: confirmed
  ///
  /// In zh, this message translates to:
  /// **'删除远程库'**
  String get lyricsLibraryPageConfirmedText;

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'导入远程库'**
  String get lyricsLibraryPageSectionContentText2;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'导入歌词库'**
  String get lyricsLibraryPageBuildText;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'刷新歌词库'**
  String get lyricsLibraryPageBuildLabel;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'搜索歌词库'**
  String get lyricsLibraryPageBuildTooltip;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'正在导入歌词'**
  String get lyricsLibraryPageBuildText2;

  /// pages/lyrics_library_page.dart: _import
  ///
  /// In zh, this message translates to:
  /// **'跳过冲突文件'**
  String get lyricsLibraryPageImportText2;

  /// pages/lyrics_library_page.dart: _import
  ///
  /// In zh, this message translates to:
  /// **'覆盖冲突文件'**
  String get lyricsLibraryPageImportText3;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'移除远程作品'**
  String get lyricsLibraryPageOkText3;

  /// pages/lyrics_library_page.dart: proceed
  ///
  /// In zh, this message translates to:
  /// **'大型内容导入'**
  String get lyricsLibraryPageProceedText2;

  /// pages/lyrics_library_page.dart: _import
  ///
  /// In zh, this message translates to:
  /// **'发现导入冲突'**
  String get lyricsLibraryPageImportText4;

  /// pages/lyrics_library_page.dart: _remoteSourceList
  ///
  /// In zh, this message translates to:
  /// **'只刷新此远程库'**
  String get lyricsLibraryPageRemoteSourceListTooltip;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'删除歌词库作品'**
  String get lyricsLibraryPageOkText4;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'刷新全部远程库'**
  String get lyricsLibraryPageBuildLabel2;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'正在准备文件…'**
  String get lyricsLibraryPageBuildText3;

  /// pages/lyrics_library_page.dart: selection
  ///
  /// In zh, this message translates to:
  /// **'选择歌词文件夹'**
  String get lyricsLibraryPageSelectionDialogTitle;

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'正在连接并同步'**
  String get lyricsLibraryPageSectionContentText3;

  /// pages/lyrics_library_page.dart: _searchField
  ///
  /// In zh, this message translates to:
  /// **'搜索作品 ID'**
  String get lyricsLibraryPageSearchFieldHintText;

  /// pages/lyrics_library_page.dart: _import
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{e}'**
  String lyricsLibraryPageImportText5(String e);

  /// pages/lyrics_library_page.dart: _remoteSourceList
  ///
  /// In zh, this message translates to:
  /// **'尚未导入远程库'**
  String get lyricsLibraryPageRemoteSourceListText;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'长按执行深度刷新'**
  String get lyricsLibraryPageBuildHint;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'正在统计歌词文件'**
  String get lyricsLibraryPageBuildText4;

  /// pages/lyrics_library_page.dart: scanProgress
  ///
  /// In zh, this message translates to:
  /// **'正在检查文件冲突'**
  String get lyricsLibraryPageScanProgressPhase;

  /// pages/lyrics_library_page.dart: result
  ///
  /// In zh, this message translates to:
  /// **'选择 ZIP 文件'**
  String get lyricsLibraryPageResultDialogTitle;

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'选择 ZIP 压缩包'**
  String get lyricsLibraryPageSectionContentText4;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂时无法统计歌词文件'**
  String get lyricsLibraryPageBuildText5;

  /// pages/lyrics_library_page.dart: _refresh
  ///
  /// In zh, this message translates to:
  /// **'刷新失败：{error}'**
  String lyricsLibraryPageRefreshText(String error);

  /// pages/lyrics_library_page.dart: _showFiles
  ///
  /// In zh, this message translates to:
  /// **'没有可用的歌词或字幕文件'**
  String get lyricsLibraryPageShowFilesText;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无数据，点击右上角导入'**
  String get lyricsLibraryPageBuildText6;

  /// pages/lyrics_library_page.dart: _showFiles
  ///
  /// In zh, this message translates to:
  /// **'加载歌词文件失败，请重试'**
  String get lyricsLibraryPageShowFilesText2;

  /// pages/lyrics_library_page.dart: _reorder
  ///
  /// In zh, this message translates to:
  /// **'调整优先级失败：{error}'**
  String lyricsLibraryPageReorderSetState(String error);

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'HTTP / HTTPS 地址'**
  String get lyricsLibraryPageSectionContentLabelText;

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'同步所有已导入远程库的作品索引'**
  String get lyricsLibraryPageBuildHint2;

  /// pages/lyrics_library_page.dart: _import
  ///
  /// In zh, this message translates to:
  /// **'所选文件夹里没有歌词或字幕文件'**
  String get lyricsLibraryPageImportText6;

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'选择要导入的歌词文件或压缩包。'**
  String get lyricsLibraryPageSectionContentText5;

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'输入开启了歌词库广播的设备地址。'**
  String get lyricsLibraryPageSectionContentText6;

  /// pages/lyrics_library_page.dart: _refreshOne
  ///
  /// In zh, this message translates to:
  /// **'刷新 {url} 失败：{error}'**
  String lyricsLibraryPageRefreshOneSetState(String url, String error);

  /// pages/lyrics_library_page.dart: _removeRemoteLibrary
  ///
  /// In zh, this message translates to:
  /// **'删除 {url} 失败：{error}'**
  String lyricsLibraryPageRemoveRemoteLibrarySetState(String url, String error);

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'{directoryCount} 个目录'**
  String lyricsLibraryPageBuildText7(String directoryCount);

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'{length} 个'**
  String lyricsLibraryPageBuildText8(String length);

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无远程作品，点击右上角导入并连接远程库'**
  String get lyricsLibraryPageBuildText9;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定移除 {workId} 的远程作品索引吗？'**
  String lyricsLibraryPageOkText5(String workId);

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定删除 {workId} 的全部歌词文件吗？'**
  String lyricsLibraryPageOkText6(String workId);

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'将删除没有歌词或字幕文件的作品目录，是否继续？'**
  String get lyricsLibraryPageOkText7;

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'已导入的远程库（从上到下优先级递减，拖动排序）'**
  String get lyricsLibraryPageSectionContentText7;

  /// pages/lyrics_library_page.dart: _remoteSourceList
  ///
  /// In zh, this message translates to:
  /// **'优先级 {value} · 长按删除'**
  String lyricsLibraryPageRemoteSourceListText2(String value);

  /// pages/lyrics_library_page.dart: confirmed
  ///
  /// In zh, this message translates to:
  /// **'确定移除远程库 {url} 及其已同步的作品索引吗？'**
  String lyricsLibraryPageConfirmedText2(String url);

  /// pages/lyrics_library_page.dart: sectionContent
  ///
  /// In zh, this message translates to:
  /// **'导入时只同步作品索引；播放时再下载该作品的全部歌词。'**
  String get lyricsLibraryPageSectionContentText8;

  /// pages/lyrics_library_page.dart: proceed
  ///
  /// In zh, this message translates to:
  /// **'检测到大型压缩包或文件夹，导入过程可能需要较长时间，请耐心等待。'**
  String get lyricsLibraryPageProceedText3;

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定删除选中的 {length} 个作品目录吗？'**
  String lyricsLibraryPageOkText8(String length);

  /// pages/lyrics_library_page.dart: _import
  ///
  /// In zh, this message translates to:
  /// **'检测到 {length} 个已存在文件，如何处理？'**
  String lyricsLibraryPageImportText7(String length);

  /// pages/lyrics_library_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定移除选中的 {length} 个远程作品索引吗？'**
  String lyricsLibraryPageOkText9(String length);

  /// pages/lyrics_library_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'{fileCount} 个歌词/字幕文件 · {value}'**
  String lyricsLibraryPageBuildText10(String fileCount, String value);

  /// pages/more_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'歌单'**
  String get morePageBuildRow;

  /// pages/more_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// pages/more_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'随心听'**
  String get morePageBuildRow2;

  /// pages/more_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'服务器：{server}'**
  String morePageBuildText(String server);

  /// pages/more_page.dart: _openRandomWork
  ///
  /// In zh, this message translates to:
  /// **'当前条件下没有可播放的作品'**
  String get morePageOpenRandomWorkText;

  /// pages/more_page.dart: _openRandomWork
  ///
  /// In zh, this message translates to:
  /// **'随心听加载失败，请稍后重试'**
  String get morePageOpenRandomWorkText2;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'归零'**
  String get playerPageShowLyricSettingsText;

  /// pages/player_page.dart: _wideLandscape
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// pages/player_page.dart: left
  ///
  /// In zh, this message translates to:
  /// **'快退'**
  String get seekBackward;

  /// pages/player_page.dart: right
  ///
  /// In zh, this message translates to:
  /// **'快进'**
  String get seekForward;

  /// pages/player_page.dart: _utils
  ///
  /// In zh, this message translates to:
  /// **'定时'**
  String get playerPageUtilsUtil;

  /// pages/player_page.dart: actions
  ///
  /// In zh, this message translates to:
  /// **'均衡器'**
  String get equalizer;

  /// pages/player_page.dart: _utils
  ///
  /// In zh, this message translates to:
  /// **'定时中'**
  String get playerPageUtilsUtil2;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'繁简互转'**
  String get playerPageShowLyricSettingsText2;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'自动匹配'**
  String get autoMatch;

  /// pages/player_page.dart: actions
  ///
  /// In zh, this message translates to:
  /// **'作品详情'**
  String get workDetails;

  /// pages/player_page.dart: actions
  ///
  /// In zh, this message translates to:
  /// **'播放列表'**
  String get playlist;

  /// pages/player_page.dart: actions
  ///
  /// In zh, this message translates to:
  /// **'定时关闭'**
  String get sleepTimer;

  /// pages/player_page.dart: _wideLyricsPanel
  ///
  /// In zh, this message translates to:
  /// **'暂无歌词'**
  String get playerPageWideLyricsPanelText;

  /// pages/player_page.dart: _topBar
  ///
  /// In zh, this message translates to:
  /// **'正在播放'**
  String get playerPageTopBarText;

  /// pages/player_page.dart: _topBar
  ///
  /// In zh, this message translates to:
  /// **'桌面歌词'**
  String get desktopLyrics;

  /// pages/player_page.dart: _playModeLabel
  ///
  /// In zh, this message translates to:
  /// **'循环播放'**
  String get playerPagePlayModeLabelText;

  /// pages/player_page.dart: _playModeLabel
  ///
  /// In zh, this message translates to:
  /// **'单曲循环'**
  String get playerPagePlayModeLabelText2;

  /// pages/player_page.dart: _playModeLabel
  ///
  /// In zh, this message translates to:
  /// **'列表播放'**
  String get playerPagePlayModeLabelText3;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'歌词设置'**
  String get playerPageShowLyricSettingsText3;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'字幕偏移'**
  String get playerPageShowLyricSettingsText4;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'简 → 繁'**
  String get simplifiedToTraditional;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'繁 → 简'**
  String get traditionalToSimplified;

  /// pages/player_page.dart: _showQueue
  ///
  /// In zh, this message translates to:
  /// **'播放列表为空'**
  String get playerPageShowQueueText;

  /// pages/player_page.dart: res
  ///
  /// In zh, this message translates to:
  /// **'选择歌词文件'**
  String get playerPageResDialogTitle;

  /// pages/player_page.dart: _pickOnlineLyric
  ///
  /// In zh, this message translates to:
  /// **'选择在线歌词'**
  String get playerPagePickOnlineLyricText;

  /// pages/player_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无播放内容'**
  String get playerPageBuildText;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'选择离线歌词'**
  String get playerPageShowLyricSettingsTitle;

  /// pages/player_page.dart: _pickOnlineLyric
  ///
  /// In zh, this message translates to:
  /// **'未找到在线歌词'**
  String get playerPagePickOnlineLyricToast;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'选择歌词库歌词'**
  String get playerPageShowLyricSettingsTitle2;

  /// pages/player_page.dart: _loadOnlineLyric
  ///
  /// In zh, this message translates to:
  /// **'该歌词无法解析'**
  String get playerPageLoadOnlineLyricToast;

  /// pages/player_page.dart: _lyricsPanel
  ///
  /// In zh, this message translates to:
  /// **'正在加载歌词…'**
  String get playerPageLyricsPanelText;

  /// No description provided for @playerAlreadyFirstTrack.
  ///
  /// In zh, this message translates to:
  /// **'已经是第一首'**
  String get playerAlreadyFirstTrack;

  /// No description provided for @playerAlreadyLastTrack.
  ///
  /// In zh, this message translates to:
  /// **'已经是最后一首'**
  String get playerAlreadyLastTrack;

  /// pages/player_page.dart: _next
  ///
  /// In zh, this message translates to:
  /// **'已播放完播放列表'**
  String get playerPageNextToast;

  /// pages/player_page.dart: _openCurrent
  ///
  /// In zh, this message translates to:
  /// **'文件流需登录后可用'**
  String get playerPageOpenCurrentToast;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'歌词库中没有该作品'**
  String get playerPageShowLyricSettingsSub;

  /// pages/player_page.dart: _openMedia
  ///
  /// In zh, this message translates to:
  /// **'打开媒体超时，请重试'**
  String get playerPageOpenMediaToast;

  /// pages/player_page.dart: _libraryAutoTile
  ///
  /// In zh, this message translates to:
  /// **'从歌词库自动匹配歌词'**
  String get playerPageLibraryAutoTileText;

  /// pages/player_page.dart: _openMedia
  ///
  /// In zh, this message translates to:
  /// **'打开失败，正在重试…'**
  String get playerPageOpenMediaToast2;

  /// pages/player_page.dart: _friendlyPlayError
  ///
  /// In zh, this message translates to:
  /// **'媒体流代理异常，请重试'**
  String get playerPageFriendlyPlayErrorText;

  /// No description provided for @playerLoudnessBoostLabel.
  ///
  /// In zh, this message translates to:
  /// **'响度提升'**
  String get playerLoudnessBoostLabel;

  /// pages/player_page.dart: _volumeControl
  ///
  /// In zh, this message translates to:
  /// **'响度提升（上限 120）'**
  String get playerPageVolumeControlTooltip;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'从本地选择歌词或字幕文件'**
  String get playerPageShowLyricSettingsSub2;

  /// pages/player_page.dart: initState
  ///
  /// In zh, this message translates to:
  /// **'网络波动，正在自动重连…'**
  String get playerPageInitStateToast;

  /// pages/player_page.dart: _pickLibraryLyric
  ///
  /// In zh, this message translates to:
  /// **'歌词库中没有该作品的歌词'**
  String get playerPagePickLibraryLyricToast;

  /// pages/player_page.dart: _openMedia
  ///
  /// In zh, this message translates to:
  /// **'打开媒体超时，正在重试…'**
  String get playerPageOpenMediaToast3;

  /// pages/player_page.dart: _showLyricSettings
  ///
  /// In zh, this message translates to:
  /// **'仅显示当前作品的歌词文件'**
  String get playerPageShowLyricSettingsSub3;

  /// pages/player_page.dart: _checkSleep
  ///
  /// In zh, this message translates to:
  /// **'已停止播放，系统接口已释放'**
  String get playerPageCheckSleepToast;

  /// pages/player_page.dart: _pickOnlineLyric
  ///
  /// In zh, this message translates to:
  /// **'按曲目名与中文优先自动选择'**
  String get playerPagePickOnlineLyricSub;

  /// pages/player_page.dart: _friendlyPlayError
  ///
  /// In zh, this message translates to:
  /// **'服务器返回错误，请稍后重试'**
  String get playerPageFriendlyPlayErrorText2;

  /// pages/player_page.dart: _volumeControl
  ///
  /// In zh, this message translates to:
  /// **'启用响度提升（上限 120）'**
  String get playerPageVolumeControlTooltip2;

  /// pages/player_page.dart: _friendlyPlayError
  ///
  /// In zh, this message translates to:
  /// **'登录已失效，请重新登录后重试'**
  String get playerPageFriendlyPlayErrorText3;

  /// pages/player_page.dart: _pickOfflineLyric
  ///
  /// In zh, this message translates to:
  /// **'文件中没有可读取的带时间轴歌词'**
  String get playerPagePickOfflineLyricToast;

  /// pages/player_page.dart: _friendlyPlayError
  ///
  /// In zh, this message translates to:
  /// **'无法连接媒体流，请检查网络后重试'**
  String get playerPageFriendlyPlayErrorText4;

  /// pages/player_page.dart: _volumeControl
  ///
  /// In zh, this message translates to:
  /// **'响度提升 Plus（上限 200）'**
  String get playerPageVolumeControlTooltip3;

  /// pages/player_page.dart: _toggleDesktopLyrics
  ///
  /// In zh, this message translates to:
  /// **'未授予悬浮窗权限，桌面歌词无法显示'**
  String get playerPageToggleDesktopLyricsToast;

  /// pages/player_page.dart: _seekCircle
  ///
  /// In zh, this message translates to:
  /// **'{label} {seconds} 秒'**
  String playerPageSeekCircleMessage(String label, String seconds);

  /// pages/player_page.dart: _libraryAutoTile
  ///
  /// In zh, this message translates to:
  /// **'优先匹配本地歌词，找不到时使用在线歌词'**
  String get playerPageLibraryAutoTileText2;

  /// pages/player_page.dart: _showQueue
  ///
  /// In zh, this message translates to:
  /// **'播放列表（{length}）'**
  String playerPageShowQueueText2(String length);

  /// pages/player_page.dart: initState
  ///
  /// In zh, this message translates to:
  /// **'播放失败：{friendlyPlayError}'**
  String playerPageInitStateToast2(String friendlyPlayError);

  /// pages/player_page.dart: _openMedia
  ///
  /// In zh, this message translates to:
  /// **'无法打开媒体流：{friendlyPlayError}'**
  String playerPageOpenMediaToast4(String friendlyPlayError);

  /// pages/playlists_page.dart: name
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get playlistsPageNameText;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get playlistsPageBuildText;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'新建歌单'**
  String get playlistsPageBuildText2;

  /// pages/playlists_page.dart: name
  ///
  /// In zh, this message translates to:
  /// **'歌单名称'**
  String get playlistsPageNameHintText;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'歌单为空'**
  String get playlistsPageBuildText3;

  /// pages/playlists_page.dart: header
  ///
  /// In zh, this message translates to:
  /// **'移除作品'**
  String get playlistsPageHeaderTooltip;

  /// pages/playlists_page.dart: name
  ///
  /// In zh, this message translates to:
  /// **'重命名歌单'**
  String get playlistsPageNameText2;

  /// pages/playlists_page.dart: header
  ///
  /// In zh, this message translates to:
  /// **'拖动调整作品顺序'**
  String get playlistsPageHeaderMessage;

  /// pages/playlists_page.dart: row
  ///
  /// In zh, this message translates to:
  /// **'拖动调整播放顺序'**
  String get playlistsPageRowMessage;

  /// pages/playlists_page.dart: _playTrack
  ///
  /// In zh, this message translates to:
  /// **'歌单中没有可播放的音频'**
  String get playlistsPagePlayTrackText;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'SFW 模式下不显示歌单'**
  String get playlistsPageBuildText4;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无歌单，点击右下角新建'**
  String get playlistsPageBuildText5;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'SFW 模式下不显示歌单内容'**
  String get playlistsPageBuildText6;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'{length} 个条目'**
  String playlistsPageBuildText7(String length);

  /// pages/playlists_page.dart: _playTrack
  ///
  /// In zh, this message translates to:
  /// **'该音频缺少可用文件流，请从作品详情重新添加'**
  String get playlistsPagePlayTrackText2;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'拖动标题调整作品顺序，拖动媒体调整播放顺序'**
  String get playlistsPageBuildText8;

  /// pages/playlists_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'长按标题调整作品顺序，长按媒体调整播放顺序'**
  String get playlistsPageBuildText9;

  /// pages/playlists_page.dart: header
  ///
  /// In zh, this message translates to:
  /// **'{length} 个音频'**
  String playlistsPageHeaderText(String length);

  /// pages/settings_page.dart: _translationTargetLabel
  ///
  /// In zh, this message translates to:
  /// **'繁中'**
  String get traditionalChineseShort;

  /// pages/settings_page.dart: _translationTargetLabel
  ///
  /// In zh, this message translates to:
  /// **'英语'**
  String get englishLanguage;

  /// pages/settings_page.dart: _translationTargetLabel
  ///
  /// In zh, this message translates to:
  /// **'简中'**
  String get simplifiedChineseShort;

  /// pages/settings_page.dart: _healthBadge
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get settingsPageHealthBadgeStartsWith;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'检测'**
  String get settingsPageSectionsMiniBtn;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get settingsPageSectionsMiniBtn2;

  /// pages/settings_page.dart: _lockRow
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get settingsPageLockRowText;

  /// pages/settings_page.dart: _sectionTitle
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'歌词'**
  String get lyrics;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'曲目'**
  String get settingsPageSectionsSection;

  /// pages/settings_page.dart: _onVersionTap
  ///
  /// In zh, this message translates to:
  /// **'好吧'**
  String get settingsPageOnVersionTapText;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'数据与网络'**
  String get settingsPageSectionsSection2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsPageSectionsSection3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsPageSectionsText;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsPageSectionsText2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsPageSectionsText3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get settingsPageSectionsText4;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsPageSectionsSection4;

  /// pages/settings_page.dart: _sectionTitle
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get settingsPageSectionTitleText;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingsPageSectionsTitle;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'仓库'**
  String get settingsPageSectionsTitle2;

  /// pages/settings_page.dart: _lockRow
  ///
  /// In zh, this message translates to:
  /// **'未锁定'**
  String get settingsPageLockRowSub;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'去关闭'**
  String get settingsPageSectionsMiniBtn3;

  /// pages/settings_page.dart: _shortcutConflict
  ///
  /// In zh, this message translates to:
  /// **'下一曲'**
  String get settingsPageShortcutConflictText;

  /// pages/settings_page.dart: _shortcutConflict
  ///
  /// In zh, this message translates to:
  /// **'上一曲'**
  String get settingsPageShortcutConflictText2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'桌面端'**
  String get settingsPageSectionsLockRow;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get settingsPageSectionsMiniBtn4;

  /// pages/settings_page.dart: _shortcutLabel
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get settingsPageShortcutLabelText;

  /// pages/settings_page.dart: _engineDropdown
  ///
  /// In zh, this message translates to:
  /// **'翻译引擎'**
  String get translationEngine;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'字体颜色'**
  String get settingsPageSectionsLabel;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'描边颜色'**
  String get settingsPageSectionsLabel2;

  /// pages/settings_page.dart: labels
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// pages/settings_page.dart: _autoCheck
  ///
  /// In zh, this message translates to:
  /// **'检测中…'**
  String get settingsPageAutoCheckSetState;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'快退秒数'**
  String get settingsPageSectionsTitle3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get interfaceLanguage;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'快进秒数'**
  String get settingsPageSectionsTitle4;

  /// pages/settings_page.dart: _aiModelInput
  ///
  /// In zh, this message translates to:
  /// **'模型名称'**
  String get settingsPageAiModelInputLabelText;

  /// pages/settings_page.dart: _shortcutLabel
  ///
  /// In zh, this message translates to:
  /// **'方向键→'**
  String get settingsPageShortcutLabelText2;

  /// pages/settings_page.dart: _convDropdown
  ///
  /// In zh, this message translates to:
  /// **'繁简转换'**
  String get chineseConversion;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'描边宽度'**
  String get settingsPageSectionsText5;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'账号设置'**
  String get settingsPageSectionsSection5;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get settingsPageSectionsText6;

  /// pages/settings_page.dart: _shortcutLabel
  ///
  /// In zh, this message translates to:
  /// **'方向键←'**
  String get settingsPageShortcutLabelText3;

  /// pages/settings_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'完全重置'**
  String get settingsPageBuildText;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'智能路径'**
  String get settingsPageSectionsSwitchRow;

  /// pages/settings_page.dart: _autoCheck
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get settingsPageAutoCheckSetState2;

  /// pages/settings_page.dart: labels
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// pages/settings_page.dart: _openRepo
  ///
  /// In zh, this message translates to:
  /// **'打开失败'**
  String get settingsPageOpenRepoToast;

  /// pages/settings_page.dart: _editAudioTypePreference
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get settingsPageEditAudioTypePreferenceText;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'界面缩放'**
  String get settingsPageSectionsText7;

  /// pages/settings_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'确定重置'**
  String get settingsPageBuildText2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get settingsPageSectionsTitle5;

  /// pages/settings_page.dart: _translationTargetDropdown
  ///
  /// In zh, this message translates to:
  /// **'目标语言'**
  String get targetLanguage;

  /// pages/settings_page.dart: _sectionTitle
  ///
  /// In zh, this message translates to:
  /// **'语言与翻译'**
  String get languageAndTranslation;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'歌词库广播'**
  String get settingsPageSectionsSwitchRow2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'剪贴板检测'**
  String get settingsPageSectionsSwitchRow3;

  /// pages/settings_page.dart: _shortcutConflict
  ///
  /// In zh, this message translates to:
  /// **'播放/暂停'**
  String get settingsPageShortcutConflictText3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'快退快捷键'**
  String get settingsPageSectionsTitle6;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'效果音偏好'**
  String get settingsPageSectionsSwitchRow4;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'快进快捷键'**
  String get settingsPageSectionsTitle7;

  /// pages/settings_page.dart: _onVersionTap
  ///
  /// In zh, this message translates to:
  /// **'开发者模式'**
  String get settingsPageOnVersionTapText2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'未配置账号'**
  String get settingsPageSectionsSub;

  /// pages/settings_page.dart: row
  ///
  /// In zh, this message translates to:
  /// **'点击进入设置'**
  String get settingsPageRowSub;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'音频类型偏好'**
  String get settingsPageSectionsTitle8;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'检测模型列表'**
  String get settingsPageSectionsText8;

  /// pages/settings_page.dart: _proxySettings
  ///
  /// In zh, this message translates to:
  /// **'清空代理地址'**
  String get settingsPageProxySettingsTooltip;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'上一曲快捷键'**
  String get settingsPageSectionsTitle9;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'关闭省电优化'**
  String get settingsPageSectionsTitle10;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'忽略音频焦点'**
  String get settingsPageSectionsSwitchRow5;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'自动检测更新'**
  String get settingsPageSectionsSwitchRow6;

  /// pages/settings_page.dart: _mediaCacheLimitRow
  ///
  /// In zh, this message translates to:
  /// **'媒体缓存上限'**
  String get settingsPageMediaCacheLimitRowText;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'下一曲快捷键'**
  String get settingsPageSectionsTitle11;

  /// pages/settings_page.dart: _translationTargetDropdown
  ///
  /// In zh, this message translates to:
  /// **'翻译目标语言'**
  String get translationTargetLanguage;

  /// pages/settings_page.dart: _translationTargetLabel
  ///
  /// In zh, this message translates to:
  /// **'跟随界面语言'**
  String get followInterfaceLanguage;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'添加自建站点'**
  String get settingsPageSectionsText9;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'安卓（横屏）'**
  String get settingsPageSectionsLockRow2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'安卓（竖屏）'**
  String get settingsPageSectionsLockRow3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'完全重置软件'**
  String get settingsPageSectionsTitle12;

  /// pages/settings_page.dart: _proxySettings
  ///
  /// In zh, this message translates to:
  /// **'HTTP 代理'**
  String get settingsPageProxySettingsSwitchRow;

  /// pages/settings_page.dart: _aiModelInput
  ///
  /// In zh, this message translates to:
  /// **'选择已检测模型'**
  String get settingsPageAiModelInputTooltip;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'恢复默认快捷键'**
  String get settingsPageSectionsTitle13;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'不记忆播放进度'**
  String get settingsPageSectionsSwitchRow7;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'歌词与桌面歌词'**
  String get settingsPageSectionsSection6;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{e}'**
  String settingsPageSectionsToast(String e);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'正在检测连接…'**
  String get settingsPageSectionsToast2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'拔出耳机自动暂停'**
  String get settingsPageSectionsSwitchRow8;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'播放/暂停快捷键'**
  String get settingsPageSectionsTitle14;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'手动请求更新服务'**
  String get settingsPageSectionsSub2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'最顶层悬浮歌词窗'**
  String get settingsPageSectionsSwitchRow9;

  /// pages/settings_page.dart: _aiModelInput
  ///
  /// In zh, this message translates to:
  /// **'请先检测模型列表'**
  String get settingsPageAiModelInputTooltip2;

  /// pages/settings_page.dart: _proxySettings
  ///
  /// In zh, this message translates to:
  /// **'留空将不使用代理'**
  String get settingsPageProxySettingsHelperText;

  /// pages/settings_page.dart: labels
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容'**
  String get settingsPageLabelsLabels;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口后保留托盘'**
  String get settingsPageSectionsSwitchRow10;

  /// pages/settings_page.dart: _detectOpenAiModels
  ///
  /// In zh, this message translates to:
  /// **'正在获取模型列表…'**
  String get settingsPageDetectOpenAiModelsToast;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'不显示通知栏媒体卡片'**
  String get settingsPageSectionsSwitchRow11;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'歌词中文部分自动转换'**
  String get settingsPageSectionsSub3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'源语言 / 目标语言'**
  String get sourceAndTargetLanguage;

  /// pages/settings_page.dart: _detectOpenAiModels
  ///
  /// In zh, this message translates to:
  /// **'请先填写 API 地址'**
  String get settingsPageDetectOpenAiModelsToast2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'定时关闭后释放系统接口'**
  String get settingsPageSectionsSwitchRow12;

  /// pages/settings_page.dart: _playbackShortcutRow
  ///
  /// In zh, this message translates to:
  /// **'播放器页获得焦点时生效'**
  String get settingsPagePlaybackShortcutRowSub;

  /// pages/settings_page.dart: _aiModelInput
  ///
  /// In zh, this message translates to:
  /// **'输入模型名或从列表选择'**
  String get settingsPageAiModelInputHintText;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'防止后台播放被系统中断'**
  String get settingsPageSectionsSub4;

  /// pages/settings_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'已保存地址，开启后生效'**
  String get settingsPageStatusStatus;

  /// pages/settings_page.dart: _lockRow
  ///
  /// In zh, this message translates to:
  /// **'{label} 歌词锁定'**
  String settingsPageLockRowTitle(String label);

  /// pages/settings_page.dart: _detectOpenAiModels
  ///
  /// In zh, this message translates to:
  /// **'模型列表获取失败：{e}'**
  String settingsPageDetectOpenAiModelsToast3(String e);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'正在检测 DeepL…'**
  String get settingsPageSectionsToast3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'优先进入包含效果音的目录'**
  String get settingsPageSectionsSwitchRow13;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'关闭歌词库广播失败：{e}'**
  String settingsPageSectionsToast4(String e);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'无法开启歌词库广播：{e}'**
  String settingsPageSectionsToast5(String e);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'打开作品自动进入最佳目录'**
  String get settingsPageSectionsSwitchRow14;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'DeepL 连接失败：{e}'**
  String settingsPageSectionsToast6(String e);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'自动识别复制的 RJ 链接'**
  String get settingsPageSectionsSwitchRow15;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'到点清除锁屏媒体卡片与通知'**
  String get settingsPageSectionsSwitchRow16;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'启动后 3 秒请求更新服务'**
  String get settingsPageSectionsSwitchRow17;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'DeepL 连接正常：{r}'**
  String settingsPageSectionsToast7(String r);

  /// pages/settings_page.dart: _onVersionTap
  ///
  /// In zh, this message translates to:
  /// **'你不会真以为有开发者模式吧？'**
  String get settingsPageOnVersionTapText3;

  /// pages/settings_page.dart: _proxySettings
  ///
  /// In zh, this message translates to:
  /// **'开启 HTTP 代理后可编辑'**
  String get settingsPageProxySettingsHelperText2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'拔出耳机或断开蓝牙时自动暂停'**
  String get settingsPageSectionsSwitchRow18;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'与其他应用同时播放，互不打断'**
  String get settingsPageSectionsSwitchRow19;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'播放时不在通知栏显示媒体卡片'**
  String get settingsPageSectionsSwitchRow20;

  /// pages/settings_page.dart: _aiModelInput
  ///
  /// In zh, this message translates to:
  /// **'例如 gpt-4o-mini'**
  String get settingsPageAiModelInputHintText2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'通知栏封面显示项目 logo'**
  String get settingsPageSectionsSwitchRow21;

  /// pages/settings_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'确定重置（{count} 秒）'**
  String settingsPageBuildText3(String count);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'清除本机全部数据，恢复初始状态'**
  String get settingsPageSectionsSub5;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'5–60 秒，每次调整 5 秒'**
  String get settingsPageSectionsSub6;

  /// pages/settings_page.dart: _editPlaybackShortcut
  ///
  /// In zh, this message translates to:
  /// **'该按键已用于{conflict}'**
  String settingsPageEditPlaybackShortcutToast(String conflict);

  /// pages/settings_page.dart: _detectOpenAiModels
  ///
  /// In zh, this message translates to:
  /// **'响应未包含 data[].id'**
  String get settingsPageDetectOpenAiModelsFormatException;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'API Key（本地服务可留空）'**
  String get settingsPageSectionsInput;

  /// pages/settings_page.dart: _confirmReset
  ///
  /// In zh, this message translates to:
  /// **'已重置：账号与全部本地数据已清除'**
  String get settingsPageConfirmResetText;

  /// pages/settings_page.dart: _requestBatteryIgnore
  ///
  /// In zh, this message translates to:
  /// **'请在系统设置中允许「忽略电池优化」'**
  String get settingsPageRequestBatteryIgnoreToast;

  /// pages/settings_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'已启用，请填写 HTTP 代理地址'**
  String get settingsPageStatusStatus2;

  /// pages/settings_page.dart: _mediaCacheLimitRow
  ///
  /// In zh, this message translates to:
  /// **'仅限制在线播放缓冲，不影响下载功能'**
  String get settingsPageMediaCacheLimitRowText2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'关闭窗口时将停止后台运行并退出程序'**
  String get settingsPageSectionsSwitchRow22;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'已加入白名单，后台播放不受省电限制'**
  String get settingsPageSectionsSub7;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'API 地址 (Base URL)'**
  String get settingsPageSectionsInput2;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'DeepL 免费版 API Key'**
  String get settingsPageSectionsInput3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'账号：{asmrUser}'**
  String settingsPageSectionsSub8(String asmrUser);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'关闭后继续在后台播放，可从系统托盘恢复'**
  String get settingsPageSectionsSwitchRow23;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'重启程序后恢复上次曲目，但从头开始播放'**
  String get settingsPageSectionsSwitchRow24;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'只读 API 服务 · 端口 2377'**
  String get settingsPageSectionsSwitchRow25;

  /// pages/settings_page.dart: _lockRow
  ///
  /// In zh, this message translates to:
  /// **'已锁定：点击歌词不会响应，可在设置中解锁'**
  String get settingsPageLockRowSub2;

  /// pages/settings_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'仅支持 HTTP 协议代理，对所有网络请求生效'**
  String get settingsPageStatusStatus3;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'开启后封面位置显示项目 logo，不显示真实封面'**
  String get settingsPageSectionsSwitchRow26;

  /// pages/settings_page.dart: _detectOpenAiModels
  ///
  /// In zh, this message translates to:
  /// **'已获取 {length} 个模型'**
  String settingsPageDetectOpenAiModelsToast4(String length);

  /// pages/settings_page.dart: _onVersionTap
  ///
  /// In zh, this message translates to:
  /// **'再执行 {value} 步进入开发者模式'**
  String settingsPageOnVersionTapToast(String value);

  /// pages/settings_page.dart: status
  ///
  /// In zh, this message translates to:
  /// **'已启用：{trim}'**
  String settingsPageStatusStatus4(String trim);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'在 deepl.com 免费注册后获取（api-free）'**
  String get settingsPageSectionsInput4;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'Space / PageUp / PageDown / 方向键←→'**
  String get settingsPageSectionsSub9;

  /// pages/settings_page.dart: _aiModelInput
  ///
  /// In zh, this message translates to:
  /// **'已检测到 {length} 个模型'**
  String settingsPageAiModelInputHelperText(String length);

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'Google / Microsoft 免费 · DeepL 免费 Key · OpenAI 兼容'**
  String get settingsPageSectionsSub10;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'https://api.openai.com/v1 或 http://127.0.0.1:11434/v1'**
  String get settingsPageSectionsInput5;

  /// pages/settings_page.dart: sections
  ///
  /// In zh, this message translates to:
  /// **'日语 → {translationTargetLabel}'**
  String settingsPageSectionsSub11(String translationTargetLabel);

  /// pages/settings_page.dart: nextKeyId
  ///
  /// In zh, this message translates to:
  /// **'当前按键：{shortcutLabel}\n\n按下新的单个按键'**
  String settingsPageNextKeyIdText(String shortcutLabel);

  /// pages/settings_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'将清除本机全部数据，且不可恢复：\n\n· ASMR.ONE 账号与自建站点配置\n· 收藏 / 播放历史 / 歌单 / 黑名单\n· 翻译结果、均衡器、桌面歌词、定时关闭等全部设置\n\n请确认是否继续。'**
  String get settingsPageBuildText4;

  /// pages/work_page.dart: _markButton
  ///
  /// In zh, this message translates to:
  /// **'标记'**
  String get mark;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get workPageBuildLabel;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'翻译'**
  String get translate;

  /// pages/work_page.dart: _refreshWork
  ///
  /// In zh, this message translates to:
  /// **'已刷新'**
  String get workPageRefreshWorkToast;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'上一张'**
  String get workPageBuildTooltip;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get workPageBuildText;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'翻译中'**
  String get workPageBuildText2;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'下一张'**
  String get workPageBuildTooltip2;

  /// pages/work_page.dart: _languageEditionsButton
  ///
  /// In zh, this message translates to:
  /// **'多语言'**
  String get workPageLanguageEditionsButtonText;

  /// pages/work_page.dart: _similarWorksSlivers
  ///
  /// In zh, this message translates to:
  /// **'相似作品'**
  String get workPageSimilarWorksSliversText;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'曲目列表'**
  String get workPageBuildText3;

  /// pages/work_page.dart: confirmed
  ///
  /// In zh, this message translates to:
  /// **'删除标记'**
  String get workPageConfirmedText;

  /// pages/work_page.dart: confirmed
  ///
  /// In zh, this message translates to:
  /// **'删除作品'**
  String get workPageConfirmedText2;

  /// pages/work_page.dart: _refreshWork
  ///
  /// In zh, this message translates to:
  /// **'刷新失败'**
  String get workPageRefreshWorkToast2;

  /// pages/work_page.dart: _showTextViewer
  ///
  /// In zh, this message translates to:
  /// **'切换编码'**
  String get workPageShowTextViewerTooltip;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'我的评论'**
  String get workPageBuildText4;

  /// pages/work_page.dart: _addToPlaylist
  ///
  /// In zh, this message translates to:
  /// **'确认添加'**
  String get workPageAddToPlaylistText;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'写评论…'**
  String get workPageBuildHintText;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'取消翻译'**
  String get workPageBuildText5;

  /// pages/work_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'加入黑名单'**
  String get workPageOkText;

  /// pages/work_page.dart: _addToPlaylist
  ///
  /// In zh, this message translates to:
  /// **'添加到歌单'**
  String get workPageAddToPlaylistText2;

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'已取消翻译'**
  String get workPageTranslateTitlesToast;

  /// pages/work_page.dart: selected
  ///
  /// In zh, this message translates to:
  /// **'选择 CV'**
  String get workPageSelectedText;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'添加至歌单'**
  String get workPageBuildText6;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'下载选中项目'**
  String get workPageBuildText7;

  /// pages/work_page.dart: _openVideoChooser
  ///
  /// In zh, this message translates to:
  /// **'选择打开方式'**
  String get workPageOpenVideoChooserText;

  /// pages/work_page.dart: _openVideoChooser
  ///
  /// In zh, this message translates to:
  /// **'音频方式打开'**
  String get workPageOpenVideoChooserText2;

  /// pages/work_page.dart: selected
  ///
  /// In zh, this message translates to:
  /// **'切换翻译引擎'**
  String get workPageSelectedText2;

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'未知翻译引擎'**
  String get workPageTranslateTitlesToast2;

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'翻译结果为空'**
  String get workPageTranslateTitlesFormatException;

  /// pages/work_page.dart: _allFilesRow
  ///
  /// In zh, this message translates to:
  /// **'查看全部文件'**
  String get workPageAllFilesRowText;

  /// pages/work_page.dart: _downloadSelected
  ///
  /// In zh, this message translates to:
  /// **'已加入下载队列'**
  String get workPageDownloadSelectedToast;

  /// pages/work_page.dart: _addToPlaylist
  ///
  /// In zh, this message translates to:
  /// **'请输入歌单名称'**
  String get workPageAddToPlaylistText3;

  /// pages/work_page.dart: _openVideoChooser
  ///
  /// In zh, this message translates to:
  /// **'外部播放器打开'**
  String get workPageOpenVideoChooserText3;

  /// pages/work_page.dart: _delete
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{e}'**
  String workPageDeleteNotify(String e);

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'添加到播放列表'**
  String get workPageBuildLabel2;

  /// pages/work_page.dart: _setProgress
  ///
  /// In zh, this message translates to:
  /// **'标记失败：{e}'**
  String workPageSetProgressToast(String e);

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'仅显示媒体文件'**
  String get workPageBuildLabel3;

  /// pages/work_page.dart: _treePlaceholder
  ///
  /// In zh, this message translates to:
  /// **'该作品暂无曲目'**
  String get workPageTreePlaceholderText;

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'翻译失败：{e}'**
  String workPageTranslateTitlesToast3(String e);

  /// pages/work_page.dart: _rateWork
  ///
  /// In zh, this message translates to:
  /// **'评分失败：{e}'**
  String workPageRateWorkToast(String e);

  /// pages/work_page.dart: applyEncoding
  ///
  /// In zh, this message translates to:
  /// **'解码失败：{e}'**
  String workPageApplyEncodingToast(String e);

  /// pages/work_page.dart: _submit
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{e}'**
  String workPageSubmitNotify(String e);

  /// pages/work_page.dart: _similarWorksSlivers
  ///
  /// In zh, this message translates to:
  /// **'加载更多相似作品'**
  String get workPageSimilarWorksSliversText2;

  /// pages/work_page.dart: _downloadSelected
  ///
  /// In zh, this message translates to:
  /// **'曲目列表尚未加载'**
  String get workPageDownloadSelectedToast2;

  /// pages/work_page.dart: _clearRating
  ///
  /// In zh, this message translates to:
  /// **'取消评分失败：{e}'**
  String workPageClearRatingToast(String e);

  /// pages/work_page.dart: _refreshWork
  ///
  /// In zh, this message translates to:
  /// **'已刷新本地下载记录'**
  String get workPageRefreshWorkToast3;

  /// pages/work_page.dart: _downloadSelected
  ///
  /// In zh, this message translates to:
  /// **'加入下载失败：{e}'**
  String workPageDownloadSelectedToast3(String e);

  /// pages/work_page.dart: _similarWorksSlivers
  ///
  /// In zh, this message translates to:
  /// **'已显示全部相似作品'**
  String get workPageSimilarWorksSliversText3;

  /// pages/work_page.dart: _openLanguageEdition
  ///
  /// In zh, this message translates to:
  /// **'无法加载该语言版本'**
  String get workPageOpenLanguageEditionToast;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'收藏操作失败：{e}'**
  String workPageBuildToast(String e);

  /// pages/work_page.dart: confirmed
  ///
  /// In zh, this message translates to:
  /// **'确定要删除标记吗？'**
  String get workPageConfirmedText3;

  /// pages/work_page.dart: _setProgress
  ///
  /// In zh, this message translates to:
  /// **'取消标记失败：{e}'**
  String workPageSetProgressToast2(String e);

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'跳转 DLsite'**
  String get workPageBuildLabel4;

  /// pages/work_page.dart: _addToPlaylist
  ///
  /// In zh, this message translates to:
  /// **'请先勾选文件或文件夹'**
  String get workPageAddToPlaylistToast;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'曲目列表（文件夹结构）'**
  String get workPageBuildText8;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'跳转 asmr.one'**
  String get workPageBuildLabel5;

  /// pages/work_page.dart: _addToPlaylist
  ///
  /// In zh, this message translates to:
  /// **'已添加到「{name}」'**
  String workPageAddToPlaylistToast2(String name);

  /// pages/work_page.dart: _addToServerPlaylist
  ///
  /// In zh, this message translates to:
  /// **'只能添加到自建播放列表'**
  String get workPageAddToServerPlaylistToast;

  /// pages/work_page.dart: _onMoreAction
  ///
  /// In zh, this message translates to:
  /// **'曲目列表加载中，请稍候'**
  String get workPageOnMoreActionToast;

  /// pages/work_page.dart: _treePlaceholder
  ///
  /// In zh, this message translates to:
  /// **'该作品没有音频或视频文件'**
  String get workPageTreePlaceholderText2;

  /// pages/work_page.dart: _addToServerPlaylist
  ///
  /// In zh, this message translates to:
  /// **'该作品缺少编号，无法添加'**
  String get workPageAddToServerPlaylistToast2;

  /// pages/work_page.dart: _openReviewDialog
  ///
  /// In zh, this message translates to:
  /// **'该作品缺少编号，无法评价'**
  String get workPageOpenReviewDialogToast;

  /// pages/work_page.dart: _deleteSelectedLocalFiles
  ///
  /// In zh, this message translates to:
  /// **'所选项目中没有已下载文件'**
  String get workPageDeleteSelectedLocalFilesToast;

  /// pages/work_page.dart: _deleteSelectedLocalFiles
  ///
  /// In zh, this message translates to:
  /// **'请先勾选要删除的本地文件'**
  String get workPageDeleteSelectedLocalFilesToast2;

  /// pages/work_page.dart: _onMoreAction
  ///
  /// In zh, this message translates to:
  /// **'曲目加载失败，请刷新后重试'**
  String get workPageOnMoreActionToast2;

  /// pages/work_page.dart: _treePlaceholder
  ///
  /// In zh, this message translates to:
  /// **'无网络连接，无法获取曲目列表'**
  String get workPageTreePlaceholderText3;

  /// pages/work_page.dart: build
  ///
  /// In zh, this message translates to:
  /// **'时长 {dur}'**
  String workPageBuildText9(String dur);

  /// pages/work_page.dart: engines
  ///
  /// In zh, this message translates to:
  /// **'DeepL（免费版 Key）'**
  String get workPageEnginesEngines;

  /// pages/work_page.dart: engines
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容（可配置）'**
  String get workPageEnginesEngines2;

  /// pages/work_page.dart: _copyRj
  ///
  /// In zh, this message translates to:
  /// **'已复制 {rj}'**
  String workPageCopyRjToast(String rj);

  /// pages/work_page.dart: _downloadSelected
  ///
  /// In zh, this message translates to:
  /// **'请先勾选要下载的项目或文件夹'**
  String get workPageDownloadSelectedToast4;

  /// pages/work_page.dart: _addToPlaylist
  ///
  /// In zh, this message translates to:
  /// **'所选项目中没有可播放的音频文件'**
  String get workPageAddToPlaylistToast3;

  /// pages/work_page.dart: _onMoreAction
  ///
  /// In zh, this message translates to:
  /// **'请先勾选需要听写翻译的媒体文件'**
  String get workPageOnMoreActionToast3;

  /// pages/work_page.dart: _playAsAudio
  ///
  /// In zh, this message translates to:
  /// **'SFW 模式下不能播放非全年龄作品'**
  String get workPagePlayAsAudioToast;

  /// pages/work_page.dart: _openLanguageEdition
  ///
  /// In zh, this message translates to:
  /// **'SFW 模式下不能打开非全年龄作品'**
  String get workPageOpenLanguageEditionToast2;

  /// pages/work_page.dart: _playFiles
  ///
  /// In zh, this message translates to:
  /// **'暂无音频文件（文件流需登录后可用）'**
  String get workPagePlayFilesToast;

  /// pages/work_page.dart: engines
  ///
  /// In zh, this message translates to:
  /// **'Google（免费，无需 Key）'**
  String get workPageEnginesEngines3;

  /// pages/work_page.dart: _nodeRow
  ///
  /// In zh, this message translates to:
  /// **'已复制文件名：{title}'**
  String workPageNodeRowToast(String title);

  /// pages/work_page.dart: _deleteSelectedLocalFiles
  ///
  /// In zh, this message translates to:
  /// **'已删除 {deleted} 个本地文件'**
  String workPageDeleteSelectedLocalFilesToast3(String deleted);

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中配置 API 地址与模型名'**
  String get workPageTranslateTitlesToast4;

  /// pages/work_page.dart: engines
  ///
  /// In zh, this message translates to:
  /// **'Microsoft（免费，无需 Key）'**
  String get workPageEnginesEngines4;

  /// pages/work_page.dart: _openFile
  ///
  /// In zh, this message translates to:
  /// **'暂不支持查看该类型：{title}'**
  String workPageOpenFileToast(String title);

  /// pages/work_page.dart: engines
  ///
  /// In zh, this message translates to:
  /// **'Index-Translate（官方接口）'**
  String get workPageEnginesEngines5;

  /// pages/work_page.dart: _confirmDeleteWork
  ///
  /// In zh, this message translates to:
  /// **'删除失败，请关闭正在占用该作品的程序后重试'**
  String get workPageConfirmDeleteWorkToast;

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'正在翻译 {length} 行标题…'**
  String workPageTranslateTitlesToast5(String length);

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中填写 DeepL 免费版 API Key'**
  String get workPageTranslateTitlesToast6;

  /// pages/work_page.dart: _addToPlaylist
  ///
  /// In zh, this message translates to:
  /// **'已选择 {length} 个音频文件'**
  String workPageAddToPlaylistText4(String length);

  /// pages/work_page.dart: _onMoreAction
  ///
  /// In zh, this message translates to:
  /// **'所选项目中没有可提交给 kikoeta-transl 的媒体文件'**
  String get workPageOnMoreActionToast4;

  /// pages/work_page.dart: _translateTitles
  ///
  /// In zh, this message translates to:
  /// **'翻译完成（标题 + {length} 个曲目）'**
  String workPageTranslateTitlesToast7(String length);

  /// pages/work_page.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'将标签「{t}」加入黑名单？\n加入后，含该标签的作品将从首页与搜索中过滤。'**
  String workPageOkText2(String t);

  /// pages/work_page.dart: confirmed
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{title}”的全部本地文件吗？此操作无法撤销。'**
  String workPageConfirmedText4(String title);

  /// services/api_service.dart: _systemPlaylistDisplayName
  ///
  /// In zh, this message translates to:
  /// **'喜欢'**
  String get liked;

  /// services/api_service.dart: playlistPrivacyLabels
  ///
  /// In zh, this message translates to:
  /// **'私有'**
  String get privatePlaylist;

  /// services/api_service.dart: playlistPrivacyLabels
  ///
  /// In zh, this message translates to:
  /// **'公开'**
  String get publicPlaylist;

  /// services/api_service.dart: playlistPrivacyLabels
  ///
  /// In zh, this message translates to:
  /// **'链接共享'**
  String get sharedByLink;

  /// services/api_service.dart: _mapPlaylist
  ///
  /// In zh, this message translates to:
  /// **'未命名歌单'**
  String get apiServiceMapPlaylistName;

  /// services/api_service.dart: _mapWork
  ///
  /// In zh, this message translates to:
  /// **'CV. 未知'**
  String get apiServiceMapWorkVa;

  /// services/api_service.dart: fetchWork
  ///
  /// In zh, this message translates to:
  /// **'作品详情格式无效'**
  String get apiServiceFetchWorkFormatException;

  /// services/api_service.dart: fetchPlaylistMetadata
  ///
  /// In zh, this message translates to:
  /// **'歌单详情格式无效'**
  String get apiServiceFetchPlaylistMetadataFormatException;

  /// services/api_service.dart: fetchAdvancedFilterEntries
  ///
  /// In zh, this message translates to:
  /// **'不支持的高级筛选类型'**
  String get apiServiceFetchAdvancedFilterEntriesValue;

  /// services/api_service.dart: fetchAdvancedFilterEntries
  ///
  /// In zh, this message translates to:
  /// **'高级筛选数据格式无效'**
  String get apiServiceFetchAdvancedFilterEntriesFormatException;

  /// services/api_service.dart: toggleFavorite
  ///
  /// In zh, this message translates to:
  /// **'该作品缺少编号，无法收藏'**
  String get apiServiceToggleFavoriteException;

  /// services/api_service.dart: clearReviewRating
  ///
  /// In zh, this message translates to:
  /// **'该作品缺少编号，无法取消评分'**
  String get apiServiceClearReviewRatingException;

  /// services/api_service.dart: clearReviewProgress
  ///
  /// In zh, this message translates to:
  /// **'该作品缺少编号，无法取消标记'**
  String get apiServiceClearReviewProgressException;

  /// services/api_service.dart: deleteReview
  ///
  /// In zh, this message translates to:
  /// **'该作品缺少编号，无法删除标记'**
  String get apiServiceDeleteReviewException;

  /// services/clipboard_watcher.dart: _check
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// services/clipboard_watcher.dart: _check
  ///
  /// In zh, this message translates to:
  /// **'检测到 {rj}，点击搜索'**
  String clipboardWatcherCheckText(String rj);

  /// services/desktop_lyrics_overlay.dart: _ensureWindow
  ///
  /// In zh, this message translates to:
  /// **'Kikoeta 桌面歌词'**
  String get desktopLyricsOverlayEnsureWindowToNativeUtf16;

  /// services/download_service.dart: _downloadFile
  ///
  /// In zh, this message translates to:
  /// **'下载文件为空'**
  String get downloadServiceDownloadFileHttpException;

  /// services/download_service.dart: _run
  ///
  /// In zh, this message translates to:
  /// **'没有可下载的文件'**
  String get downloadServiceRunStateError;

  /// services/download_service.dart: _run
  ///
  /// In zh, this message translates to:
  /// **'下载文件地址为空'**
  String get downloadServiceRunStateError2;

  /// services/download_transfer.dart: downloadToFile
  ///
  /// In zh, this message translates to:
  /// **'下载响应不完整'**
  String get downloadTransferDownloadToFileHttpException;

  /// services/download_transfer.dart: downloadToFile
  ///
  /// In zh, this message translates to:
  /// **'下载分片长度发生变化'**
  String get downloadTransferDownloadToFileHttpException2;

  /// services/download_transfer.dart: downloadToFile
  ///
  /// In zh, this message translates to:
  /// **'下载文件长度校验失败'**
  String get downloadTransferDownloadToFileHttpException3;

  /// services/download_transfer.dart: downloadToFile
  ///
  /// In zh, this message translates to:
  /// **'下载响应的字节范围不匹配'**
  String get downloadTransferDownloadToFileHttpException4;

  /// services/download_transfer.dart: downloadToFile
  ///
  /// In zh, this message translates to:
  /// **'下载响应超过声明的文件长度'**
  String get downloadTransferDownloadToFileHttpException5;

  /// services/download_transfer.dart: downloadToFile
  ///
  /// In zh, this message translates to:
  /// **'下载响应使用了非原始字节编码'**
  String get downloadTransferDownloadToFileHttpException6;

  /// services/download_transfer.dart: downloadToFile
  ///
  /// In zh, this message translates to:
  /// **'下载失败 HTTP {status}'**
  String downloadTransferDownloadToFileHttpException7(String status);

  /// services/kt_service.dart: normalizeEndpoint
  ///
  /// In zh, this message translates to:
  /// **'连接地址格式应为 IP/域名:端口'**
  String get ktServiceNormalizeEndpointFormatException;

  /// services/kt_service.dart: _decode
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 返回了无效响应'**
  String get ktServiceDecodeFormatException;

  /// services/kt_service.dart: normalizeEndpoint
  ///
  /// In zh, this message translates to:
  /// **'请输入 kikoeta-transl 的 IP/域名与端口'**
  String get ktServiceNormalizeEndpointFormatException2;

  /// services/kt_service.dart: _errorMessage
  ///
  /// In zh, this message translates to:
  /// **'kikoeta-transl 请求失败（HTTP {statusCode}）'**
  String ktServiceErrorMessageText(String statusCode);

  /// services/lyrics_library_remote_client.dart: _validateWorkId
  ///
  /// In zh, this message translates to:
  /// **'无效的作品号'**
  String get lyricsLibraryRemoteClientValidateWorkIdFormatException;

  /// services/lyrics_library_remote_client.dart: fetchWorks
  ///
  /// In zh, this message translates to:
  /// **'远程歌词库分页游标无效'**
  String get lyricsLibraryRemoteClientFetchWorksFormatException;

  /// services/lyrics_library_remote_client.dart: fetchWorks
  ///
  /// In zh, this message translates to:
  /// **'远程歌词库未提供作品列表'**
  String get lyricsLibraryRemoteClientFetchWorksFormatException2;

  /// services/lyrics_library_remote_client.dart: fetchLyrics
  ///
  /// In zh, this message translates to:
  /// **'远程作品没有歌词文件列表'**
  String get lyricsLibraryRemoteClientFetchLyricsFormatException;

  /// services/lyrics_library_remote_client.dart: fetchLyrics
  ///
  /// In zh, this message translates to:
  /// **'远程作品没有可用歌词文件'**
  String get lyricsLibraryRemoteClientFetchLyricsFormatException2;

  /// services/lyrics_library_remote_client.dart: _getJson
  ///
  /// In zh, this message translates to:
  /// **'远程歌词库返回的数据格式无效'**
  String get lyricsLibraryRemoteClientGetJsonFormatException;

  /// services/lyrics_library_remote_client.dart: normalizeBaseUrl
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 HTTP 或 HTTPS 地址'**
  String get lyricsLibraryRemoteClientNormalizeBaseUrlFormatException;

  /// services/lyrics_library_remote_client.dart: _getJson
  ///
  /// In zh, this message translates to:
  /// **'远程歌词库返回 HTTP {statusCode}'**
  String lyricsLibraryRemoteClientGetJsonHttpException(String statusCode);

  /// services/lyrics_library_service.dart: _extractArchive
  ///
  /// In zh, this message translates to:
  /// **'正在解压'**
  String get lyricsLibraryServiceExtractArchivePhase;

  /// services/lyrics_library_service.dart: _copyTree
  ///
  /// In zh, this message translates to:
  /// **'正在复制'**
  String get lyricsLibraryServiceCopyTreePhase;

  /// services/lyrics_library_service.dart: removeRemoteLibrary
  ///
  /// In zh, this message translates to:
  /// **'该远程库尚未导入'**
  String get lyricsLibraryServiceRemoveRemoteLibraryStateError;

  /// services/lyrics_library_service.dart: saveTranslatedLyrics
  ///
  /// In zh, this message translates to:
  /// **'不支持的歌词格式'**
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError;

  /// services/lyrics_library_service.dart: saveTranslatedLyrics
  ///
  /// In zh, this message translates to:
  /// **'文件中没有有效时间轴'**
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError2;

  /// services/lyrics_library_service.dart: _importRemoteWork
  ///
  /// In zh, this message translates to:
  /// **'远程作品没有有效歌词文件'**
  String get lyricsLibraryServiceImportRemoteWorkFormatException;

  /// services/lyrics_library_service.dart: saveTranslatedLyrics
  ///
  /// In zh, this message translates to:
  /// **'目标文件必须位于作品目录内'**
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError3;

  /// services/lyrics_library_service.dart: setRemoteLibraryOrder
  ///
  /// In zh, this message translates to:
  /// **'远程库列表已变化，请重新打开导入窗口'**
  String get lyricsLibraryServiceSetRemoteLibraryOrderArgumentError;

  /// services/lyrics_library_service.dart: subscription
  ///
  /// In zh, this message translates to:
  /// **'歌词导入进程异常: {message}'**
  String lyricsLibraryServiceSubscriptionStateError(String message);

  /// services/update_service.dart: showUpdateDialog
  ///
  /// In zh, this message translates to:
  /// **'不再提示'**
  String get updateServiceShowUpdateDialogText;

  /// services/update_service.dart: showUpdateDialog
  ///
  /// In zh, this message translates to:
  /// **'跳转下载'**
  String get updateServiceShowUpdateDialogText2;

  /// services/update_service.dart: showUpdateDialog
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateServiceShowUpdateDialogText3;

  /// services/update_service.dart: checkManually
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新…'**
  String get updateServiceCheckManuallyText;

  /// services/update_service.dart: check
  ///
  /// In zh, this message translates to:
  /// **'更新服务连接失败'**
  String get updateServiceCheckError;

  /// services/update_service.dart: checkManually
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本'**
  String get updateServiceCheckManuallyToast;

  /// services/update_service.dart: showUpdateDialog
  ///
  /// In zh, this message translates to:
  /// **'打开下载页面失败'**
  String get updateServiceShowUpdateDialogToast;

  /// services/update_service.dart: _getUpdateResponse
  ///
  /// In zh, this message translates to:
  /// **'更新服务请求未执行'**
  String get updateServiceGetUpdateResponseStateError;

  /// services/update_service.dart: _parseReleaseResponse
  ///
  /// In zh, this message translates to:
  /// **'更新响应缺少版本信息'**
  String get updateServiceParseReleaseResponseFormatException;

  /// services/update_service.dart: check
  ///
  /// In zh, this message translates to:
  /// **'更新服务未返回有效版本信息'**
  String get updateServiceCheckError2;

  /// services/update_service.dart: check
  ///
  /// In zh, this message translates to:
  /// **'无法连接更新服务或 GitHub'**
  String get updateServiceCheckError3;

  /// services/update_service.dart: showUpdateDialog
  ///
  /// In zh, this message translates to:
  /// **'最新版本：{version}\n当前版本：{currentVersion}'**
  String updateServiceShowUpdateDialogText4(
    String version,
    String currentVersion,
  );

  /// services/windows_tray_service.dart: _setContextMenu
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// services/windows_tray_service.dart: _setContextMenu
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get quit;

  /// services/windows_tray_service.dart: _setContextMenu
  ///
  /// In zh, this message translates to:
  /// **'显示首页'**
  String get windowsTrayServiceSetContextMenuLabel;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get sheetsShowSleepSheetSuffixText;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get sheetsBuildText;

  /// sheets.dart: showSiteSheet
  ///
  /// In zh, this message translates to:
  /// **'别名'**
  String get sheetsShowSiteSheetField;

  /// sheets.dart: showSiteSheet
  ///
  /// In zh, this message translates to:
  /// **'地址'**
  String get sheetsShowSiteSheetField2;

  /// sheets.dart: showSiteSheet
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get account;

  /// sheets.dart: presets
  ///
  /// In zh, this message translates to:
  /// **'人声'**
  String get sheetsPresetsPresets;

  /// sheets.dart: presets
  ///
  /// In zh, this message translates to:
  /// **'低音'**
  String get sheetsPresetsPresets2;

  /// sheets.dart: presets
  ///
  /// In zh, this message translates to:
  /// **'平直'**
  String get sheetsPresetsPresets3;

  /// sheets.dart: presets
  ///
  /// In zh, this message translates to:
  /// **'流行'**
  String get sheetsPresetsPresets4;

  /// sheets.dart: presets
  ///
  /// In zh, this message translates to:
  /// **'摇滚'**
  String get sheetsPresetsPresets5;

  /// sheets.dart: showEqSheet
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get sheetsShowEqSheetText;

  /// sheets.dart: showEqSheet
  ///
  /// In zh, this message translates to:
  /// **'已应用'**
  String get sheetsShowEqSheetText2;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'取消定时'**
  String get sheetsShowSleepSheetText;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'开始定时'**
  String get sheetsShowSleepSheetText2;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'播放完毕'**
  String get playbackComplete;

  /// sheets.dart: _timePicker
  ///
  /// In zh, this message translates to:
  /// **'关闭时间'**
  String get sheetsTimePickerText;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'指定时间'**
  String get sheetsShowSleepSheetLabel;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'{m} 分钟'**
  String sheetsShowSleepSheetLabel2(String m);

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'N 分钟后'**
  String get sheetsShowSleepSheetLabel3;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'选择服务器'**
  String get sheetsBuildTitle;

  /// sheets.dart: showEqSheet
  ///
  /// In zh, this message translates to:
  /// **'启用均衡器'**
  String get sheetsShowEqSheetText3;

  /// sheets.dart: showSiteSheet
  ///
  /// In zh, this message translates to:
  /// **'编辑自建站点'**
  String get sheetsShowSiteSheetTitle;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'管理自建站点'**
  String get sheetsBuildText2;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'自定义分钟数'**
  String get sheetsShowSleepSheetHintText;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'暂无自建站点'**
  String get sheetsBuildText3;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'选择自建站点'**
  String get sheetsBuildText4;

  /// sheets.dart: showSiteSheet
  ///
  /// In zh, this message translates to:
  /// **'如：家庭 NAS'**
  String get sheetsShowSiteSheetHint;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'请先添加自建站点'**
  String get sheetsBuildText5;

  /// sheets.dart: showOneConfigSheet
  ///
  /// In zh, this message translates to:
  /// **'ASMR.ONE 账号'**
  String get sheetsShowOneConfigSheetTitle;

  /// sheets.dart: showOneConfigSheet
  ///
  /// In zh, this message translates to:
  /// **'asmr.one 账号'**
  String get sheetsShowOneConfigSheetHint;

  /// sheets.dart: showOneConfigSheet
  ///
  /// In zh, this message translates to:
  /// **'账号信息仅保存在本地（演示）'**
  String get sheetsShowOneConfigSheetSub;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'当前播放列表播完后自动停止并关闭'**
  String get sheetsShowSleepSheetText3;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'剩余时间 · 到点后自动停止并退出'**
  String get sheetsShowSleepSheetText4;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'官方服务或自建 Kikoeru 站点'**
  String get sheetsBuildSub;

  /// sheets.dart: showEqSheet
  ///
  /// In zh, this message translates to:
  /// **'真 10 段 · ±12 dB · 全平台'**
  String get sheetsShowEqSheetSub;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'当前播放列表的内容播放完毕后自动停止并关闭'**
  String get sheetsShowSleepSheetText5;

  /// sheets.dart: showSleepSheet
  ///
  /// In zh, this message translates to:
  /// **'到点后停止播放并释放系统接口（锁屏卡片 / 通知全部清除）'**
  String get sheetsShowSleepSheetSub;

  /// sheets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'自定义配置（{length}）'**
  String sheetsBuildLabel(String length);

  /// widgets/playback_seek_seconds_control.dart: build
  ///
  /// In zh, this message translates to:
  /// **'减少{label}秒数'**
  String playbackSeekSecondsControlBuildTooltip(String label);

  /// widgets/playback_seek_seconds_control.dart: build
  ///
  /// In zh, this message translates to:
  /// **'增加{label}秒数'**
  String playbackSeekSecondsControlBuildTooltip2(String label);

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get name;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get description;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'权限'**
  String get playlistPickerRowsMapEntry;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// widgets/playlist_picker.dart: copy
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirmAction;

  /// widgets/playlist_picker.dart: build
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get create;

  /// widgets/playlist_picker.dart: _showEditor
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get playlistPickerShowEditorLabelText;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'创建人'**
  String get playlistPickerRowsMapEntry2;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'更新时间'**
  String get playlistPickerRowsMapEntry3;

  /// widgets/playlist_picker.dart: _reviewsItem
  ///
  /// In zh, this message translates to:
  /// **'我的收藏'**
  String get playlistPickerReviewsItemName;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'播放次数'**
  String get playlistPickerRowsMapEntry4;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'作品数量'**
  String get playlistPickerRowsMapEntry5;

  /// widgets/playlist_picker.dart: copy
  ///
  /// In zh, this message translates to:
  /// **'歌单详情'**
  String get playlistPickerCopyText;

  /// widgets/playlist_picker.dart: link
  ///
  /// In zh, this message translates to:
  /// **'分享链接'**
  String get playlistPickerLinkLabelText;

  /// widgets/playlist_picker.dart: copy
  ///
  /// In zh, this message translates to:
  /// **'复制链接'**
  String get playlistPickerCopyText2;

  /// widgets/playlist_picker.dart: rows
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get playlistPickerRowsMapEntry6;

  /// widgets/playlist_picker.dart: build
  ///
  /// In zh, this message translates to:
  /// **'切换播放列表'**
  String get playlistPickerBuildText;

  /// widgets/playlist_picker.dart: _playlistItem
  ///
  /// In zh, this message translates to:
  /// **'移除播放列表'**
  String get playlistPickerPlaylistItemTooltip;

  /// widgets/playlist_picker.dart: _playlistItem
  ///
  /// In zh, this message translates to:
  /// **'编辑播放列表'**
  String get playlistPickerPlaylistItemTooltip2;

  /// widgets/playlist_picker.dart: _showEditor
  ///
  /// In zh, this message translates to:
  /// **'创建播放列表'**
  String get playlistPickerShowEditorText;

  /// widgets/playlist_picker.dart: link
  ///
  /// In zh, this message translates to:
  /// **'导入播放列表'**
  String get playlistPickerLinkText;

  /// widgets/playlist_picker.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'删除播放列表'**
  String get playlistPickerOkText;

  /// widgets/playlist_picker.dart: _removeLiked
  ///
  /// In zh, this message translates to:
  /// **'移除失败：{e}'**
  String playlistPickerRemoveLikedToast(String e);

  /// widgets/playlist_picker.dart: _createPlaylist
  ///
  /// In zh, this message translates to:
  /// **'创建失败：{e}'**
  String playlistPickerCreatePlaylistToast(String e);

  /// widgets/playlist_picker.dart: _load
  ///
  /// In zh, this message translates to:
  /// **'无法加载播放列表'**
  String get playlistPickerLoadSetState;

  /// widgets/playlist_picker.dart: _importPlaylist
  ///
  /// In zh, this message translates to:
  /// **'无法识别播放列表链接'**
  String get playlistPickerImportPlaylistToast;

  /// widgets/playlist_picker.dart: _reviewsItem
  ///
  /// In zh, this message translates to:
  /// **'我的评价/收藏（所有作品）'**
  String get playlistPickerReviewsItemSubtitle;

  /// widgets/playlist_picker.dart: _createPlaylist
  ///
  /// In zh, this message translates to:
  /// **'已创建，但列表中未找到该播放列表'**
  String get playlistPickerCreatePlaylistToast2;

  /// widgets/playlist_picker.dart: _importPlaylist
  ///
  /// In zh, this message translates to:
  /// **'已添加，但列表中暂未找到该播放列表'**
  String get playlistPickerImportPlaylistToast2;

  /// widgets/playlist_picker.dart: subtitle
  ///
  /// In zh, this message translates to:
  /// **'{worksCount} 个作品'**
  String playlistPickerSubtitleSubtitle(String worksCount);

  /// widgets/playlist_picker.dart: link
  ///
  /// In zh, this message translates to:
  /// **'粘贴别人分享的播放列表链接，会收藏到我的播放列表。'**
  String get playlistPickerLinkText2;

  /// widgets/playlist_picker.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”吗？此操作无法撤销。'**
  String playlistPickerOkText2(String name);

  /// widgets/playlist_picker.dart: ok
  ///
  /// In zh, this message translates to:
  /// **'确定从我的播放列表中移除“{name}”吗？'**
  String playlistPickerOkText3(String name);

  /// widgets/playlist_picker.dart: subtitle
  ///
  /// In zh, this message translates to:
  /// **'{worksCount} 个作品 · {replaceAll}'**
  String playlistPickerSubtitleSubtitle2(String worksCount, String replaceAll);

  /// widgets.dart: _filterButton
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get widgetsFilterButtonTooltip;

  /// widgets.dart: _filterButton
  ///
  /// In zh, this message translates to:
  /// **'仅字幕'**
  String get widgetsFilterButtonLabel;

  /// widgets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'全年龄'**
  String get allAges;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'排除语言'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'搜索社团'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter2;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'搜索声优'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter3;

  /// widgets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'AI歌词'**
  String get widgetsBuildBuilder;

  /// widgets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'远程歌词'**
  String get widgetsBuildBuilder2;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'筛选语言'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter4;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'排除标签'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter5;

  /// widgets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'本地歌词'**
  String get widgetsBuildBuilder3;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'排除社团'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter6;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'排除声优'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter7;

  /// widgets.dart: _inputRow
  ///
  /// In zh, this message translates to:
  /// **'高级搜索'**
  String get widgetsInputRowMessage;

  /// widgets.dart: _historyPanel
  ///
  /// In zh, this message translates to:
  /// **'搜索历史'**
  String get widgetsHistoryPanelText;

  /// widgets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'在线歌词'**
  String get widgetsBuildBuilder4;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'搜索标签'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter8;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'筛选年龄分级'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter9;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'排除年龄分级'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter10;

  /// widgets.dart: build
  ///
  /// In zh, this message translates to:
  /// **'高级搜索参数'**
  String get widgetsBuildText;

  /// widgets.dart: _historyPanel
  ///
  /// In zh, this message translates to:
  /// **'暂无搜索历史'**
  String get widgetsHistoryPanelText2;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'包含低愿力标签'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter11;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'排除低愿力标签'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter12;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'筛选评分（大于）'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter13;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'筛选销量（大于）'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter14;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'筛选价格（大于）'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter15;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'筛选作品时长（小于）'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter16;

  /// widgets.dart: advancedSearchParameters
  ///
  /// In zh, this message translates to:
  /// **'筛选作品时长（大于）'**
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter17;

  /// widgets.dart: _historyPanel
  ///
  /// In zh, this message translates to:
  /// **'已删除「{value}」'**
  String widgetsHistoryPanelText3(String value);

  /// No description provided for @playbackSpeed.
  ///
  /// In zh, this message translates to:
  /// **'倍速'**
  String get playbackSpeed;

  /// No description provided for @playbackSpeedDescription.
  ///
  /// In zh, this message translates to:
  /// **'切换播放速度，保持音调'**
  String get playbackSpeedDescription;

  /// No description provided for @playbackSpeedEntry.
  ///
  /// In zh, this message translates to:
  /// **'显示倍速入口'**
  String get playbackSpeedEntry;

  /// No description provided for @playbackSpeedEntryDescription.
  ///
  /// In zh, this message translates to:
  /// **'在播放器显示倍速控制，关闭后恢复 1×'**
  String get playbackSpeedEntryDescription;

  /// No description provided for @audioChannels.
  ///
  /// In zh, this message translates to:
  /// **'声道'**
  String get audioChannels;

  /// No description provided for @audioChannelsDescription.
  ///
  /// In zh, this message translates to:
  /// **'反转左右声道，或合并后双耳播放相同声音'**
  String get audioChannelsDescription;

  /// No description provided for @audioChannelsOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始声道'**
  String get audioChannelsOriginal;

  /// No description provided for @audioChannelsSwap.
  ///
  /// In zh, this message translates to:
  /// **'左右反转'**
  String get audioChannelsSwap;

  /// No description provided for @audioChannelsMerge.
  ///
  /// In zh, this message translates to:
  /// **'声道合并'**
  String get audioChannelsMerge;

  /// widgets.dart: _inputRow
  ///
  /// In zh, this message translates to:
  /// **'搜索 RJ 号、作品名、声优…'**
  String get widgetsInputRowHintText;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
