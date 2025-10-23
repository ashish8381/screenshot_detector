import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'screenshot_detector_platform_interface.dart';

/// An implementation of [ScreenshotDetectorPlatform] that uses method channels.
class MethodChannelScreenshotDetector extends ScreenshotDetectorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('screenshot_detector');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
