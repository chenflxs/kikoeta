import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/services/download_service.dart';

void main() {
  const initialTree = [
    MediaNode(
      title: 'Display root',
      type: 'folder',
      path: 'Display root',
      children: [
        MediaNode(title: 'a.mp3', type: 'file', path: 'Display root/a.mp3'),
        MediaNode(title: 'b.mp3', type: 'file', path: 'Display root/b.mp3'),
        MediaNode(title: 'c.mp3', type: 'file', path: 'Display root/c.mp3'),
      ],
    ),
  ];

  test(
    'supplemental download keeps old files when the refreshed tree changes',
    () {
      final stored = normalizeDownloadTree(initialTree);
      final refreshed = const [
        MediaNode(title: 'b.mp3', type: 'file', path: 'b.mp3'),
        MediaNode(title: 'c.mp3', type: 'file', path: 'c.mp3'),
      ];

      final merged = mergeDownloadTrees(stored, refreshed);

      expect(merged.map((node) => node.path), ['b.mp3', 'c.mp3', 'a.mp3']);
    },
  );

  test('selecting a display root remains an all-files selection', () {
    expect(normalizeDownloadSelectionPaths({'Display root'}, initialTree), {
      '',
    });
  });

  test('paths inside a display root use the same stored location', () {
    expect(
      normalizeDownloadSelectionPaths({'Display root/b.mp3'}, initialTree),
      {'b.mp3'},
    );
  });
}
