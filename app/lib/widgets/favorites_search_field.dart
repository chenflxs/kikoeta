import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme.dart';

/// 收藏页的本地关键词输入，外观沿用下载页的搜索框。
class FavoritesSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  const FavoritesSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.only(left: 13, right: 8),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.accent),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .24),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            Icon(Icons.search, size: 19, color: p.dim),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: p.text),
                decoration: InputDecoration(
                  hintText: context.l10n.favoritesSearchHint,
                  hintStyle: TextStyle(fontSize: 14, color: p.dim),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged();
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: p.surface3,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
