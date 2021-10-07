import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../globalUtilities.dart';

class LogInfoItem {
  final DateTime dateTime;
  final String boardID;
  final String boardAlias;
  final String logFilePath;
  final double avgMovingSpeed;
  final double avgMovingSpeedGPS;
  final double avgSpeed;
  final double avgSpeedGPS;
  final double maxSpeed;
  final double maxSpeedGPS;
  final double altitudeMax;
  final double altitudeMin;
  final double maxAmpsBattery;
  final double maxAmpsMotors;
  final double wattHoursTotal;
  final double wattHoursRegenTotal;
  final double distance;
  final double distanceGPS;
  final int    durationSeconds;
  final int    faultCount;
  final String rideName;
  final String notes;

  LogInfoItem({
    this.dateTime,
    this.boardID,
    this.boardAlias,
    this.logFilePath,
    this.avgMovingSpeed,
    this.avgMovingSpeedGPS,
    this.avgSpeed,
    this.avgSpeedGPS,
    this.maxSpeed,
    this.maxSpeedGPS,
    this.altitudeMax,
    this.altitudeMin,
    this.maxAmpsBattery,
    this.maxAmpsMotors,
    this.wattHoursTotal,
    this.wattHoursRegenTotal,
    this.distance,
    this.distanceGPS,
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
      'avg_moving_speed' : avgMovingSpeed,
      'avg_moving_speed_gps' : avgMovingSpeedGPS,
      'avg_speed' : avgSpeed,
      'avg_speed_gps' : avgSpeedGPS,
      'max_speed' : maxSpeed,
      'max_speed_gps' : maxSpeedGPS,
      'altitude_max' : altitudeMax,
      'altitude_min' : altitudeMin,
      'max_amps_battery' : maxAmpsBattery,
      'max_amps_motors' : maxAmpsMotors,
      'watt_hours' : wattHoursTotal,
      'watt_hours_regen' : wattHoursRegenTotal,
      'distance_km' : distance,
      'distance_km_gps' : distanceGPS,
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
      'ALTER TABLE logs ADD COLUMN watt_hours REAL;&&ALTER TABLE logs ADD COLUMN watt_hours_regen REAL;', //Version 5 adds watt_hours and watt_hours_regen
      //Version 6 adds max_speed_gps, avg_speed_gps, distance_km_gps, altitude_min, altitude_max, avg_moving_speed, avg_moving_speed_gps
      //          Removes elevation_change
      //NOTE: sqflite does not do DROP: `ALTER TABLE logs DROP COLUMN elevation_change;&&` will not execute successfully
      'ALTER TABLE logs ADD COLUMN max_speed_gps REAL;&&ALTER TABLE logs ADD COLUMN avg_speed_gps REAL;&&ALTER TABLE logs ADD COLUMN distance_km_gps REAL;&&ALTER TABLE logs ADD COLUMN altitude_min REAL;&&ALTER TABLE logs ADD COLUMN altitude_max REAL;&&ALTER TABLE logs ADD COLUMN avg_moving_speed REAL;&&ALTER TABLE logs ADD COLUMN avg_moving_speed_gps REAL;',
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
              "avg_moving_speed REAL, "
              "avg_moving_speed_gps REAL, "
              "avg_speed REAL, "
              "avg_speed_gps REAL, "
              "max_speed REAL, "
              "max_speed_gps REAL, "
              "altitude_min REAL, "
              "altitude_max REAL, "
              "max_amps_battery REAL, "
              "max_amps_motors REAL, "
              "watt_hours REAL, "
              "watt_hours_regen REAL, "
              "distance_km REAL, "
              "distance_km_gps REAL, "
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
            globalLogger.d("Executing $element");
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
            case 5:
              globalLogger.d("onUpgrade adding max_speed_gps, avg_speed_gps, distance_km_gps, altitude_min, altitude_max, avg_moving_speed, avg_moving_speed_gps");
              await db.execute("UPDATE logs SET max_speed_gps = -1.0, avg_speed_gps = -1.0, distance_km_gps = -1.0, altitude_min = -1.0, altitude_max = -1.0, avg_moving_speed = -1.0, avg_moving_speed_gps = -1.0;");
              break;
          }
        }
      },
      // Set the version. This executes the onCreate function and provides a path to perform database upgrades and downgrades.
      version: 6,
    );
  }

  static Future<int> dbInsertLog(LogInfoItem logItem) async {
    final Database db = await getDatabase();
    int response = await db.insert('logs', logItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.close();
    return Future.value(response);
  }

  static Future<int> dbUpdateLog(LogInfoItem logItem) async {
    final Database db = await getDatabase();
    int response = await db.update('logs', logItem.toMap(), where: 'log_file_path = ?', whereArgs: [logItem.logFilePath]);
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
          avgMovingSpeed:  rideLogEntries[i]['avg_moving_speed'],
          avgMovingSpeedGPS: rideLogEntries[i]['avg_moving_speed_gps'],
          avgSpeed:        rideLogEntries[i]['avg_speed'],
          avgSpeedGPS:     rideLogEntries[i]['avg_speed_gps'],
          maxSpeed:        rideLogEntries[i]['max_speed'],
          maxSpeedGPS:     rideLogEntries[i]['max_speed_gps'],
          altitudeMax:     rideLogEntries[i]['altitude_max'],
          altitudeMin:     rideLogEntries[i]['altitude_min'],
          maxAmpsBattery:  rideLogEntries[i]['max_amps_battery'],
          maxAmpsMotors:   rideLogEntries[i]['max_amps_motors'],
          wattHoursTotal:  rideLogEntries[i]['watt_hours'],
          wattHoursRegenTotal: rideLogEntries[i]['watt_hours_regen'],
          distance:        rideLogEntries[i]['distance_km'],
          distanceGPS:        rideLogEntries[i]['distance_km_gps'],
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

  static Future<double> dbGetOdometer(String boardID, bool preferGPS) async {
    final Database db = await getDatabase();
    double distance = 0;
    try {
      final String columnName = preferGPS ? "distance_km_gps" : "distance_km";
      final List<Map<String, dynamic>> rideLogEntries = await db.query('logs', columns: [columnName], where: "board_id = ?", whereArgs: [boardID]);

      rideLogEntries.forEach((element) {
        if (element[columnName] != -1.0) {
          distance += element[columnName];
        }
      });
      await db.close();
    } catch (e) {
      globalLogger.e(e);
    }

    return distance;
  }

  static Future<double> dbGetConsumption(String boardID, bool useImperial, bool preferGPS) async {
    final String columnName = preferGPS ? "distance_km_gps" : "distance_km";
    final Database db = await getDatabase();
    final List<Map<String, dynamic>> rideLogEntries = await db.query('logs', columns: [columnName, "watt_hours", "watt_hours_regen"], where: "board_id = ?", whereArgs: [boardID]);
    double distance = 0;
    double wattHours = 0;

    rideLogEntries.forEach((element) {
      if (element[columnName] != -1.0 && element['watt_hours'] != -1.0) {
        distance += element[columnName];

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

  static Future<double> getMaxValue(String boardID, String columnName) async {
    final Database db = await getDatabase();
    final List<Map<String, dynamic>> dbResults = await db.query('logs', columns: [columnName], where: "board_id = ?", whereArgs: [boardID]);
    double maxValue = 0;
    dbResults.forEach((element) {
      if (element[columnName] > maxValue) maxValue = element[columnName];
    });
    await db.close();
    return maxValue;
  }

  static Future<double> getTrendingValue(String boardID, String columnName, Duration window, DateTime moment, DateTime previousMoment, bool averageValue) async {
    final Database db = await getDatabase();
    final List<Map<String, dynamic>> dbResultsEarlier = await db.query('logs', columns: [columnName], where: "board_id = ? AND date_time BETWEEN ? AND ?", whereArgs: [boardID, previousMoment.millisecondsSinceEpoch / 1000 - window.inSeconds, previousMoment.millisecondsSinceEpoch / 1000]);
    final List<Map<String, dynamic>> dbResultsLater = await db.query('logs', columns: [columnName], where: "board_id = ? AND date_time BETWEEN ? AND ?", whereArgs: [boardID, moment.millisecondsSinceEpoch / 1000 - window.inSeconds, moment.millisecondsSinceEpoch / 1000]);

    double totalEarlier = 0;
    int earlierCount = 0;
    dbResultsEarlier.forEach((element) {
      if (element[columnName] != -1.0) {
        totalEarlier += element[columnName];
        ++earlierCount;
      }
    });
    if (averageValue) totalEarlier /= earlierCount;

    double totalLater = 0;
    int laterCount = 0;
    dbResultsLater.forEach((element) {
      if (element[columnName] != -1.0) {
        totalLater += element[columnName];
        ++laterCount;
      }
    });
    if (averageValue) totalLater /= laterCount;

    //TODO: calculate trend properly
    double trend;
    trend = totalLater / totalEarlier;
    if (trend.isNaN || trend.isInfinite) trend = 1.1;

    if (trend < 1.0) trend = 1.0 - trend;
    else if (trend > 1.0) trend -= 1.0;

    if (columnName == "distance_km")
    globalLogger.wtf("Trending Column $columnName Window ${window.inSeconds} Earlier $totalEarlier Later $totalLater Trend $trend Agv $averageValue  ${previousMoment} ${moment}");


    return trend;
  }

  static Future<double> getRangedValue(String boardID, String columnName, Duration window, DateTime moment, bool averageValue) async {
    final Database db = await getDatabase();
    final List<Map<String, dynamic>> dbResultsLater = await db.query('logs', columns: [columnName], where: "board_id = ? AND date_time BETWEEN ? AND ?", whereArgs: [boardID, moment.millisecondsSinceEpoch / 1000 - window.inSeconds, moment.millisecondsSinceEpoch / 1000]);

    double totalLater = 0;
    int laterCount = 0;
    dbResultsLater.forEach((element) {
      if (element[columnName] != -1.0) {
        totalLater += element[columnName];
        ++laterCount;
      }
    });
    if (averageValue) totalLater /= laterCount;

    return totalLater;
  }
}
