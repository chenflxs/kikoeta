# Kikoeta 项目一致性约定

Kikoeta 的 Windows 和 Android 客户端共用 Flutter 界面、media_kit 播放器与 Rust 核心。查找代码和运行入口时，以当前源码和仓库文档为准。[文件功能索引](docs/文件功能索引.md) · [开发说明](README.md#开发说明)

## 修改前

- 先找项目内最接近的实现。统一 UI 时选一个完整参照，成套对齐字号、字重、行高、间距、颜色、圆角、图标和按钮布局。改动限于用户指定的范围，涉及公共组件或全局主题时，先核对调用方并说明影响。
- 新增或改动功能前，核对官方组件或成熟项目的机制，优先复用。交付时注明参考来源。需要自定义时，说明直接采用的限制和实现差异。性能改动说明每帧或每次操作的实际开销，包括重建范围、扫描或请求次数及额外缓存。

## UI 与交互

- **主题与布局。** 从 `buildTheme` 和当前亮度的 `Palette` 取样式。组件主题显式声明 `TextStyle` 时沿用 `kAppFontFamily`。按父容器的逻辑尺寸适配，保留窄屏底栏、宽屏侧栏和迷你播放器的关系，以及 Windows 标题栏裁剪。界面缩放由 `_UiScale` 统一处理，独立歌词窗沿用自己的字号和缩放设置。[主题](app/lib/theme.dart) · [应用壳](app/lib/main.dart)
- **公共组件。** 作品列表复用 `WorkCard`、`CoverArt` 和 `ResponsiveGrid`，保留 4:3 封面及角标布局。菜单、弹层和设置项沿用同用途组件，歌词外观滑块复用 `_lyricsSliderRow` 对齐滑轨。错误、操作受阻或需要用户决定时，沿用所在流程的提示方式，同一次操作只反馈一次。[公共组件](app/lib/widgets.dart) · [表单弹层](app/lib/widgets/form_sheet.dart) · [播放与服务器弹层](app/lib/sheets.dart) · [设置页](app/lib/pages/settings_page.dart)
- **导航与动画。** 作品详情走 `buildWorkRoute`，主标签页沿用 `NavigationPageStack` 保留页面和滚动状态，标签切换尊重系统关闭动画设置。主题切换用 `ThemeReveal`，首页与歌词库横向分类切换用 `SubpageSwipe`。[路由](app/lib/routes.dart) · [标签页容器](app/lib/navigation_page_stack.dart) · [主题揭示](app/lib/services/theme_reveal.dart) · [子页手势](app/lib/subpage_swipe.dart)
- **滚动与高频更新。** 纵向鼠标滚轮复用 Smooth 系列组件，保留触控板、横向滚动及组合键的现有处理。媒体树按目录快照建索引，以路径标识行并按视口构建。图片与封面共用预览，缩放和平移沿用局部 `ValueNotifier` 和稳定的图片子树。[滚动组件](app/lib/smooth_scroll.dart) · [媒体树索引](app/lib/services/media_tree.dart) · [媒体列表](app/lib/widgets/media_tree_sliver.dart) · [作品页](app/lib/pages/work_page.dart)

## 语言与数据身份

- 用户可见文案用 `context.l10n` 或 `appL10n`，状态与样式根据类型或状态值判断。新增文案同步各语言 ARB 的键与参数，以 `app_zh.arb` 为模板，保留 `app_zh_CN.arb` 的继承关系。在 `app/` 运行 `flutter gen-l10n` 更新生成文件。[本地化入口](app/lib/l10n/strings.dart) · [生成配置](app/l10n.yaml)
- 标签显示通过 `TagNames` 取译名，搜索、黑名单和持久化继续使用原名或 ID。作品卡片用本地化的「翻译字幕」角标，歌词库沿用 `AI` 和 `TL`。[标签本地化](app/lib/l10n/tag_names.dart) · [作品卡片](app/lib/widgets.dart) · [歌词库](app/lib/pages/lyrics_library_page.dart)
- 界面语言、翻译源语言和翻译目标分别处理。保留界面的中文脚本解析和英语回退。`ui` 表示跟随界面语言，发送请求、读写语言相关缓存和保存字幕时使用解析后的实际目标代码。改界面语言选项时联查设置菜单、启动恢复和备份校验。当前日语、俄语已可选，便携备份的 `ui_language` 校验仍缺这两项。[界面语言](app/lib/l10n/app_language.dart) · [翻译代码](app/lib/l10n/translation_language.dart) · [备份校验](app/lib/services/portable_backup.dart)

## 功能约定

- **站点与列表。** 作品、曲目、登录和媒体解析统一通过 `ApiService` 处理 asmr.one、自建站和 DLsite Play 的来源差异。首页和搜索沿用 `WorksPageBuffer` 的有界预取及在途请求复用，失败保留可重试的游标。查询、筛选或来源变化时丢弃旧结果，异步回到界面前检查生命周期和任务有效性。[站点 API](app/lib/services/api_service.dart) · [分页缓冲](app/lib/services/works_page_buffer.dart)
- **播放与下载。** `AppState` 管理播放队列，`AppPlayer` 在页面之外持有播放器。切歌、停止和重连沿用串行命令与代际校验。手动切歌遵循队列边界，自动续播遵循播放模式，队列结构和频繁写入的位置检查点分开保存。下载沿用暂停、取消、断点校验和完成后转为正式文件的流程。[应用状态](app/lib/data.dart) · [播放器](app/lib/services/player_service.dart) · [下载管理](app/lib/services/download_service.dart) · [续传](app/lib/services/download_transfer.dart)
- **歌词匹配与显示。** `LyricsHub` 持有当前歌词和时间状态。切歌时按当前曲目匹配，先试歌词库，再按现有条件回退到在线歌词，保留当前曲目的手选结果。改进度、偏移、显示语言或暂停行为时，联查播放器、Windows 桌面歌词和 Android 悬浮歌词。[歌词中枢](app/lib/services/lyrics_hub.dart)
- **歌词库与翻译。** 歌词库按作品号和翻译状态区分卡片，在已加载索引上分批展示和读取文件数，追加时保留选择。沿用搜索防抖，刷新和切换来源时作废过期结果。远程作品索引沿用游标分页及旧服务兼容，按需读取文件索引和歌词，保留库的优先顺序。翻译沿用分批、限速、去重、取消和重试，保留原顺序和时间轴，按 `RJ号-目标语言` 另存 LRC。[歌词库页面](app/lib/pages/lyrics_library_page.dart) · [远程客户端](app/lib/services/lyrics_library_remote_client.dart) · [歌词翻译](app/lib/services/lyrics_translation_service.dart)
- **听写与写回。** 听写队列跨页继续运行，状态限当前进程。插队等待 KT 确认抢占，任务及恢复绑定原服务器和账号。歌词入库、缓存同步与站点写回分别处理，写回失败可单独重试。保留站点凭据作用域、媒体匹配、同源及相对路径校验。[听写队列](app/lib/services/dictation_queue.dart) · [KT 连接](app/lib/services/kt_service.dart) · [缓存同步](app/lib/services/kt_cache_sync.dart) · [写回实现](app/lib/services/kikoeru_lyrics_writeback.dart)
- **设置与持久化。** 用 `AppState` 的设置入口通知监听方并持久化。新增配置时核对默认、启动恢复、完全重置和备份白名单。目录解析沿用 `AppPaths`，保留便携目录和旧数据迁移。备份与 WebDAV 沿用冲突判断及中断恢复，导入后核对新设置在当前会话生效。[设置存储](app/lib/services/settings_store.dart) · [数据路径](app/lib/services/app_paths.dart) · [同步服务](app/lib/services/cloud_sync_service.dart)
- **网络与平台。** Rust 请求复用对应 HTTP 客户端，保留代理、网络切换及翻译服务策略。远程歌词库端口写在 URL 的主机之后。修改锁屏、通知、托盘、音频焦点或耳机事件时，联查平台调用、回调和状态回传。[Rust 客户端](app/rust/src/api/http_client.rs) · [网络接口](docs/网络接口.md) · [Android 桥接](app/android/app/src/main/kotlin/com/kikoeta/kikoeta_app) · [Windows 托盘](app/lib/services/windows_tray_service.dart)

## 生成与验证

- 改 Rust 导出接口时，用仓库的 FRB 配置同步生成 Dart 和 Rust 绑定。诊断通过 `AppLog` 记录异常和栈，保留脱敏与容量限制，避免用日常请求成功记录淹没错误。[FRB 配置](app/flutter_rust_bridge.yaml) · [诊断日志](app/lib/services/app_log.dart)
- 按影响范围验证。UI 检查亮暗主题、窄宽布局、语言及受影响的输入方式。功能检查旧数据、来源切换、取消重试及失败恢复。优先用已有入口、`flutter analyze` 等静态检查和目标平台实测，交付时说明实测范围。临时验证产物应由 `.gitignore` 覆盖，用完清理。
