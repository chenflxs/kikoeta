import 'package:flutter/material.dart';

import '../services/media_tree.dart';

/// Builds only the media rows that enter the scroll viewport.
class MediaTreeSliver extends StatelessWidget {
  const MediaTreeSliver({
    super.key,
    required this.rows,
    required this.rowBuilder,
    this.header,
    this.decoration,
  });

  final List<MediaTreeRow> rows;
  final Widget Function(BuildContext context, MediaTreeRow row) rowBuilder;
  final Widget? header;
  final Decoration? decoration;

  @override
  Widget build(BuildContext context) {
    final offset = header == null ? 0 : 1;
    final sliver = SliverList.builder(
      itemCount: rows.length + offset,
      itemBuilder: (context, index) {
        if (offset == 1 && index == 0) return header!;
        final row = rows[index - offset];
        return KeyedSubtree(
          key: ValueKey(row.node.path),
          child: rowBuilder(context, row),
        );
      },
    );
    return decoration == null
        ? sliver
        : DecoratedSliver(decoration: decoration!, sliver: sliver);
  }
}
