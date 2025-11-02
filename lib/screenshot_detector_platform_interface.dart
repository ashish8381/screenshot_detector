import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'screenshot_detector_method_channel.dart';

abstract class ScreenshotDetectorPlatform extends PlatformInterface {
  /// Constructs a ScreenshotDetectorPlatform.
  ScreenshotDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static ScreenshotDetectorPlatform _instance =
      MethodChannelScreenshotDetector();

  /// The default instance of [ScreenshotDetectorPlatform] to use.
  ///
  /// Defaults to [MethodChannelScreenshotDetector].
  static ScreenshotDetectorPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ScreenshotDetectorPlatform] when
  /// they register themselves.
  static set instance(ScreenshotDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
