
import Flutter
import UIKit

public class ScreenshotDetectorPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "screenshot_detector", binaryMessenger: registrar.messenger())
    let instance = ScreenshotDetectorPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    NotificationCenter.default.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) { _ in
        channel.invokeMethod("onScreenshot", arguments: nil)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // nothing to handle
    result(nil)
  }
}

