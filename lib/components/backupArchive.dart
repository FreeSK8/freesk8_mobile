import 'dart:io';

import 'package:archive/archive_io.dart';

/// Writes a zip archive to [outputPath] containing every existing entry of
/// [directories] (recursively, keyed by directory name) and [files].
///
/// archive 4.x made `ZipFileEncoder`'s add and close methods asynchronous;
/// each step is awaited so the archive is never closed before its entries
/// have been written.
Future<File> createBackupArchive({
  required String outputPath,
  List<Directory> directories = const [],
  List<File> files = const [],
}) async {
  final encoder = ZipFileEncoder();
  encoder.create(outputPath);
  try {
    for (final directory in directories) {
      if (await directory.exists()) {
        await encoder.addDirectory(directory);
      }
    }
    for (final file in files) {
      if (await file.exists()) {
        await encoder.addFile(file);
      }
    }
  } finally {
    await encoder.close();
  }
  return File(outputPath);
}
