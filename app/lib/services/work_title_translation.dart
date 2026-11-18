import '../data.dart';

String _singleLine(String text) =>
    text.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

Future<({String title, Map<String, String> names})?> translateWorkTitles({
  required String title,
  required Iterable<MediaNode> nodes,
  required String engine,
  required Future<String> Function(String) request,
  required bool Function() isCurrent,
  required String invalidResponse,
}) async {
  final titleKey = _singleLine(title);
  final namesByPath = <String, ({String stem, String extension})>{};
  final translations = <String, String>{};
  if (titleKey.isNotEmpty) translations[titleKey] = '';
  for (final node in nodes) {
    final dot = node.title.lastIndexOf('.');
    final hasExtension = !node.isDir && dot > 0 && dot < node.title.length - 1;
    final stem = _singleLine(
      hasExtension ? node.title.substring(0, dot) : node.title,
    );
    if (stem.isEmpty) continue;
    namesByPath[node.path] = (
      stem: stem,
      extension: hasExtension ? node.title.substring(dot) : '',
    );
    translations.putIfAbsent(stem, () => '');
  }

  final (maxLines, maxUnits, parallelism) = switch (engine) {
    'index' => (10, 500, 2),
    'openai' => (10, 1600, 2),
    'deepl' => (50, 4000, 1),
    _ => (30, 1000, 1),
  };
  final batches = <List<String>>[];
  var batch = <String>[];
  var units = 0;
  for (final name in translations.keys) {
    if (batch.isNotEmpty &&
        (batch.length == maxLines || units + 1 + name.length > maxUnits)) {
      batches.add(batch);
      batch = [];
      units = 0;
    }
    units += name.length + (batch.isEmpty ? 0 : 1);
    batch.add(name);
  }
  if (batch.isNotEmpty) batches.add(batch);

  Future<void> translateBatch(List<String> batch) async {
    if (!isCurrent()) return;
    final output = await request(batch.join('\n'));
    if (!isCurrent()) return;
    if (batch.length == 1) {
      final translation = _singleLine(output);
      if (translation.isEmpty) throw FormatException(invalidResponse);
      translations[batch.single] = translation;
      return;
    }
    final lines = output.replaceAll('\r\n', '\n').split('\n');
    if (lines.length != batch.length) {
      // A plain-text response can merge title boundaries. Retry smaller groups
      // only for malformed results, leaving request failures to the caller.
      final middle = batch.length ~/ 2;
      await translateBatch(batch.sublist(0, middle));
      await translateBatch(batch.sublist(middle));
      return;
    }
    for (var i = 0; i < batch.length; i++) {
      final translation = lines[i].trim();
      if (translation.isEmpty) {
        await translateBatch([batch[i]]);
      } else {
        translations[batch[i]] = translation;
      }
    }
  }

  for (var start = 0; start < batches.length; start += parallelism) {
    if (!isCurrent()) return null;
    await Future.wait([
      for (var i = start; i < batches.length && i < start + parallelism; i++)
        translateBatch(batches[i]),
    ]);
  }
  if (!isCurrent()) return null;
  return (
    title: translations[titleKey] ?? title,
    names: {
      for (final entry in namesByPath.entries)
        entry.key: translations[entry.value.stem]! + entry.value.extension,
    },
  );
}
