import 'package:flutter/material.dart';

import 'data.dart';
import 'pages/work_page.dart';
import 'services/download_service.dart';

/// 作品详情页路由：使用主题中统一的短距离滑动 + 淡入淡出转场。
Route<void> buildWorkRoute(
  AppState app,
  Work w, {
  VoiceDownload? downloadItem,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => WorkPage(app: app, work: w, downloadItem: downloadItem),
  );
}
