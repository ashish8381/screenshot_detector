# screenshot_detector

A Flutter plugin to detect screenshots on Android and iOS.

## Usage

```dart
import 'package:screenshot_detector/screenshot_detector.dart';

ScreenshotDetector.onScreenshot.listen((_) {
  print("Screenshot captured!");
});



- Add a simple `CHANGELOG.md`:

```markdown
# Changelog

## 0.0.1
- Initial release
- Detect screenshots on Android and iOS
