import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screenshot_detector/screenshot_detector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _message = 'Try taking a screenshot!';
  late final StreamSubscription _screenshotSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for screenshot events
    _screenshotSubscription =
        ScreenshotDetector.onScreenshot.listen((_) {
          // Check if the widget is still mounted
          if (!mounted) return;

          // Update UI
          setState(() {
            _message = 'Screenshot detected! 🚨';
          });

          // Show a Snackbar safely
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screenshot detected!'),
            ),
          );
        });
  }

  @override
  void dispose() {
    _screenshotSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Screenshot Detector'),
        ),
        body: Center(
          child: Text(
            _message,
            style: const TextStyle(fontSize: 20),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
