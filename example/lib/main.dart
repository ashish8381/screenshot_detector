import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screenshot_watcher/screenshot_detector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _message = 'Try screenshot or screen recording.';
  StreamSubscription<SecurityEvent>? _eventsSubscription;
  StreamSubscription<SecurityEvent>? _alertsSubscription;

  @override
  void initState() {
    super.initState();
    _setupDetector();
  }

  Future<void> _setupDetector() async {
    await ScreenshotDetector.configure(
      enableScreenshotDetection: true,
      enableRecordingDetection: true,
      enableProtection: true,
      includeDeviceInfo: true,
      autoProtectSensitiveScreens: true,
      blurOnScreenshotDetected: true,
      onScreenshot: (event) {
        debugPrint('onScreenshot callback: ${event.toJson()}');
      },
      onRecordingStart: (event) {
        debugPrint('onRecordingStart callback: ${event.toJson()}');
      },
      onRecordingStop: (event) {
        debugPrint('onRecordingStop callback: ${event.toJson()}');
      },
    );

    ScreenshotDetector.setUserId('demo-user-42');
    await ScreenshotDetector.setCurrentScreen(
      name: 'PaymentScreen',
      type: 'payment',
      isSensitive: true,
    );

    if (!mounted) return;

    _alertsSubscription = ScreenshotDetector.attachDefaultAlerts(
      context,
      config: const SecurityAlertConfig(mode: SecurityAlertMode.snackbar),
    );

    _eventsSubscription = ScreenshotDetector.events.listen((event) {
      if (!mounted) return;

      setState(() {
        _message = 'Event: ${event.type.name} @ ${event.timestamp.toLocal()}';
      });
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _alertsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SecurityWatermark(
        config: const WatermarkConfig(
          name: 'Ashish',
          email: 'ashish@example.com',
          template: WatermarkTemplate.diagonalRepeating,
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Screenshot Detector')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _message,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text('Sensitive card area (per-widget protection):'),
                const SizedBox(height: 8),
                const ProtectedWidget(
                  blurOnRecording: true,
                  child: Card(
                    child: ListTile(
                      title: Text('Card Number'),
                      subtitle: Text('4111 1111 1111 1111'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final List<SecurityEvent> filtered =
                        ScreenshotDetector.filterEventHistory(
                          searchQuery: 'payment',
                        );

                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Filtered logs: ${filtered.length}'),
                      ),
                    );
                  },
                  child: const Text('Filter Logs'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
