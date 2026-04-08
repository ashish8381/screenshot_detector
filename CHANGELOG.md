## Unreleased
- Added modular detection/protection configuration flags:
  - `enableScreenshotDetection`
  - `enableRecordingDetection`
  - `enableProtection`
- Added dedicated callback options in `configure(...)`:
  - `onScreenshot`
  - `onRecordingStart`
  - `onRecordingStop`
- Added built-in alert/UX layer:
  - `SecurityAlertConfig`
  - `SecurityAlertMode` (`silent`, `snackbar`, `dialog`, `toast`)
  - `attachDefaultAlerts(...)` helper
- Added watermark and UI protection widgets:
  - `SecurityWatermark` + `WatermarkConfig`
  - `ProtectedWidget` for per-widget blur protection
  - Watermark templates (`topBanner`, `bottomBanner`, `cornerTag`, `diagonalRepeating`)
- Added logs/history helpers:
  - `eventHistory`
  - `filterEventHistory(...)`
  - `clearEventHistory()`
  - `shareableLogs(...)` / `shareLogsViaPlatform(...)`

## 0.1.0
- Added unified `SecurityEvent` stream with screenshot + recording event types.
- Added smart context APIs (`setCurrentScreen`, sensitive screen tagging, rules engine).
- Added metadata support (timestamp, app state, optional device info, file path where available).
- Added protection controls:
  - Android `FLAG_SECURE` toggle for screenshot/screen-recording protection.
  - iOS blur/block protection overlay modes.
- Added event log export (`JSON` / `CSV`) and analytics dispatcher hook for backend/Firebase/REST integrations.
- Added backward compatibility via legacy `onScreenshot` stream.

## 0.0.2
- Improved null-safety and JS interop implementations.
- Cleanup unused example code and improved documentation.

## 0.0.1
- Initial release
- Detect screenshots on Android and iOS
