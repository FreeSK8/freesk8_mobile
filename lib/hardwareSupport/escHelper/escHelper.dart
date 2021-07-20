
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './appConf.dart';
import './mcConf.dart';

import '../../globalUtilities.dart';
import './serialization/buffers.dart';
import './serialization/firmware5_1.dart';
import './serialization/firmware5_2.dart';

import 'dataTypes.dart';

enum ESC_FIRMWARE {
  UNSUPPORTED,
  FW5_1,
  FW5_2,
}

class ESCTelemetry {
  ESCTelemetry() {
    v_in = 0;
    temp_mos = 0;
    temp_mos_1 = 0;
    temp_mos_2 = 0;
    temp_mos_3 = 0;
    temp_motor = 0;
    current_motor = 0;
    current_in = 0;
    foc_id = 0;
    foc_iq = 0;
    rpm = 0;
    duty_now = 0;
    amp_hours = 0;
    amp_hours_charged = 0;
    watt_hours = 0;
    watt_hours_charged = 0;
    tachometer = 0;
    tachometer_abs = 0;
    position = 0;
    vesc_id = 0;
    vd = 0;
    vq = 0;
    fault_code = mc_fault_code.FAULT_CODE_NONE;

    //NOTE: Extras for COMM_GET_VALUES_SETUP
    speed = null;
    battery_level = null;
    num_vescs = null;
    battery_wh = null;
  }
  //FW 5
  double v_in;
  double temp_mos;
  double temp_mos_1;
  double temp_mos_2;
  double temp_mos_3;
  double temp_motor;
  double current_motor;
  double current_in;
  double foc_id;
  double foc_iq;
  double rpm;
  double duty_now;
  double amp_hours;
  double amp_hours_charged;
  double watt_hours;
  double watt_hours_charged;
  int tachometer;
  int tachometer_abs;
  double position;
  mc_fault_code fault_code;
  int vesc_id;
  double vd;
  double vq;

  //NOTE: Extras for COMM_GET_VALUES_SETUP
  double speed;
  double battery_level;
  int num_vescs;
  double battery_wh;
}

class ESCProfile {
  ESCProfile({this.profileName});
  // For user interaction
  String profileName;
  double speedKmh;
  double speedKmhRev;
  // VESC based ESC variables :smirk:
  double l_current_min_scale;
  double l_current_max_scale;
  double l_watt_min;
  double l_watt_max;
}



class ESCFirmware {
  ESCFirmware() {
    fw_version_major = 0;
    fw_version_minor = 0;
    hardware_name = "loading...";
  }
  int fw_version_major;
  int fw_version_minor;
  String hardware_name;
}

class ESCFault {
  int faultCode;
  int faultCount;
  int escID;
  DateTime firstSeen;
  DateTime lastSeen;

  ESCFault({this.faultCode, this.faultCount, this.escID, this.firstSeen, this.lastSeen});

  String toString() {
    return "${mc_fault_code.values[this.faultCode].toString().substring(14)} was seen ${this.faultCount} time${this.faultCount!=1?"s":""} on ESC ${this.escID} at ${this.firstSeen.toString().substring(0,19)}${this.faultCount > 1 ? " until ${this.lastSeen.toString().substring(11,19)}" : ""}";
  }

  TableRow toTableRow() {
    return TableRow(children: [
      Text(mc_fault_code.values[this.faultCode].toString().substring(14)),
      Text(this.faultCount.toString()),
      Text(this.escID.toString()),
      Text(this.firstSeen.toString()),
      Text(this.lastSeen.toString())
    ]);
  }
}

class ESCHelper {
  static const int MCCONF_SIGNATURE_FW5_1 = 3698540221;
  static const int APPCONF_SIGNATURE_FW5_1 = 2460147246;

  static const int MCCONF_SIGNATURE_FW5_2 = 2211848314;
  static const int APPCONF_SIGNATURE_FW5_2 = 3264926020;

  static SerializeFirmware51 fw51serializer = new SerializeFirmware51();
  static SerializeFirmware52 fw52serializer = new SerializeFirmware52();

  List<ESCFault> processFaults(int faultCount, Uint8List payload) {
    //globalLogger.wtf(payload);
    List<ESCFault> response = [];
    int index = 0;
    for (int i=0; i<faultCount; ++i) {
      ESCFault fault = new ESCFault();
      fault.faultCode = payload[index++];
      fault.faultCount = buffer_get_uint16(payload, index); index += 2;
      fault.escID = buffer_get_uint16(payload, index); index += 2;
      index += 3; //NOTE: Alignment
      fault.firstSeen = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(payload, index, Endian.little) * 1000, isUtc: true).add((DateTime.now().timeZoneOffset)); index += 8;
      fault.lastSeen = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(payload, index, Endian.little) * 1000, isUtc: true).add((DateTime.now().timeZoneOffset)); index += 8;
      globalLogger.d("processFaults: Adding ${fault.toString()}");
      response.add(fault);
    }
    return response;
  }

  ESCFirmware processFirmware(Uint8List payload) {
    int index = 1;
    ESCFirmware firmwarePacket = new ESCFirmware();
    firmwarePacket.fw_version_major = payload[index++];
    firmwarePacket.fw_version_minor = payload[index++];

    Uint8List hardwareBytes = new Uint8List(30);
    int i = 0;
    while (payload[index] != 0) {
      hardwareBytes[i++] = payload[index++];
    }
    firmwarePacket.hardware_name = new String.fromCharCodes(hardwareBytes);

    return firmwarePacket;
  }

  ESCTelemetry processTelemetry(Uint8List payload) {
    int index = 1;
    ESCTelemetry telemetryPacket = new ESCTelemetry();

    telemetryPacket.temp_mos = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_motor = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.current_motor = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.current_in = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.foc_id = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.foc_iq = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.duty_now = buffer_get_float16(payload, index, 1000.0); index += 2;
    telemetryPacket.rpm = buffer_get_float32(payload, index, 1.0); index += 4;
    telemetryPacket.v_in = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.amp_hours = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.amp_hours_charged = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.watt_hours = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.watt_hours_charged = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.tachometer = buffer_get_int32(payload, index); index += 4;
    telemetryPacket.tachometer_abs = buffer_get_int32(payload, index); index += 4;
    telemetryPacket.fault_code = mc_fault_code.values[payload[index++]];
    telemetryPacket.position = buffer_get_float32(payload, index, 1000000.0); index += 4;
    telemetryPacket.vesc_id = payload[index++];
    telemetryPacket.temp_mos_1 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_mos_2 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_mos_3 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.vd = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.vq = buffer_get_float32(payload, index, 100.0);

    return telemetryPacket;
  }

  //Dear future people,
  //COMM_GET_VALUES and COMM_GET_VALUES_SETUP are quite similar but have some differences:
  //In SETUP the energy values are from all ESCs
  //In SETUP the distance values are in meters
  ESCTelemetry processSetupValues(Uint8List payload) {
    int index = 1;
    ESCTelemetry telemetryPacket = new ESCTelemetry();

    telemetryPacket.temp_mos = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_motor = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.current_motor = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.current_in = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.duty_now = buffer_get_float16(payload, index, 1000.0); index += 2;
    telemetryPacket.rpm = buffer_get_float32(payload, index, 1.0); index += 4;
    telemetryPacket.speed = buffer_get_float32(payload, index, 1000.0); index += 4;
    telemetryPacket.v_in = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.battery_level = buffer_get_float16(payload, index, 1000.0); index += 2;
    telemetryPacket.amp_hours = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.amp_hours_charged = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.watt_hours = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.watt_hours_charged = buffer_get_float32(payload, index, 10000.0); index += 4;
    telemetryPacket.tachometer = buffer_get_float32(payload, index, 1000.0).toInt(); index += 4;
    telemetryPacket.tachometer_abs = buffer_get_float32(payload, index, 1000.0).toInt(); index += 4;
    telemetryPacket.position = buffer_get_float32(payload, index, 1e6); index += 4;
    telemetryPacket.fault_code = mc_fault_code.values[payload[index++]];
    telemetryPacket.vesc_id = payload[index++];
    telemetryPacket.num_vescs = payload[index++];
    telemetryPacket.battery_wh = buffer_get_float32(payload, index, 1000.0); index += 4;

    return telemetryPacket;
  }

  APPCONF processAPPCONF(Uint8List buffer, ESC_FIRMWARE escFirmwareVersion) {
    switch(escFirmwareVersion) {
      case ESC_FIRMWARE.FW5_1:
        return fw51serializer.processAPPCONF(buffer);
      case ESC_FIRMWARE.FW5_2:
        return fw52serializer.processAPPCONF(buffer);
      default:
        throw("unsupported ESC version");
    }
  }

  ByteData serializeAPPCONF(APPCONF conf, ESC_FIRMWARE escFirmwareVersion) {
    switch(escFirmwareVersion) {
      case ESC_FIRMWARE.FW5_1:
        return fw51serializer.serializeAPPCONF(conf);
      case ESC_FIRMWARE.FW5_2:
        return fw52serializer.serializeAPPCONF(conf);
      default:
        throw("unsupported ESC version");
    }
  }

  MCCONF processMCCONF(Uint8List buffer, ESC_FIRMWARE escFirmwareVersion) {
    switch(escFirmwareVersion) {
      case ESC_FIRMWARE.FW5_1:
        return fw51serializer.processMCCONF(buffer);
      case ESC_FIRMWARE.FW5_2:
        return fw52serializer.processMCCONF(buffer);
      default:
        throw("unsupported ESC version");
    }
  }

  ByteData serializeMCCONF(MCCONF conf, ESC_FIRMWARE escFirmwareVersion) {
    switch(escFirmwareVersion) {
      case ESC_FIRMWARE.FW5_1:
        return fw51serializer.serializeMCCONF(conf);
      case ESC_FIRMWARE.FW5_2:
        return fw52serializer.serializeMCCONF(conf);
      default:
        throw("unsupported ESC version");
    }
  }

  ///ESC Profiles
  static Future<ESCProfile> getESCProfile(int profileIndex) async {
    //globalLogger.d("getESCProfile is loading index $profileIndex");
    final prefs = await SharedPreferences.getInstance();
    ESCProfile response = new ESCProfile();
    response.profileName = prefs.getString('profile$profileIndex name') ?? "Unnamed";
    response.speedKmh = prefs.getDouble('profile$profileIndex speedKmh') ?? 32.0;
    response.speedKmhRev = prefs.getDouble('profile$profileIndex speedKmhRev') ?? -32.0;
    response.l_current_min_scale = prefs.getDouble('profile$profileIndex l_current_min_scale') ?? 1.0;
    response.l_current_max_scale = prefs.getDouble('profile$profileIndex l_current_max_scale') ?? 1.0;
    response.l_watt_min = prefs.getDouble('profile$profileIndex l_watt_min') ?? 0.0;
    response.l_watt_max = prefs.getDouble('profile$profileIndex l_watt_max') ?? 0.0;

    return response;
  }
  static Future<String> getESCProfileName(int profileIndex) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profile$profileIndex name') ?? "Unnamed";
  }
  static Future<void> setESCProfile(int profileIndex, ESCProfile profile) async {
    globalLogger.d("setESCProfile is saving index $profileIndex");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile$profileIndex name', profile.profileName);
    await prefs.setDouble('profile$profileIndex speedKmh', profile.speedKmh);
    await prefs.setDouble('profile$profileIndex speedKmhRev', profile.speedKmhRev);
    await prefs.setDouble('profile$profileIndex l_current_min_scale', profile.l_current_min_scale);
    await prefs.setDouble('profile$profileIndex l_current_max_scale', profile.l_current_max_scale);
    await prefs.setDouble('profile$profileIndex l_watt_min', profile.l_watt_min);
    await prefs.setDouble('profile$profileIndex l_watt_max', profile.l_watt_max);
  }
  static ESCProfile getESCProfileDefaults(int profileIndex) {
    ESCProfile profile = new ESCProfile();
    switch (profileIndex) {
      default:
        profile.profileName = "Unnamed";
        profile.speedKmh = 32.0;
        profile.speedKmhRev = -32.0;
        profile.l_current_max_scale = 1.0;
        profile.l_current_min_scale = 1.0;
        profile.l_watt_max = 0.0;
        profile.l_watt_min = 0.0;
        break;
    }
    return profile;
  }
}

