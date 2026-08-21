# Kikoeta

面向 ASMR 音声的跨平台本地收听客户端，支持 asmr.one 与自建站点（kikoeru-express），提供浏览、播放、歌词、翻译、收藏等一站式体验。

> ⚠️ 本项目为非官方个人项目，仅供学习与本地收听使用，接口可能随时变动。

## 功能特性

### 浏览与搜索

- 作品流：分页浏览、排序、年龄分级（全年龄 / R15 / R18）与字幕筛选
- 搜索：标题 / 标签 / 社团 / 声优，支持搜索历史
- SFW 模式：仅显示全年龄内容
- 黑名单过滤：按标签、社团、声优、作品屏蔽
- 剪贴板检测：复制 RJ 号自动提示一键搜索

### 作品详情

- 曲目树浏览，智能初始路径（按音频类型偏好过滤）
- 标题 / 曲目在线翻译
- 标签、社团、声优快捷搜索与黑名单
- 图片、文本（自动识别编码）、视频等文件预览与外部打开

### 播放器

- 播放模式、音量与音量增强
- 真 10 段均衡器，全平台生效
- 歌词：在线 / 离线、时间偏移、简繁转换
- 迷你播放器（退出播放页后持续播放）
- 定时关闭：N 分钟 / 定点 / 播放完毕

### 本地数据

- 收藏、播放历史、搜索历史、播放列表、黑名单，全部本地保存
- 标题翻译缓存、播放进度记忆

### 翻译

- Google / Microsoft Edge / DeepL / OpenAI 多引擎，可配置密钥与接口地址

### 平台特性

- Windows 桌面歌词悬浮窗（可锁定、可调字号与配色）
- Android 悬浮歌词（可拖动 / 锁定，横竖屏独立记忆）
- Android 锁屏与通知栏媒体控制（Jetpack Media3 + 前台服务）
- Android 耳机拔出自动暂停、音频焦点控制、电池优化白名单

### 多服务器

- asmr.one 官方接口 + 自建站点（支持 IP + 端口），可随时切换

## 技术栈

| 层 | 方案 |
|---|---|
| UI | Flutter（Material 3） |
| 核心逻辑 | Rust（flutter_rust_bridge v2） |
| 音频 | media_kit（Android / 桌面均基于 libmpv） |
| 数据 | SQLite（rusqlite） |
| 原生桥接 | Android Jetpack Media3（锁屏 / 通知控制） |

## 项目结构

```
kikoeta/
├── app/                     Flutter 应用
│   ├── lib/                 Dart 源码（入口、pages/ 页面、services/ 服务、src/rust/ FRB 绑定）
│   ├── rust/                Rust 核心（API 客户端、翻译、文本处理、流媒体代理、SQLite 存储）
│   ├── rust_builder/        kikoeta_core 桥接插件（cargokit）
│   ├── android/             Android 原生（Media3、悬浮歌词、音频控制）
│   ├── windows/             Windows 桌面壳
│   ├── web/                 Web 宿主
│   └── assets/fonts/        内置字体（Sarasa UI SC）
├── docs/                    文档
│   └── 文件功能索引.md       文件定位速查
├── README.md                项目说明（本文档）
└── LICENSE                  许可（MIT）
```

## 快速开始

### 环境要求

- Flutter stable
- Rust stable
- Android SDK（构建 Android 需额外安装 [cargo-ndk](https://github.com/bbqsrc/cargo-ndk)）

### 运行

```bash
cd app
flutter run -d windows   # Windows
flutter run              # Android（连接设备后）
```

### 构建发布版

Windows：

```bash
cd app
flutter build windows
```

Android（arm64 + x64，含混淆瘦身）：

```bash
cd app
flutter build apk --release --split-per-abi \
  --target-platform android-arm64,android-x64 \
  --obfuscate --split-debug-info=build/symbols
```

## 相关文档

- [文件功能索引](docs/文件功能索引.md)：按目录定位源码文件与对应功能

## 致谢

- 项目参考了 [Kikoeru](https://github.com/loli-ball/KikoeruRelease) 的不少设计与实现，特此致谢。
- 感谢 [asmr.one](https://asmr.one)：自 2021 年上线以来，始终免费向音声爱好者提供数万部同人音声的在线收听与下载，并持续补充中文字幕、歌词等本地化内容。
- 感谢 [kikoeru-express](https://github.com/Number178/kikoeru-express) 及其维护者：作为同人音声自托管流媒体服务器，历经多年仍保持活跃更新，为自建站点生态与 Kikoeta 这类第三方客户端提供了稳定可靠的开放后端

## 其他

-该项目处于早期测试阶段，如果你需要更加稳定的跨平台项目，我推荐你使用 [kikoflu](https://github.com/pa-jesusf/KikoFlu)

## 许可

[MIT](LICENSE) © 2026 chenflxs
