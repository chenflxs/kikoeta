// Tests live in checks/ in this project rather than Dart's conventional test/.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:win32/win32.dart';

import 'package:kikoeta_app/services/shortcut_service.dart';

String _readTarget(String path) {
  final hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr)) throw WindowsException(hr);
  try {
    final link = ShellLink.createInstance()..detach();
    try {
      final persist = IPersistFile.from(link)..detach();
      final name = path.toNativeUtf16();
      try {
        final result = persist.load(name, STGM_READ);
        if (FAILED(result)) throw WindowsException(result);
      } finally {
        calloc.free(name);
        persist.release();
        calloc.free(persist.ptr);
      }
      final target = calloc<Uint16>(MAX_PATH).cast<Utf16>();
      final findData = calloc<WIN32_FIND_DATA>();
      try {
        final result = link.getPath(target, MAX_PATH, findData, 0);
        if (FAILED(result)) throw WindowsException(result);
        return target.toDartString();
      } finally {
        calloc.free(target);
        calloc.free(findData);
      }
    } finally {
      link.release();
      calloc.free(link.ptr);
    }
  } finally {
    CoUninitialize();
  }
}

void main() {
  test(
    'Shell shortcuts run off UI and survive repeated apartment teardown',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kikoeta-shortcuts-',
      );
      final desktop = await Directory('${directory.path}/desktop').create();
      final programs = await Directory('${directory.path}/programs').create();
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      try {
        final exe = Platform.resolvedExecutable;
        for (var i = 0; i < 5; i++) {
          expect(
            await ShortcutService.createForTesting(
              exe,
              desktop.path,
              programs.path,
            ),
            isTrue,
          );
        }
        expect(ticks, greaterThan(0));
        for (final folder in [desktop, programs]) {
          final path = '${folder.path}/Kikoeta.lnk';
          expect(await Isolate.run(() => _readTarget(path)), exe);
        }
      } finally {
        timer.cancel();
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );

  test(
    'failed shortcut creation releases COM and next attempt succeeds',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kikoeta-shortcut-failure-',
      );
      try {
        final exe = Platform.resolvedExecutable;
        await expectLater(
          ShortcutService.createForTesting(
            exe,
            '${directory.path}/missing',
            directory.path,
          ),
          throwsA(isA<WindowsException>()),
        );
        expect(
          await ShortcutService.createForTesting(
            exe,
            directory.path,
            directory.path,
          ),
          isTrue,
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
    skip: !Platform.isWindows,
  );
}
