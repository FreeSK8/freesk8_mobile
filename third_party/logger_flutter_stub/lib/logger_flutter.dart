/// Minimal null-safe stub of package:logger_flutter for static analysis.
library logger_flutter;

import 'package:flutter/material.dart';

class LogConsoleOnShake extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}

class LogConsole extends StatelessWidget {
  const LogConsole({Key? key, this.dark = false, this.showCloseButton = false})
      : super(key: key);

  final bool dark;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
