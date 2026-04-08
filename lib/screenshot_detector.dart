import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Types of security-relevant events reported by [ScreenshotDetector].
enum SecurityEventType { screenshot, recordingStarted, recordingStopped }

/// Protection mode used while screen recording is active or suspected.
enum ScreenProtectionMode { off, blur, block }

/// Built-in alert behavior for UI notifications.
enum SecurityAlertMode { silent, snackbar, dialog, toast }

/// Visual templates supported by [SecurityWatermark].
enum WatermarkTemplate { topBanner, bottomBanner, cornerTag, diagonalRepeating }

/// Context for the current app route/screen.
class ScreenContext {
  const ScreenContext({
    required this.name,
    required this.type,
    required this.isSensitive,
  });

  final String name;
  final String type;
  final bool isSensitive;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'type': type,
    'isSensitive': isSensitive,
  };
}

/// A normalized security event with metadata.
class SecurityEvent {
  const SecurityEvent({
    required this.type,
    required this.timestamp,
    required this.appState,
    required this.platform,
    this.filePath,
    this.userId,
    this.screen,
    this.deviceInfo,
    this.raw,
  });

  final SecurityEventType type;
  final DateTime timestamp;
  final String appState;
  final String platform;
  final String? filePath;
  final String? userId;
  final ScreenContext? screen;
  final Map<String, dynamic>? deviceInfo;
  final Map<String, dynamic>? raw;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'eventType': type.name,
    'timestamp': timestamp.toIso8601String(),
    'appState': appState,
    'platform': platform,
    'filePath': filePath,
    'userId': userId,
    'screen': screen?.toJson(),
    'deviceInfo': deviceInfo,
    'raw': raw,
  };

  static SecurityEventType parseType(String value) {
    switch (value) {
      case 'screenshot':
        return SecurityEventType.screenshot;
      case 'recordingStarted':
        return SecurityEventType.recordingStarted;
      case 'recordingStopped':
        return SecurityEventType.recordingStopped;
      default:
        return SecurityEventType.screenshot;
    }
  }
}

typedef SecurityEventRule = bool Function(SecurityEvent event);
typedef SecurityEventDispatcher = FutureOr<void> Function(SecurityEvent event);
typedef SecurityEventCallback = FutureOr<void> Function(SecurityEvent event);
typedef SecurityUiHandler =
    FutureOr<void> Function(
      BuildContext context,
      SecurityEvent event,
      String message,
    );
typedef WatermarkTextBuilder = String Function(DateTime now);

class SecurityAlertConfig {
  const SecurityAlertConfig({
    this.mode = SecurityAlertMode.silent,
    this.customMessageByType = const <SecurityEventType, String>{},
    this.customHandler,
  });

  final SecurityAlertMode mode;
  final Map<SecurityEventType, String> customMessageByType;
  final SecurityUiHandler? customHandler;
}

/// Configuration for watermark content and styling.
class WatermarkConfig {
  const WatermarkConfig({
    required this.name,
    this.email,
    this.showTimestamp = true,
    this.template = WatermarkTemplate.diagonalRepeating,
    this.opacity = 0.14,
    this.textColor = Colors.black,
    this.backgroundColor = Colors.transparent,
    this.customTextBuilder,
    this.refreshInterval = const Duration(seconds: 1),
  });

  final String name;
  final String? email;
  final bool showTimestamp;
  final WatermarkTemplate template;
  final double opacity;
  final Color textColor;
  final Color backgroundColor;
  final WatermarkTextBuilder? customTextBuilder;
  final Duration refreshInterval;

  String buildText(DateTime now) {
    if (customTextBuilder != null) {
      return customTextBuilder!(now);
    }

    final List<String> parts = <String>[name];
    if (email != null && email!.isNotEmpty) {
      parts.add(email!);
    }
    if (showTimestamp) {
      parts.add(now.toIso8601String());
    }

    return parts.join('  |  ');
  }
}

class ScreenshotDetector {
  static const MethodChannel _channel = MethodChannel('screenshot_detector');

  static final StreamController<SecurityEvent> _eventsController =
      StreamController<SecurityEvent>.broadcast();

  static bool _initialized = false;
  static bool _includeDeviceInfo = false;
  static bool _ignoreNonSensitiveScreens = false;
  static bool _autoProtectSensitiveScreens = false;
  static bool _blurOnScreenshotDetected = false;
  static bool _enableScreenshotDetection = true;
  static bool _enableRecordingDetection = true;
  static bool _enableProtection = false;
  static bool _recordingActive = false;
  static int _maxLogEntries = 1000;
  static String _appState = 'foreground';
  static String? _userId;
  static ScreenContext? _currentScreen;
  static SecurityEventDispatcher? _eventDispatcher;
  static SecurityEventCallback? _onScreenshotCallback;
  static SecurityEventCallback? _onRecordingStartCallback;
  static SecurityEventCallback? _onRecordingStopCallback;
  static final List<SecurityEventRule> _rules = <SecurityEventRule>[];
  static final List<SecurityEvent> _eventLog = <SecurityEvent>[];
  static final _ScreenshotLifecycleObserver _observer =
      _ScreenshotLifecycleObserver();

  static Stream<SecurityEvent> get events {
    _ensureInitialized();
    return _eventsController.stream;
  }

  static Stream<void> get onScreenshot {
    _ensureInitialized();
    return _eventsController.stream
        .where((event) => event.type == SecurityEventType.screenshot)
        .map((_) {});
  }

  static Stream<SecurityEvent> get onRecordingStart {
    _ensureInitialized();
    return _eventsController.stream.where(
      (event) => event.type == SecurityEventType.recordingStarted,
    );
  }

  static Stream<SecurityEvent> get onRecordingStop {
    _ensureInitialized();
    return _eventsController.stream.where(
      (event) => event.type == SecurityEventType.recordingStopped,
    );
  }

  static List<SecurityEvent> get eventHistory =>
      List<SecurityEvent>.unmodifiable(_eventLog);

  static bool get isRecordingActive => _recordingActive;

  /// Modular configuration requested by app developers.
  static Future<void> configure({
    bool includeDeviceInfo = false,
    bool ignoreNonSensitiveScreens = false,
    bool autoProtectSensitiveScreens = false,
    bool blurOnScreenshotDetected = false,
    bool enableScreenshotDetection = true,
    bool enableRecordingDetection = true,
    bool enableProtection = false,
    int maxLogEntries = 1000,
    SecurityEventDispatcher? dispatcher,
    SecurityEventCallback? onScreenshot,
    SecurityEventCallback? onRecordingStart,
    SecurityEventCallback? onRecordingStop,
  }) async {
    _ensureInitialized();
    _includeDeviceInfo = includeDeviceInfo;
    _ignoreNonSensitiveScreens = ignoreNonSensitiveScreens;
    _autoProtectSensitiveScreens = autoProtectSensitiveScreens;
    _blurOnScreenshotDetected = blurOnScreenshotDetected;
    _enableScreenshotDetection = enableScreenshotDetection;
    _enableRecordingDetection = enableRecordingDetection;
    _enableProtection = enableProtection;
    _maxLogEntries = maxLogEntries.clamp(50, 20000).toInt();
    _eventDispatcher = dispatcher;
    _onScreenshotCallback = onScreenshot;
    _onRecordingStartCallback = onRecordingStart;
    _onRecordingStopCallback = onRecordingStop;

    await setScreenshotProtectionEnabled(enabled: _enableProtection);
  }

  static void setUserId(String? userId) {
    _userId = userId;
  }

  static Future<void> setCurrentScreen({
    required String name,
    String type = 'custom',
    bool isSensitive = false,
  }) async {
    _ensureInitialized();
    _currentScreen = ScreenContext(
      name: name,
      type: type,
      isSensitive: isSensitive,
    );

    if (_enableProtection && _autoProtectSensitiveScreens) {
      await setScreenshotProtectionEnabled(enabled: isSensitive);
    }
  }

  static ScreenContext? get currentScreen => _currentScreen;

  static void addRule(SecurityEventRule rule) {
    _rules.add(rule);
  }

  static void clearRules() {
    _rules.clear();
  }

  static Future<void> setScreenshotProtectionEnabled({
    required bool enabled,
  }) async {
    _ensureInitialized();
    if (!_enableProtection && enabled) {
      return;
    }

    await _invokeSafely('setScreenshotProtectionEnabled', <String, dynamic>{
      'enabled': enabled,
    });
  }

  static Future<void> setScreenRecordingProtection({
    required ScreenProtectionMode mode,
  }) async {
    _ensureInitialized();
    if (!_enableProtection && mode != ScreenProtectionMode.off) {
      return;
    }

    await _invokeSafely('setScreenRecordingProtection', <String, dynamic>{
      'mode': mode.name,
    });
  }

  static Future<void> protectScreen({required bool enabled}) async {
    await setScreenshotProtectionEnabled(enabled: enabled);
  }

  static String exportLogsAsJson() {
    return jsonEncode(_eventLog.map((e) => e.toJson()).toList());
  }

  static String exportLogsAsCsv() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'eventType,timestamp,appState,platform,userId,screenName,screenType,isSensitive,filePath',
    );

    for (final event in _eventLog) {
      final String line = <String>[
        event.type.name,
        event.timestamp.toIso8601String(),
        event.appState,
        event.platform,
        event.userId ?? '',
        event.screen?.name ?? '',
        event.screen?.type ?? '',
        (event.screen?.isSensitive ?? false).toString(),
        event.filePath ?? '',
      ].map(_csvEscape).join(',');

      buffer.writeln(line);
    }

    return buffer.toString();
  }

  static List<SecurityEvent> filterEventHistory({
    SecurityEventType? type,
    String? searchQuery,
    DateTime? from,
    DateTime? to,
    bool sensitiveOnly = false,
  }) {
    final String normalizedQuery = searchQuery?.trim().toLowerCase() ?? '';

    return _eventLog
        .where((event) {
          if (type != null && event.type != type) {
            return false;
          }

          if (from != null && event.timestamp.isBefore(from)) {
            return false;
          }

          if (to != null && event.timestamp.isAfter(to)) {
            return false;
          }

          if (sensitiveOnly && !(event.screen?.isSensitive ?? false)) {
            return false;
          }

          if (normalizedQuery.isNotEmpty) {
            final String haystack = jsonEncode(event.toJson()).toLowerCase();
            if (!haystack.contains(normalizedQuery)) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: false);
  }

  static void clearEventHistory() {
    _eventLog.clear();
  }

  /// Returns a shareable content payload. Host app can pass this to `share_plus`.
  static String shareableLogs({bool csv = false}) {
    return csv ? exportLogsAsCsv() : exportLogsAsJson();
  }

  /// Optional native hook. Returns false on unsupported platforms.
  static Future<bool> shareLogsViaPlatform({bool csv = false}) async {
    _ensureInitialized();
    final dynamic result = await _invokeSafely('shareLogs', <String, dynamic>{
      'content': csv ? exportLogsAsCsv() : exportLogsAsJson(),
      'mimeType': csv ? 'text/csv' : 'application/json',
      'fileName': csv ? 'security_logs.csv' : 'security_logs.json',
    });

    return result == true;
  }

  static Future<void> emitManualEvent({
    required SecurityEventType type,
    String? filePath,
    Map<String, dynamic>? raw,
  }) async {
    final SecurityEvent event = SecurityEvent(
      type: type,
      timestamp: DateTime.now().toUtc(),
      appState: _appState,
      platform: _platformName,
      filePath: filePath,
      userId: _userId,
      screen: _currentScreen,
      raw: raw,
    );
    await _handleEvent(event);
  }

  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    _ensureInitialized();
    final dynamic response = await _invokeSafely('getDeviceInfo', null);
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return null;
  }

  static StreamSubscription<SecurityEvent> attachDefaultAlerts(
    BuildContext context, {
    SecurityAlertConfig config = const SecurityAlertConfig(),
  }) {
    _ensureInitialized();
    return events.listen((event) {
      // ignore: use_build_context_synchronously
      unawaited(showAlert(context, event, config: config));
    });
  }

  static Future<void> showAlert(
    BuildContext context,
    SecurityEvent event, {
    SecurityAlertConfig config = const SecurityAlertConfig(),
  }) async {
    if (config.mode == SecurityAlertMode.silent) {
      return;
    }

    final String message =
        config.customMessageByType[event.type] ?? _defaultMessageFor(event);

    if (config.customHandler != null) {
      await config.customHandler!(context, event, message);
      return;
    }

    if (!context.mounted) {
      return;
    }

    switch (config.mode) {
      case SecurityAlertMode.silent:
        return;
      case SecurityAlertMode.snackbar:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        return;
      case SecurityAlertMode.toast:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(left: 24, right: 24, bottom: 52),
          ),
        );
        return;
      case SecurityAlertMode.dialog:
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Security Alert'),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
    }
  }

  static void dispose() {
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(_observer);
      _channel.setMethodCallHandler(null);
      _initialized = false;
    }
    _currentScreen = null;
    _eventDispatcher = null;
    _onScreenshotCallback = null;
    _onRecordingStartCallback = null;
    _onRecordingStopCallback = null;
    _rules.clear();
    _eventLog.clear();
  }

  static void _ensureInitialized() {
    if (_initialized) {
      return;
    }

    WidgetsBinding.instance.addObserver(_observer);
    _observer.onStateChanged = (String state) {
      _appState = state;
    };

    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onScreenshot') {
        final SecurityEvent event = SecurityEvent(
          type: SecurityEventType.screenshot,
          timestamp: DateTime.now().toUtc(),
          appState: _appState,
          platform: _platformName,
          userId: _userId,
          screen: _currentScreen,
          raw: const <String, dynamic>{'legacy': true},
        );
        await _handleEvent(event);
        return;
      }

      if (call.method != 'onSecurityEvent') {
        return;
      }

      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        (call.arguments as Map?) ?? const <String, dynamic>{},
      );

      final DateTime timestamp =
          DateTime.tryParse(payload['timestamp']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc();

      final SecurityEvent event = SecurityEvent(
        type: SecurityEvent.parseType(payload['eventType']?.toString() ?? ''),
        timestamp: timestamp,
        appState: _appState,
        platform: payload['platform']?.toString() ?? _platformName,
        filePath: payload['filePath']?.toString(),
        userId: _userId,
        screen: _currentScreen,
        deviceInfo: _includeDeviceInfo ? await getDeviceInfo() : null,
        raw: payload,
      );

      await _handleEvent(event);
    });

    _initialized = true;
  }

  static Future<void> _handleEvent(SecurityEvent event) async {
    if (event.type == SecurityEventType.screenshot &&
        !_enableScreenshotDetection) {
      return;
    }

    if ((event.type == SecurityEventType.recordingStarted ||
            event.type == SecurityEventType.recordingStopped) &&
        !_enableRecordingDetection) {
      return;
    }

    if (event.type == SecurityEventType.recordingStarted) {
      _recordingActive = true;
    }

    if (event.type == SecurityEventType.recordingStopped) {
      _recordingActive = false;
    }

    if (_ignoreNonSensitiveScreens &&
        _currentScreen != null &&
        !_currentScreen!.isSensitive) {
      return;
    }

    for (final SecurityEventRule rule in _rules) {
      if (!rule(event)) {
        return;
      }
    }

    _eventLog.add(event);
    if (_eventLog.length > _maxLogEntries) {
      _eventLog.removeRange(0, _eventLog.length - _maxLogEntries);
    }

    _eventsController.add(event);

    if (_blurOnScreenshotDetected &&
        event.type == SecurityEventType.screenshot &&
        (_currentScreen?.isSensitive ?? false)) {
      await setScreenRecordingProtection(mode: ScreenProtectionMode.blur);
      Future<void>.delayed(
        const Duration(milliseconds: 1200),
        () => setScreenRecordingProtection(mode: ScreenProtectionMode.off),
      );
    }

    switch (event.type) {
      case SecurityEventType.screenshot:
        if (_onScreenshotCallback != null) {
          await _onScreenshotCallback!(event);
        }
        break;
      case SecurityEventType.recordingStarted:
        if (_onRecordingStartCallback != null) {
          await _onRecordingStartCallback!(event);
        }
        break;
      case SecurityEventType.recordingStopped:
        if (_onRecordingStopCallback != null) {
          await _onRecordingStopCallback!(event);
        }
        break;
    }

    if (_eventDispatcher != null) {
      await _eventDispatcher!(event);
    }
  }

  static Future<dynamic> _invokeSafely(
    String method,
    Map<String, dynamic>? arguments,
  ) async {
    try {
      return await _channel.invokeMethod<dynamic>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static String _defaultMessageFor(SecurityEvent event) {
    switch (event.type) {
      case SecurityEventType.screenshot:
        return 'Screenshot detected on ${event.screen?.name ?? 'current screen'}.';
      case SecurityEventType.recordingStarted:
        return 'Screen recording started.';
      case SecurityEventType.recordingStopped:
        return 'Screen recording stopped.';
    }
  }

  static String _csvEscape(String value) {
    if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  static String get _platformName => defaultTargetPlatform.name;
}

class _ScreenshotLifecycleObserver with WidgetsBindingObserver {
  void Function(String state)? onStateChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onStateChanged?.call('foreground');
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        onStateChanged?.call('background');
        break;
    }
  }
}

/// Adds a dynamic watermark layer over [child].
class SecurityWatermark extends StatefulWidget {
  /// Creates a watermark wrapper with the provided [config].
  const SecurityWatermark({
    super.key,
    required this.child,
    required this.config,
  });

  /// The protected content.
  final Widget child;

  /// Watermark behavior and style.
  final WatermarkConfig config;

  @override
  State<SecurityWatermark> createState() => _SecurityWatermarkState();
}

class _SecurityWatermarkState extends State<SecurityWatermark> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(widget.config.refreshInterval, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.config.buildText(_now);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        IgnorePointer(
          child: _WatermarkLayer(config: widget.config, text: text),
        ),
      ],
    );
  }
}

class _WatermarkLayer extends StatelessWidget {
  const _WatermarkLayer({required this.config, required this.text});

  final WatermarkConfig config;
  final String text;

  @override
  Widget build(BuildContext context) {
    switch (config.template) {
      case WatermarkTemplate.topBanner:
        return Align(alignment: Alignment.topCenter, child: _banner());
      case WatermarkTemplate.bottomBanner:
        return Align(alignment: Alignment.bottomCenter, child: _banner());
      case WatermarkTemplate.cornerTag:
        return Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: config.backgroundColor.withValues(alpha: config.opacity),
            child: _textWidget(),
          ),
        );
      case WatermarkTemplate.diagonalRepeating:
        return LayoutBuilder(
          builder: (_, constraints) {
            final int rows = (constraints.maxHeight / 80).ceil();
            return Transform.rotate(
              angle: -0.45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List<Widget>.generate(rows, (index) {
                  return Opacity(
                    opacity: config.opacity,
                    child: Text(
                      '$text   $text   $text',
                      style: TextStyle(
                        color: config.textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        );
    }
  }

  Widget _banner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: config.backgroundColor.withValues(alpha: config.opacity),
      child: Center(child: _textWidget()),
    );
  }

  Widget _textWidget() {
    return Opacity(
      opacity: config.opacity,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: config.textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Per-widget protection helper for sensitive UI components.
///
/// This widget can blur content after a screenshot event and while recording.
class ProtectedWidget extends StatefulWidget {
  /// Creates a protected wrapper around [child].
  const ProtectedWidget({
    super.key,
    required this.child,
    this.enabled = true,
    this.blurOnRecording = true,
    this.blurOnScreenshotFor = const Duration(milliseconds: 1200),
    this.blurSigma = 8,
    this.placeholder,
  });

  /// The content that may be blurred for protection.
  final Widget child;

  /// Whether protection behavior is enabled for this widget.
  final bool enabled;

  /// Whether to blur while a recording session is active.
  final bool blurOnRecording;

  /// How long to blur after a screenshot event is detected.
  final Duration blurOnScreenshotFor;

  /// Blur intensity applied on both axes.
  final double blurSigma;

  /// Optional overlay displayed while blur is active.
  final Widget? placeholder;

  @override
  State<ProtectedWidget> createState() => _ProtectedWidgetState();
}

class _ProtectedWidgetState extends State<ProtectedWidget> {
  StreamSubscription<SecurityEvent>? _subscription;
  bool _blurredByScreenshot = false;

  @override
  void initState() {
    super.initState();
    _subscription = ScreenshotDetector.events.listen((event) {
      if (!widget.enabled) {
        return;
      }

      if (event.type == SecurityEventType.screenshot) {
        setState(() {
          _blurredByScreenshot = true;
        });

        Future<void>.delayed(widget.blurOnScreenshotFor, () {
          if (!mounted) {
            return;
          }
          setState(() {
            _blurredByScreenshot = false;
          });
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldBlur =
        widget.enabled &&
        (_blurredByScreenshot ||
            (widget.blurOnRecording && ScreenshotDetector.isRecordingActive));

    if (!shouldBlur) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
            ),
            child: widget.child,
          ),
        ),
        if (widget.placeholder != null)
          Positioned.fill(child: widget.placeholder!),
      ],
    );
  }
}
