// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get dataExport => '导出本地数据';

  @override
  String get dataImport => '导入本地数据';

  @override
  String get dataScope => '收藏、歌单、黑名单、历史与偏好；不含下载、歌词库、账号密码和密钥。';

  @override
  String get dataImportConfirm => '将覆盖备份范围内的本地数据。导入前会保留一份本地副本，当前播放不受影响。';

  @override
  String get dataExportDone => '数据已导出';

  @override
  String get dataImportDone => '数据已导入';

  @override
  String get dataOperationFailed => '操作失败，请重试';

  @override
  String get backupInvalid => '备份格式无效、版本不兼容或文件已损坏';

  @override
  String get backupTooLarge => '备份超过 16 MB 上限';

  @override
  String get webdavTitle => 'WebDAV 云同步';

  @override
  String get webdavUrl => '服务器地址';

  @override
  String get webdavUsername => '账号';

  @override
  String get webdavPassword => '应用密码';

  @override
  String get webdavFolder => '同步文件夹';

  @override
  String get webdavAuto => '每小时自动同步';

  @override
  String get webdavAutoHint => '应用运行期间每小时检查；回到前台时补查。无变化不上传。';

  @override
  String get webdavTest => '测试连接';

  @override
  String get webdavTestDone => '连接正常，测试文件已删除';

  @override
  String get webdavSyncNow => '立即同步';

  @override
  String get webdavUploadOverwrite => '上传本地数据覆盖云端';

  @override
  String get webdavDownloadOverwrite => '使用云端数据覆盖本地';

  @override
  String get webdavMergeData => '合并本地与云端数据';

  @override
  String get webdavMergeHint => '收藏、黑名单、歌单和历史去重合并，设置冲突保留本地。';

  @override
  String get webdavSyncDone => '同步完成';

  @override
  String get webdavNever => '尚未同步';

  @override
  String get webdavSyncing => '正在同步…';

  @override
  String get webdavConflict => '本地和云端都有更改，请选择保留的版本';

  @override
  String get webdavUseLocal => '保留本地';

  @override
  String get webdavUseCloud => '使用云端';

  @override
  String get webdavConflictConfirm => '所选版本将覆盖另一端的数据。使用云端前会保留本地副本。';

  @override
  String get webdavInvalidConfig => '请填写 HTTPS 地址、账号、应用密码及单层文件夹名称';

  @override
  String get webdavAuthError => '认证失败，请检查账号和应用密码';

  @override
  String get webdavTimeout => '连接超时，请稍后重试';

  @override
  String get webdavNetworkError => '网络连接失败，请检查网络及服务器地址';

  @override
  String get webdavRateLimited => '服务器请求限流，请稍后重试';

  @override
  String get webdavRequestFailed => '同步失败，请检查服务器配置后重试';

  @override
  String get webdavNoEtag => '服务器未提供可用的 ETag，无法安全覆盖云端文件';

  @override
  String get webdavNoBackup => '云端暂无备份';

  @override
  String get webdavCleanupFailed => '测试文件清理失败，请重试测试以检查连接';

  @override
  String get webdavBusy => '正在处理数据，请稍候';

  @override
  String get appName => 'Kikoeta';

  @override
  String get playbackShortcuts => '快捷键设置';

  @override
  String get dictationQueueTitle => '听写翻译队列';

  @override
  String get dictationQueueClear => '清空列表';

  @override
  String get dictationQueueEmpty => '暂无任务';

  @override
  String dictationQueueTracks(String count) {
    return '$count 个音频';
  }

  @override
  String dictationQueueActions(String name) {
    return '你想对 $name 执行的操作';
  }

  @override
  String get dictationQueueJump => '插队';

  @override
  String get dictationQueuePending => '待处理';

  @override
  String get dictationQueueRunning => '处理中';

  @override
  String get dictationQueueCompleted => '已完成';

  @override
  String get dictationQueueFailed => '失败';

  @override
  String get dictationQueueCancelled => '已取消';

  @override
  String get dictationQueueDrag => '拖动调整待处理顺序';

  @override
  String dictationQueueProcessing(String name) {
    return '开始处理队列批次：$name';
  }

  @override
  String get invertSelection => '反选';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get home => '首页';

  @override
  String get favorites => '收藏';

  @override
  String get more => '更多';

  @override
  String get voiceActor => '声优';

  @override
  String get circle => '社团';

  @override
  String get tag => '标签';

  @override
  String get retry => '重试';

  @override
  String get advancedFilterPageBuildText => '高级筛选';

  @override
  String get advancedFilterPageBuildContentText => '暂无数据';

  @override
  String get advancedFilterPageBuildContentText2 => '没有匹配的参数';

  @override
  String advancedFilterPageBuildSearchFieldHintText(String placeholder) {
    return '搜索$placeholder…';
  }

  @override
  String get add => '添加';

  @override
  String get cancel => '取消';

  @override
  String get blacklistPageTypeLabelsTypeLabels => 'RJ号';

  @override
  String get blacklist => '黑名单';

  @override
  String get blacklistPageResultText => '添加黑名单';

  @override
  String get blacklistPageResultHintText => '要屏蔽的 RJ 号 / 名称';

  @override
  String get blacklistPageBuildText => '暂无黑名单条目\n黑名单中的作品不会出现在首页与搜索';

  @override
  String get local => '本地';

  @override
  String get network => '网络';

  @override
  String get password => '密码';

  @override
  String get dictationTranslationPageWorkCardTitle => '作品';

  @override
  String get username => '用户名';

  @override
  String get dictationTranslationPageWorkCardText => '取消任务';

  @override
  String get dictationTranslationPageInitStateText => '等待开始';

  @override
  String get dictationTranslationPageTestConnectionToast => '连接成功';

  @override
  String get dictationTranslationPageLogCardTitle => '运行日志';

  @override
  String get dictationTranslationPageStartUpdate => '任务失败';

  @override
  String get dictationTranslationPageBuildText => '听写翻译';

  @override
  String get dictationTranslationPageConnectionCardTitle => '服务连接';

  @override
  String get dictationTranslationPageConnectionCardInputDecoration => '服务地址';

  @override
  String get dictationTranslationPageConnectionCardTooltip => '显示密码';

  @override
  String get dictationTranslationPageConnectionCardTooltip2 => '隐藏密码';

  @override
  String get testConnection => '测试连接';

  @override
  String get dictationTranslationPageProgressCardTitle => '听写进度';

  @override
  String get dictationTranslationPageStartUpdate2 => '任务已排队';

  @override
  String get dictationTranslationPageStartUpdate3 => '任务已取消';

  @override
  String get dictationTranslationPageWorkCardTitle2 => '待处理音频';

  @override
  String get dictationTranslationPageWorkCardText2 => '正在取消…';

  @override
  String get dictationTranslationPageStartUpdate4 => '听写翻译完成';

  @override
  String get dictationTranslationPageSyncCachedResultsUpdate => '缓存同步完成';

  @override
  String get dictationTranslationPageConnectionCardText => '使用默认账密';

  @override
  String get dictationTranslationPageWorkCardText3 => '开始听写翻译';

  @override
  String get dictationTranslationPageStartUpdate5 => '正在写入歌词库';

  @override
  String dictationTranslationPageStartAppendLog(String error) {
    return '错误：$error';
  }

  @override
  String get dictationTranslationPageConnectionCardInputDecoration2 =>
      '本地服务地址（固定）';

  @override
  String get dictationTranslationPageConnectionCardText2 => '安卓设备仅支持网络连接';

  @override
  String dictationTranslationPageTestConnectionToast2(String error) {
    return '连接失败：$error';
  }

  @override
  String dictationTranslationPageCancelToast(String error) {
    return '取消失败：$error';
  }

  @override
  String get dictationTranslationPageConnectionCardText3 => '前往 GitHub 下载';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog(String error) {
    return '缓存同步失败：$error';
  }

  @override
  String dictationTranslationPageStartToast(String error) {
    return '听写翻译失败：$error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast(String skipped) {
    return '，去重 $skipped 个';
  }

  @override
  String get dictationTranslationPageStartUpdate6 => '正在连接 kikoeta-transl';

  @override
  String get dictationTranslationPageStartException => 'kikoeta-transl 任务失败';

  @override
  String get dictationTranslationPageBuildTooltip => '同步 kikoeta-transl 缓存';

  @override
  String get dictationTranslationPageConnectionCardText4 =>
      '尚未安装 kikoeta-transl？';

  @override
  String get dictationTranslationPageTestConnectionFormatException =>
      'kikoeta-transl 服务未就绪';

  @override
  String get dictationTranslationPageLogCardSelectableText =>
      '等待 kikoeta-transl 日志…';

  @override
  String get dictationTranslationPageStartToast2 => '请从作品详情页的更多选项进入并启动听写翻译';

  @override
  String get dictationTranslationPageStartToast3 => '请返回作品详情页勾选需要听写翻译的媒体文件';

  @override
  String get dictationTranslationPageStartFormatException =>
      'kikoeta-transl 未返回任务编号';

  @override
  String get dictationTranslationPageOpenKikoetaTranslDownloadToast =>
      '无法打开 kikoeta-transl 项目页面';

  @override
  String get dictationTranslationPageServiceFormatException =>
      'kikoeta-transl 用户名不能包含冒号';

  @override
  String get dictationTranslationPageCancelAppendLog =>
      '已向 kikoeta-transl 发送取消请求';

  @override
  String get dictationTranslationPageServiceFormatException2 =>
      '请输入 kikoeta-transl 用户名和密码';

  @override
  String get dictationTranslationPageSyncCachedResultsToast2 =>
      'kikoeta-transl 没有可同步的缓存结果';

  @override
  String get dictationTranslationPageStartFormatException2 =>
      'kikoeta-transl 没有返回可用的 LRC 文件';

  @override
  String dictationTranslationPageProgressCardText(String savedFiles) {
    return ' · 已入库 $savedFiles';
  }

  @override
  String dictationTranslationPageStartToast4(String missing) {
    return '有 $missing 个音频缺少可下载地址，请登录作品服务器后重试';
  }

  @override
  String dictationTranslationPageStartAppendLog2(String jobId, String length) {
    return '任务 $jobId 已创建，共 $length 个音频';
  }

  @override
  String get dictationTranslationPageConnectionCardText5 =>
      '下载并启动 kikoeta-transl 后，即可使用本地或网络听写翻译。';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog2(
    String jobId,
    String name,
    String error,
  ) {
    return '同步 $jobId/$name 失败：$error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog3(
    String saved,
    String skipped,
    String failed,
  ) {
    return '缓存同步完成：写入 $saved，去重跳过 $skipped，失败 $failed';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog4(String length) {
    return '开始同步 $length 条 kikoeta-transl 缓存任务';
  }

  @override
  String get dictationTranslationPageWorkCardText4 =>
      '要创建任务，请打开作品详情页，在右上角“更多”中选择“听写翻译”。未勾选文件时会自动匹配，优先选择无效果音版本并保留独立特典；也可先手动勾选指定文件。';

  @override
  String get dictationAutoSelectionHint =>
      '已自动匹配：优先无效果音，保留独立特典。请检查媒体列表；需要调整时，可返回作品页手动勾选。';

  @override
  String dictationTranslationPageStartAppendLog3(String rj, String savedFiles) {
    return '已按 $rj 写入 $savedFiles 个歌词文件';
  }

  @override
  String dictationTranslationPageWorkCardText5(String rj, String length) {
    return '$rj · 已从作品详情页勾选 $length 个媒体文件';
  }

  @override
  String dictationTranslationPageStartToast5(String savedFiles, String rj) {
    return '完成：$savedFiles 个歌词已写入 $rj 歌词库';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast3(
    String saved,
    String value,
  ) {
    return '同步完成：写入 $saved 个歌词$value';
  }

  @override
  String dictationTranslationPageProgressCardText2(
    String finishedFiles,
    String length,
    String value,
  ) {
    return '已处理 $finishedFiles / $length$value';
  }

  @override
  String get selectMultiple => '多选';

  @override
  String get selectAll => '全选';

  @override
  String get downloads => '下载';

  @override
  String get downloading => '下载中';

  @override
  String get downloadsPageStatusStatus => '等待中';

  @override
  String get downloadsPageStatusStatus2 => '已完成';

  @override
  String get downloadsPageStatusStatus3 => '已暂停';

  @override
  String get exitSelection => '退出多选';

  @override
  String get downloadsPageBuildTooltip => '关闭搜索';

  @override
  String get downloadsPageStatusStatus4 => '下载失败';

  @override
  String get downloadsPageStatusStatus5 => '等待下载';

  @override
  String get deselectAll => '取消全选';

  @override
  String get downloadsPageBuildText => '下载文件';

  @override
  String get downloadsPageBuildText2 => '暂无下载音声';

  @override
  String get downloadsPageBuildText3 => '完整文件结构';

  @override
  String get downloadsPageBuildTooltip2 => '删除选中作品';

  @override
  String get downloadsPageBuildText4 => '暂无下载文件';

  @override
  String get downloadsPageBuildTooltip3 => '搜索已下载作品';

  @override
  String get downloadsPageBuildTooltip4 => '开始/暂停全部';

  @override
  String get downloadsPageBuildTooltip5 => '删除选中下载记录';

  @override
  String get downloadsPageFileNameFileName => '暂无正在下载的文件';

  @override
  String downloadsPageProgressTextText(String percent) {
    return '下载中 $percent%';
  }

  @override
  String downloadsPageBuildText5(String value) {
    return '加载更多（$value）';
  }

  @override
  String downloadsPageBuildText6(String rj, String downloaded, String length) {
    return '$rj  $downloaded/$length 个文件已下载';
  }

  @override
  String downloadsPageStatusStatus6(String round) {
    return '下载中 $round%';
  }

  @override
  String get postponed => '搁置';

  @override
  String get remove => '移除';

  @override
  String get all => '全部';

  @override
  String get wantToListen => '想听';

  @override
  String get listening => '在听';

  @override
  String get listened => '听过';

  @override
  String get replay => '重听';

  @override
  String get favoritesPageReviewFilterButtonTooltip => '进度筛选';

  @override
  String get favoritesPageLabelLabel => '取消收藏';

  @override
  String get loading => '加载中…';

  @override
  String get favoritesPageReviewSortDropdownTooltip => '排序方式';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels => '评论数量';

  @override
  String get favoritesPageBodyText => '点击重试';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels2 => '销售数量';

  @override
  String get favoritesPageBuildTooltip => '切换歌单';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels3 => '发布时间';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels4 => '我的评价';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels5 => '标记时间';

  @override
  String get ageRating => '年龄分级';

  @override
  String get favoritesPageInputText => '添加作品';

  @override
  String get favoritesPageBodyText2 => '已显示全部';

  @override
  String get favoritesPageLabelLabel2 => '移出播放列表';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip => '复制分享链接';

  @override
  String favoritesPageAddWorksByRjToast(String e) {
    return '添加失败：$e';
  }

  @override
  String get shareLinkCopied => '已复制分享链接';

  @override
  String get favoritesPageRemoveSelectedWorksToast => '无法获取作品编号';

  @override
  String get favoritesPageBodyText3 => '还没有收藏的作品';

  @override
  String favoritesPageRemoveCurrentLikedPlaylistToast(String e) {
    return '取消收藏失败：$e';
  }

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip2 => '取消收藏该播放列表';

  @override
  String get favoritesPageBodyText4 => '该播放列表还没有作品';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip3 => '按 RJ 号添加作品';

  @override
  String get favoritesPageAddWorksByRjToast2 => '没有识别到 RJ 号';

  @override
  String favoritesPageSelectionBarText(String count) {
    return '已选 $count 项';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast2(String label, String e) {
    return '$label失败：$e';
  }

  @override
  String get favoritesPageBodyText5 => 'SFW 模式下不显示收藏内容';

  @override
  String get favoritesPageBodyText6 => '加载失败，请确认已在设置中登录';

  @override
  String get favoritesPageOkText => '确定从我的播放列表中移除该歌单吗？';

  @override
  String favoritesPageAddWorksByRjToast3(String length) {
    return '已添加 $length 个作品';
  }

  @override
  String favoritesPageOkText2(String count, String label) {
    return '确定将 $count 个作品$label吗？';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast3(String label, String length) {
    return '已$label $length 个作品';
  }

  @override
  String get favoritesPageInputHintText =>
      '输入 RJ 号，可一次填多个\n例如：RJ01367541 RJ01417842\n支持换行、空格或逗号分隔';

  @override
  String get clear => '清空';

  @override
  String get historyPageEntryWorkTitle => '未知作品';

  @override
  String get playHistory => '播放历史';

  @override
  String get historyPageBuildText => '暂无播放历史';

  @override
  String get historyPageBuildText2 => 'SFW 模式下不显示播放历史';

  @override
  String historyPageFmtTimeText(String padLeft, String padLeft2) {
    return '今天 $padLeft:$padLeft2';
  }

  @override
  String historyPageFmtTimeText2(
    String month,
    String day,
    String padLeft,
    String padLeft2,
  ) {
    return '$month月$day日 $padLeft:$padLeft2';
  }

  @override
  String get homePageServerLabelText => '自建';

  @override
  String get homePageLabelsLabels => '热门';

  @override
  String get homePageLabelsLabels2 => '推荐';

  @override
  String get homePageSortLabelsSortLabels => '总评价';

  @override
  String get homePageSortLabelsSortLabels2 => '收录时间';

  @override
  String get homePageSortLabelsSortLabels3 => '销售价格';

  @override
  String get homePageEmptyHintText => '暂无作品';

  @override
  String get homePageSearchResultsViewText => '搜索中…';

  @override
  String get homePageEmptyHintText2 => '正在加载…';

  @override
  String get homePageGridText => '已显示全部作品';

  @override
  String get homePageEmptyHintText3 => '点击任意处重试';

  @override
  String get homePageSearchResultsViewText2 => '没有找到相关作品';

  @override
  String get homePageSearchResultsViewText3 => '已显示全部搜索结果';

  @override
  String get homePageEmptyHintText4 => '当前筛选条件下暂无作品';

  @override
  String get homePageEmptyHintText5 => '无网络连接，请检查网络或服务器设置';

  @override
  String get homePageHeaderTooltip => 'SFW 模式已开启：仅显示全年龄内容';

  @override
  String get homePageHeaderTooltip2 => '开启 SFW 模式（仅显示全年龄内容）';

  @override
  String get save => '保存';

  @override
  String get loginPageBuildLoginText => '登 录';

  @override
  String get loginPageShowNoAccountText => '关于账号';

  @override
  String get loginPageShowNoAccountText2 => '我知道了';

  @override
  String get loginPageBuildSiteConfigTooltip => '返回登录';

  @override
  String get loginPageBuildSiteConfigText => '已有站点';

  @override
  String get loginPageBuildSiteConfigHint => '站点密码';

  @override
  String get loginPageShowProxyDialogLabelText => '代理服务器';

  @override
  String get loginPageBuildLoginText2 => '我没有账号';

  @override
  String get loginPageBuildSiteConfigText2 => '使用该站点';

  @override
  String get loginPageBuildSiteConfigText3 => '添加新站点';

  @override
  String get loginPageBuildSiteConfigText4 => '保存并进入';

  @override
  String get loginPageShowProxyDialogText => '配置网络代理';

  @override
  String get loginPageBuildLoginText3 => '配置自建站点';

  @override
  String get loginPageBuildSiteConfigHint2 => '站点登录账号';

  @override
  String get loginPageShowProxyDialogToast => '网络代理已启用';

  @override
  String get loginPageShowProxyDialogToast2 => '网络代理已关闭';

  @override
  String get loginPageBuildLoginHint => 'one 站账号';

  @override
  String get loginPageLoginToast => '请输入账号和密码';

  @override
  String get loginPageLoginToast2 => '请检查网络或账号密码';

  @override
  String get loginPageShowProxyDialogText2 => '使用 HTTP 代理';

  @override
  String get loginPageBuildLoginText4 => '登录 one 站账号';

  @override
  String get loginPageShowProxyDialogHelperText => '仅支持 HTTP 代理';

  @override
  String get loginPageBuildSiteConfigHint3 => '别名，如：家庭 NAS';

  @override
  String get loginPageSaveNewSiteToast => '请填写别名、地址、账号和密码';

  @override
  String get loginPageShowProxyDialogHintText => '例如 http://代理地址:端口';

  @override
  String get loginPageBuildSiteConfigText5 =>
      '支持 IP+端口，如 http://192.168.1.100:3000';

  @override
  String loginPageLoginToast3(String value) {
    return '登录失败：$value';
  }

  @override
  String get loginPageShowNoAccountText3 =>
      '本项目不提供任何注册服务。\n\n账号与密码需要您自行获取，本项目不提供任何获取渠道。\n\n您使用该账号在本应用中获取、播放的任何内容，其所有权与责任均归属内容提供方与账号持有人，本项目对此不承担任何责任。\n\n账号信息仅保存在本地设备，不会上传到任何第三方服务器。';

  @override
  String get close => '关闭';

  @override
  String get delete => '删除';

  @override
  String get remote => '远程';

  @override
  String get continueAction => '继续';

  @override
  String get online => '在线';

  @override
  String get importAction => '导入';

  @override
  String get lyricsLibraryPageBuildNavItem => '远程库';

  @override
  String get lyricsLibrary => '歌词库';

  @override
  String get lyricsLibraryPageBuildNavItem2 => '本地文件';

  @override
  String get lyricsLibraryPageProceedText => '继续导入';

  @override
  String get lyricsLibraryPageImportText => '取消导入';

  @override
  String get lyricsLibraryPageProgressPhase => '准备导入';

  @override
  String get lyricsLibraryPageOkText => '深度刷新';

  @override
  String get lyricsLibraryPageOkText2 => '删除歌词';

  @override
  String get lyricsLibraryPageSectionContentText => '选择文件夹';

  @override
  String get lyricsLibraryPageConfirmedText => '删除远程库';

  @override
  String get lyricsLibraryPageSectionContentText2 => '导入远程库';

  @override
  String get lyricsLibraryPageBuildText => '导入歌词库';

  @override
  String get lyricsLibraryPageBuildLabel => '刷新歌词库';

  @override
  String get lyricsLibraryPageBuildTooltip => '搜索歌词库';

  @override
  String get lyricsLibraryPageBuildText2 => '正在导入歌词';

  @override
  String get lyricsLibraryPageImportText2 => '跳过冲突文件';

  @override
  String get lyricsLibraryPageImportText3 => '覆盖冲突文件';

  @override
  String get lyricsLibraryPageOkText3 => '移除远程作品';

  @override
  String get lyricsLibraryPageProceedText2 => '大型内容导入';

  @override
  String get lyricsLibraryPageImportText4 => '发现导入冲突';

  @override
  String get lyricsLibraryPageRemoteSourceListTooltip => '只刷新此远程库';

  @override
  String get lyricsLibraryPageOkText4 => '删除歌词库作品';

  @override
  String get lyricsLibraryPageBuildLabel2 => '刷新全部远程库';

  @override
  String get lyricsLibraryPageBuildText3 => '正在准备文件…';

  @override
  String get lyricsLibraryPageSelectionDialogTitle => '选择歌词文件夹';

  @override
  String get lyricsLibraryPageSectionContentText3 => '正在连接并同步';

  @override
  String get lyricsLibraryPageSearchFieldHintText => '搜索作品 ID';

  @override
  String lyricsLibraryPageImportText5(String e) {
    return '导入失败：$e';
  }

  @override
  String get lyricsLibraryPageRemoteSourceListText => '尚未导入远程库';

  @override
  String get lyricsLibraryPageBuildHint => '长按执行深度刷新';

  @override
  String get lyricsLibraryPageBuildText4 => '正在统计歌词文件';

  @override
  String get lyricsLibraryPageScanProgressPhase => '正在检查文件冲突';

  @override
  String get lyricsLibraryPageResultDialogTitle => '选择 ZIP 文件';

  @override
  String get lyricsLibraryPageSectionContentText4 => '选择 ZIP 压缩包';

  @override
  String get lyricsLibraryPageBuildText5 => '暂时无法统计歌词文件';

  @override
  String lyricsLibraryPageRefreshText(String error) {
    return '刷新失败：$error';
  }

  @override
  String get lyricsLibraryPageShowFilesText => '没有可用的歌词或字幕文件';

  @override
  String get lyricsLibraryPageBuildText6 => '暂无数据，点击右上角导入';

  @override
  String get lyricsLibraryPageShowFilesText2 => '加载歌词文件失败，请重试';

  @override
  String lyricsLibraryPageReorderSetState(String error) {
    return '调整优先级失败：$error';
  }

  @override
  String get lyricsLibraryPageSectionContentLabelText => 'HTTP / HTTPS 地址';

  @override
  String get lyricsLibraryPageBuildHint2 => '同步所有已导入远程库的作品索引';

  @override
  String get lyricsLibraryPageImportText6 => '所选文件夹里没有歌词或字幕文件';

  @override
  String get lyricsLibraryPageSectionContentText5 => '选择要导入的歌词文件或压缩包。';

  @override
  String get lyricsLibraryPageSectionContentText6 => '输入开启了歌词库广播的设备地址。';

  @override
  String lyricsLibraryPageRefreshOneSetState(String url, String error) {
    return '刷新 $url 失败：$error';
  }

  @override
  String lyricsLibraryPageRemoveRemoteLibrarySetState(
    String url,
    String error,
  ) {
    return '删除 $url 失败：$error';
  }

  @override
  String lyricsLibraryPageBuildText7(String directoryCount) {
    return '$directoryCount 个目录';
  }

  @override
  String lyricsLibraryPageBuildText8(String length) {
    return '$length 个';
  }

  @override
  String get lyricsLibraryPageBuildText9 => '暂无远程作品，点击右上角导入并连接远程库';

  @override
  String lyricsLibraryPageOkText5(String workId) {
    return '确定移除 $workId 的远程作品索引吗？';
  }

  @override
  String lyricsLibraryPageOkText6(String workId) {
    return '确定删除 $workId 的全部歌词文件吗？';
  }

  @override
  String get lyricsLibraryPageOkText7 => '将删除没有歌词或字幕文件的作品目录，是否继续？';

  @override
  String get lyricsLibraryPageSectionContentText7 => '已导入的远程库（从上到下优先级递减，拖动排序）';

  @override
  String lyricsLibraryPageRemoteSourceListText2(String value) {
    return '优先级 $value · 长按删除';
  }

  @override
  String lyricsLibraryPageConfirmedText2(String url) {
    return '确定移除远程库 $url 及其已同步的作品索引吗？';
  }

  @override
  String get lyricsLibraryPageSectionContentText8 =>
      '导入时只同步作品索引；播放时再下载该作品的全部歌词。';

  @override
  String get lyricsLibraryPageProceedText3 =>
      '检测到大型压缩包或文件夹，导入过程可能需要较长时间，请耐心等待。';

  @override
  String lyricsLibraryPageOkText8(String length) {
    return '确定删除选中的 $length 个作品目录吗？';
  }

  @override
  String lyricsLibraryPageImportText7(String length) {
    return '检测到 $length 个已存在文件，如何处理？';
  }

  @override
  String lyricsLibraryPageOkText9(String length) {
    return '确定移除选中的 $length 个远程作品索引吗？';
  }

  @override
  String lyricsLibraryPageBuildText10(String fileCount, String value) {
    return '$fileCount 个歌词/字幕文件 · $value';
  }

  @override
  String get morePageBuildRow => '歌单';

  @override
  String get settings => '设置';

  @override
  String get morePageBuildRow2 => '随心听';

  @override
  String morePageBuildText(String server) {
    return '服务器：$server';
  }

  @override
  String get morePageOpenRandomWorkText => '当前条件下没有可播放的作品';

  @override
  String get morePageOpenRandomWorkText2 => '随心听加载失败，请稍后重试';

  @override
  String get playerPageShowLyricSettingsText => '归零';

  @override
  String get back => '返回';

  @override
  String get seekBackward => '快退';

  @override
  String get seekForward => '快进';

  @override
  String get playerPageUtilsUtil => '定时';

  @override
  String get equalizer => '均衡器';

  @override
  String get playerPageUtilsUtil2 => '定时中';

  @override
  String get playerPageShowLyricSettingsText2 => '繁简互转';

  @override
  String get autoMatch => '自动匹配';

  @override
  String get workDetails => '作品详情';

  @override
  String get playlist => '播放列表';

  @override
  String get sleepTimer => '定时关闭';

  @override
  String get playerPageWideLyricsPanelText => '暂无歌词';

  @override
  String get playerPageTopBarText => '正在播放';

  @override
  String get desktopLyrics => '桌面歌词';

  @override
  String get playerPagePlayModeLabelText => '循环播放';

  @override
  String get playerPagePlayModeLabelText2 => '单曲循环';

  @override
  String get playerPagePlayModeLabelText3 => '列表播放';

  @override
  String get playerPageShowLyricSettingsText3 => '歌词设置';

  @override
  String get playerPageShowLyricSettingsText4 => '字幕偏移';

  @override
  String get simplifiedToTraditional => '简 → 繁';

  @override
  String get traditionalToSimplified => '繁 → 简';

  @override
  String get playerPageShowQueueText => '播放列表为空';

  @override
  String get playerPageResDialogTitle => '选择歌词文件';

  @override
  String get playerPagePickOnlineLyricText => '选择在线歌词';

  @override
  String get playerPageBuildText => '暂无播放内容';

  @override
  String get playerPageShowLyricSettingsTitle => '选择离线歌词';

  @override
  String get playerPagePickOnlineLyricToast => '未找到在线歌词';

  @override
  String get playerPageShowLyricSettingsTitle2 => '选择歌词库歌词';

  @override
  String get playerPageLoadOnlineLyricToast => '该歌词无法解析';

  @override
  String get playerPageLyricsPanelText => '正在加载歌词…';

  @override
  String get playerAlreadyFirstTrack => '已经是第一首';

  @override
  String get playerAlreadyLastTrack => '已经是最后一首';

  @override
  String get playerPageNextToast => '已播放完播放列表';

  @override
  String get playerPageOpenCurrentToast => '文件流需登录后可用';

  @override
  String get playerPageShowLyricSettingsSub => '歌词库中没有该作品';

  @override
  String get playerPageOpenMediaToast => '打开媒体超时，请重试';

  @override
  String get playerPageLibraryAutoTileText => '从歌词库自动匹配歌词';

  @override
  String get playerPageOpenMediaToast2 => '打开失败，正在重试…';

  @override
  String get playerPageFriendlyPlayErrorText => '媒体流代理异常，请重试';

  @override
  String get playerLoudnessBoostLabel => '响度提升';

  @override
  String get playerPageVolumeControlTooltip => '响度提升（上限 120）';

  @override
  String get playerPageShowLyricSettingsSub2 => '从本地选择歌词或字幕文件';

  @override
  String get playerPageInitStateToast => '网络波动，正在自动重连…';

  @override
  String get playerPagePickLibraryLyricToast => '歌词库中没有该作品的歌词';

  @override
  String get playerPageOpenMediaToast3 => '打开媒体超时，正在重试…';

  @override
  String get playerPageShowLyricSettingsSub3 => '仅显示当前作品的歌词文件';

  @override
  String get playerPageCheckSleepToast => '已停止播放，系统接口已释放';

  @override
  String get playerPagePickOnlineLyricSub => '按曲目名与中文优先自动选择';

  @override
  String get playerPageFriendlyPlayErrorText2 => '服务器返回错误，请稍后重试';

  @override
  String get playerPageVolumeControlTooltip2 => '启用响度提升（上限 120）';

  @override
  String get playerPageFriendlyPlayErrorText3 => '登录已失效，请重新登录后重试';

  @override
  String get playerPagePickOfflineLyricToast => '文件中没有可读取的带时间轴歌词';

  @override
  String get playerPageFriendlyPlayErrorText4 => '无法连接媒体流，请检查网络后重试';

  @override
  String get playerPageVolumeControlTooltip3 => '响度提升 Plus（上限 200）';

  @override
  String get playerPageToggleDesktopLyricsToast => '未授予悬浮窗权限，桌面歌词无法显示';

  @override
  String playerPageSeekCircleMessage(String label, String seconds) {
    return '$label $seconds 秒';
  }

  @override
  String get playerPageLibraryAutoTileText2 => '优先匹配本地歌词，找不到时使用在线歌词';

  @override
  String playerPageShowQueueText2(String length) {
    return '播放列表（$length）';
  }

  @override
  String playerPageInitStateToast2(String friendlyPlayError) {
    return '播放失败：$friendlyPlayError';
  }

  @override
  String playerPageOpenMediaToast4(String friendlyPlayError) {
    return '无法打开媒体流：$friendlyPlayError';
  }

  @override
  String get playlistsPageNameText => '创建';

  @override
  String get playlistsPageBuildText => '重命名';

  @override
  String get playlistsPageBuildText2 => '新建歌单';

  @override
  String get playlistsPageNameHintText => '歌单名称';

  @override
  String get playlistsPageBuildText3 => '歌单为空';

  @override
  String get playlistsPageHeaderTooltip => '移除作品';

  @override
  String get playlistsPageNameText2 => '重命名歌单';

  @override
  String get playlistsPageHeaderMessage => '拖动调整作品顺序';

  @override
  String get playlistsPageRowMessage => '拖动调整播放顺序';

  @override
  String get playlistsPagePlayTrackText => '歌单中没有可播放的音频';

  @override
  String get playlistsPageBuildText4 => 'SFW 模式下不显示歌单';

  @override
  String get playlistsPageBuildText5 => '暂无歌单，点击右下角新建';

  @override
  String get playlistsPageBuildText6 => 'SFW 模式下不显示歌单内容';

  @override
  String playlistsPageBuildText7(String length) {
    return '$length 个条目';
  }

  @override
  String get playlistsPagePlayTrackText2 => '该音频缺少可用文件流，请从作品详情重新添加';

  @override
  String get playlistsPageBuildText8 => '拖动标题调整作品顺序，拖动媒体调整播放顺序';

  @override
  String get playlistsPageBuildText9 => '长按标题调整作品顺序，长按媒体调整播放顺序';

  @override
  String playlistsPageHeaderText(String length) {
    return '$length 个音频';
  }

  @override
  String get traditionalChineseShort => '繁中';

  @override
  String get englishLanguage => '英语';

  @override
  String get simplifiedChineseShort => '简中';

  @override
  String get settingsPageHealthBadgeStartsWith => '正常';

  @override
  String get settingsPageSectionsMiniBtn => '检测';

  @override
  String get settingsPageSectionsMiniBtn2 => '配置';

  @override
  String get settingsPageLockRowText => '解锁';

  @override
  String get play => '播放';

  @override
  String get lyrics => '歌词';

  @override
  String get settingsPageSectionsSection => '曲目';

  @override
  String get settingsPageOnVersionTapText => '好吧';

  @override
  String get settingsPageSectionsSection2 => '数据与网络';

  @override
  String get settingsPageSectionsSection3 => '外观';

  @override
  String get settingsPageSectionsText => '主题';

  @override
  String get settingsPageSectionsText2 => '浅色';

  @override
  String get settingsPageSectionsText3 => '深色';

  @override
  String get settingsPageSectionsText4 => '重置';

  @override
  String get settingsPageSectionsSection4 => '关于';

  @override
  String get settingsPageSectionTitleText => '隐私';

  @override
  String get settingsPageSectionsTitle => '版本';

  @override
  String get settingsPageSectionsTitle2 => '仓库';

  @override
  String get settingsPageLockRowSub => '未锁定';

  @override
  String get settingsPageSectionsMiniBtn3 => '去关闭';

  @override
  String get settingsPageShortcutConflictText => '下一曲';

  @override
  String get settingsPageShortcutConflictText2 => '上一曲';

  @override
  String get settingsPageSectionsLockRow => '桌面端';

  @override
  String get settingsPageSectionsMiniBtn4 => '已关闭';

  @override
  String get settingsPageShortcutLabelText => '未设置';

  @override
  String get translationEngine => '翻译引擎';

  @override
  String get settingsPageSectionsLabel => '字体颜色';

  @override
  String get settingsPageSectionsLabel2 => '描边颜色';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get settingsPageAutoCheckSetState => '检测中…';

  @override
  String get settingsPageSectionsTitle3 => '快退秒数';

  @override
  String get interfaceLanguage => '界面语言';

  @override
  String get settingsPageSectionsTitle4 => '快进秒数';

  @override
  String get settingsPageAiModelInputLabelText => '模型名称';

  @override
  String get settingsPageShortcutLabelText2 => '方向键→';

  @override
  String get chineseConversion => '繁简转换';

  @override
  String get settingsPageSectionsText5 => '描边宽度';

  @override
  String get settingsPageSectionsSection5 => '账号设置';

  @override
  String get settingsPageSectionsText6 => '字体大小';

  @override
  String get settingsPageShortcutLabelText3 => '方向键←';

  @override
  String get settingsPageBuildText => '完全重置';

  @override
  String get settingsPageSectionsSwitchRow => '智能路径';

  @override
  String get settingsPageAutoCheckSetState2 => '连接失败';

  @override
  String get followSystem => '跟随系统';

  @override
  String get settingsPageOpenRepoToast => '打开失败';

  @override
  String get settingsPageEditAudioTypePreferenceText => '恢复默认';

  @override
  String get settingsPageSectionsText7 => '界面缩放';

  @override
  String get settingsPageBuildText2 => '确定重置';

  @override
  String get settingsPageSectionsTitle5 => '检查更新';

  @override
  String get targetLanguage => '目标语言';

  @override
  String get languageAndTranslation => '语言与翻译';

  @override
  String get settingsPageSectionsSwitchRow2 => '歌词库广播';

  @override
  String get settingsPageSectionsSwitchRow3 => '剪贴板检测';

  @override
  String get settingsPageShortcutConflictText3 => '播放/暂停';

  @override
  String get settingsPageSectionsTitle6 => '快退快捷键';

  @override
  String get settingsPageSectionsSwitchRow4 => '效果音偏好';

  @override
  String get settingsPageSectionsTitle7 => '快进快捷键';

  @override
  String get settingsPageOnVersionTapText2 => '开发者模式';

  @override
  String get settingsPageSectionsSub => '未配置账号';

  @override
  String get settingsPageRowSub => '点击进入设置';

  @override
  String get settingsPageSectionsTitle8 => '音频类型偏好';

  @override
  String get settingsPageSectionsText8 => '检测模型列表';

  @override
  String get settingsPageProxySettingsTooltip => '清空代理地址';

  @override
  String get settingsPageSectionsTitle9 => '上一曲快捷键';

  @override
  String get settingsPageSectionsTitle10 => '关闭省电优化';

  @override
  String get settingsPageSectionsSwitchRow5 => '忽略音频焦点';

  @override
  String get settingsPageSectionsSwitchRow6 => '自动检测更新';

  @override
  String get settingsPageMediaCacheLimitRowText => '媒体缓存上限';

  @override
  String get settingsPageSectionsTitle11 => '下一曲快捷键';

  @override
  String get translationTargetLanguage => '翻译目标语言';

  @override
  String get followInterfaceLanguage => '跟随界面语言';

  @override
  String get settingsPageSectionsText9 => '添加自建站点';

  @override
  String get settingsPageSectionsLockRow2 => '安卓（横屏）';

  @override
  String get settingsPageSectionsLockRow3 => '安卓（竖屏）';

  @override
  String get settingsPageSectionsTitle12 => '完全重置软件';

  @override
  String get settingsPageProxySettingsSwitchRow => 'HTTP 代理';

  @override
  String get settingsPageAiModelInputTooltip => '选择已检测模型';

  @override
  String get settingsPageSectionsTitle13 => '恢复默认快捷键';

  @override
  String get settingsPageSectionsSwitchRow7 => '不记忆播放进度';

  @override
  String get settingsPageSectionsSection6 => '歌词与桌面歌词';

  @override
  String settingsPageSectionsToast(String e) {
    return '连接失败：$e';
  }

  @override
  String get settingsPageSectionsToast2 => '正在检测连接…';

  @override
  String get settingsPageSectionsSwitchRow8 => '拔出耳机自动暂停';

  @override
  String get settingsPageSectionsTitle14 => '播放/暂停快捷键';

  @override
  String get settingsPageSectionsSub2 => '手动请求更新服务';

  @override
  String get settingsPageSectionsSwitchRow9 => '最顶层悬浮歌词窗';

  @override
  String get settingsPageAiModelInputTooltip2 => '请先检测模型列表';

  @override
  String get settingsPageProxySettingsHelperText => '留空将不使用代理';

  @override
  String get settingsPageLabelsLabels => 'OpenAI 兼容';

  @override
  String get settingsPageSectionsSwitchRow10 => '关闭窗口后保留托盘';

  @override
  String get settingsPageDetectOpenAiModelsToast => '正在获取模型列表…';

  @override
  String get settingsPageSectionsSwitchRow11 => '不显示通知栏媒体卡片';

  @override
  String get settingsPageSectionsSub3 => '歌词中文部分自动转换';

  @override
  String get sourceAndTargetLanguage => '源语言 / 目标语言';

  @override
  String get settingsPageDetectOpenAiModelsToast2 => '请先填写 API 地址';

  @override
  String get settingsPageSectionsSwitchRow12 => '定时关闭后释放系统接口';

  @override
  String get settingsPagePlaybackShortcutRowSub => '播放器页获得焦点时生效';

  @override
  String get settingsPageAiModelInputHintText => '输入模型名或从列表选择';

  @override
  String get settingsPageSectionsSub4 => '防止后台播放被系统中断';

  @override
  String get settingsPageStatusStatus => '已保存地址，开启后生效';

  @override
  String settingsPageLockRowTitle(String label) {
    return '$label 歌词锁定';
  }

  @override
  String settingsPageDetectOpenAiModelsToast3(String e) {
    return '模型列表获取失败：$e';
  }

  @override
  String get settingsPageSectionsToast3 => '正在检测 DeepL…';

  @override
  String get settingsPageSectionsSwitchRow13 => '优先进入包含效果音的目录';

  @override
  String settingsPageSectionsToast4(String e) {
    return '关闭歌词库广播失败：$e';
  }

  @override
  String settingsPageSectionsToast5(String e) {
    return '无法开启歌词库广播：$e';
  }

  @override
  String get settingsPageSectionsSwitchRow14 => '打开作品自动进入最佳目录';

  @override
  String settingsPageSectionsToast6(String e) {
    return 'DeepL 连接失败：$e';
  }

  @override
  String get settingsPageSectionsSwitchRow15 => '自动识别复制的 RJ 链接';

  @override
  String get settingsPageSectionsSwitchRow16 => '到点清除锁屏媒体卡片与通知';

  @override
  String get settingsPageSectionsSwitchRow17 => '启动后 3 秒请求更新服务';

  @override
  String settingsPageSectionsToast7(String r) {
    return 'DeepL 连接正常：$r';
  }

  @override
  String get settingsPageOnVersionTapText3 => '你不会真以为有开发者模式吧？';

  @override
  String get settingsPageProxySettingsHelperText2 => '开启 HTTP 代理后可编辑';

  @override
  String get settingsPageSectionsSwitchRow18 => '拔出耳机或断开蓝牙时自动暂停';

  @override
  String get settingsPageSectionsSwitchRow19 => '与其他应用同时播放，互不打断';

  @override
  String get settingsPageSectionsSwitchRow20 => '播放时不在通知栏显示媒体卡片';

  @override
  String get settingsPageAiModelInputHintText2 => '例如 gpt-4o-mini';

  @override
  String get settingsPageSectionsSwitchRow21 => '通知栏封面显示项目 logo';

  @override
  String settingsPageBuildText3(String count) {
    return '确定重置（$count 秒）';
  }

  @override
  String get settingsPageSectionsSub5 => '清除本机全部数据，恢复初始状态';

  @override
  String get settingsPageSectionsSub6 => '5–60 秒，每次调整 5 秒';

  @override
  String settingsPageEditPlaybackShortcutToast(String conflict) {
    return '该按键已用于$conflict';
  }

  @override
  String get settingsPageDetectOpenAiModelsFormatException => '响应未包含 data[].id';

  @override
  String get settingsPageSectionsInput => 'API Key（本地服务可留空）';

  @override
  String get settingsPageConfirmResetText => '已重置：账号与全部本地数据已清除';

  @override
  String get settingsPageRequestBatteryIgnoreToast => '请在系统设置中允许「忽略电池优化」';

  @override
  String get settingsPageStatusStatus2 => '已启用，请填写 HTTP 代理地址';

  @override
  String get settingsPageMediaCacheLimitRowText2 => '仅限制在线播放缓冲，不影响下载功能';

  @override
  String get settingsPageSectionsSwitchRow22 => '关闭窗口时将停止后台运行并退出程序';

  @override
  String get settingsPageSectionsSub7 => '已加入白名单，后台播放不受省电限制';

  @override
  String get settingsPageSectionsInput2 => 'API 地址 (Base URL)';

  @override
  String get settingsPageSectionsInput3 => 'DeepL 免费版 API Key';

  @override
  String settingsPageSectionsSub8(String asmrUser) {
    return '账号：$asmrUser';
  }

  @override
  String get settingsPageSectionsSwitchRow23 => '关闭后继续在后台播放，可从系统托盘恢复';

  @override
  String get settingsPageSectionsSwitchRow24 => '重启程序后恢复上次曲目，但从头开始播放';

  @override
  String get settingsPageSectionsSwitchRow25 => '只读 API 服务 · 端口 2377';

  @override
  String get settingsPageLockRowSub2 => '已锁定：点击歌词不会响应，可在设置中解锁';

  @override
  String get settingsPageStatusStatus3 => '仅支持 HTTP 协议代理，对所有网络请求生效';

  @override
  String get settingsPageSectionsSwitchRow26 => '开启后封面位置显示项目 logo，不显示真实封面';

  @override
  String settingsPageDetectOpenAiModelsToast4(String length) {
    return '已获取 $length 个模型';
  }

  @override
  String settingsPageOnVersionTapToast(String value) {
    return '再执行 $value 步进入开发者模式';
  }

  @override
  String settingsPageStatusStatus4(String trim) {
    return '已启用：$trim';
  }

  @override
  String get settingsPageSectionsInput4 => '在 deepl.com 免费注册后获取（api-free）';

  @override
  String get settingsPageSectionsSub9 => 'Space / PageUp / PageDown / 方向键←→';

  @override
  String settingsPageAiModelInputHelperText(String length) {
    return '已检测到 $length 个模型';
  }

  @override
  String get settingsPageSectionsSub10 =>
      'Google / Microsoft 免费 · DeepL 免费 Key · OpenAI 兼容';

  @override
  String get settingsPageSectionsInput5 =>
      'https://api.openai.com/v1 或 http://127.0.0.1:11434/v1';

  @override
  String settingsPageSectionsSub11(String translationTargetLabel) {
    return '日语 → $translationTargetLabel';
  }

  @override
  String settingsPageNextKeyIdText(String shortcutLabel) {
    return '当前按键：$shortcutLabel\n\n按下新的单个按键';
  }

  @override
  String get settingsPageBuildText4 =>
      '将清除本机全部数据，且不可恢复：\n\n· ASMR.ONE 账号与自建站点配置\n· 收藏 / 播放历史 / 歌单 / 黑名单\n· 翻译结果、均衡器、桌面歌词、定时关闭等全部设置\n\n请确认是否继续。';

  @override
  String get mark => '标记';

  @override
  String get confirm => '确定';

  @override
  String get refresh => '刷新';

  @override
  String get workPageBuildLabel => '评论';

  @override
  String get translate => '翻译';

  @override
  String get workPageRefreshWorkToast => '已刷新';

  @override
  String get workPageBuildTooltip => '上一张';

  @override
  String get workPageBuildText => '已收藏';

  @override
  String get workPageBuildText2 => '翻译中';

  @override
  String get workPageBuildTooltip2 => '下一张';

  @override
  String get workPageLanguageEditionsButtonText => '多语言';

  @override
  String get workPageSimilarWorksSliversText => '相似作品';

  @override
  String get workPageBuildText3 => '曲目列表';

  @override
  String get workPageConfirmedText => '删除标记';

  @override
  String get workPageConfirmedText2 => '删除作品';

  @override
  String get workPageRefreshWorkToast2 => '刷新失败';

  @override
  String get workPageShowTextViewerTooltip => '切换编码';

  @override
  String get workPageBuildText4 => '我的评论';

  @override
  String get workPageAddToPlaylistText => '确认添加';

  @override
  String get workPageBuildHintText => '写评论…';

  @override
  String get workPageBuildText5 => '取消翻译';

  @override
  String get workPageOkText => '加入黑名单';

  @override
  String get workPageAddToPlaylistText2 => '添加到歌单';

  @override
  String get workPageTranslateTitlesToast => '已取消翻译';

  @override
  String get workPageSelectedText => '选择 CV';

  @override
  String get workPageBuildText6 => '添加至歌单';

  @override
  String get workPageBuildText7 => '下载选中项目';

  @override
  String get workPageOpenVideoChooserText => '选择打开方式';

  @override
  String get workPageOpenVideoChooserText2 => '音频方式打开';

  @override
  String get workPageSelectedText2 => '切换翻译引擎';

  @override
  String get workPageTranslateTitlesToast2 => '未知翻译引擎';

  @override
  String get workPageTranslateTitlesFormatException => '翻译结果为空';

  @override
  String get workPageAllFilesRowText => '查看全部文件';

  @override
  String get workPageDownloadSelectedToast => '已加入下载队列';

  @override
  String get workPageAddToPlaylistText3 => '请输入歌单名称';

  @override
  String get workPageOpenVideoChooserText3 => '外部播放器打开';

  @override
  String workPageDeleteNotify(String e) {
    return '删除失败：$e';
  }

  @override
  String get workPageBuildLabel2 => '添加到播放列表';

  @override
  String workPageSetProgressToast(String e) {
    return '标记失败：$e';
  }

  @override
  String get workPageBuildLabel3 => '仅显示媒体文件';

  @override
  String get workPageTreePlaceholderText => '该作品暂无曲目';

  @override
  String workPageTranslateTitlesToast3(String e) {
    return '翻译失败：$e';
  }

  @override
  String workPageRateWorkToast(String e) {
    return '评分失败：$e';
  }

  @override
  String workPageApplyEncodingToast(String e) {
    return '解码失败：$e';
  }

  @override
  String workPageSubmitNotify(String e) {
    return '保存失败：$e';
  }

  @override
  String get workPageSimilarWorksSliversText2 => '加载更多相似作品';

  @override
  String get workPageDownloadSelectedToast2 => '曲目列表尚未加载';

  @override
  String workPageClearRatingToast(String e) {
    return '取消评分失败：$e';
  }

  @override
  String get workPageRefreshWorkToast3 => '已刷新本地下载记录';

  @override
  String workPageDownloadSelectedToast3(String e) {
    return '加入下载失败：$e';
  }

  @override
  String get workPageSimilarWorksSliversText3 => '已显示全部相似作品';

  @override
  String get workPageOpenLanguageEditionToast => '无法加载该语言版本';

  @override
  String workPageBuildToast(String e) {
    return '收藏操作失败：$e';
  }

  @override
  String get workPageConfirmedText3 => '确定要删除标记吗？';

  @override
  String workPageSetProgressToast2(String e) {
    return '取消标记失败：$e';
  }

  @override
  String get workPageBuildLabel4 => '跳转 DLsite';

  @override
  String get workPageAddToPlaylistToast => '请先勾选文件或文件夹';

  @override
  String get workPageBuildText8 => '曲目列表（文件夹结构）';

  @override
  String get workPageBuildLabel5 => '跳转 asmr.one';

  @override
  String workPageAddToPlaylistToast2(String name) {
    return '已添加到「$name」';
  }

  @override
  String get workPageAddToServerPlaylistToast => '只能添加到自建播放列表';

  @override
  String get workPageOnMoreActionToast => '曲目列表加载中，请稍候';

  @override
  String get workPageTreePlaceholderText2 => '该作品没有音频或视频文件';

  @override
  String get workPageAddToServerPlaylistToast2 => '该作品缺少编号，无法添加';

  @override
  String get workPageOpenReviewDialogToast => '该作品缺少编号，无法评价';

  @override
  String get workPageDeleteSelectedLocalFilesToast => '所选项目中没有已下载文件';

  @override
  String get workPageDeleteSelectedLocalFilesToast2 => '请先勾选要删除的本地文件';

  @override
  String get workPageOnMoreActionToast2 => '曲目加载失败，请刷新后重试';

  @override
  String get workPageTreePlaceholderText3 => '无网络连接，无法获取曲目列表';

  @override
  String workPageBuildText9(String dur) {
    return '时长 $dur';
  }

  @override
  String get workPageEnginesEngines => 'DeepL（免费版 Key）';

  @override
  String get workPageEnginesEngines2 => 'OpenAI 兼容（可配置）';

  @override
  String workPageCopyRjToast(String rj) {
    return '已复制 $rj';
  }

  @override
  String get workPageDownloadSelectedToast4 => '请先勾选要下载的项目或文件夹';

  @override
  String get workPageAddToPlaylistToast3 => '所选项目中没有可播放的音频文件';

  @override
  String get workPageOnMoreActionToast3 => '请先勾选需要听写翻译的媒体文件';

  @override
  String get workPagePlayAsAudioToast => 'SFW 模式下不能播放非全年龄作品';

  @override
  String get workPageOpenLanguageEditionToast2 => 'SFW 模式下不能打开非全年龄作品';

  @override
  String get workPagePlayFilesToast => '暂无音频文件（文件流需登录后可用）';

  @override
  String get workPageEnginesEngines3 => 'Google（免费，无需 Key）';

  @override
  String workPageNodeRowToast(String title) {
    return '已复制文件名：$title';
  }

  @override
  String workPageDeleteSelectedLocalFilesToast3(String deleted) {
    return '已删除 $deleted 个本地文件';
  }

  @override
  String get workPageTranslateTitlesToast4 => '请先在设置中配置 API 地址与模型名';

  @override
  String get workPageEnginesEngines4 => 'Microsoft（免费，无需 Key）';

  @override
  String workPageOpenFileToast(String title) {
    return '暂不支持查看该类型：$title';
  }

  @override
  String get workPageEnginesEngines5 => 'Index-Translate（官方接口）';

  @override
  String get workPageConfirmDeleteWorkToast => '删除失败，请关闭正在占用该作品的程序后重试';

  @override
  String workPageTranslateTitlesToast5(String length) {
    return '正在翻译 $length 行标题…';
  }

  @override
  String get workPageTranslateTitlesToast6 => '请先在设置中填写 DeepL 免费版 API Key';

  @override
  String workPageAddToPlaylistText4(String length) {
    return '已选择 $length 个音频文件';
  }

  @override
  String get workPageOnMoreActionToast4 => '所选项目中没有可提交给 kikoeta-transl 的媒体文件';

  @override
  String workPageTranslateTitlesToast7(String length) {
    return '翻译完成（标题 + $length 个曲目）';
  }

  @override
  String workPageOkText2(String t) {
    return '将标签「$t」加入黑名单？\n加入后，含该标签的作品将从首页与搜索中过滤。';
  }

  @override
  String workPageConfirmedText4(String title) {
    return '确定删除“$title”的全部本地文件吗？此操作无法撤销。';
  }

  @override
  String get liked => '喜欢';

  @override
  String get privatePlaylist => '私有';

  @override
  String get publicPlaylist => '公开';

  @override
  String get sharedByLink => '链接共享';

  @override
  String get apiServiceMapPlaylistName => '未命名歌单';

  @override
  String get apiServiceMapWorkVa => 'CV. 未知';

  @override
  String get apiServiceFetchWorkFormatException => '作品详情格式无效';

  @override
  String get apiServiceFetchPlaylistMetadataFormatException => '歌单详情格式无效';

  @override
  String get apiServiceFetchAdvancedFilterEntriesValue => '不支持的高级筛选类型';

  @override
  String get apiServiceFetchAdvancedFilterEntriesFormatException =>
      '高级筛选数据格式无效';

  @override
  String get apiServiceToggleFavoriteException => '该作品缺少编号，无法收藏';

  @override
  String get apiServiceClearReviewRatingException => '该作品缺少编号，无法取消评分';

  @override
  String get apiServiceClearReviewProgressException => '该作品缺少编号，无法取消标记';

  @override
  String get apiServiceDeleteReviewException => '该作品缺少编号，无法删除标记';

  @override
  String get search => '搜索';

  @override
  String clipboardWatcherCheckText(String rj) {
    return '检测到 $rj，点击搜索';
  }

  @override
  String get desktopLyricsOverlayEnsureWindowToNativeUtf16 => 'Kikoeta 桌面歌词';

  @override
  String get downloadServiceDownloadFileHttpException => '下载文件为空';

  @override
  String get downloadServiceRunStateError => '没有可下载的文件';

  @override
  String get downloadServiceRunStateError2 => '下载文件地址为空';

  @override
  String get downloadTransferDownloadToFileHttpException => '下载响应不完整';

  @override
  String get downloadTransferDownloadToFileHttpException2 => '下载分片长度发生变化';

  @override
  String get downloadTransferDownloadToFileHttpException3 => '下载文件长度校验失败';

  @override
  String get downloadTransferDownloadToFileHttpException4 => '下载响应的字节范围不匹配';

  @override
  String get downloadTransferDownloadToFileHttpException5 => '下载响应超过声明的文件长度';

  @override
  String get downloadTransferDownloadToFileHttpException6 => '下载响应使用了非原始字节编码';

  @override
  String downloadTransferDownloadToFileHttpException7(String status) {
    return '下载失败 HTTP $status';
  }

  @override
  String get ktServiceNormalizeEndpointFormatException => '连接地址格式应为 IP/域名:端口';

  @override
  String get ktServiceDecodeFormatException => 'kikoeta-transl 返回了无效响应';

  @override
  String get ktServiceNormalizeEndpointFormatException2 =>
      '请输入 kikoeta-transl 的 IP/域名与端口';

  @override
  String ktServiceErrorMessageText(String statusCode) {
    return 'kikoeta-transl 请求失败（HTTP $statusCode）';
  }

  @override
  String get lyricsLibraryRemoteClientValidateWorkIdFormatException => '无效的作品号';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException =>
      '远程歌词库分页游标无效';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException2 =>
      '远程歌词库未提供作品列表';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException =>
      '远程作品没有歌词文件列表';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException2 =>
      '远程作品没有可用歌词文件';

  @override
  String get lyricsLibraryRemoteClientGetJsonFormatException =>
      '远程歌词库返回的数据格式无效';

  @override
  String get lyricsLibraryRemoteClientNormalizeBaseUrlFormatException =>
      '请输入有效的 HTTP 或 HTTPS 地址';

  @override
  String lyricsLibraryRemoteClientGetJsonHttpException(String statusCode) {
    return '远程歌词库返回 HTTP $statusCode';
  }

  @override
  String get lyricsLibraryServiceExtractArchivePhase => '正在解压';

  @override
  String get lyricsLibraryServiceCopyTreePhase => '正在复制';

  @override
  String get lyricsLibraryServiceRemoveRemoteLibraryStateError => '该远程库尚未导入';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError =>
      '不支持的歌词格式';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError2 =>
      '文件中没有有效时间轴';

  @override
  String get lyricsLibraryServiceImportRemoteWorkFormatException =>
      '远程作品没有有效歌词文件';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError3 =>
      '目标文件必须位于作品目录内';

  @override
  String get lyricsLibraryServiceSetRemoteLibraryOrderArgumentError =>
      '远程库列表已变化，请重新打开导入窗口';

  @override
  String lyricsLibraryServiceSubscriptionStateError(String message) {
    return '歌词导入进程异常: $message';
  }

  @override
  String get updateServiceShowUpdateDialogText => '不再提示';

  @override
  String get updateServiceShowUpdateDialogText2 => '跳转下载';

  @override
  String get updateServiceShowUpdateDialogText3 => '发现新版本';

  @override
  String get updateServiceCheckManuallyText => '正在检查更新…';

  @override
  String get updateServiceCheckError => '更新服务连接失败';

  @override
  String get updateServiceCheckManuallyToast => '当前已是最新版本';

  @override
  String get updateServiceShowUpdateDialogToast => '打开下载页面失败';

  @override
  String get updateServiceGetUpdateResponseStateError => '更新服务请求未执行';

  @override
  String get updateServiceParseReleaseResponseFormatException => '更新响应缺少版本信息';

  @override
  String get updateServiceCheckError2 => '更新服务未返回有效版本信息';

  @override
  String get updateServiceCheckError3 => '无法连接更新服务或 GitHub';

  @override
  String updateServiceShowUpdateDialogText4(
    String version,
    String currentVersion,
  ) {
    return '最新版本：$version\n当前版本：$currentVersion';
  }

  @override
  String get pause => '暂停';

  @override
  String get quit => '退出';

  @override
  String get windowsTrayServiceSetContextMenuLabel => '显示首页';

  @override
  String get sheetsShowSleepSheetSuffixText => '分钟';

  @override
  String get sheetsBuildText => '应用';

  @override
  String get sheetsShowSiteSheetField => '别名';

  @override
  String get sheetsShowSiteSheetField2 => '地址';

  @override
  String get account => '账号';

  @override
  String get sheetsPresetsPresets => '人声';

  @override
  String get sheetsPresetsPresets2 => '低音';

  @override
  String get sheetsPresetsPresets3 => '平直';

  @override
  String get sheetsPresetsPresets4 => '流行';

  @override
  String get sheetsPresetsPresets5 => '摇滚';

  @override
  String get sheetsShowEqSheetText => '未启用';

  @override
  String get sheetsShowEqSheetText2 => '已应用';

  @override
  String get sheetsShowSleepSheetText => '取消定时';

  @override
  String get sheetsShowSleepSheetText2 => '开始定时';

  @override
  String get playbackComplete => '播放完毕';

  @override
  String get sheetsTimePickerText => '关闭时间';

  @override
  String get sheetsShowSleepSheetLabel => '指定时间';

  @override
  String sheetsShowSleepSheetLabel2(String m) {
    return '$m 分钟';
  }

  @override
  String get sheetsShowSleepSheetLabel3 => 'N 分钟后';

  @override
  String get sheetsBuildTitle => '选择服务器';

  @override
  String get sheetsShowEqSheetText3 => '启用均衡器';

  @override
  String get sheetsShowSiteSheetTitle => '编辑自建站点';

  @override
  String get sheetsBuildText2 => '管理自建站点';

  @override
  String get sheetsShowSleepSheetHintText => '自定义分钟数';

  @override
  String get sheetsBuildText3 => '暂无自建站点';

  @override
  String get sheetsBuildText4 => '选择自建站点';

  @override
  String get sheetsShowSiteSheetHint => '如：家庭 NAS';

  @override
  String get sheetsBuildText5 => '请先添加自建站点';

  @override
  String get sheetsShowOneConfigSheetTitle => 'ASMR.ONE 账号';

  @override
  String get sheetsShowOneConfigSheetHint => 'asmr.one 账号';

  @override
  String get sheetsShowOneConfigSheetSub => '账号信息仅保存在本地（演示）';

  @override
  String get sheetsShowSleepSheetText3 => '当前播放列表播完后自动停止并关闭';

  @override
  String get sheetsShowSleepSheetText4 => '剩余时间 · 到点后自动停止并退出';

  @override
  String get sheetsBuildSub => '官方服务或自建 Kikoeru 站点';

  @override
  String get sheetsShowEqSheetSub => '真 10 段 · ±12 dB · 全平台';

  @override
  String get sheetsShowSleepSheetText5 => '当前播放列表的内容播放完毕后自动停止并关闭';

  @override
  String get sheetsShowSleepSheetSub => '到点后停止播放并释放系统接口（锁屏卡片 / 通知全部清除）';

  @override
  String sheetsBuildLabel(String length) {
    return '自定义配置（$length）';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip(String label) {
    return '减少$label秒数';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip2(String label) {
    return '增加$label秒数';
  }

  @override
  String get name => '名称';

  @override
  String get description => '描述';

  @override
  String get playlistPickerRowsMapEntry => '权限';

  @override
  String get language => '语言';

  @override
  String get confirmAction => '确认';

  @override
  String get create => '新建';

  @override
  String get playlistPickerShowEditorLabelText => '类型';

  @override
  String get playlistPickerRowsMapEntry2 => '创建人';

  @override
  String get playlistPickerRowsMapEntry3 => '更新时间';

  @override
  String get playlistPickerReviewsItemName => '我的收藏';

  @override
  String get playlistPickerRowsMapEntry4 => '播放次数';

  @override
  String get playlistPickerRowsMapEntry5 => '作品数量';

  @override
  String get playlistPickerCopyText => '歌单详情';

  @override
  String get playlistPickerLinkLabelText => '分享链接';

  @override
  String get playlistPickerCopyText2 => '复制链接';

  @override
  String get playlistPickerRowsMapEntry6 => '创建时间';

  @override
  String get playlistPickerBuildText => '切换播放列表';

  @override
  String get playlistPickerPlaylistItemTooltip => '移除播放列表';

  @override
  String get playlistPickerPlaylistItemTooltip2 => '编辑播放列表';

  @override
  String get playlistPickerShowEditorText => '创建播放列表';

  @override
  String get playlistPickerLinkText => '导入播放列表';

  @override
  String get playlistPickerOkText => '删除播放列表';

  @override
  String playlistPickerRemoveLikedToast(String e) {
    return '移除失败：$e';
  }

  @override
  String playlistPickerCreatePlaylistToast(String e) {
    return '创建失败：$e';
  }

  @override
  String get playlistPickerLoadSetState => '无法加载播放列表';

  @override
  String get playlistPickerImportPlaylistToast => '无法识别播放列表链接';

  @override
  String get playlistPickerReviewsItemSubtitle => '我的评价/收藏（所有作品）';

  @override
  String get playlistPickerCreatePlaylistToast2 => '已创建，但列表中未找到该播放列表';

  @override
  String get playlistPickerImportPlaylistToast2 => '已添加，但列表中暂未找到该播放列表';

  @override
  String playlistPickerSubtitleSubtitle(String worksCount) {
    return '$worksCount 个作品';
  }

  @override
  String get playlistPickerLinkText2 => '粘贴别人分享的播放列表链接，会收藏到我的播放列表。';

  @override
  String playlistPickerOkText2(String name) {
    return '确定删除“$name”吗？此操作无法撤销。';
  }

  @override
  String playlistPickerOkText3(String name) {
    return '确定从我的播放列表中移除“$name”吗？';
  }

  @override
  String playlistPickerSubtitleSubtitle2(String worksCount, String replaceAll) {
    return '$worksCount 个作品 · $replaceAll';
  }

  @override
  String get widgetsFilterButtonTooltip => '筛选';

  @override
  String get widgetsFilterButtonLabel => '仅字幕';

  @override
  String get allAges => '全年龄';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter => '排除语言';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter2 => '搜索社团';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter3 => '搜索声优';

  @override
  String get widgetsBuildBuilder => 'AI歌词';

  @override
  String get widgetsBuildBuilder2 => '远程歌词';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter4 => '筛选语言';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter5 => '排除标签';

  @override
  String get widgetsBuildBuilder3 => '本地歌词';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter6 => '排除社团';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter7 => '排除声优';

  @override
  String get widgetsInputRowMessage => '高级搜索';

  @override
  String get widgetsHistoryPanelText => '搜索历史';

  @override
  String get widgetsBuildBuilder4 => '在线歌词';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter8 => '搜索标签';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter9 =>
      '筛选年龄分级';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter10 =>
      '排除年龄分级';

  @override
  String get widgetsBuildText => '高级搜索参数';

  @override
  String get widgetsHistoryPanelText2 => '暂无搜索历史';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter11 =>
      '包含低愿力标签';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter12 =>
      '排除低愿力标签';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter13 =>
      '筛选评分（大于）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter14 =>
      '筛选销量（大于）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter15 =>
      '筛选价格（大于）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter16 =>
      '筛选作品时长（小于）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter17 =>
      '筛选作品时长（大于）';

  @override
  String widgetsHistoryPanelText3(String value) {
    return '已删除「$value」';
  }

  @override
  String get playbackSpeed => '倍速';

  @override
  String get playbackSpeedDescription => '切换播放速度，保持音调';

  @override
  String get playbackSpeedEntry => '显示倍速入口';

  @override
  String get playbackSpeedEntryDescription => '在播放器显示倍速控制，关闭后恢复 1×';

  @override
  String get audioChannels => '声道';

  @override
  String get audioChannelsDescription => '反转左右声道，或合并后双耳播放相同声音';

  @override
  String get audioChannelsOriginal => '原始声道';

  @override
  String get audioChannelsSwap => '左右反转';

  @override
  String get audioChannelsMerge => '声道合并';

  @override
  String get widgetsInputRowHintText => '搜索 RJ 号、作品名、声优…';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get dataExport => '匯出本機資料';

  @override
  String get dataImport => '匯入本機資料';

  @override
  String get dataScope => '收藏、歌單、黑名單、歷史與偏好；不含下載、歌詞庫、帳號密碼和金鑰。';

  @override
  String get dataImportConfirm => '將覆蓋備份範圍內的本機資料。匯入前會保留一份本機副本，目前播放不受影響。';

  @override
  String get dataExportDone => '資料已匯出';

  @override
  String get dataImportDone => '資料已匯入';

  @override
  String get dataOperationFailed => '操作失敗，請重試';

  @override
  String get backupInvalid => '備份格式無效、版本不相容或檔案已損壞';

  @override
  String get backupTooLarge => '備份超過 16 MB 上限';

  @override
  String get webdavTitle => 'WebDAV 雲端同步';

  @override
  String get webdavUrl => '伺服器位址';

  @override
  String get webdavUsername => '帳號';

  @override
  String get webdavPassword => '應用程式密碼';

  @override
  String get webdavFolder => '同步資料夾';

  @override
  String get webdavAuto => '每小時自動同步';

  @override
  String get webdavAutoHint => '應用程式執行期間每小時檢查；回到前景時補查。無變化不會上傳。';

  @override
  String get webdavTest => '測試連線';

  @override
  String get webdavTestDone => '連線正常，測試檔案已刪除';

  @override
  String get webdavSyncNow => '立即同步';

  @override
  String get webdavUploadOverwrite => '上傳本機資料覆蓋雲端';

  @override
  String get webdavDownloadOverwrite => '使用雲端資料覆蓋本機';

  @override
  String get webdavMergeData => '合併本機與雲端資料';

  @override
  String get webdavMergeHint => '收藏、黑名單、歌單和歷史去重合併，設定衝突保留本機。';

  @override
  String get webdavSyncDone => '同步完成';

  @override
  String get webdavNever => '尚未同步';

  @override
  String get webdavSyncing => '正在同步…';

  @override
  String get webdavConflict => '本機和雲端都有變更，請選擇保留的版本';

  @override
  String get webdavUseLocal => '保留本機';

  @override
  String get webdavUseCloud => '使用雲端';

  @override
  String get webdavConflictConfirm => '所選版本將覆蓋另一端的資料。使用雲端前會保留本機副本。';

  @override
  String get webdavInvalidConfig => '請填寫 HTTPS 位址、帳號、應用程式密碼及單層資料夾名稱';

  @override
  String get webdavAuthError => '驗證失敗，請檢查帳號和應用程式密碼';

  @override
  String get webdavTimeout => '連線逾時，請稍後重試';

  @override
  String get webdavNetworkError => '網路連線失敗，請檢查網路及伺服器位址';

  @override
  String get webdavRateLimited => '伺服器請求受限，請稍後重試';

  @override
  String get webdavRequestFailed => '同步失敗，請檢查伺服器設定後重試';

  @override
  String get webdavNoEtag => '伺服器未提供可用的 ETag，無法安全覆蓋雲端檔案';

  @override
  String get webdavNoBackup => '雲端尚無備份';

  @override
  String get webdavCleanupFailed => '測試檔案清理失敗，請檢查伺服器連線';

  @override
  String get webdavBusy => '正在處理資料，請稍候';

  @override
  String get appName => 'Kikoeta';

  @override
  String get playbackShortcuts => '快捷鍵設定';

  @override
  String get dictationQueueTitle => '聽寫翻譯佇列';

  @override
  String get dictationQueueClear => '清空清單';

  @override
  String get dictationQueueEmpty => '暫無任務';

  @override
  String dictationQueueTracks(String count) {
    return '$count 個音訊檔案';
  }

  @override
  String dictationQueueActions(String name) {
    return '你想對 $name 執行的操作';
  }

  @override
  String get dictationQueueJump => '插隊';

  @override
  String get dictationQueuePending => '待處理';

  @override
  String get dictationQueueRunning => '處理中';

  @override
  String get dictationQueueCompleted => '已完成';

  @override
  String get dictationQueueFailed => '失敗';

  @override
  String get dictationQueueCancelled => '已取消';

  @override
  String get dictationQueueDrag => '拖動調整待處理順序';

  @override
  String dictationQueueProcessing(String name) {
    return '開始處理佇列批次：$name';
  }

  @override
  String get invertSelection => '反選';

  @override
  String get traditionalChinese => '繁體中文';

  @override
  String get home => '首頁';

  @override
  String get favorites => '收藏';

  @override
  String get more => '更多';

  @override
  String get voiceActor => '聲優';

  @override
  String get circle => '社團';

  @override
  String get tag => '標籤';

  @override
  String get retry => '重試';

  @override
  String get advancedFilterPageBuildText => '進階篩選';

  @override
  String get advancedFilterPageBuildContentText => '暫無資料';

  @override
  String get advancedFilterPageBuildContentText2 => '沒有符合的參數';

  @override
  String advancedFilterPageBuildSearchFieldHintText(String placeholder) {
    return '搜尋$placeholder…';
  }

  @override
  String get add => '新增';

  @override
  String get cancel => '取消';

  @override
  String get blacklistPageTypeLabelsTypeLabels => 'RJ號';

  @override
  String get blacklist => '黑名單';

  @override
  String get blacklistPageResultText => '新增黑名單';

  @override
  String get blacklistPageResultHintText => '要遮蔽的 RJ 號 / 名稱';

  @override
  String get blacklistPageBuildText => '暫無黑名單條目\n黑名單中的作品不會出現在首頁與搜尋';

  @override
  String get local => '本機';

  @override
  String get network => '網路';

  @override
  String get password => '密碼';

  @override
  String get dictationTranslationPageWorkCardTitle => '作品';

  @override
  String get username => '使用者名稱';

  @override
  String get dictationTranslationPageWorkCardText => '取消任務';

  @override
  String get dictationTranslationPageInitStateText => '等待開始';

  @override
  String get dictationTranslationPageTestConnectionToast => '連線成功';

  @override
  String get dictationTranslationPageLogCardTitle => '執行紀錄';

  @override
  String get dictationTranslationPageStartUpdate => '任務失敗';

  @override
  String get dictationTranslationPageBuildText => '聽寫翻譯';

  @override
  String get dictationTranslationPageConnectionCardTitle => '服務連線';

  @override
  String get dictationTranslationPageConnectionCardInputDecoration => '服務位址';

  @override
  String get dictationTranslationPageConnectionCardTooltip => '顯示密碼';

  @override
  String get dictationTranslationPageConnectionCardTooltip2 => '隱藏密碼';

  @override
  String get testConnection => '測試連線';

  @override
  String get dictationTranslationPageProgressCardTitle => '聽寫進度';

  @override
  String get dictationTranslationPageStartUpdate2 => '任務已排隊';

  @override
  String get dictationTranslationPageStartUpdate3 => '任務已取消';

  @override
  String get dictationTranslationPageWorkCardTitle2 => '待處理音訊';

  @override
  String get dictationTranslationPageWorkCardText2 => '正在取消…';

  @override
  String get dictationTranslationPageStartUpdate4 => '聽寫翻譯完成';

  @override
  String get dictationTranslationPageSyncCachedResultsUpdate => '快取同步完成';

  @override
  String get dictationTranslationPageConnectionCardText => '使用預設帳密';

  @override
  String get dictationTranslationPageWorkCardText3 => '開始聽寫翻譯';

  @override
  String get dictationTranslationPageStartUpdate5 => '正在寫入歌詞庫';

  @override
  String dictationTranslationPageStartAppendLog(String error) {
    return '錯誤：$error';
  }

  @override
  String get dictationTranslationPageConnectionCardInputDecoration2 =>
      '本機服務位址（固定）';

  @override
  String get dictationTranslationPageConnectionCardText2 => 'Android裝置僅支援網路連線';

  @override
  String dictationTranslationPageTestConnectionToast2(String error) {
    return '連線失敗：$error';
  }

  @override
  String dictationTranslationPageCancelToast(String error) {
    return '取消失敗：$error';
  }

  @override
  String get dictationTranslationPageConnectionCardText3 => '前往 GitHub 下載';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog(String error) {
    return '快取同步失敗：$error';
  }

  @override
  String dictationTranslationPageStartToast(String error) {
    return '聽寫翻譯失敗：$error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast(String skipped) {
    return '，略過 $skipped 個重複項目';
  }

  @override
  String get dictationTranslationPageStartUpdate6 => '正在連線 kikoeta-transl';

  @override
  String get dictationTranslationPageStartException => 'kikoeta-transl 任務失敗';

  @override
  String get dictationTranslationPageBuildTooltip => '同步 kikoeta-transl 快取';

  @override
  String get dictationTranslationPageConnectionCardText4 =>
      '尚未安裝 kikoeta-transl？';

  @override
  String get dictationTranslationPageTestConnectionFormatException =>
      'kikoeta-transl 服務未就緒';

  @override
  String get dictationTranslationPageLogCardSelectableText =>
      '等待 kikoeta-transl 紀錄…';

  @override
  String get dictationTranslationPageStartToast2 => '請從作品詳情頁的更多選項進入並啟動聽寫翻譯';

  @override
  String get dictationTranslationPageStartToast3 => '請返回作品詳情頁勾選需要聽寫翻譯的媒體檔案';

  @override
  String get dictationTranslationPageStartFormatException =>
      'kikoeta-transl 未回傳任務編號';

  @override
  String get dictationTranslationPageOpenKikoetaTranslDownloadToast =>
      '無法開啟 kikoeta-transl 專案頁面';

  @override
  String get dictationTranslationPageServiceFormatException =>
      'kikoeta-transl 使用者名稱不能包含冒號';

  @override
  String get dictationTranslationPageCancelAppendLog =>
      '已向 kikoeta-transl 傳送取消請求';

  @override
  String get dictationTranslationPageServiceFormatException2 =>
      '請輸入 kikoeta-transl 使用者名稱和密碼';

  @override
  String get dictationTranslationPageSyncCachedResultsToast2 =>
      'kikoeta-transl 沒有可同步的快取結果';

  @override
  String get dictationTranslationPageStartFormatException2 =>
      'kikoeta-transl 未回傳可用的 LRC 檔案';

  @override
  String dictationTranslationPageProgressCardText(String savedFiles) {
    return ' · 已入庫 $savedFiles';
  }

  @override
  String dictationTranslationPageStartToast4(String missing) {
    return '有 $missing 個音訊檔案缺少下載位址，請登入作品伺服器後重試';
  }

  @override
  String dictationTranslationPageStartAppendLog2(String jobId, String length) {
    return '任務 $jobId 已建立，共 $length 個音訊檔案';
  }

  @override
  String get dictationTranslationPageConnectionCardText5 =>
      '下載並啟動 kikoeta-transl 後，即可使用本機或網路聽寫翻譯。';

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog2(
    String jobId,
    String name,
    String error,
  ) {
    return '同步 $jobId/$name 失敗：$error';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog3(
    String saved,
    String skipped,
    String failed,
  ) {
    return '快取同步完成：寫入 $saved，略過重複項目 $skipped，失敗 $failed';
  }

  @override
  String dictationTranslationPageSyncCachedResultsAppendLog4(String length) {
    return '開始同步 $length 條 kikoeta-transl 快取任務';
  }

  @override
  String get dictationTranslationPageWorkCardText4 =>
      '要建立任務，請開啟作品詳情頁，在右上角「更多」中選擇「聽寫翻譯」。未勾選檔案時會自動比對，優先選擇無效果音版本並保留獨立特典；也可先手動勾選指定檔案。';

  @override
  String get dictationAutoSelectionHint =>
      '已自動比對：優先無效果音，保留獨立特典。請檢查媒體清單；需要調整時，可返回作品頁手動勾選。';

  @override
  String dictationTranslationPageStartAppendLog3(String rj, String savedFiles) {
    return '已按 $rj 寫入 $savedFiles 個歌詞檔案';
  }

  @override
  String dictationTranslationPageWorkCardText5(String rj, String length) {
    return '$rj · 已從作品詳情頁勾選 $length 個媒體檔案';
  }

  @override
  String dictationTranslationPageStartToast5(String savedFiles, String rj) {
    return '完成：$savedFiles 個歌詞已寫入 $rj 歌詞庫';
  }

  @override
  String dictationTranslationPageSyncCachedResultsToast3(
    String saved,
    String value,
  ) {
    return '同步完成：寫入 $saved 個歌詞$value';
  }

  @override
  String dictationTranslationPageProgressCardText2(
    String finishedFiles,
    String length,
    String value,
  ) {
    return '已處理 $finishedFiles / $length$value';
  }

  @override
  String get selectMultiple => '多選';

  @override
  String get selectAll => '全選';

  @override
  String get downloads => '下載';

  @override
  String get downloading => '下載中';

  @override
  String get downloadsPageStatusStatus => '等待中';

  @override
  String get downloadsPageStatusStatus2 => '已完成';

  @override
  String get downloadsPageStatusStatus3 => '已暫停';

  @override
  String get exitSelection => '結束多選';

  @override
  String get downloadsPageBuildTooltip => '關閉搜尋';

  @override
  String get downloadsPageStatusStatus4 => '下載失敗';

  @override
  String get downloadsPageStatusStatus5 => '等待下載';

  @override
  String get deselectAll => '取消全選';

  @override
  String get downloadsPageBuildText => '下載檔案';

  @override
  String get downloadsPageBuildText2 => '暫無下載音聲';

  @override
  String get downloadsPageBuildText3 => '完整檔案結構';

  @override
  String get downloadsPageBuildTooltip2 => '刪除選取的作品';

  @override
  String get downloadsPageBuildText4 => '暫無下載檔案';

  @override
  String get downloadsPageBuildTooltip3 => '搜尋已下載作品';

  @override
  String get downloadsPageBuildTooltip4 => '開始/暫停全部';

  @override
  String get downloadsPageBuildTooltip5 => '刪除選取的下載紀錄';

  @override
  String get downloadsPageFileNameFileName => '暫無正在下載的檔案';

  @override
  String downloadsPageProgressTextText(String percent) {
    return '下載中 $percent%';
  }

  @override
  String downloadsPageBuildText5(String value) {
    return '載入更多（$value）';
  }

  @override
  String downloadsPageBuildText6(String rj, String downloaded, String length) {
    return '$rj  $downloaded/$length 個檔案已下載';
  }

  @override
  String downloadsPageStatusStatus6(String round) {
    return '下載中 $round%';
  }

  @override
  String get postponed => '擱置';

  @override
  String get remove => '移除';

  @override
  String get all => '全部';

  @override
  String get wantToListen => '想聽';

  @override
  String get listening => '在聽';

  @override
  String get listened => '聽過';

  @override
  String get replay => '重聽';

  @override
  String get favoritesPageReviewFilterButtonTooltip => '進度篩選';

  @override
  String get favoritesPageLabelLabel => '取消收藏';

  @override
  String get loading => '載入中…';

  @override
  String get favoritesPageReviewSortDropdownTooltip => '排序方式';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels => '評論數量';

  @override
  String get favoritesPageBodyText => '點選重試';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels2 => '銷售數量';

  @override
  String get favoritesPageBuildTooltip => '切換歌單';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels3 => '發售日期';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels4 => '我的評價';

  @override
  String get favoritesPageReviewSortLabelsReviewSortLabels5 => '標記時間';

  @override
  String get ageRating => '年齡分級';

  @override
  String get favoritesPageInputText => '新增作品';

  @override
  String get favoritesPageBodyText2 => '已顯示全部';

  @override
  String get favoritesPageLabelLabel2 => '移出播放清單';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip => '複製分享連結';

  @override
  String favoritesPageAddWorksByRjToast(String e) {
    return '新增失敗：$e';
  }

  @override
  String get shareLinkCopied => '已複製分享連結';

  @override
  String get favoritesPageRemoveSelectedWorksToast => '無法取得作品編號';

  @override
  String get favoritesPageBodyText3 => '還沒有收藏的作品';

  @override
  String favoritesPageRemoveCurrentLikedPlaylistToast(String e) {
    return '取消收藏失敗：$e';
  }

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip2 => '取消收藏該播放清單';

  @override
  String get favoritesPageBodyText4 => '該播放清單還沒有作品';

  @override
  String get favoritesPagePlaylistHeaderActionsTooltip3 => '按 RJ 號新增作品';

  @override
  String get favoritesPageAddWorksByRjToast2 => '沒有識別到 RJ 號';

  @override
  String favoritesPageSelectionBarText(String count) {
    return '已選 $count 項';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast2(String label, String e) {
    return '$label失敗：$e';
  }

  @override
  String get favoritesPageBodyText5 => 'SFW 模式下不顯示收藏內容';

  @override
  String get favoritesPageBodyText6 => '載入失敗，請確認已在設定中登入';

  @override
  String get favoritesPageOkText => '確定從我的播放清單中移除該歌單嗎？';

  @override
  String favoritesPageAddWorksByRjToast3(String length) {
    return '已新增 $length 個作品';
  }

  @override
  String favoritesPageOkText2(String count, String label) {
    return '確定將 $count 個作品$label嗎？';
  }

  @override
  String favoritesPageRemoveSelectedWorksToast3(String label, String length) {
    return '已$label $length 個作品';
  }

  @override
  String get favoritesPageInputHintText =>
      '輸入 RJ 號，可一次填多個\n例如：RJ01367541 RJ01417842\n支援換行、空格或逗號分隔';

  @override
  String get clear => '清空';

  @override
  String get historyPageEntryWorkTitle => '未知作品';

  @override
  String get playHistory => '播放歷史';

  @override
  String get historyPageBuildText => '暫無播放歷史';

  @override
  String get historyPageBuildText2 => 'SFW 模式下不顯示播放歷史';

  @override
  String historyPageFmtTimeText(String padLeft, String padLeft2) {
    return '今天 $padLeft:$padLeft2';
  }

  @override
  String historyPageFmtTimeText2(
    String month,
    String day,
    String padLeft,
    String padLeft2,
  ) {
    return '$month月$day日 $padLeft:$padLeft2';
  }

  @override
  String get homePageServerLabelText => '自建';

  @override
  String get homePageLabelsLabels => '熱門';

  @override
  String get homePageLabelsLabels2 => '推薦';

  @override
  String get homePageSortLabelsSortLabels => '整體評價';

  @override
  String get homePageSortLabelsSortLabels2 => '收錄時間';

  @override
  String get homePageSortLabelsSortLabels3 => '銷售價格';

  @override
  String get homePageEmptyHintText => '暫無作品';

  @override
  String get homePageSearchResultsViewText => '搜尋中…';

  @override
  String get homePageEmptyHintText2 => '正在載入…';

  @override
  String get homePageGridText => '已顯示全部作品';

  @override
  String get homePageEmptyHintText3 => '點選任意處重試';

  @override
  String get homePageSearchResultsViewText2 => '沒有找到相關作品';

  @override
  String get homePageSearchResultsViewText3 => '已顯示全部搜尋結果';

  @override
  String get homePageEmptyHintText4 => '目前篩選條件下暫無作品';

  @override
  String get homePageEmptyHintText5 => '無網路連線，請檢查網路或伺服器設定';

  @override
  String get homePageHeaderTooltip => 'SFW 模式已開啟：僅顯示全年齡內容';

  @override
  String get homePageHeaderTooltip2 => '開啟 SFW 模式（僅顯示全年齡內容）';

  @override
  String get save => '儲存';

  @override
  String get loginPageBuildLoginText => '登 入';

  @override
  String get loginPageShowNoAccountText => '關於帳號';

  @override
  String get loginPageShowNoAccountText2 => '我知道了';

  @override
  String get loginPageBuildSiteConfigTooltip => '返回登入';

  @override
  String get loginPageBuildSiteConfigText => '已有站台';

  @override
  String get loginPageBuildSiteConfigHint => '站台密碼';

  @override
  String get loginPageShowProxyDialogLabelText => '代理伺服器';

  @override
  String get loginPageBuildLoginText2 => '我沒有帳號';

  @override
  String get loginPageBuildSiteConfigText2 => '使用該站台';

  @override
  String get loginPageBuildSiteConfigText3 => '新增站台';

  @override
  String get loginPageBuildSiteConfigText4 => '儲存並進入';

  @override
  String get loginPageShowProxyDialogText => '設定網路代理';

  @override
  String get loginPageBuildLoginText3 => '設定自建站台';

  @override
  String get loginPageBuildSiteConfigHint2 => '站台登入帳號';

  @override
  String get loginPageShowProxyDialogToast => '網路代理已啟用';

  @override
  String get loginPageShowProxyDialogToast2 => '網路代理已關閉';

  @override
  String get loginPageBuildLoginHint => 'one 站帳號';

  @override
  String get loginPageLoginToast => '請輸入帳號和密碼';

  @override
  String get loginPageLoginToast2 => '請檢查網路或帳號密碼';

  @override
  String get loginPageShowProxyDialogText2 => '使用 HTTP 代理';

  @override
  String get loginPageBuildLoginText4 => '登入 one 站帳號';

  @override
  String get loginPageShowProxyDialogHelperText => '僅支援 HTTP 代理';

  @override
  String get loginPageBuildSiteConfigHint3 => '別名，如：家庭 NAS';

  @override
  String get loginPageSaveNewSiteToast => '請填寫別名、位址、帳號和密碼';

  @override
  String get loginPageShowProxyDialogHintText => '例如 http://代理位址:連接埠';

  @override
  String get loginPageBuildSiteConfigText5 =>
      '支援 IP+連接埠，如 http://192.168.1.100:3000';

  @override
  String loginPageLoginToast3(String value) {
    return '登入失敗：$value';
  }

  @override
  String get loginPageShowNoAccountText3 =>
      '本專案不提供任何註冊服務。\n\n帳號與密碼需由您自行取得，本專案不提供任何取得管道。\n\n您使用該帳號在本應用程式中取得、播放的任何內容，其所有權與責任均歸屬內容提供者與帳號持有人，本專案對此不承擔任何責任。\n\n帳號資訊僅儲存在本機裝置，不會上傳到任何第三方伺服器。';

  @override
  String get close => '關閉';

  @override
  String get delete => '刪除';

  @override
  String get remote => '遠端';

  @override
  String get continueAction => '繼續';

  @override
  String get online => '線上';

  @override
  String get importAction => '匯入';

  @override
  String get lyricsLibraryPageBuildNavItem => '遠端庫';

  @override
  String get lyricsLibrary => '歌詞庫';

  @override
  String get lyricsLibraryPageBuildNavItem2 => '本機檔案';

  @override
  String get lyricsLibraryPageProceedText => '繼續匯入';

  @override
  String get lyricsLibraryPageImportText => '取消匯入';

  @override
  String get lyricsLibraryPageProgressPhase => '準備匯入';

  @override
  String get lyricsLibraryPageOkText => '深度重新整理';

  @override
  String get lyricsLibraryPageOkText2 => '刪除歌詞';

  @override
  String get lyricsLibraryPageSectionContentText => '選擇資料夾';

  @override
  String get lyricsLibraryPageConfirmedText => '刪除遠端庫';

  @override
  String get lyricsLibraryPageSectionContentText2 => '匯入遠端庫';

  @override
  String get lyricsLibraryPageBuildText => '匯入歌詞庫';

  @override
  String get lyricsLibraryPageBuildLabel => '重新整理歌詞庫';

  @override
  String get lyricsLibraryPageBuildTooltip => '搜尋歌詞庫';

  @override
  String get lyricsLibraryPageBuildText2 => '正在匯入歌詞';

  @override
  String get lyricsLibraryPageImportText2 => '跳過衝突檔案';

  @override
  String get lyricsLibraryPageImportText3 => '覆蓋衝突檔案';

  @override
  String get lyricsLibraryPageOkText3 => '移除遠端作品';

  @override
  String get lyricsLibraryPageProceedText2 => '大型內容匯入';

  @override
  String get lyricsLibraryPageImportText4 => '發現匯入衝突';

  @override
  String get lyricsLibraryPageRemoteSourceListTooltip => '只重新整理此遠端庫';

  @override
  String get lyricsLibraryPageOkText4 => '刪除歌詞庫作品';

  @override
  String get lyricsLibraryPageBuildLabel2 => '重新整理全部遠端庫';

  @override
  String get lyricsLibraryPageBuildText3 => '正在準備檔案…';

  @override
  String get lyricsLibraryPageSelectionDialogTitle => '選擇歌詞資料夾';

  @override
  String get lyricsLibraryPageSectionContentText3 => '正在連線並同步';

  @override
  String get lyricsLibraryPageSearchFieldHintText => '搜尋作品 ID';

  @override
  String lyricsLibraryPageImportText5(String e) {
    return '匯入失敗：$e';
  }

  @override
  String get lyricsLibraryPageRemoteSourceListText => '尚未匯入遠端庫';

  @override
  String get lyricsLibraryPageBuildHint => '長按執行深度重新整理';

  @override
  String get lyricsLibraryPageBuildText4 => '正在統計歌詞檔案';

  @override
  String get lyricsLibraryPageScanProgressPhase => '正在檢查檔案衝突';

  @override
  String get lyricsLibraryPageResultDialogTitle => '選擇 ZIP 檔案';

  @override
  String get lyricsLibraryPageSectionContentText4 => '選擇 ZIP 壓縮檔';

  @override
  String get lyricsLibraryPageBuildText5 => '暫時無法統計歌詞檔案';

  @override
  String lyricsLibraryPageRefreshText(String error) {
    return '重新整理失敗：$error';
  }

  @override
  String get lyricsLibraryPageShowFilesText => '沒有可用的歌詞或字幕檔案';

  @override
  String get lyricsLibraryPageBuildText6 => '暫無資料，點選右上角匯入';

  @override
  String get lyricsLibraryPageShowFilesText2 => '載入歌詞檔案失敗，請重試';

  @override
  String lyricsLibraryPageReorderSetState(String error) {
    return '調整優先順序失敗：$error';
  }

  @override
  String get lyricsLibraryPageSectionContentLabelText => 'HTTP / HTTPS 位址';

  @override
  String get lyricsLibraryPageBuildHint2 => '同步所有已匯入遠端庫的作品索引';

  @override
  String get lyricsLibraryPageImportText6 => '所選資料夾裡沒有歌詞或字幕檔案';

  @override
  String get lyricsLibraryPageSectionContentText5 => '選擇要匯入的歌詞檔案或壓縮檔。';

  @override
  String get lyricsLibraryPageSectionContentText6 => '輸入開啟了歌詞庫廣播的裝置位址。';

  @override
  String lyricsLibraryPageRefreshOneSetState(String url, String error) {
    return '重新整理 $url 失敗：$error';
  }

  @override
  String lyricsLibraryPageRemoveRemoteLibrarySetState(
    String url,
    String error,
  ) {
    return '刪除 $url 失敗：$error';
  }

  @override
  String lyricsLibraryPageBuildText7(String directoryCount) {
    return '$directoryCount 個目錄';
  }

  @override
  String lyricsLibraryPageBuildText8(String length) {
    return '$length 個';
  }

  @override
  String get lyricsLibraryPageBuildText9 => '暫無遠端作品，點選右上角匯入並連線遠端庫';

  @override
  String lyricsLibraryPageOkText5(String workId) {
    return '確定移除 $workId 的遠端作品索引嗎？';
  }

  @override
  String lyricsLibraryPageOkText6(String workId) {
    return '確定刪除 $workId 的全部歌詞檔案嗎？';
  }

  @override
  String get lyricsLibraryPageOkText7 => '將刪除沒有歌詞或字幕檔案的作品目錄，是否繼續？';

  @override
  String get lyricsLibraryPageSectionContentText7 => '已匯入的遠端庫（從上到下優先順序遞減，拖動排序）';

  @override
  String lyricsLibraryPageRemoteSourceListText2(String value) {
    return '優先順序 $value · 長按刪除';
  }

  @override
  String lyricsLibraryPageConfirmedText2(String url) {
    return '確定移除遠端庫 $url 及其已同步的作品索引嗎？';
  }

  @override
  String get lyricsLibraryPageSectionContentText8 =>
      '匯入時只同步作品索引；播放時再下載該作品的全部歌詞。';

  @override
  String get lyricsLibraryPageProceedText3 =>
      '偵測到大型壓縮檔或資料夾，匯入過程可能需要較長時間，請耐心等待。';

  @override
  String lyricsLibraryPageOkText8(String length) {
    return '確定刪除選取的 $length 個作品目錄嗎？';
  }

  @override
  String lyricsLibraryPageImportText7(String length) {
    return '偵測到 $length 個已存在檔案，如何處理？';
  }

  @override
  String lyricsLibraryPageOkText9(String length) {
    return '確定移除選取的 $length 個遠端作品索引嗎？';
  }

  @override
  String lyricsLibraryPageBuildText10(String fileCount, String value) {
    return '$fileCount 個歌詞/字幕檔案 · $value';
  }

  @override
  String get morePageBuildRow => '歌單';

  @override
  String get settings => '設定';

  @override
  String get morePageBuildRow2 => '隨心聽';

  @override
  String morePageBuildText(String server) {
    return '伺服器：$server';
  }

  @override
  String get morePageOpenRandomWorkText => '目前條件下沒有可播放的作品';

  @override
  String get morePageOpenRandomWorkText2 => '隨心聽載入失敗，請稍後重試';

  @override
  String get playerPageShowLyricSettingsText => '歸零';

  @override
  String get back => '返回';

  @override
  String get seekBackward => '快退';

  @override
  String get seekForward => '快進';

  @override
  String get playerPageUtilsUtil => '定時';

  @override
  String get equalizer => '均衡器';

  @override
  String get playerPageUtilsUtil2 => '定時中';

  @override
  String get playerPageShowLyricSettingsText2 => '繁簡互轉';

  @override
  String get autoMatch => '自動比對';

  @override
  String get workDetails => '作品詳情';

  @override
  String get playlist => '播放清單';

  @override
  String get sleepTimer => '定時關閉';

  @override
  String get playerPageWideLyricsPanelText => '暫無歌詞';

  @override
  String get playerPageTopBarText => '正在播放';

  @override
  String get desktopLyrics => '桌面歌詞';

  @override
  String get playerPagePlayModeLabelText => '循環播放';

  @override
  String get playerPagePlayModeLabelText2 => '單曲循環';

  @override
  String get playerPagePlayModeLabelText3 => '依序播放';

  @override
  String get playerPageShowLyricSettingsText3 => '歌詞設定';

  @override
  String get playerPageShowLyricSettingsText4 => '字幕偏移';

  @override
  String get simplifiedToTraditional => '簡 → 繁';

  @override
  String get traditionalToSimplified => '繁 → 簡';

  @override
  String get playerPageShowQueueText => '播放清單為空';

  @override
  String get playerPageResDialogTitle => '選擇歌詞檔案';

  @override
  String get playerPagePickOnlineLyricText => '選擇線上歌詞';

  @override
  String get playerPageBuildText => '暫無播放內容';

  @override
  String get playerPageShowLyricSettingsTitle => '選擇離線歌詞';

  @override
  String get playerPagePickOnlineLyricToast => '未找到線上歌詞';

  @override
  String get playerPageShowLyricSettingsTitle2 => '選擇歌詞庫歌詞';

  @override
  String get playerPageLoadOnlineLyricToast => '該歌詞無法解析';

  @override
  String get playerPageLyricsPanelText => '正在載入歌詞…';

  @override
  String get playerAlreadyFirstTrack => '已經是第一首';

  @override
  String get playerAlreadyLastTrack => '已經是最後一首';

  @override
  String get playerPageNextToast => '已播放完播放清單';

  @override
  String get playerPageOpenCurrentToast => '檔案串流需登入後可用';

  @override
  String get playerPageShowLyricSettingsSub => '歌詞庫中沒有該作品';

  @override
  String get playerPageOpenMediaToast => '開啟媒體逾時，請重試';

  @override
  String get playerPageLibraryAutoTileText => '從歌詞庫自動比對歌詞';

  @override
  String get playerPageOpenMediaToast2 => '開啟失敗，正在重試…';

  @override
  String get playerPageFriendlyPlayErrorText => '媒體串流代理異常，請重試';

  @override
  String get playerLoudnessBoostLabel => '響度提升';

  @override
  String get playerPageVolumeControlTooltip => '響度提升（上限 120）';

  @override
  String get playerPageShowLyricSettingsSub2 => '從本機選擇歌詞或字幕檔案';

  @override
  String get playerPageInitStateToast => '網路波動，正在自動重新連線…';

  @override
  String get playerPagePickLibraryLyricToast => '歌詞庫中沒有該作品的歌詞';

  @override
  String get playerPageOpenMediaToast3 => '開啟媒體逾時，正在重試…';

  @override
  String get playerPageShowLyricSettingsSub3 => '僅顯示目前作品的歌詞檔案';

  @override
  String get playerPageCheckSleepToast => '已停止播放，系統資源已釋放';

  @override
  String get playerPagePickOnlineLyricSub => '按曲目名與中文優先自動選擇';

  @override
  String get playerPageFriendlyPlayErrorText2 => '伺服器回傳錯誤，請稍後重試';

  @override
  String get playerPageVolumeControlTooltip2 => '啟用響度提升（上限 120）';

  @override
  String get playerPageFriendlyPlayErrorText3 => '登入已失效，請重新登入後重試';

  @override
  String get playerPagePickOfflineLyricToast => '檔案中沒有可讀取的帶時間軸歌詞';

  @override
  String get playerPageFriendlyPlayErrorText4 => '無法連線媒體串流，請檢查網路後重試';

  @override
  String get playerPageVolumeControlTooltip3 => '響度提升 Plus（上限 200）';

  @override
  String get playerPageToggleDesktopLyricsToast => '未授予懸浮視窗權限，無法顯示桌面歌詞';

  @override
  String playerPageSeekCircleMessage(String label, String seconds) {
    return '$label $seconds 秒';
  }

  @override
  String get playerPageLibraryAutoTileText2 => '優先比對本機歌詞，找不到時使用線上歌詞';

  @override
  String playerPageShowQueueText2(String length) {
    return '播放清單（$length）';
  }

  @override
  String playerPageInitStateToast2(String friendlyPlayError) {
    return '播放失敗：$friendlyPlayError';
  }

  @override
  String playerPageOpenMediaToast4(String friendlyPlayError) {
    return '無法開啟媒體串流：$friendlyPlayError';
  }

  @override
  String get playlistsPageNameText => '建立';

  @override
  String get playlistsPageBuildText => '重新命名';

  @override
  String get playlistsPageBuildText2 => '新增歌單';

  @override
  String get playlistsPageNameHintText => '歌單名稱';

  @override
  String get playlistsPageBuildText3 => '歌單為空';

  @override
  String get playlistsPageHeaderTooltip => '移除作品';

  @override
  String get playlistsPageNameText2 => '重新命名歌單';

  @override
  String get playlistsPageHeaderMessage => '拖動調整作品順序';

  @override
  String get playlistsPageRowMessage => '拖動調整播放順序';

  @override
  String get playlistsPagePlayTrackText => '歌單中沒有可播放的音訊';

  @override
  String get playlistsPageBuildText4 => 'SFW 模式下不顯示歌單';

  @override
  String get playlistsPageBuildText5 => '暫無歌單，點選右下角新增';

  @override
  String get playlistsPageBuildText6 => 'SFW 模式下不顯示歌單內容';

  @override
  String playlistsPageBuildText7(String length) {
    return '$length 個條目';
  }

  @override
  String get playlistsPagePlayTrackText2 => '該音訊缺少可用檔案串流，請從作品詳情重新新增';

  @override
  String get playlistsPageBuildText8 => '拖動標題調整作品順序，拖動媒體調整播放順序';

  @override
  String get playlistsPageBuildText9 => '長按標題調整作品順序，長按媒體調整播放順序';

  @override
  String playlistsPageHeaderText(String length) {
    return '$length 個音訊';
  }

  @override
  String get traditionalChineseShort => '繁中';

  @override
  String get englishLanguage => '英語';

  @override
  String get simplifiedChineseShort => '簡中';

  @override
  String get settingsPageHealthBadgeStartsWith => '正常';

  @override
  String get settingsPageSectionsMiniBtn => '偵測';

  @override
  String get settingsPageSectionsMiniBtn2 => '設定';

  @override
  String get settingsPageLockRowText => '解鎖';

  @override
  String get play => '播放';

  @override
  String get lyrics => '歌詞';

  @override
  String get settingsPageSectionsSection => '曲目';

  @override
  String get settingsPageOnVersionTapText => '好吧';

  @override
  String get settingsPageSectionsSection2 => '資料與網路';

  @override
  String get settingsPageSectionsSection3 => '外觀';

  @override
  String get settingsPageSectionsText => '主題';

  @override
  String get settingsPageSectionsText2 => '淺色';

  @override
  String get settingsPageSectionsText3 => '深色';

  @override
  String get settingsPageSectionsText4 => '重置';

  @override
  String get settingsPageSectionsSection4 => '關於';

  @override
  String get settingsPageSectionTitleText => '隱私';

  @override
  String get settingsPageSectionsTitle => '版本';

  @override
  String get settingsPageSectionsTitle2 => '原始碼';

  @override
  String get settingsPageLockRowSub => '未鎖定';

  @override
  String get settingsPageSectionsMiniBtn3 => '去關閉';

  @override
  String get settingsPageShortcutConflictText => '下一曲';

  @override
  String get settingsPageShortcutConflictText2 => '上一曲';

  @override
  String get settingsPageSectionsLockRow => '桌面端';

  @override
  String get settingsPageSectionsMiniBtn4 => '已關閉';

  @override
  String get settingsPageShortcutLabelText => '未設定';

  @override
  String get translationEngine => '翻譯引擎';

  @override
  String get settingsPageSectionsLabel => '字型顏色';

  @override
  String get settingsPageSectionsLabel2 => '描邊顏色';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get settingsPageAutoCheckSetState => '偵測中…';

  @override
  String get settingsPageSectionsTitle3 => '快退秒數';

  @override
  String get interfaceLanguage => '介面語言';

  @override
  String get settingsPageSectionsTitle4 => '快進秒數';

  @override
  String get settingsPageAiModelInputLabelText => '模型名稱';

  @override
  String get settingsPageShortcutLabelText2 => '方向鍵→';

  @override
  String get chineseConversion => '繁簡轉換';

  @override
  String get settingsPageSectionsText5 => '描邊寬度';

  @override
  String get settingsPageSectionsSection5 => '帳號設定';

  @override
  String get settingsPageSectionsText6 => '字型大小';

  @override
  String get settingsPageShortcutLabelText3 => '方向鍵←';

  @override
  String get settingsPageBuildText => '完全重置';

  @override
  String get settingsPageSectionsSwitchRow => '智慧路徑';

  @override
  String get settingsPageAutoCheckSetState2 => '連線失敗';

  @override
  String get followSystem => '跟隨系統';

  @override
  String get settingsPageOpenRepoToast => '開啟失敗';

  @override
  String get settingsPageEditAudioTypePreferenceText => '恢復預設';

  @override
  String get settingsPageSectionsText7 => '介面縮放';

  @override
  String get settingsPageBuildText2 => '確定重置';

  @override
  String get settingsPageSectionsTitle5 => '檢查更新';

  @override
  String get targetLanguage => '目標語言';

  @override
  String get languageAndTranslation => '語言與翻譯';

  @override
  String get settingsPageSectionsSwitchRow2 => '歌詞庫廣播';

  @override
  String get settingsPageSectionsSwitchRow3 => '剪貼簿偵測';

  @override
  String get settingsPageShortcutConflictText3 => '播放/暫停';

  @override
  String get settingsPageSectionsTitle6 => '快退快捷鍵';

  @override
  String get settingsPageSectionsSwitchRow4 => '效果音偏好';

  @override
  String get settingsPageSectionsTitle7 => '快進快捷鍵';

  @override
  String get settingsPageOnVersionTapText2 => '開發者模式';

  @override
  String get settingsPageSectionsSub => '未設定帳號';

  @override
  String get settingsPageRowSub => '點選進入設定';

  @override
  String get settingsPageSectionsTitle8 => '音訊類型偏好';

  @override
  String get settingsPageSectionsText8 => '偵測模型清單';

  @override
  String get settingsPageProxySettingsTooltip => '清空代理位址';

  @override
  String get settingsPageSectionsTitle9 => '上一曲快捷鍵';

  @override
  String get settingsPageSectionsTitle10 => '停用電池最佳化';

  @override
  String get settingsPageSectionsSwitchRow5 => '忽略音訊焦點';

  @override
  String get settingsPageSectionsSwitchRow6 => '自動檢查更新';

  @override
  String get settingsPageMediaCacheLimitRowText => '媒體快取上限';

  @override
  String get settingsPageSectionsTitle11 => '下一曲快捷鍵';

  @override
  String get translationTargetLanguage => '翻譯目標語言';

  @override
  String get followInterfaceLanguage => '跟隨介面語言';

  @override
  String get settingsPageSectionsText9 => '新增自建站台';

  @override
  String get settingsPageSectionsLockRow2 => 'Android（橫向）';

  @override
  String get settingsPageSectionsLockRow3 => 'Android（直向）';

  @override
  String get settingsPageSectionsTitle12 => '完全重置軟體';

  @override
  String get settingsPageProxySettingsSwitchRow => 'HTTP 代理';

  @override
  String get settingsPageAiModelInputTooltip => '選擇已偵測模型';

  @override
  String get settingsPageSectionsTitle13 => '恢復預設快捷鍵';

  @override
  String get settingsPageSectionsSwitchRow7 => '不記憶播放進度';

  @override
  String get settingsPageSectionsSection6 => '歌詞與桌面歌詞';

  @override
  String settingsPageSectionsToast(String e) {
    return '連線失敗：$e';
  }

  @override
  String get settingsPageSectionsToast2 => '正在測試連線…';

  @override
  String get settingsPageSectionsSwitchRow8 => '拔出耳機自動暫停';

  @override
  String get settingsPageSectionsTitle14 => '播放/暫停快捷鍵';

  @override
  String get settingsPageSectionsSub2 => '手動檢查更新服務';

  @override
  String get settingsPageSectionsSwitchRow9 => '歌詞視窗保持最上層';

  @override
  String get settingsPageAiModelInputTooltip2 => '請先偵測模型清單';

  @override
  String get settingsPageProxySettingsHelperText => '留空將不使用代理';

  @override
  String get settingsPageLabelsLabels => 'OpenAI 相容';

  @override
  String get settingsPageSectionsSwitchRow10 => '關閉視窗後縮小至系統匣';

  @override
  String get settingsPageDetectOpenAiModelsToast => '正在取得模型清單…';

  @override
  String get settingsPageSectionsSwitchRow11 => '不顯示通知欄媒體卡片';

  @override
  String get settingsPageSectionsSub3 => '歌詞中文部分自動轉換';

  @override
  String get sourceAndTargetLanguage => '來源語言 / 目標語言';

  @override
  String get settingsPageDetectOpenAiModelsToast2 => '請先填寫 API 位址';

  @override
  String get settingsPageSectionsSwitchRow12 => '定時關閉後釋放系統資源';

  @override
  String get settingsPagePlaybackShortcutRowSub => '播放器頁取得焦點時生效';

  @override
  String get settingsPageAiModelInputHintText => '輸入模型名或從清單選擇';

  @override
  String get settingsPageSectionsSub4 => '防止背景播放被系統中斷';

  @override
  String get settingsPageStatusStatus => '已儲存位址，開啟後生效';

  @override
  String settingsPageLockRowTitle(String label) {
    return '$label 歌詞鎖定';
  }

  @override
  String settingsPageDetectOpenAiModelsToast3(String e) {
    return '模型清單取得失敗：$e';
  }

  @override
  String get settingsPageSectionsToast3 => '正在測試 DeepL…';

  @override
  String get settingsPageSectionsSwitchRow13 => '優先進入包含效果音的目錄';

  @override
  String settingsPageSectionsToast4(String e) {
    return '關閉歌詞庫廣播失敗：$e';
  }

  @override
  String settingsPageSectionsToast5(String e) {
    return '無法開啟歌詞庫廣播：$e';
  }

  @override
  String get settingsPageSectionsSwitchRow14 => '開啟作品自動進入最佳目錄';

  @override
  String settingsPageSectionsToast6(String e) {
    return 'DeepL 連線失敗：$e';
  }

  @override
  String get settingsPageSectionsSwitchRow15 => '自動識別複製的 RJ 連結';

  @override
  String get settingsPageSectionsSwitchRow16 => '到點清除鎖定畫面媒體卡片與通知';

  @override
  String get settingsPageSectionsSwitchRow17 => '啟動後 3 秒請求更新服務';

  @override
  String settingsPageSectionsToast7(String r) {
    return 'DeepL 連線正常：$r';
  }

  @override
  String get settingsPageOnVersionTapText3 => '你不會真以為有開發者模式吧？';

  @override
  String get settingsPageProxySettingsHelperText2 => '開啟 HTTP 代理後可編輯';

  @override
  String get settingsPageSectionsSwitchRow18 => '拔出耳機或中斷藍牙連線時自動暫停';

  @override
  String get settingsPageSectionsSwitchRow19 => '與其他應用程式同時播放，互不打斷';

  @override
  String get settingsPageSectionsSwitchRow20 => '播放時不在通知欄顯示媒體卡片';

  @override
  String get settingsPageAiModelInputHintText2 => '例如 gpt-4o-mini';

  @override
  String get settingsPageSectionsSwitchRow21 => '通知欄封面顯示專案 logo';

  @override
  String settingsPageBuildText3(String count) {
    return '確定重置（$count 秒）';
  }

  @override
  String get settingsPageSectionsSub5 => '清除本機全部資料，恢復初始狀態';

  @override
  String get settingsPageSectionsSub6 => '5–60 秒，每次調整 5 秒';

  @override
  String settingsPageEditPlaybackShortcutToast(String conflict) {
    return '該按鍵已用於$conflict';
  }

  @override
  String get settingsPageDetectOpenAiModelsFormatException => '回應未包含 data[].id';

  @override
  String get settingsPageSectionsInput => 'API Key（本機服務可留空）';

  @override
  String get settingsPageConfirmResetText => '已重置：帳號與全部本機資料已清除';

  @override
  String get settingsPageRequestBatteryIgnoreToast => '請在系統設定中允許「忽略電池最佳化」';

  @override
  String get settingsPageStatusStatus2 => '已啟用，請填寫 HTTP 代理位址';

  @override
  String get settingsPageMediaCacheLimitRowText2 => '僅限制線上播放緩衝，不影響下載功能';

  @override
  String get settingsPageSectionsSwitchRow22 => '關閉視窗時停止背景執行並結束程式';

  @override
  String get settingsPageSectionsSub7 => '已加入白名單，背景播放不受省電限制';

  @override
  String get settingsPageSectionsInput2 => 'API 位址 (Base URL)';

  @override
  String get settingsPageSectionsInput3 => 'DeepL 免費版 API Key';

  @override
  String settingsPageSectionsSub8(String asmrUser) {
    return '帳號：$asmrUser';
  }

  @override
  String get settingsPageSectionsSwitchRow23 => '關閉後繼續在背景播放，可從系統匣還原視窗';

  @override
  String get settingsPageSectionsSwitchRow24 => '重啟程式後恢復上次曲目，但從頭開始播放';

  @override
  String get settingsPageSectionsSwitchRow25 => '唯讀 API 服務 · 連接埠 2377';

  @override
  String get settingsPageLockRowSub2 => '已鎖定：點選歌詞不會回應，可在設定中解鎖';

  @override
  String get settingsPageStatusStatus3 => '僅支援 HTTP 代理協定，適用於所有網路請求';

  @override
  String get settingsPageSectionsSwitchRow26 => '開啟後封面位置顯示專案 logo，不顯示真實封面';

  @override
  String settingsPageDetectOpenAiModelsToast4(String length) {
    return '已取得 $length 個模型';
  }

  @override
  String settingsPageOnVersionTapToast(String value) {
    return '再執行 $value 步進入開發者模式';
  }

  @override
  String settingsPageStatusStatus4(String trim) {
    return '已啟用：$trim';
  }

  @override
  String get settingsPageSectionsInput4 => '在 deepl.com 免費註冊後取得（api-free）';

  @override
  String get settingsPageSectionsSub9 => 'Space / PageUp / PageDown / 方向鍵←→';

  @override
  String settingsPageAiModelInputHelperText(String length) {
    return '已偵測到 $length 個模型';
  }

  @override
  String get settingsPageSectionsSub10 =>
      'Google / Microsoft 免費 · DeepL 免費 Key · OpenAI 相容';

  @override
  String get settingsPageSectionsInput5 =>
      'https://api.openai.com/v1 或 http://127.0.0.1:11434/v1';

  @override
  String settingsPageSectionsSub11(String translationTargetLabel) {
    return '日語 → $translationTargetLabel';
  }

  @override
  String settingsPageNextKeyIdText(String shortcutLabel) {
    return '目前按鍵：$shortcutLabel\n\n按下新的單個按鍵';
  }

  @override
  String get settingsPageBuildText4 =>
      '將清除本機全部資料，且不可恢復：\n\n· ASMR.ONE 帳號與自建站台設定\n· 收藏 / 播放歷史 / 歌單 / 黑名單\n· 翻譯結果、均衡器、桌面歌詞、定時關閉等全部設定\n\n請確認是否繼續。';

  @override
  String get mark => '標記';

  @override
  String get confirm => '確定';

  @override
  String get refresh => '重新整理';

  @override
  String get workPageBuildLabel => '評論';

  @override
  String get translate => '翻譯';

  @override
  String get workPageRefreshWorkToast => '已重新整理';

  @override
  String get workPageBuildTooltip => '上一張';

  @override
  String get workPageBuildText => '已收藏';

  @override
  String get workPageBuildText2 => '翻譯中';

  @override
  String get workPageBuildTooltip2 => '下一張';

  @override
  String get workPageLanguageEditionsButtonText => '多語言';

  @override
  String get workPageSimilarWorksSliversText => '相似作品';

  @override
  String get workPageBuildText3 => '曲目清單';

  @override
  String get workPageConfirmedText => '刪除標記';

  @override
  String get workPageConfirmedText2 => '刪除作品';

  @override
  String get workPageRefreshWorkToast2 => '重新整理失敗';

  @override
  String get workPageShowTextViewerTooltip => '切換編碼';

  @override
  String get workPageBuildText4 => '我的評論';

  @override
  String get workPageAddToPlaylistText => '確認新增';

  @override
  String get workPageBuildHintText => '寫評論…';

  @override
  String get workPageBuildText5 => '取消翻譯';

  @override
  String get workPageOkText => '加入黑名單';

  @override
  String get workPageAddToPlaylistText2 => '新增到歌單';

  @override
  String get workPageTranslateTitlesToast => '已取消翻譯';

  @override
  String get workPageSelectedText => '選擇 CV';

  @override
  String get workPageBuildText6 => '新增至歌單';

  @override
  String get workPageBuildText7 => '下載選取項目';

  @override
  String get workPageOpenVideoChooserText => '選擇開啟方式';

  @override
  String get workPageOpenVideoChooserText2 => '音訊方式開啟';

  @override
  String get workPageSelectedText2 => '切換翻譯引擎';

  @override
  String get workPageTranslateTitlesToast2 => '未知翻譯引擎';

  @override
  String get workPageTranslateTitlesFormatException => '翻譯結果為空';

  @override
  String get workPageAllFilesRowText => '檢視全部檔案';

  @override
  String get workPageDownloadSelectedToast => '已加入下載佇列';

  @override
  String get workPageAddToPlaylistText3 => '請輸入歌單名稱';

  @override
  String get workPageOpenVideoChooserText3 => '外部播放器開啟';

  @override
  String workPageDeleteNotify(String e) {
    return '刪除失敗：$e';
  }

  @override
  String get workPageBuildLabel2 => '新增到播放清單';

  @override
  String workPageSetProgressToast(String e) {
    return '標記失敗：$e';
  }

  @override
  String get workPageBuildLabel3 => '僅顯示媒體檔案';

  @override
  String get workPageTreePlaceholderText => '該作品暫無曲目';

  @override
  String workPageTranslateTitlesToast3(String e) {
    return '翻譯失敗：$e';
  }

  @override
  String workPageRateWorkToast(String e) {
    return '評分失敗：$e';
  }

  @override
  String workPageApplyEncodingToast(String e) {
    return '解碼失敗：$e';
  }

  @override
  String workPageSubmitNotify(String e) {
    return '儲存失敗：$e';
  }

  @override
  String get workPageSimilarWorksSliversText2 => '載入更多相似作品';

  @override
  String get workPageDownloadSelectedToast2 => '曲目清單尚未載入';

  @override
  String workPageClearRatingToast(String e) {
    return '取消評分失敗：$e';
  }

  @override
  String get workPageRefreshWorkToast3 => '已重新整理本機下載紀錄';

  @override
  String workPageDownloadSelectedToast3(String e) {
    return '加入下載失敗：$e';
  }

  @override
  String get workPageSimilarWorksSliversText3 => '已顯示全部相似作品';

  @override
  String get workPageOpenLanguageEditionToast => '無法載入該語言版本';

  @override
  String workPageBuildToast(String e) {
    return '收藏操作失敗：$e';
  }

  @override
  String get workPageConfirmedText3 => '確定要刪除標記嗎？';

  @override
  String workPageSetProgressToast2(String e) {
    return '取消標記失敗：$e';
  }

  @override
  String get workPageBuildLabel4 => '前往 DLsite';

  @override
  String get workPageAddToPlaylistToast => '請先勾選檔案或資料夾';

  @override
  String get workPageBuildText8 => '曲目清單（資料夾結構）';

  @override
  String get workPageBuildLabel5 => '前往 asmr.one';

  @override
  String workPageAddToPlaylistToast2(String name) {
    return '已新增到「$name」';
  }

  @override
  String get workPageAddToServerPlaylistToast => '只能新增到自建播放清單';

  @override
  String get workPageOnMoreActionToast => '曲目清單載入中，請稍候';

  @override
  String get workPageTreePlaceholderText2 => '該作品沒有音訊或影片檔案';

  @override
  String get workPageAddToServerPlaylistToast2 => '該作品缺少編號，無法新增';

  @override
  String get workPageOpenReviewDialogToast => '該作品缺少編號，無法評價';

  @override
  String get workPageDeleteSelectedLocalFilesToast => '所選項目中沒有已下載檔案';

  @override
  String get workPageDeleteSelectedLocalFilesToast2 => '請先勾選要刪除的本機檔案';

  @override
  String get workPageOnMoreActionToast2 => '曲目載入失敗，請重新整理後重試';

  @override
  String get workPageTreePlaceholderText3 => '無網路連線，無法取得曲目清單';

  @override
  String workPageBuildText9(String dur) {
    return '長度 $dur';
  }

  @override
  String get workPageEnginesEngines => 'DeepL（免費版 Key）';

  @override
  String get workPageEnginesEngines2 => 'OpenAI 相容（可設定）';

  @override
  String workPageCopyRjToast(String rj) {
    return '已複製 $rj';
  }

  @override
  String get workPageDownloadSelectedToast4 => '請先勾選要下載的項目或資料夾';

  @override
  String get workPageAddToPlaylistToast3 => '所選項目中沒有可播放的音訊檔案';

  @override
  String get workPageOnMoreActionToast3 => '請先勾選需要聽寫翻譯的媒體檔案';

  @override
  String get workPagePlayAsAudioToast => 'SFW 模式下不能播放非全年齡作品';

  @override
  String get workPageOpenLanguageEditionToast2 => 'SFW 模式下不能開啟非全年齡作品';

  @override
  String get workPagePlayFilesToast => '暫無音訊檔案（檔案串流需登入後可用）';

  @override
  String get workPageEnginesEngines3 => 'Google（免費，無需 Key）';

  @override
  String workPageNodeRowToast(String title) {
    return '已複製檔名：$title';
  }

  @override
  String workPageDeleteSelectedLocalFilesToast3(String deleted) {
    return '已刪除 $deleted 個本機檔案';
  }

  @override
  String get workPageTranslateTitlesToast4 => '請先在設定中填寫 API 位址與模型名稱';

  @override
  String get workPageEnginesEngines4 => 'Microsoft（免費，無需 Key）';

  @override
  String workPageOpenFileToast(String title) {
    return '暫不支援檢視該類型：$title';
  }

  @override
  String get workPageEnginesEngines5 => 'Index-Translate（官方 API）';

  @override
  String get workPageConfirmDeleteWorkToast => '刪除失敗，請關閉正在佔用該作品的程式後重試';

  @override
  String workPageTranslateTitlesToast5(String length) {
    return '正在翻譯 $length 行標題…';
  }

  @override
  String get workPageTranslateTitlesToast6 => '請先在設定中填寫 DeepL 免費版 API Key';

  @override
  String workPageAddToPlaylistText4(String length) {
    return '已選擇 $length 個音訊檔案';
  }

  @override
  String get workPageOnMoreActionToast4 => '所選項目中沒有可傳送給 kikoeta-transl 的媒體檔案';

  @override
  String workPageTranslateTitlesToast7(String length) {
    return '翻譯完成（標題 + $length 個曲目）';
  }

  @override
  String workPageOkText2(String t) {
    return '將標籤「$t」加入黑名單？\n加入後，含該標籤的作品將從首頁與搜尋中過濾。';
  }

  @override
  String workPageConfirmedText4(String title) {
    return '確定刪除「$title」的全部本機檔案嗎？此操作無法復原。';
  }

  @override
  String get liked => '喜歡';

  @override
  String get privatePlaylist => '私人';

  @override
  String get publicPlaylist => '公開';

  @override
  String get sharedByLink => '透過連結分享';

  @override
  String get apiServiceMapPlaylistName => '未命名歌單';

  @override
  String get apiServiceMapWorkVa => 'CV. 未知';

  @override
  String get apiServiceFetchWorkFormatException => '作品詳情格式無效';

  @override
  String get apiServiceFetchPlaylistMetadataFormatException => '歌單詳情格式無效';

  @override
  String get apiServiceFetchAdvancedFilterEntriesValue => '不支援的進階篩選類型';

  @override
  String get apiServiceFetchAdvancedFilterEntriesFormatException =>
      '進階篩選資料格式無效';

  @override
  String get apiServiceToggleFavoriteException => '該作品缺少編號，無法收藏';

  @override
  String get apiServiceClearReviewRatingException => '該作品缺少編號，無法取消評分';

  @override
  String get apiServiceClearReviewProgressException => '該作品缺少編號，無法取消標記';

  @override
  String get apiServiceDeleteReviewException => '該作品缺少編號，無法刪除標記';

  @override
  String get search => '搜尋';

  @override
  String clipboardWatcherCheckText(String rj) {
    return '偵測到 $rj，點選搜尋';
  }

  @override
  String get desktopLyricsOverlayEnsureWindowToNativeUtf16 => 'Kikoeta 桌面歌詞';

  @override
  String get downloadServiceDownloadFileHttpException => '下載檔案為空';

  @override
  String get downloadServiceRunStateError => '沒有可下載的檔案';

  @override
  String get downloadServiceRunStateError2 => '下載檔案位址為空';

  @override
  String get downloadTransferDownloadToFileHttpException => '下載回應不完整';

  @override
  String get downloadTransferDownloadToFileHttpException2 => '下載分片長度發生變化';

  @override
  String get downloadTransferDownloadToFileHttpException3 => '下載檔案長度驗證失敗';

  @override
  String get downloadTransferDownloadToFileHttpException4 => '下載回應的位元組範圍不符';

  @override
  String get downloadTransferDownloadToFileHttpException5 => '下載回應超過宣告的檔案長度';

  @override
  String get downloadTransferDownloadToFileHttpException6 => '下載回應使用了非原始位元組編碼';

  @override
  String downloadTransferDownloadToFileHttpException7(String status) {
    return '下載失敗 HTTP $status';
  }

  @override
  String get ktServiceNormalizeEndpointFormatException =>
      '連線位址格式應為 IP/網域名稱:連接埠';

  @override
  String get ktServiceDecodeFormatException => 'kikoeta-transl 回傳了無效回應';

  @override
  String get ktServiceNormalizeEndpointFormatException2 =>
      '請輸入 kikoeta-transl 的 IP/網域名稱與連接埠';

  @override
  String ktServiceErrorMessageText(String statusCode) {
    return 'kikoeta-transl 請求失敗（HTTP $statusCode）';
  }

  @override
  String get lyricsLibraryRemoteClientValidateWorkIdFormatException => '無效的作品號';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException =>
      '遠端歌詞庫分頁游標無效';

  @override
  String get lyricsLibraryRemoteClientFetchWorksFormatException2 =>
      '遠端歌詞庫未提供作品清單';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException =>
      '遠端作品沒有歌詞檔案清單';

  @override
  String get lyricsLibraryRemoteClientFetchLyricsFormatException2 =>
      '遠端作品沒有可用歌詞檔案';

  @override
  String get lyricsLibraryRemoteClientGetJsonFormatException =>
      '遠端歌詞庫回傳的資料格式無效';

  @override
  String get lyricsLibraryRemoteClientNormalizeBaseUrlFormatException =>
      '請輸入有效的 HTTP 或 HTTPS 位址';

  @override
  String lyricsLibraryRemoteClientGetJsonHttpException(String statusCode) {
    return '遠端歌詞庫回傳 HTTP $statusCode';
  }

  @override
  String get lyricsLibraryServiceExtractArchivePhase => '正在解壓縮';

  @override
  String get lyricsLibraryServiceCopyTreePhase => '正在複製';

  @override
  String get lyricsLibraryServiceRemoveRemoteLibraryStateError => '該遠端庫尚未匯入';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError =>
      '不支援的歌詞格式';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError2 =>
      '檔案中沒有有效時間軸';

  @override
  String get lyricsLibraryServiceImportRemoteWorkFormatException =>
      '遠端作品沒有有效歌詞檔案';

  @override
  String get lyricsLibraryServiceSaveTranslatedLyricsArgumentError3 =>
      '目標檔案必須位於作品目錄內';

  @override
  String get lyricsLibraryServiceSetRemoteLibraryOrderArgumentError =>
      '遠端庫清單已變化，請重新開啟匯入視窗';

  @override
  String lyricsLibraryServiceSubscriptionStateError(String message) {
    return '歌詞匯入處理程序異常：$message';
  }

  @override
  String get updateServiceShowUpdateDialogText => '不再提示';

  @override
  String get updateServiceShowUpdateDialogText2 => '前往下載';

  @override
  String get updateServiceShowUpdateDialogText3 => '發現新版本';

  @override
  String get updateServiceCheckManuallyText => '正在檢查更新…';

  @override
  String get updateServiceCheckError => '更新服務連線失敗';

  @override
  String get updateServiceCheckManuallyToast => '目前已是最新版本';

  @override
  String get updateServiceShowUpdateDialogToast => '開啟下載頁面失敗';

  @override
  String get updateServiceGetUpdateResponseStateError => '更新服務請求未執行';

  @override
  String get updateServiceParseReleaseResponseFormatException => '更新回應缺少版本資訊';

  @override
  String get updateServiceCheckError2 => '更新服務未回傳有效版本資訊';

  @override
  String get updateServiceCheckError3 => '無法連線更新服務或 GitHub';

  @override
  String updateServiceShowUpdateDialogText4(
    String version,
    String currentVersion,
  ) {
    return '最新版本：$version\n目前版本：$currentVersion';
  }

  @override
  String get pause => '暫停';

  @override
  String get quit => '結束';

  @override
  String get windowsTrayServiceSetContextMenuLabel => '顯示首頁';

  @override
  String get sheetsShowSleepSheetSuffixText => '分鐘';

  @override
  String get sheetsBuildText => '套用';

  @override
  String get sheetsShowSiteSheetField => '別名';

  @override
  String get sheetsShowSiteSheetField2 => '位址';

  @override
  String get account => '帳號';

  @override
  String get sheetsPresetsPresets => '人聲';

  @override
  String get sheetsPresetsPresets2 => '低音';

  @override
  String get sheetsPresetsPresets3 => '平坦';

  @override
  String get sheetsPresetsPresets4 => '流行';

  @override
  String get sheetsPresetsPresets5 => '搖滾';

  @override
  String get sheetsShowEqSheetText => '未啟用';

  @override
  String get sheetsShowEqSheetText2 => '已套用';

  @override
  String get sheetsShowSleepSheetText => '取消定時';

  @override
  String get sheetsShowSleepSheetText2 => '開始定時';

  @override
  String get playbackComplete => '播放完畢';

  @override
  String get sheetsTimePickerText => '關閉時間';

  @override
  String get sheetsShowSleepSheetLabel => '指定時間';

  @override
  String sheetsShowSleepSheetLabel2(String m) {
    return '$m 分鐘';
  }

  @override
  String get sheetsShowSleepSheetLabel3 => 'N 分鐘後';

  @override
  String get sheetsBuildTitle => '選擇伺服器';

  @override
  String get sheetsShowEqSheetText3 => '啟用均衡器';

  @override
  String get sheetsShowSiteSheetTitle => '編輯自建站台';

  @override
  String get sheetsBuildText2 => '管理自建站台';

  @override
  String get sheetsShowSleepSheetHintText => '自訂分鐘數';

  @override
  String get sheetsBuildText3 => '暫無自建站台';

  @override
  String get sheetsBuildText4 => '選擇自建站台';

  @override
  String get sheetsShowSiteSheetHint => '如：家庭 NAS';

  @override
  String get sheetsBuildText5 => '請先新增自建站台';

  @override
  String get sheetsShowOneConfigSheetTitle => 'ASMR.ONE 帳號';

  @override
  String get sheetsShowOneConfigSheetHint => 'asmr.one 帳號';

  @override
  String get sheetsShowOneConfigSheetSub => '帳號資訊僅儲存在本機（示範）';

  @override
  String get sheetsShowSleepSheetText3 => '目前播放清單播完後自動停止並關閉';

  @override
  String get sheetsShowSleepSheetText4 => '剩餘時間 · 到時自動停止並結束程式';

  @override
  String get sheetsBuildSub => '官方服務或自建 Kikoeru 站台';

  @override
  String get sheetsShowEqSheetSub => '真 10 段 · ±12 dB · 全平台';

  @override
  String get sheetsShowSleepSheetText5 => '目前播放清單的內容播放完畢後自動停止並關閉';

  @override
  String get sheetsShowSleepSheetSub => '到時停止播放並釋放系統資源（清除鎖定畫面卡片與通知）';

  @override
  String sheetsBuildLabel(String length) {
    return '自訂設定（$length）';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip(String label) {
    return '減少$label秒數';
  }

  @override
  String playbackSeekSecondsControlBuildTooltip2(String label) {
    return '增加$label秒數';
  }

  @override
  String get name => '名稱';

  @override
  String get description => '描述';

  @override
  String get playlistPickerRowsMapEntry => '權限';

  @override
  String get language => '語言';

  @override
  String get confirmAction => '確認';

  @override
  String get create => '新增';

  @override
  String get playlistPickerShowEditorLabelText => '類型';

  @override
  String get playlistPickerRowsMapEntry2 => '建立者';

  @override
  String get playlistPickerRowsMapEntry3 => '更新時間';

  @override
  String get playlistPickerReviewsItemName => '我的收藏';

  @override
  String get playlistPickerRowsMapEntry4 => '播放次數';

  @override
  String get playlistPickerRowsMapEntry5 => '作品數量';

  @override
  String get playlistPickerCopyText => '歌單詳情';

  @override
  String get playlistPickerLinkLabelText => '分享連結';

  @override
  String get playlistPickerCopyText2 => '複製連結';

  @override
  String get playlistPickerRowsMapEntry6 => '建立時間';

  @override
  String get playlistPickerBuildText => '切換播放清單';

  @override
  String get playlistPickerPlaylistItemTooltip => '移除播放清單';

  @override
  String get playlistPickerPlaylistItemTooltip2 => '編輯播放清單';

  @override
  String get playlistPickerShowEditorText => '建立播放清單';

  @override
  String get playlistPickerLinkText => '匯入播放清單';

  @override
  String get playlistPickerOkText => '刪除播放清單';

  @override
  String playlistPickerRemoveLikedToast(String e) {
    return '移除失敗：$e';
  }

  @override
  String playlistPickerCreatePlaylistToast(String e) {
    return '建立失敗：$e';
  }

  @override
  String get playlistPickerLoadSetState => '無法載入播放清單';

  @override
  String get playlistPickerImportPlaylistToast => '無法識別播放清單連結';

  @override
  String get playlistPickerReviewsItemSubtitle => '我的評價/收藏（所有作品）';

  @override
  String get playlistPickerCreatePlaylistToast2 => '已建立，但清單中未找到該播放清單';

  @override
  String get playlistPickerImportPlaylistToast2 => '已新增，但清單中暫未找到該播放清單';

  @override
  String playlistPickerSubtitleSubtitle(String worksCount) {
    return '$worksCount 個作品';
  }

  @override
  String get playlistPickerLinkText2 => '貼上別人分享的播放清單連結，會收藏到我的播放清單。';

  @override
  String playlistPickerOkText2(String name) {
    return '確定刪除「$name」嗎？此操作無法復原。';
  }

  @override
  String playlistPickerOkText3(String name) {
    return '確定從我的播放清單中移除「$name」嗎？';
  }

  @override
  String playlistPickerSubtitleSubtitle2(String worksCount, String replaceAll) {
    return '$worksCount 個作品 · $replaceAll';
  }

  @override
  String get widgetsFilterButtonTooltip => '篩選';

  @override
  String get widgetsFilterButtonLabel => '僅字幕';

  @override
  String get allAges => '全年齡';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter => '排除語言';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter2 => '搜尋社團';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter3 => '搜尋聲優';

  @override
  String get widgetsBuildBuilder => 'AI歌詞';

  @override
  String get widgetsBuildBuilder2 => '遠端歌詞';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter4 => '篩選語言';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter5 => '排除標籤';

  @override
  String get widgetsBuildBuilder3 => '本機歌詞';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter6 => '排除社團';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter7 => '排除聲優';

  @override
  String get widgetsInputRowMessage => '進階搜尋';

  @override
  String get widgetsHistoryPanelText => '搜尋歷史';

  @override
  String get widgetsBuildBuilder4 => '線上歌詞';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter8 => '搜尋標籤';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter9 =>
      '篩選年齡分級';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter10 =>
      '排除年齡分級';

  @override
  String get widgetsBuildText => '進階搜尋參數';

  @override
  String get widgetsHistoryPanelText2 => '暫無搜尋歷史';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter11 =>
      '包含低願力標籤';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter12 =>
      '排除低願力標籤';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter13 =>
      '篩選評分（大於）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter14 =>
      '篩選銷量（大於）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter15 =>
      '篩選價格（大於）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter16 =>
      '篩選作品長度（小於）';

  @override
  String get widgetsAdvancedSearchParametersAdvancedSearchParameter17 =>
      '篩選作品長度（大於）';

  @override
  String widgetsHistoryPanelText3(String value) {
    return '已刪除「$value」';
  }

  @override
  String get playbackSpeed => '倍速';

  @override
  String get playbackSpeedDescription => '切換播放速度，保持音調';

  @override
  String get playbackSpeedEntry => '顯示倍速控制';

  @override
  String get playbackSpeedEntryDescription => '在播放器顯示倍速控制，關閉後恢復 1×';

  @override
  String get audioChannels => '聲道';

  @override
  String get audioChannelsDescription => '反轉左右聲道，或合併後雙耳播放相同聲音';

  @override
  String get audioChannelsOriginal => '原始聲道';

  @override
  String get audioChannelsSwap => '左右反轉';

  @override
  String get audioChannelsMerge => '聲道合併';

  @override
  String get widgetsInputRowHintText => '搜尋 RJ 號、作品名、聲優…';
}
