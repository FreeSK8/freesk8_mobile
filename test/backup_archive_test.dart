// Regression test: the data backup zip must contain every file that was added.
// archive 4.x made ZipFileEncoder asynchronous; closing before the adds
// completed produced an empty archive.
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:freesk8_mobile/components/backupArchive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('freesk8_backup_test');
    await Directory('${tmp.path}/logs').create();
    await Directory('${tmp.path}/avatars').create();
    await File('${tmp.path}/logs/ride.csv').writeAsString('a,b,c\n1,2,3\n');
    await File('${tmp.path}/avatars/board.png').writeAsBytes(List<int>.filled(64, 7));
    await File('${tmp.path}/logDatabase.db').writeAsBytes(List<int>.filled(128, 1));
    await File('${tmp.path}/settings.json').writeAsString('{"ok":true}');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('createBackupArchive writes every directory entry and file', () async {
    final zip = await createBackupArchive(
      outputPath: '${tmp.path}/backup.zip',
      directories: [
        Directory('${tmp.path}/logs'),
        Directory('${tmp.path}/avatars'),
        Directory('${tmp.path}/does-not-exist'),
      ],
      files: [
        File('${tmp.path}/logDatabase.db'),
        File('${tmp.path}/settings.json'),
        File('${tmp.path}/missing.txt'),
      ],
    );

    expect(await zip.exists(), isTrue);
    final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final entries = {
      for (final f in archive.files.where((f) => f.isFile)) f.name: f.size,
    };

    expect(entries.keys, containsAll(<String>[
      'logs/ride.csv',
      'avatars/board.png',
      'logDatabase.db',
      'settings.json',
    ]));
    expect(entries.length, 4);
    for (final size in entries.values) {
      expect(size, greaterThan(0));
    }
  });
}
