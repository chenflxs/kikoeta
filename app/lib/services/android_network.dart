import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../src/rust/api/simple.dart';

class AndroidNetwork {
  AndroidNetwork._();

  static const _channel = MethodChannel('kikoeta/network');

  static void init() {
    if (kIsWeb || !Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'defaultNetworkChanged') {
        throw MissingPluginException(call.method);
      }
      notifyDefaultNetworkChanged();
    });
  }
}
