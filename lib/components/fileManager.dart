
import 'dart:io';

import '../components/logFileParser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class FileManager {

  static DateTime logFileStartTime;

  static Future<void> writeBytesToLogFile(List<int> bytes) async {
    final file = await _getTempLogFile();
    file.writeAsBytesSync(bytes, mode: FileMode.append);
  }

  static Future<void> writeToLogFile(String log) async {
    final file = await _getTempLogFile();
    file.writeAsStringSync(log, mode: FileMode.append);
  }

  static Future<String> readLogFile() async {
    final file = await _getTempLogFile();
    return file.readAsString();
  }

  static Future<File> _getTempLogFile() async {
    final temporaryDirectory = await getTemporaryDirectory();
    final file = File('${temporaryDirectory.path}/temp.log');
    if (!await file.exists()) {
      await file.writeAsString('');
    }
    return file;
  }

  static Future<void> clearLogFile() async {
    final file = await _getTempLogFile();
    await file.writeAsString('');
    logFileStartTime = DateTime.now();
  }

  static Future<String> saveLogToDocuments({String filename}) async {
    // Get temporary log file
    final file = await _getTempLogFile();
    // Convert binary data to CSV
    final fileParsed = await LogFileParser.parseFile(file);
    // Create file at final destination
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final newPath = "${documentsDirectory.path}/logs/${filename != null? filename: now.toIso8601String()}.csv";
    new File(newPath).create(recursive: true);
    // Copy CSV data to final destination
    await fileParsed.copy(newPath);
    //NOTE: return relative path as iOS updates will create new container UUIDs
    return "/logs/${filename != null ? filename : now.toIso8601String()}.csv";
  }

  static Future<void> createLogDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directoryPath = "${documentsDirectory.path}/logs/";
    await new Directory(directoryPath).create()
        .then((Directory directory) {
      print("createLogDirectory: created: ${directory.path}");
    });
  }

  static Future<String> debugAsset() async {
    return await rootBundle.loadString('assets/debug_logs/debug_user.csv');
  }

  static Future<String> openLogFile(String filepath) async {
    //NOTE: For Debugging: return debugAsset();
    final documentsDirectory = await getApplicationDocumentsDirectory();

    //TODO: no safety checking here. Opening file must be on device
    final file = File("${documentsDirectory.path}$filepath");
    return file.readAsString();
  }

  static Future<void> eraseLogFile(String filepath) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    //TODO: no safety checking here. Opening file must be on device
    final file = File("${documentsDirectory.path}$filepath");
    await file.delete();
  }
}
