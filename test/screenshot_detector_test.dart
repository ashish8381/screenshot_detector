import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:screenshot_watcher/screenshot_detector_method_channel.dart';
import 'package:screenshot_watcher/screenshot_detector_platform_interface.dart';

class MockScreenshotDetectorPlatform
    with MockPlatformInterfaceMixin
    implements ScreenshotDetectorPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ScreenshotDetectorPlatform initialPlatform = ScreenshotDetectorPlatform.instance;

  test('$MethodChannelScreenshotDetector is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelScreenshotDetector>());
  });
}
