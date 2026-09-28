import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'package:freesk8_mobile/widgets/debugLog/debugLogBuffer.dart';

OutputEvent event(Level level, String text) => OutputEvent(LogEvent(level, text), [text]);

void main() {
  setUp(DebugLogBuffer.clear);

  test('keeps at most capacity events, oldest dropped first', () {
    for (var i = 0; i < DebugLogBuffer.capacity + 25; i++) {
      DebugLogBuffer.add(event(Level.debug, 'line $i'));
    }
    final events = DebugLogBuffer.events;
    expect(events.length, DebugLogBuffer.capacity);
    expect(events.first.lines.single, 'line 25');
    expect(events.last.lines.single, 'line ${DebugLogBuffer.capacity + 24}');
  });

  test('install captures output from any Logger and changes stream fires', () async {
    DebugLogBuffer.install();
    addTearDown(DebugLogBuffer.uninstall);
    final fired = DebugLogBuffer.changes.first;
    final logger = Logger(printer: SimplePrinter(colors: false), filter: ProductionFilter());
    logger.w('hello from test');
    await fired.timeout(const Duration(seconds: 1));
    expect(DebugLogBuffer.events.last.level, Level.warning);
    expect(DebugLogBuffer.events.last.lines.join(), contains('hello from test'));
  });
}
