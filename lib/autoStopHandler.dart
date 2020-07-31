
import 'dart:ui';

import 'package:flutter/material.dart';

class AutoStopHandler extends WidgetsBindingObserver {
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
        print("AppLifecycleState: Inactive");
        break;
      case AppLifecycleState.paused:
        print("AppLifecycleState: Paused");
        break;
      case AppLifecycleState.detached:
        print("AppLifecycleState: Detached");
        break;
      case AppLifecycleState.resumed:
        print("AppLifecycleState: Resumed");
        break;
    }
  }
}
