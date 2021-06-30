import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../globalUtilities.dart';

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
  final double wattHoursTotal;
  final double wattHoursRegenTotal;
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
    this.wattHoursTotal,
    this.wattHoursRegenTotal,
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
      'watt_hours' : wattHoursTotal,
      'watt_hours_regen' : wattHoursRegenTotal,
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
    //globalLogger.d("DatabaseAssistant: getDatabase: called");
    const migrationScripts = [
      '', //Version 1 not released
      '', //Version 2 not released
      '', //Version 3 initial beta release with onCreate
      'ALTER TABLE logs ADD COLUMN date_time INTEGER;', //Version 4 adds the ride time to schema for calendar view
      'ALTER TABLE logs ADD COLUMN watt_hours REAL;&&ALTER TABLE logs ADD COLUMN watt_hours_regen REAL;' //Version 5 adds watt_hours and watt_hours_regen
    ]; // Migration sql scripts

    return openDatabase(
      join(await getDatabasesPath(), 'logDatabase.db'), // Set the path to the database.
      onCreate: (db, version) async {
        final int dbCurrentVersion = await db.getVersion();
        globalLogger.d("DatabaseAssistant: getDatabase: openDatabase: onCreate() called. Version $version DBVersion $dbCurrentVersion");
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
              "watt_hours REAL, "
              "watt_hours_regen REAL, "
              "distance_km REAL, "
              "duration_seconds REAL, "
              "fault_count INTEGER, "
              "ride_name TEXT, "
              "notes TEXT)",
        );
      },
      onOpen: (db) async {
        //int version = await db.getVersion();
        //globalLogger.wtf("DatabaseAssistant: getDatabase: openDatabase: onOpen(). Version $version");
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        globalLogger.d("DatabaseAssistant: getDatabase: openDatabase: onUpgrade(): oldVersion $oldVersion -> newVersion $newVersion");
        for (var i = oldVersion; i < newVersion; ++i) {
          // Split migration script because you cannot execute multiple commands in one line =(
          List<String> migrationScriptCommands = migrationScripts[i].split("&&");
          migrationScriptCommands.forEach((element) async {
            await db.execute(element);
          });

          // Post process after SQL modifications
          switch(i) {
            case 3:
              globalLogger.d("onUpgrade adding missing date_time field to existing records");
              final List<Map<String, dynamic>> databaseEntries = await db.query('logs', columns: ['id','log_file_path']);
              databaseEntries.forEach((element) async {
                String dtString = element['log_file_path'].substring(element['log_file_path'].lastIndexOf("/") + 1, element['log_file_path'].lastIndexOf("/") + 20);
                DateTime thisDt = DateTime.parse(dtString);
                await db.execute('UPDATE logs SET date_time = ${thisDt.millisecondsSinceEpoch / 1000} WHERE id = ${element['id']};');
              });
              break;
            case 4:
              globalLogger.d("onUpgrade adding watt_hours, watt_hours_regen default values to existing records");
              await db.execute('UPDATE logs SET watt_hours = -1.0, watt_hours_regen = -1.0;');
              break;
          }
        }
      },
      // Set the version. This executes the onCreate function and provides a path to perform database upgrades and downgrades.
      version: 5,
    );
  }

  static Future<int> dbInsertLog(LogInfoItem logItem) async {
    final Database db = await getDatabase();
    int response = await db.insert('logs', logItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.close();
    return Future.value(response);
  }

  static Future<int> dbRemoveLog(String logFilePath) async {
    final Database db = await getDatabase();
    int response = await db.delete('logs', where: "log_file_path = '$logFilePath'");
    await db.close();
    return Future.value(response);
  }

  static Future<List<LogInfoItem>> dbSelectLogs({String orderByClause = "id DESC"}) async {
    final Database db = await getDatabase();
    final List<Map<String, dynamic>> rideLogEntries = await db.query('logs', orderBy: orderByClause);

    var response = List.generate(rideLogEntries.length, (i) {
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
          wattHoursTotal:  rideLogEntries[i]['watt_hours'],
          wattHoursRegenTotal: rideLogEntries[i]['watt_hours_regen'],
          distance:        rideLogEntries[i]['distance_km'],
          durationSeconds: rideLogEntries[i]['duration_seconds'].toInt(),
          faultCount:      rideLogEntries[i]['fault_count'],
          rideName:        rideLogEntries[i]['ride_name'],
          notes:           rideLogEntries[i]['notes']
      );
    });

    await db.close();
    return response;
  }

  static Future<int> dbUpdateNote( String file, String note ) async {
    final Database db = await getDatabase();
    int response = await db.update('logs', {'notes': note}, where: 'log_file_path = ?', whereArgs: [file]);
    await db.close();
    return Future.value(response);
  }

  static Future<int> dbAssociateVehicle( String deviceID, String newDeviceID ) async {
    final Database db = await getDatabase();
    globalLogger.wtf("db moving $deviceID records to $newDeviceID");
    int response = await db.update('logs', {'board_id': newDeviceID}, where: 'board_id = ?', whereArgs: [deviceID]);
    await db.close();
    return Future.value(response);
  }

  static Future<int> dbRemoveVehicle(String deviceID) async {
    final Database db = await getDatabase();
    int response = await db.delete('logs', where: 'board_id = ?', whereArgs: [deviceID]);
    await db.close();
    return Future.value(response);
  }

  static Future<double> dbGetOdometer(String boardID) async {
    final Database db = await getDatabase();
    double distance = 0;
    try {
      final List<Map<String, dynamic>> rideLogEntries = await db.query('logs', columns: ["distance_km"], where: "board_id = ?", whereArgs: [boardID]);

      rideLogEntries.forEach((element) {
        if (element['distance_km'] != -1.0) {
          distance += element['distance_km'];
        }
      });
      await db.close();
    } catch (e) {
      globalLogger.e(e);
    }

    return distance;
  }

  static Future<double> dbGetConsumption(String boardID, bool useImperial) async {
    final Database db = await getDatabase();
    final List<Map<String, dynamic>> rideLogEntries = await db.query('logs', columns: ["distance_km", "watt_hours", "watt_hours_regen"], where: "board_id = ?", whereArgs: [boardID]);
    double distance = 0;
    double wattHours = 0;

    rideLogEntries.forEach((element) {
      if (element['distance_km'] != -1.0 && element['watt_hours'] != -1.0) {
        distance += element['distance_km'];

        wattHours += element['watt_hours'] - element['watt_hours_regen'];
      }
    });
    await db.close();

    if (useImperial) {
      distance = kmToMile(distance);
    }
    double consumption = wattHours/ distance;

    if (consumption.isNaN || consumption.isInfinite) {
      consumption = 0;
    }
    //globalLogger.wtf("distance $distance wh $wattHours imperial $useImperial consumption $consumption");
    return consumption;
  }
}
