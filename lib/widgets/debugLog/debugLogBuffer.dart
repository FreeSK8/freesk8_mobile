import 'dart:async';
import 'dart:collection';

import 'package:logger/logger.dart';

/// In-memory ring buffer of the most recent [Logger] output, shared by every
/// [Logger] instance in the app through [Logger.addOutputListener].
///
/// Call [DebugLogBuffer.install] once (before `runApp`) so that output from
/// application start-up is captured; the console reads [events] and listens
/// to [changes] to refresh itself.
class DebugLogBuffer {
  DebugLogBuffer._();

  /// Number of log events retained.
  static const int capacity = 200;

  static final ListQueue<OutputEvent> _events = ListQueue<OutputEvent>(capacity);
  static final StreamController<void> _changes = StreamController<void>.broadcast();
  static bool _installed = false;

  /// Retained events, oldest first.
  static List<OutputEvent> get events => List<OutputEvent>.unmodifiable(_events);

  /// Fires after every event is added or the buffer is cleared.
  static Stream<void> get changes => _changes.stream;

  static bool get isInstalled => _installed;

  /// Starts capturing output from all loggers. Safe to call more than once.
  static void install() {
    if (_installed) return;
    _installed = true;
    Logger.addOutputListener(add);
  }

  /// Stops capturing (mainly for tests).
  static void uninstall() {
    if (!_installed) return;
    _installed = false;
    Logger.removeOutputListener(add);
  }

  /// Adds one event, dropping the oldest when the buffer is full.
  static void add(OutputEvent event) {
    while (_events.length >= capacity) {
      _events.removeFirst();
    }
    _events.add(event);
    _changes.add(null);
  }

  static void clear() {
    _events.clear();
    _changes.add(null);
  }
}
