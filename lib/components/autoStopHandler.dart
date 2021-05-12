import '../globalUtilities.dart';

import 'dart:ui';

import 'package:flutter/material.dart';

class AutoStopHandler extends WidgetsBindingObserver {
  static bool _unexpectedDisconnect;
  static ValueChanged<int> _delayedTabControllerIndexChange;

  @override
  AutoStopHandler(ValueChanged<int> tabChangeFunc, bool unexpectedDisconnect)
  {
    _delayedTabControllerIndexChange = tabChangeFunc;
    _unexpectedDisconnect = unexpectedDisconnect;
  }

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
        // If the application has disconnected in the background we
        // need to navigate back to the connection tab upon resuming
        if (_unexpectedDisconnect) {
          globalLogger.d("AppLifecycleState: Navigating to Connection tab (unexpectedDisconnect)");
          _delayedTabControllerIndexChange(controllerViewConnection);
        }
        break;
    }
  }
}
