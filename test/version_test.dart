// Keeps the version shown in the app in step with pubspec.yaml and with the
// CI tag guard (.github/workflows/android-release.yml).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/main.dart freeSK8ApplicationVersion matches pubspec version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final versionLine = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
    expect(versionLine, isNotNull, reason: 'pubspec.yaml has no version: line');
    final versionName = versionLine!.group(1)!.split('+').first;

    final main = File('lib/main.dart').readAsStringSync();
    final constant = RegExp(r'^const String freeSK8ApplicationVersion = "([^"]+)";', multiLine: true).firstMatch(main);
    expect(constant, isNotNull, reason: 'lib/main.dart has no freeSK8ApplicationVersion constant');

    expect(constant!.group(1), versionName);
  });
}
