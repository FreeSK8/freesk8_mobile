import 'dart:io';
import 'dart:typed_data';

import 'package:freesk8_mobile/escHelper.dart';
import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:path_provider/path_provider.dart';

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
}

class LogGPS {
  DateTime dt;
  int satellites;
  double altitude;
  double speed;
  double latitude;
  double longitude;
}

class LogFileParser {
  static Future<File> parseFile(File file) async {
    LogESC lastESCPacket = new LogESC();
    LogGPS lastGPSPacket = new LogGPS();

    // Create file to store contents
    final temporaryDirectory = await getTemporaryDirectory();
    final convertedFile = File('${temporaryDirectory.path}/parsed.log');
    await convertedFile.writeAsString('');

    // Write header contents
    convertedFile.writeAsStringSync("header,version,1\n", mode: FileMode.append);
    //0 = dt, 1 = type, 2 = first value
    convertedFile.writeAsStringSync("header,format,esc,esc_id,voltage,motor_temp,esc_temp,duty_cycle,motor_current,battery_current,watt_hours,watt_hours_regen,e_rpm,e_distance,fault\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,format,gps,satellites,altitude,speed,latitude,longitude\n", mode: FileMode.append);
    convertedFile.writeAsStringSync("header,format,err,fault_name,fault_code,esc_id\n", mode: FileMode.append);

    // Iterate contents of file
    Uint8List bytes = file.readAsBytesSync();
    //for (int i=0; i<bytes.length; ++i) {
    //  print("bytes[$i] = ${bytes[i]}");
    //}
    for (int i=0; i<bytes.length; ++i) {
      if (bytes[i] == PacketStart) {
        ++i; // Skip to next byte (1)
        int msgTypeByte = bytes[i++]; // Increment i after we read
        if (msgTypeByte >= LOG_MSG_TYPES.values.length) {
          print("logFileParser::parseFile: Unexpected LOG_MSG_TYPE: $msgTypeByte");
          // Go to next byte
          continue;
        }
        LOG_MSG_TYPES msgType = LOG_MSG_TYPES.values[msgTypeByte];
        int messageLength = bytes[i++]; // Increment i after we read
        //print("message length $messageLength @ byte ${i-1}");
        if (bytes[i+messageLength] != PacketEnd) {
          print("logFileParser::parseFile: Unexpected byte at end of message: bytes[${i+messageLength}] = ${bytes[i+messageLength]}");
        }
        switch(msgType) {
          case LOG_MSG_TYPES.DEBUG:
            break;
          case LOG_MSG_TYPES.HEADER:
            break;
          case LOG_MSG_TYPES.ESC:
            print("Parsing ESC LOG entry");
            lastESCPacket.dt = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(bytes, i, Endian.little) * 1000, isUtc: true); i+=8;
            lastESCPacket.escID = buffer_get_uint16(bytes, i, Endian.little); i+=2;
            lastESCPacket.vIn = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.motorTemp = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.mosfetTemp = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.dutyCycle = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.motorCurrent = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.batteryCurrent = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.wattHours = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.wattHoursRegen = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastESCPacket.faultCode = bytes[i++];
            ++i; //NOTE: alignment
            i+=4; //NOTE: alignment
            lastESCPacket.eRPM = buffer_get_uint32(bytes, i, Endian.little); i+=4;
            lastESCPacket.eDistance = buffer_get_uint32(bytes, i, Endian.little); i+=4;

            if (bytes[i] == PacketEnd) {
              // Write ESC CSV data
              convertedFile.writeAsStringSync("${lastESCPacket.dt.toIso8601String().substring(0,19)},"
                  "esc,"
                  "${lastESCPacket.escID},"
                  "${lastESCPacket.vIn},"
                  "${lastESCPacket.motorTemp},"
                  "${lastESCPacket.mosfetTemp},"
                  "${lastESCPacket.dutyCycle},"
                  "${lastESCPacket.motorCurrent},"
                  "${lastESCPacket.batteryCurrent},"
                  "${lastESCPacket.wattHours},"
                  "${lastESCPacket.wattHoursRegen},"
                  "${lastESCPacket.eRPM},"
                  "${lastESCPacket.eDistance},"
                  "${lastESCPacket.faultCode}\n", mode: FileMode.append);

              // Write faults on their own line
              if (lastESCPacket.faultCode != 0) {
                convertedFile.writeAsStringSync("${lastESCPacket.dt.toIso8601String().substring(0,19)},"
                    "err,"
                    "${mc_fault_code.values[lastESCPacket.faultCode].toString().substring(14)},"
                    "${lastESCPacket.faultCode},"
                    "${lastESCPacket.escID}\n", mode: FileMode.append);
              }
            } else {
              print("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.ESC_DELTA:
            break;
          case LOG_MSG_TYPES.GPS:
            print("Parsing GPS LOG entry");
            lastGPSPacket.dt = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(bytes, i, Endian.little) * 1000, isUtc: true); i+=8;
            lastGPSPacket.satellites = bytes[i++];
            ++i; //NOTE: alignment
            lastGPSPacket.altitude = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            lastGPSPacket.speed = buffer_get_uint16(bytes, i, Endian.little) / 10.0; i+=2;
            i+=2; //NOTE: alignment
            lastGPSPacket.latitude = buffer_get_int32(bytes, i, Endian.little) / 100000.0; i+=4;
            lastGPSPacket.longitude = buffer_get_int32(bytes, i, Endian.little) / 100000.0; i+=4;
            if (bytes[i] == PacketEnd) {
              // Write GPS CSV data
              convertedFile.writeAsStringSync("${lastGPSPacket.dt.toIso8601String().substring(0,19)},"
                  "gps,"
                  "${lastGPSPacket.satellites},"
                  "${lastGPSPacket.altitude},"
                  "${lastGPSPacket.speed},"
                  "${lastGPSPacket.latitude},"
                  "${lastGPSPacket.longitude}\n", mode: FileMode.append);
            } else {
              print("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.GPS_DELTA:
            print("Parsing GPS DELTA LOG entry");
            int deltaDt = bytes[i++];
            int deltaSatellites = buffer_get_int8(bytes, i++);
            double deltaAltitude = buffer_get_int8(bytes, i++) / 10.0;
            double deltaSpeed = buffer_get_int8(bytes, i++) / 10.0;
            double deltaLatitude = buffer_get_int16(bytes, i, Endian.little) / 100000.0; i+=2;
            double deltaLongitude = buffer_get_int16(bytes, i, Endian.little) / 100000.0; i+=2;
            print("GPS DELTA Time $deltaDt Satellites $deltaSatellites Altitude $deltaAltitude Speed $deltaSpeed Latitude $deltaLatitude Longitude $deltaLongitude");
            if (bytes[i] == PacketEnd) {
              lastGPSPacket.dt.add(Duration(seconds: deltaDt));
              lastGPSPacket.satellites += deltaSatellites;
              lastGPSPacket.altitude = doublePrecision(lastGPSPacket.altitude + deltaAltitude, 1);
              lastGPSPacket.speed = doublePrecision(lastGPSPacket.speed - deltaSpeed, 1);
              lastGPSPacket.latitude = doublePrecision(lastGPSPacket.latitude + deltaLatitude, 5);
              lastGPSPacket.longitude = doublePrecision(lastGPSPacket.longitude + deltaLongitude, 5);
              // Write GPS CSV data
              convertedFile.writeAsStringSync("${lastGPSPacket.dt.toIso8601String().substring(0,19)},"
                  "gps,"
                  "${lastGPSPacket.satellites},"
                  "${lastGPSPacket.altitude},"
                  "${lastGPSPacket.speed},"
                  "${lastGPSPacket.latitude},"
                  "${lastGPSPacket.longitude}\n", mode: FileMode.append);
            } else {
              print("logFileParser::parseFile: Unexpected byte at end of packet: bytes[$i] = ${bytes[i]}");
            }
            break;
          case LOG_MSG_TYPES.IMU:
            break;
          case LOG_MSG_TYPES.BMS:
            break;
        }


      } else {
        print("logFileParser::parseFile: Unexpected start of packet at byte $i of ${bytes.length}: ${bytes[i]}");
      }
    }

    return convertedFile;
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

