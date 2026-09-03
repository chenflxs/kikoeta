import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeta_app/data.dart';
import 'package:kikoeta_app/services/media_selection.dart';

void main() {
  final tree = [
    const MediaNode(
      title: 'Root',
      type: 'folder',
      path: 'root',
      children: [
        MediaNode(title: 'one.mp3', type: 'file', path: 'root/one.mp3'),
        MediaNode(
          title: 'Subfolder',
          type: 'folder',
          path: 'root/sub',
          children: [
            MediaNode(title: 'two.mp3', type: 'file', path: 'root/sub/two.mp3'),
            MediaNode(
              title: 'three.mp3',
              type: 'file',
              path: 'root/sub/three.mp3',
            ),
          ],
        ),
      ],
    ),
  ];

  test('selecting a folder selects every descendant', () {
    final selection = MediaSelection();

    selection.toggle(tree.single, tree);

    expect(selection.state(tree.single), isTrue);
    expect(selection.paths, {
      'root',
      'root/one.mp3',
      'root/sub',
      'root/sub/two.mp3',
      'root/sub/three.mp3',
    });
  });

  test('selecting one file makes each ancestor partially selected', () {
    final selection = MediaSelection();
    final file = tree.single.children.first;

    selection.toggle(file, tree);

    expect(selection.state(file), isTrue);
    expect(selection.state(tree.single.children[1]), isFalse);
    expect(selection.state(tree.single), isNull);
    expect(selection.paths, {'root/one.mp3'});
  });

  test('toggling a partial folder selects it completely', () {
    final selection = MediaSelection();
    final file = tree.single.children.first;

    selection.toggle(file, tree);
    selection.toggle(tree.single, tree);

    expect(selection.state(tree.single), isTrue);
    expect(selection.paths.length, 5);
  });
}
