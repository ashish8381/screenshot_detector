import 'dart:async';
import 'package:flutter/services.dart';

class ScreenshotDetector {
  static const MethodChannel _channel = MethodChannel('screenshot_detector');

  static StreamController<void>? _screenshotController;

  /// Listen for screenshots
  static Stream<void> get onScreenshot {
    _screenshotController ??= StreamController<void>.broadcast();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onScreenshot') {
        _screenshotController?.add(null);
      }
    });
    return _screenshotController!.stream;
  }
}
