import 'package:flutter/material.dart';

import 'data.dart';
import 'pages/work_page.dart';

/// 作品详情页路由：缩放 + 淡入的展开动画
Route<void> buildWorkRoute(AppState app, Work w) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        WorkPage(app: app, work: w),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(curved),
          alignment: Alignment.center,
          child: child,
        ),
      );
    },
  );
}
