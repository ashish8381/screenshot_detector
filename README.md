# screenshot_detector

`screenshot_watcher` is a Flutter plugin for screenshot/screen-recording detection, protection, watermarking, and security event logging.

## Install

```yaml
dependencies:
  screenshot_watcher: ^0.1.0
```

## Highlights

- Screenshot detection (real-time event stream)
- Screen recording start/stop detection (platform support dependent)
- Foreground/background app state tagging
- Screen protection controls (`FLAG_SECURE` on Android, overlay modes on iOS)
- Smart screen context tagging (`name`, `type`, `isSensitive`)
- Rules engine for filtering events
- Dynamic watermark overlay with templates
- Per-widget blur protection (`ProtectedWidget`)
- Built-in alerts: silent/snackbar/dialog/toast
- Local event history, filtering, and JSON/CSV export

## Quick Start

```dart
import 'package:screenshot_watcher/screenshot_detector.dart';

Future<void> setupSecurity() async {
  await ScreenshotDetector.configure(
    enableScreenshotDetection: true,
    enableRecordingDetection: true,
    enableProtection: true,
    includeDeviceInfo: true,
    autoProtectSensitiveScreens: true,
    blurOnScreenshotDetected: true,
    onScreenshot: (event) async {
      // Custom callback
    },
    onRecordingStart: (event) async {},
    onRecordingStop: (event) async {},
  );

  ScreenshotDetector.setUserId('user_123');

  await ScreenshotDetector.setCurrentScreen(
    name: 'PaymentScreen',
    type: 'payment',
    isSensitive: true,
  );

  ScreenshotDetector.events.listen((event) {
    // screenshot / recordingStarted / recordingStopped
  });
}
```

## Detection API

- `ScreenshotDetector.events`
- `ScreenshotDetector.onScreenshot`
- `ScreenshotDetector.onRecordingStart`
- `ScreenshotDetector.onRecordingStop`
- `ScreenshotDetector.emitManualEvent(...)` (useful for custom Web/Desktop integrations)

## Protection API

- `ScreenshotDetector.setScreenshotProtectionEnabled(enabled: true)`
- `ScreenshotDetector.setScreenRecordingProtection(mode: ScreenProtectionMode.blur|block|off)`
- `ScreenshotDetector.protectScreen(enabled: true)`

## Smart Context + Rules

- `ScreenshotDetector.setCurrentScreen(name:, type:, isSensitive:)`
- `ScreenshotDetector.addRule((event) => true/false)`
- `ScreenshotDetector.clearRules()`

## Alerts & UX

```dart
final sub = ScreenshotDetector.attachDefaultAlerts(
  context,
  config: const SecurityAlertConfig(
    mode: SecurityAlertMode.snackbar,
  ),
);
```

Modes:
- `SecurityAlertMode.silent`
- `SecurityAlertMode.snackbar`
- `SecurityAlertMode.dialog`
- `SecurityAlertMode.toast`

You can also provide custom messages and custom UI handlers via `SecurityAlertConfig`.

## Watermark & Per-Widget Protection

```dart
SecurityWatermark(
  config: const WatermarkConfig(
    name: 'Ashish',
    email: 'ashish@example.com',
    template: WatermarkTemplate.diagonalRepeating,
    showTimestamp: true,
  ),
  child: const ProtectedWidget(
    blurOnRecording: true,
    child: Text('Sensitive content'),
  ),
)
```

Watermark templates:
- `topBanner`
- `bottomBanner`
- `cornerTag`
- `diagonalRepeating`

## Logs & History

- `ScreenshotDetector.eventHistory`
- `ScreenshotDetector.filterEventHistory(...)`
- `ScreenshotDetector.clearEventHistory()`
- `ScreenshotDetector.exportLogsAsJson()`
- `ScreenshotDetector.exportLogsAsCsv()`
- `ScreenshotDetector.shareableLogs(csv: true/false)`

## Platform Notes

- Android:
  - Screenshot detection via media observer
  - `FLAG_SECURE` support
  - Recording callback support on newer Android versions
- iOS:
  - Screenshot notification support
  - Screen capture change detection
  - Blur/block overlay modes
- Web/Desktop:
  - Dart APIs are available
  - Native screenshot/recording detection is not universally available; use `emitManualEvent(...)` or host-level integration where needed

## Example

See:
- `example/lib/main.dart`
