import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LogInfoItem {
  final DateTime dateTime;
  final String boardID;
  final String boardAlias;
  final String logFilePath;
  final double avgSpeed;
  final double maxSpeed;
  final double elevationChange;
  final double maxAmpsBattery;
  final double maxAmpsMotors;
  final double distance;
  final int    durationSeconds;
  final int    faultCount;
  final String rideName;
  final String notes;

  LogInfoItem({
    this.dateTime,
    this.boardID,
    this.boardAlias,
    this.logFilePath,
    this.avgSpeed,
    this.maxSpeed,
    this.elevationChange,
    this.maxAmpsBattery,
    this.maxAmpsMotors,
    this.distance,
    this.durationSeconds,
    this.faultCount,
    this.rideName,
    this.notes
  });

  // Convert a LogInfoItem into a map for the database
  // The keys correspond to the names of the columns in the database.
  Map<String, dynamic> toMap() {
    return {
      'date_time' : dateTime.millisecondsSinceEpoch / 1000,
      'board_id' : boardID,
      'board_alias' : boardAlias,
      'log_file_path' : logFilePath, //NOTE: relative path as iOS updates will create new container UUIDs
      'avg_speed' : avgSpeed,
      'max_speed' : maxSpeed,
      'elevation_change' : elevationChange,
      'max_amps_battery' : maxAmpsBattery,
      'max_amps_motors' : maxAmpsMotors,
      'distance_km' : distance,
      'duration_seconds' : durationSeconds,
      'fault_count' : faultCount,
      'ride_name' : rideName,
      'notes': notes,
    };
  }
}

class DatabaseAssistant {

  static Future<Database> getDatabase() async {
    //print("DatabaseAssistant: getDatabase: called");
    const migrationScripts = [
      '', //Version 1 not released
      '', //Version 2 not released
      '', //Version 3 initial beta release with onCreate
      'ALTER TABLE logs ADD COLUMN date_time INTEGER;', //Version 4 adds the ride time to schema for calendar view
    ]; // Migration sql scripts

    return openDatabase(
      join(await getDatabasesPath(), 'logDatabase.db'), // Set the path to the database.
      onCreate: (db, version) async {
        final int dbCurrentVersion = await db.getVersion();
        print("DatabaseAssistant: getDatabase: openDatabase: onCreate() called. Version $version DBVersion $dbCurrentVersion");
        // Create a table to store ride log details
        return db.execute(
          "CREATE TABLE IF NOT EXISTS logs("
              "id INTEGER PRIMARY KEY, "
              "date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP, "
              "date_time INTEGER, "
              "board_id TEXT, "
              "board_alias TEXT, "
              "log_file_path TEXT UNIQUE, "
              "avg_speed REAL, "
              "max_speed REAL, "
              "elevation_change REAL, "
              "max_amps_battery REAL, "
              "max_amps_motors REAL, "
              "distance_km REAL, "
              "duration_seconds REAL, "
              "fault_count INTEGER, "
              "ride_name TEXT, "
              "notes TEXT)",
        );
      },
      onOpen: (db) async {
        int version = await db.getVersion();
        print("DatabaseAssistant: getDatabase: openDatabase: onOpen(). Version $version");

        //TODO: remove this patch after everyone moves on from my mistake (0.7.0/0.7.1 did not set the date_time for new files in LogInfoItem.toMap())
        final List<Map<String, dynamic>> databaseEntries = await db.query('logs', columns: ['id','log_file_path','date_time'], where: 'date_time IS NULL');
        print(databaseEntries.toString());
        databaseEntries.forEach((element) async {
          print("renee was too excited and didn't bug test enough so now we are updating ${element['log_file_path']}");
          String dtString = element['log_file_path'].substring(element['log_file_path'].lastIndexOf("/") + 1, element['log_file_path'].lastIndexOf("/") + 20);
          DateTime thisDt = DateTime.parse(dtString);
          await db.execute('UPDATE logs SET date_time = ${thisDt.millisecondsSinceEpoch / 1000} WHERE id = ${element['id']};');
        });
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        print("DatabaseAssistant: getDatabase: openDatabase: onUpgrade(): oldVersion $oldVersion -> newVersion $newVersion");
        for (var i = oldVersion; i < newVersion; ++i) {
          await db.execute(migrationScripts[i]);

          // Post process after SQL modifications
          switch(i) {
            case 3:
              print("onUpgrade adding missing date_time field to existing records");
              final List<Map<String, dynamic>> databaseEntries = await db.query('logs', columns: ['id','log_file_path']);
              databaseEntries.forEach((element) async {
                String dtString = element['log_file_path'].substring(element['log_file_path'].lastIndexOf("/") + 1, element['log_file_path'].lastIndexOf("/") + 20);
                DateTime thisDt = DateTime.parse(dtString);
                await db.execute('UPDATE logs SET date_time = ${thisDt.millisecondsSinceEpoch / 1000} WHERE id = ${element['id']};');
              });
              break;
          }
        }
      },
      // Set the version. This executes the onCreate function and provides a path to perform database upgrades and downgrades.
      version: 4,
    );
  }

  static Future<int> dbInsertLog(LogInfoItem logItem) async {
    final Database db = await getDatabase();

    return db.insert('logs', logItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    //TODO: consider closing database// .then((value){db.close();return value;});
  }

  static Future<int> dbRemoveLog(String logFilePath) async {
    final Database db = await getDatabase();

    return db.delete('logs', where: "log_file_path = '$logFilePath'" );
  }

  static Future<List<LogInfoItem>> dbSelectLogs({String orderByClause = "id DESC"}) async {
    final Database db = await getDatabase();
    final List<Map<String, dynamic>> rideLogEntries = await db.query('logs', orderBy: orderByClause);

    return List.generate(rideLogEntries.length, (i) {
      return LogInfoItem(
          dateTime:        DateTime.fromMillisecondsSinceEpoch(rideLogEntries[i]['date_time'] * 1000),
          boardID:         rideLogEntries[i]['board_id'],
          boardAlias:      rideLogEntries[i]['board_alias'],
          logFilePath:     rideLogEntries[i]['log_file_path'],
          avgSpeed:        rideLogEntries[i]['avg_speed'],
          maxSpeed:        rideLogEntries[i]['max_speed'],
          elevationChange: rideLogEntries[i]['elevation_change'],
          maxAmpsBattery:  rideLogEntries[i]['max_amps_battery'],
          maxAmpsMotors:   rideLogEntries[i]['max_amps_motors'],
          distance:        rideLogEntries[i]['distance_km'],
          durationSeconds: rideLogEntries[i]['duration_seconds'].toInt(),
          faultCount:      rideLogEntries[i]['fault_count'],
          rideName:        rideLogEntries[i]['ride_name'],
          notes:           rideLogEntries[i]['notes']
      );
    });
  }
  
  static Future<int> dbUpdateNote( String file, String note ) async {
    final Database db = await getDatabase();
    return db.update('logs', {'notes': note}, where: 'log_file_path = ?', whereArgs: [file]);
  }
  
  static Future<void> close() async {
    final Database db = await getDatabase();
    await db.close();
  }
}