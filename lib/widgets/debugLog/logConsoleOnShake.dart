import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'debugLogBuffer.dart';
import 'logConsole.dart';
import 'shakeDetector.dart';

/// Wraps [child] and opens the [LogConsole] when the phone is shaken.
///
/// Shake detection is active only while [showOnShake] is true (and, when
/// [debugOnly] is set, only in debug builds).
class LogConsoleOnShake extends StatefulWidget {
  const LogConsoleOnShake({
    Key? key,
    required this.child,
    this.dark = false,
    this.debugOnly = true,
    this.showOnShake = true,
  }) : super(key: key);

  final Widget child;
  final bool dark;
  final bool debugOnly;
  final bool? showOnShake;

  @override
  State<LogConsoleOnShake> createState() => _LogConsoleOnShakeState();
}

class _LogConsoleOnShakeState extends State<LogConsoleOnShake> {
  ShakeDetector? _detector;
  bool _open = false;

  bool get _enabled => (widget.showOnShake ?? true) && (!widget.debugOnly || kDebugMode);

  @override
  void initState() {
    super.initState();
    DebugLogBuffer.install();
    _syncDetector();
  }

  @override
  void didUpdateWidget(LogConsoleOnShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDetector();
  }

  @override
  void dispose() {
    _detector?.stopListening();
    super.dispose();
  }

  void _syncDetector() {
    if (_enabled) {
      _detector ??= ShakeDetector(onPhoneShake: _openConsole);
      _detector!.startListening();
    } else {
      _detector?.stopListening();
    }
  }

  Future<void> _openConsole() async {
    if (_open || !mounted) return;
    _open = true;
    final console = LogConsole(dark: widget.dark, showCloseButton: true);
    final PageRoute<void> route = Platform.isIOS
        ? CupertinoPageRoute(builder: (_) => console)
        : MaterialPageRoute(builder: (_) => console);
    try {
      await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
