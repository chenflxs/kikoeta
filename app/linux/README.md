# Linux 桌面开发

安装项目要求的 Flutter stable 和通过 `rustup` 安装的 Rust stable。Debian / Ubuntu 还需要以下系统依赖。

```bash
sudo apt install build-essential clang cmake ninja-build pkg-config \
  libgtk-3-dev libsecret-1-dev libayatana-appindicator3-dev libmpv-dev
```

在仓库根目录执行：

```bash
cd app
flutter pub get
flutter run -d linux
```

执行 `flutter build linux --release` 生成发布构建。产物位于 `app/build/linux/<架构>/release/bundle/`。运行时应保留其中的 `data/` 和 `lib/` 目录，目标系统需提供 GTK 3、libsecret、AppIndicator 和 libmpv。
