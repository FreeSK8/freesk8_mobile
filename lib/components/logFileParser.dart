import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import './userSettings.dart';
import '../globalUtilities.dart';
import '../hardwareSupport/escHelper/dataTypes.dart';

// Define the version for the parser's output, increment with changes to CSV
const int ParserVersion = 1;

// Define the expected start and ending of a log entry
const int PacketStart = 0x0d;
const int PacketEnd = 0x0a;

enum LOG_MSG_TYPES {
  DEBUG,
  HEADER,
  ESC,
  ESC_DELTA,
  GPS,
  GPS_DELTA,
  IMU,
  BMS,
  FREESK8,
}

class LogESC {
  DateTime dt;
  int escID;
  double vIn;
  double motorTemp;
  double mosfetTemp;
  double dutyCycle;
  double motorCurrent;
  double batteryCurrent;
  double wattHours;
  double wattHoursRegen;
  int eRPM;
  int eDistance;
  int faultCode;

  LogESC fromValues(LogESC values) {
    this.dt = values.dt;
    this.escID = values.escID;
    this.vIn = values.vIn;
    this.motorTemp = values.motorTemp;
    this.mosfetTemp = values.mosfetTemp;
    this.dutyCycle = values.dutyCycle;
    this.motorCurrent = values.motorCurrent;
    this.batteryCurrent = values.batteryCurrent;
    this.wattHours = values.wattHours;
    this.wattHoursRegen = values.wattHoursRegen;
    this.eRPM = values.eRPM;
    this.eDistance = values.eDistance;
    this.faultCode = values.faultCode;
    return this;
  }
}

class LogGPS {
  DateTime dt;
  int satellites;
  double altitude;
  double speed;
  double latitude;
  double longitude;

  LogGPS fromValues(LogGPS values) {
    this.dt = values.dt;
    this.satellites = values.satellites;
    this.altitude = values.altitude;
    this.speed = values.speed;
    this.latitude = values.latitude;
    this.longitude = values.longitude;
    return this;
  }
}

class LogFileParser {
  static Future<Pair<String, File>> parseFile(File file, String fileName, UserSettings userSettings) async {
    String fileNameOut = fileName;
    LogESC lastESCPacket = new LogESC();
    LogGPS lastGPSPacket = new LogGPS();

    // Create file to store contents
    final temporaryDirectory = await getTemporaryDirectory();
    final convertedFile = File('${temporaryDirectory.path}/parsed.log');
    await convertedFile.writeAsString('');

    // Write header contents
    convertedFile.writeAsStringSync("header,format_esc,esc_id,voltage,motor_temp,esc_temp,duty_cycle,motor_current,battery_current,watt_hours,watt_hours_regen,e_rpm,e_distance,fault,speed_kph,distance_km\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,format_gps,satellites,altitude,speed_kph,latitude,longitude\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,format_err,fault_name,fault_code,esc_id\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,version_output,$ParserVersion\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,gear_ratio,${doublePrecision(userSettings.settings.gearRatio, 2)}\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,wheel_diameter_mm,${userSettings.settings.wheelDiameterMillimeters}\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,motor_poles,${userSettings.settings.motorPoles}\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,utc_offset,${prettyPrintDuration(DateTime.now().timeZoneOffset)}\n", mode: FileMode.append);

    // Iterate contents of file
    Uint8List bytes = file.readAsBytesSync();
    //for (int i=0; i<bytes.length; ++i) {
    //  print("bytes[$i] = ${bytes[i]}");
    //}
    globalLogger.d("logFileParser::parseFile: Unpacking binary data received from Robogotchi");

    Map<int, LogESC> parsedESC = new Map();
    Map<int, LogGPS> parsedGPS = new Map();
    int parsedIndex = 0;
    String parsedResults = "";
    for (int i=0; i<bytes.length; ++i) {
      if (bytes[i] == PacketStart) {
        ++i; // Skip to next byte (1)
        int msgTypeByte = bytes[i++]; // Increment i after we read
        if (msgTypeByte >= LOG_MSG_TYPES.values.length) {
          globalLogger.e("logFileParser::parseFile: Unexpected LOG_MSG_TYPE: $msgTypeByte");
          // Go to next byte
          continue;
        }
        LOG_MSG_TYPES msgType = LOG_MSG_TYPES.values[msgTypeByte];
        int messageLength = bytes[i++]; // Increment i after we read
        //logger.wtf("message length $messageLength @ byte ${i-1}");
        if (i+messageLength > bytes.length) {
          globalLogger.w("logFileParser::parseFile: reached EOF early: Index ${i+messageLength} but bytes.length is only ${bytes.length}");
          continue;
        }
        if (bytes[i+messageLength] != PacketEnd) {
          globalLogger.w("logFileParser::parseFile: Unexpected byte at end of message: bytes[${i+messageLength}] = ${bytes[i+messageLength]}");
        }
        switch(msgType) {
          case LOG_MSG_TYPES.DEBUG:
            globalLogger.wtf("logFileParser::parseFile: LOG_MSG_TYPE = DEBUG is not implemented");
            break;
          case LOG_MSG_TYPES.HEADER:
            int logFileVersion = buffer_get_uint16(bytes, i, Endian.little); i+=2;
            int logMultiESCMode = bytes[i++];
            int logFileHz = bytes[i++];

            if (bytes[i] == PacketEnd) {
              // Store log file header data from Robogotchi
              parsedResults += "header,version_input,$logFileVersion\n";
              parsedResults += "header,multi_esc_mode,$logMultiESCMode\n";
              parsedResults += "header,esc_hz,$logFileHz\n";
            } else {
              globalLogger.e("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.ESC:
            //globalLogger.d("Parsing ESC LOG entry");
            lastESCPacket.dt = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(bytes, i, Endian.little) * 1000, isUtc: true); i+=8;
            lastESCPacket.escID = buffer_get_uint16(bytes, i, Endian.little); i+=2;
            lastESCPacket.vIn = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.motorTemp = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.mosfetTemp = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.dutyCycle = buffer_get_int16(bytes, i, Endian.little) / 1000.0; i+=2;
            lastESCPacket.motorCurrent = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.batteryCurrent = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            i+=2; //NOTE: alignment
            lastESCPacket.wattHoursRegen = buffer_get_uint16(bytes, i, Endian.little) / 100.0; i+=2;
            lastESCPacket.faultCode = bytes[i++];
            ++i; //NOTE: alignment
            lastESCPacket.wattHours = buffer_get_uint32(bytes, i, Endian.little) / 100.0; i+=4;
            lastESCPacket.eRPM = buffer_get_int32(bytes, i, Endian.little); i+=4;
            lastESCPacket.eDistance = buffer_get_uint32(bytes, i, Endian.little); i+=4;
            //globalLogger.wtf("ESC Duty ${lastESCPacket.dutyCycle}");

            if (bytes[i] == PacketEnd) {
              parsedESC[parsedIndex++] = new LogESC().fromValues(lastESCPacket);
            } else {
              globalLogger.e("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.ESC_DELTA:
            //globalLogger.d("Parsing ESC DELTA LOG entry");
            int deltaDT = bytes[i++];
            ++i; //NOTE: alignment
            int escID = buffer_get_uint16(bytes, i, Endian.little); i+=2;
            double deltaVin = buffer_get_int8(bytes, i++) / 10.0;
            double deltaMotorTemp = buffer_get_int8(bytes, i++) / 10.0;
            double deltaESCTemp = buffer_get_int8(bytes, i++) / 10.0;
            i+=1; //NOTE: alignment
            double deltaDuty = buffer_get_int16(bytes, i, Endian.little) / 1000.0; i+=2;
            double deltaMotorCurrent = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            double deltaBatteryCurrent = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            double deltaWattHours = buffer_get_int8(bytes, i++) / 100.0;

            double deltaWattHoursRegen = buffer_get_int8(bytes, i++) / 100.0;
            int deltaERPM = buffer_get_int16(bytes, i, Endian.little); i+=2;
            int deltaEDistance = buffer_get_int16(bytes, i, Endian.little); i+=2;
            int faultCode = bytes[i++];
            i+=1; //NOTE: alignment
            //globalLogger.wtf("ESC DELTA dt $deltaDT id $escID vin $deltaVin mt $deltaMotorTemp et $deltaESCTemp duty $deltaDuty mc $deltaMotorCurrent bc $deltaBatteryCurrent wh $deltaWattHours whr $deltaWattHoursRegen erpm $deltaERPM edist $deltaEDistance f $faultCode");
            //globalLogger.wtf("ESC Duty ${lastESCPacket.dutyCycle} Delta $deltaDuty");

            if (bytes[i] == PacketEnd) {
              // Update ESC packet with delta values
              lastESCPacket.dt = lastESCPacket.dt.add(Duration(seconds: deltaDT));
              lastESCPacket.escID = escID;
              lastESCPacket.vIn = doublePrecision(lastESCPacket.vIn + deltaVin, 1);
              lastESCPacket.motorTemp = doublePrecision(lastESCPacket.motorTemp + deltaMotorTemp, 1);
              lastESCPacket.mosfetTemp = doublePrecision(lastESCPacket.mosfetTemp + deltaESCTemp, 1);
              lastESCPacket.dutyCycle = doublePrecision(lastESCPacket.dutyCycle + deltaDuty, 4);
              lastESCPacket.motorCurrent = doublePrecision(lastESCPacket.motorCurrent + deltaMotorCurrent, 1);
              lastESCPacket.batteryCurrent = doublePrecision(lastESCPacket.batteryCurrent + deltaBatteryCurrent, 1);
              lastESCPacket.wattHours = doublePrecision(lastESCPacket.wattHours + deltaWattHours, 2);
              lastESCPacket.wattHoursRegen = doublePrecision(lastESCPacket.wattHoursRegen + deltaWattHoursRegen, 2);
              lastESCPacket.eRPM += deltaERPM;
              lastESCPacket.eDistance += deltaEDistance;
              lastESCPacket.faultCode = faultCode;

              parsedESC[parsedIndex++] = new LogESC().fromValues(lastESCPacket);
            } else {
              globalLogger.e("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.GPS:
            //globalLogger.d("Parsing GPS LOG entry");
            lastGPSPacket.dt = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(bytes, i, Endian.little) * 1000, isUtc: true); i+=8;
            lastGPSPacket.satellites = bytes[i++];
            ++i; //NOTE: alignment
            lastGPSPacket.altitude = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            lastGPSPacket.speed = buffer_get_int16(bytes, i, Endian.little) / 10.0; i+=2;
            i+=2; //NOTE: alignment
            lastGPSPacket.latitude = buffer_get_int32(bytes, i, Endian.little) / 100000.0; i+=4;
            lastGPSPacket.longitude = buffer_get_int32(bytes, i, Endian.little) / 100000.0; i+=4;
            if (bytes[i] == PacketEnd) {
              parsedGPS[parsedIndex++] = new LogGPS().fromValues(lastGPSPacket);
            } else {
              globalLogger.e("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.GPS_DELTA:
            //globalLogger.d("Parsing GPS DELTA LOG entry");
            int deltaDt = bytes[i++];
            int deltaSatellites = buffer_get_int8(bytes, i++);
            double deltaAltitude = buffer_get_int8(bytes, i++) / 10.0;
            double deltaSpeed = buffer_get_int8(bytes, i++) / 10.0;
            double deltaLatitude = buffer_get_int16(bytes, i, Endian.little) / 100000.0; i+=2;
            double deltaLongitude = buffer_get_int16(bytes, i, Endian.little) / 100000.0; i+=2;
            //logger.wtf("GPS DELTA Time $deltaDt Satellites $deltaSatellites Altitude $deltaAltitude Speed $deltaSpeed Latitude $deltaLatitude Longitude $deltaLongitude");
            if (bytes[i] == PacketEnd) {
              lastGPSPacket.dt = lastGPSPacket.dt.add(Duration(seconds: deltaDt));
              lastGPSPacket.satellites += deltaSatellites;
              lastGPSPacket.altitude = doublePrecision(lastGPSPacket.altitude + deltaAltitude, 1);
              lastGPSPacket.speed = doublePrecision(lastGPSPacket.speed + deltaSpeed, 1);
              lastGPSPacket.latitude = doublePrecision(lastGPSPacket.latitude + deltaLatitude, 5);
              lastGPSPacket.longitude = doublePrecision(lastGPSPacket.longitude + deltaLongitude, 5);

              parsedGPS[parsedIndex++] = new LogGPS().fromValues(lastGPSPacket);
            } else {
              globalLogger.e("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.IMU:
            globalLogger.wtf("logFileParser::parseFile: LOG_MSG_TYPE = IMU is not implemented");
            break;
          case LOG_MSG_TYPES.BMS:
            globalLogger.wtf("logFileParser::parseFile: LOG_MSG_TYPE = BMS is not implemented");
            break;
          case LOG_MSG_TYPES.FREESK8:
            int eventType = bytes[i++];
            i+=7; //NOTE: Alignment
            int eventData = buffer_get_int64(bytes, i, Endian.little); i+=8;
            if (bytes[i] == PacketEnd) {
              switch(eventType) {
                case 0: //TIME_SYNC
                  globalLogger.d("logFileParser::parseFile: TIME_SYNC received ($eventData seconds)");
                  // Write file header entry before parsed data is appended
                  convertedFile.writeAsStringSync("header,gps_time_sync,$eventData\n", mode: FileMode.append);

                  // Update parsed records and filename IF we time travel
                  if (eventData != 0) {
                    for (int j=0; j<parsedIndex; ++j) {
                      // Adjust time for ESC records
                      if (parsedESC[j] != null) {
                        parsedESC[j].dt = parsedESC[j].dt.add(Duration(seconds: eventData));
                      }
                      // Adjust time for GPS records
                      if (parsedGPS[j] != null) {
                        parsedGPS[j].dt = parsedGPS[j].dt.add(Duration(seconds: eventData));
                      }
                      // Adjust fileName with new starting time
                      DateTime dtFromString = DateTime.tryParse(fileName);
                      if (dtFromString == null) {
                        globalLogger.wtf("logFileParser::parseFile:TIME_SYNC: unable to parse time from filename ($fileName) checking records");
                        if (parsedESC.values.length > 0) {
                          dtFromString = parsedESC.values.first.dt.add(Duration(seconds: eventData));
                          fileNameOut = dtFromString.toIso8601String();
                        } else {
                          globalLogger.wtf("logFileParser::parseFile:TIME_SYNC: No ESC records found to parse valid time. Using original filename");
                        }
                      } else {
                        dtFromString = dtFromString.add(Duration(seconds: eventData));
                        fileNameOut = dtFromString.toIso8601String().substring(0,19);
                      }
                    }
                  }
                  break;
                case 1:
                  globalLogger.wtf("logFileParser::parseFile: FreeSK8 message USER_FLAG is not implemented");
                  break;
                default:
                  globalLogger.wtf("logFileParser::parseFile: FreeSK8 message $eventType is unknown");
                  break;
              }
            }
        }


      } else {
        globalLogger.e("logFileParser::parseFile: Unexpected start of packet at byte $i of ${bytes.length}: ${bytes[i]}");
      }
    }

    globalLogger.d("logFileParser::parseFile: Unpacking complete. Saving to filesystem");

    // Convert data to CSV
    for (int i=0; i<parsedIndex; ++i) {
      if (parsedESC[i] != null) {
        // Store ESC CSV data
        parsedResults += "${parsedESC[i].dt.toIso8601String().substring(0,19)},"
            "esc,"
            "${parsedESC[i].escID},"
            "${parsedESC[i].vIn},"
            "${parsedESC[i].motorTemp},"
            "${parsedESC[i].mosfetTemp},"
            "${parsedESC[i].dutyCycle},"
            "${parsedESC[i].motorCurrent},"
            "${parsedESC[i].batteryCurrent},"
            "${parsedESC[i].wattHours},"
            "${parsedESC[i].wattHoursRegen},"
            "${parsedESC[i].eRPM},"
            "${parsedESC[i].eDistance},"
            "${parsedESC[i].faultCode},"
            "${eRPMToKph(parsedESC[i].eRPM.toDouble(), userSettings.settings.gearRatio, userSettings.settings.wheelDiameterMillimeters, userSettings.settings.motorPoles)},"
            "${eDistanceToKm(parsedESC[i].eDistance.toDouble(), userSettings.settings.gearRatio, userSettings.settings.wheelDiameterMillimeters, userSettings.settings.motorPoles)}\n";

        // Store faults on their own line
        if (parsedESC[i].faultCode != 0) {
          parsedResults += "${parsedESC[i].dt.toIso8601String().substring(0,19)},"
              "err,"
              "${mc_fault_code.values[parsedESC[i].faultCode].toString().substring(14)},"
              "${parsedESC[i].faultCode},"
              "${parsedESC[i].escID}\n";
        }
      }
      if (parsedGPS[i] != null) {
        // Store GPS CSV data
        parsedResults += "${parsedGPS[i].dt.toIso8601String().substring(0,19)},"
            "gps,"
            "${parsedGPS[i].satellites},"
            "${parsedGPS[i].altitude},"
            "${parsedGPS[i].speed},"
            "${parsedGPS[i].latitude},"
            "${parsedGPS[i].longitude}\n";
      }
    }
    // Write parsed CSV to filesystem
    convertedFile.writeAsStringSync(parsedResults, mode: FileMode.append, flush: true);

    return Pair<String, File>(fileNameOut, convertedFile);
  }

  static int buffer_get_int64(Uint8List buffer, int index, [Endian endian = Endian.big]) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt64(index, endian);
  }

  static int buffer_get_uint64(Uint8List buffer, int index, [Endian endian = Endian.big]) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getUint64(index, endian);
  }

  static int buffer_get_uint16(Uint8List buffer, int index, [Endian endian = Endian.big]) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getUint16(index, endian);
  }

  static int buffer_get_int8(Uint8List buffer, int index) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt8(index);
  }

  static int buffer_get_int16(Uint8List buffer, int index, [Endian endian = Endian.big]) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt16(index, endian);
  }

  static int buffer_get_int32(Uint8List buffer, int index, [Endian endian = Endian.big]) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt32(index, endian);
  }

  static int buffer_get_uint32(Uint8List buffer, int index, [Endian endian = Endian.big]) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getUint32(index, endian);
  }
}

