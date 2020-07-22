
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FileManager {

  static DateTime logFileStartTime;

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
    final file = File('${temporaryDirectory.path}/log.txt');
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
    final file = await _getTempLogFile();
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final newPath = "${documentsDirectory.path}/logs/${filename != null? filename: now.toIso8601String()}.csv";
    //print("saveLogToDocuments: New file path: $newPath");
    new File(newPath).create(recursive: true);
    await file.copy(newPath).then((value){
      //print("File copy returned: $value");
    });
    return newPath;
  }

  static Future<void> createLogDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directoryPath = "${documentsDirectory.path}/logs/";
    await new Directory(directoryPath).create()
        .then((Directory directory) {
      print("createLogDirectory: created: ${directory.path}");
    });
  }

  static Future<String> openLogFile(String filepath) async {
    //TODO: no safety checking here. Opening file must be on device
    final file = File(filepath);
    return file.readAsString();
  }

  static Future<void> eraseLogFile(String filepath) async {
    //TODO: no safety checking here. Opening file must be on device
    final file = File(filepath);
    await file.delete();
  }
}
