import Flutter
import UIKit

public class ScreenshotDetectorPlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var screenshotObserver: NSObjectProtocol?
  private var captureObserver: NSObjectProtocol?

  private var recordingProtectionMode: String = "off"
  private var protectionOverlay: UIView?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "screenshot_detector", binaryMessenger: registrar.messenger())
    let instance = ScreenshotDetectorPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(channel: FlutterMethodChannel) {
    super.init()
    self.channel = channel
    registerObservers()
  }

  deinit {
    removeObservers()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setScreenshotProtectionEnabled":
      // iOS does not offer a direct equivalent to Android FLAG_SECURE.
      result(nil)

    case "setScreenRecordingProtection":
      let arguments = call.arguments as? [String: Any]
      recordingProtectionMode = (arguments?["mode"] as? String) ?? "off"
      applyProtectionIfNeeded(force: true)
      result(nil)

    case "getDeviceInfo":
      let device = UIDevice.current
      result([
        "name": device.name,
        "model": device.model,
        "systemName": device.systemName,
        "systemVersion": device.systemVersion,
      ])

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func registerObservers() {
    screenshotObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      self.emitEvent(type: "screenshot", filePath: nil, raw: ["source": "ios_notification"])
      self.channel?.invokeMethod("onScreenshot", arguments: nil)
    }

    captureObserver = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }

      if UIScreen.main.isCaptured {
        self.emitEvent(type: "recordingStarted", filePath: nil, raw: ["source": "screen_capture_state"])
      } else {
        self.emitEvent(type: "recordingStopped", filePath: nil, raw: ["source": "screen_capture_state"])
      }

      self.applyProtectionIfNeeded(force: false)
    }
  }

  private func removeObservers() {
    if let screenshotObserver {
      NotificationCenter.default.removeObserver(screenshotObserver)
      self.screenshotObserver = nil
    }

    if let captureObserver {
      NotificationCenter.default.removeObserver(captureObserver)
      self.captureObserver = nil
    }
  }

  private func emitEvent(type: String, filePath: String?, raw: [String: Any]) {
    channel?.invokeMethod("onSecurityEvent", arguments: [
      "eventType": type,
      "timestamp": ISO8601DateFormatter().string(from: Date()),
      "platform": "ios",
      "filePath": filePath,
      "raw": raw,
    ])
  }

  private func applyProtectionIfNeeded(force: Bool) {
    guard let window = Self.keyWindow() else { return }

    if recordingProtectionMode == "off" {
      removeProtectionOverlay()
      return
    }

    // For recording protection, apply while capture is active. For force mode
    // (e.g. screenshot blur reaction), apply immediately.
    if !force && !UIScreen.main.isCaptured {
      removeProtectionOverlay()
      return
    }

    if protectionOverlay == nil {
      let overlay = makeProtectionView(mode: recordingProtectionMode)
      overlay.frame = window.bounds
      overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      window.addSubview(overlay)
      protectionOverlay = overlay
    }
  }

  private func removeProtectionOverlay() {
    protectionOverlay?.removeFromSuperview()
    protectionOverlay = nil
  }

  private func makeProtectionView(mode: String) -> UIView {
    if mode == "block" {
      let view = UIView(frame: .zero)
      view.backgroundColor = .black
      return view
    }

    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    blur.backgroundColor = UIColor.black.withAlphaComponent(0.15)
    return blur
  }

  private static func keyWindow() -> UIWindow? {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
    }

    return UIApplication.shared.keyWindow
  }
}
