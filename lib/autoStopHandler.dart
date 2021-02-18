import './globalUtilities.dart';

import 'dart:ui';

import 'package:flutter/material.dart';

class AutoStopHandler extends WidgetsBindingObserver {
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
        globalLogger.d("AppLifecycleState: Inactive");
        break;
      case AppLifecycleState.paused:
        globalLogger.d("AppLifecycleState: Paused");
        break;
      case AppLifecycleState.detached:
        globalLogger.d("AppLifecycleState: Detached");
        break;
      case AppLifecycleState.resumed:
        globalLogger.d("AppLifecycleState: Resumed");
        break;
    }
  }
}
