import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:share_plus/share_plus.dart';

import 'debugLogBuffer.dart';

/// Full-screen viewer for the events captured by [DebugLogBuffer]: level
/// filter, text search, font size, share and clear.
class LogConsole extends StatefulWidget {
  const LogConsole({Key? key, this.dark = false, this.showCloseButton = false}) : super(key: key);

  final bool dark;
  final bool showCloseButton;

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  static final RegExp _ansiEscape = RegExp(r'\x1B\[[0-9;]*m');
  static const List<Level> _levels = [Level.trace, Level.debug, Level.info, Level.warning, Level.error, Level.fatal];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  StreamSubscription<void>? _changes;

  Level _minimumLevel = Level.trace;
  double _fontSize = 12;
  bool _followTail = true;

  @override
  void initState() {
    super.initState();
    DebugLogBuffer.install();
    _changes = DebugLogBuffer.changes.listen((_) {
      if (!mounted) return;
      setState(() {});
      if (_followTail) _scrollToEnd();
    });
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final atEnd = _scrollController.offset >= _scrollController.position.maxScrollExtent - 24;
      if (atEnd != _followTail) setState(() => _followTail = atEnd);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  @override
  void dispose() {
    _changes?.cancel();
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  static String plainText(OutputEvent event) => event.lines.map((line) => line.replaceAll(_ansiEscape, '')).join('\n');

  List<OutputEvent> get _visibleEvents {
    final needle = _filterController.text.trim().toLowerCase();
    return DebugLogBuffer.events.where((event) {
      if (event.level.value < _minimumLevel.value) return false;
      if (needle.isEmpty) return true;
      return plainText(event).toLowerCase().contains(needle);
    }).toList();
  }

  Color _levelColor(Level level, ColorScheme scheme) {
    switch (level) {
      case Level.trace:
        return scheme.onSurface.withValues(alpha: 0.6);
      case Level.debug:
        return scheme.onSurface;
      case Level.info:
        return Colors.lightBlueAccent;
      case Level.warning:
        return Colors.orangeAccent;
      case Level.error:
      case Level.fatal:
        return Colors.redAccent;
      default:
        return scheme.onSurface;
    }
  }

  Future<void> _share() async {
    final events = _visibleEvents;
    if (events.isEmpty) return;
    await SharePlus.instance.share(ShareParams(
      text: events.map(plainText).join('\n'),
      subject: 'FreeSK8 Debug Log',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.dark ? ThemeData.dark() : ThemeData.light();
    final events = _visibleEvents;
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debug Log'),
          automaticallyImplyLeading: widget.showCloseButton,
          actions: [
            IconButton(
              tooltip: 'Smaller text',
              icon: const Icon(Icons.remove),
              onPressed: _fontSize > 6 ? () => setState(() => _fontSize -= 1) : null,
            ),
            IconButton(
              tooltip: 'Larger text',
              icon: const Icon(Icons.add),
              onPressed: _fontSize < 24 ? () => setState(() => _fontSize += 1) : null,
            ),
            IconButton(
              tooltip: 'Share log',
              icon: const Icon(Icons.share),
              onPressed: events.isEmpty ? null : _share,
            ),
            IconButton(
              tooltip: 'Clear log',
              icon: const Icon(Icons.delete_outline),
              onPressed: DebugLogBuffer.clear,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _filterController,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Filter',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<Level>(
                    value: _minimumLevel,
                    items: [
                      for (final level in _levels)
                        DropdownMenuItem(value: level, child: Text(level.name.toUpperCase())),
                    ],
                    onChanged: (level) {
                      if (level != null) setState(() => _minimumLevel = level);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? const Center(child: Text('No log entries'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return SelectableText(
                          plainText(event),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: _fontSize,
                            color: _levelColor(event.level, theme.colorScheme),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: _followTail
            ? null
            : FloatingActionButton.small(
                tooltip: 'Jump to newest',
                onPressed: () {
                  setState(() => _followTail = true);
                  _scrollToEnd();
                },
                child: const Icon(Icons.arrow_downward),
              ),
      ),
    );
  }
}
