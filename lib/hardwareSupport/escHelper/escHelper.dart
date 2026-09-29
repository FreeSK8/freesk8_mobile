
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './appConf.dart';
import './mcConf.dart';

import '../../globalUtilities.dart';
import './serialization/buffers.dart';
import './serialization/escConfigSerializer.dart';
import './serialization/firmware5_1.dart';
import './serialization/firmware5_2.dart';
import './serialization/firmware5_3.dart';
import './serialization/firmware6_0.dart';
import './serialization/firmware6_5.dart';
import './serialization/firmware6_6.dart';
import './serialization/firmware7_0.dart';

import 'dataTypes.dart';

/// Supported VESC firmware releases, in chronological order (feature checks
/// compare indices). The configuration serializers are generated per release
/// by tool/esc_serializers/generate.py.
enum ESC_FIRMWARE {
  UNSUPPORTED,
  FW5_1, // 5.01
  FW5_2, // 5.02
  FW5_3, // 5.03
  FW6_0, // 6.00
  FW6_2, // 6.02 (same configuration layout as 6.00)
  FW6_5, // 6.05
  FW6_6, // 6.06
  FW7_0, // 7.00
}

/// Which configuration features a firmware release has; used by the editors
/// to show, hide or reinterpret fields.
class FirmwareFeatures {
  const FirmwareFeatures(this.firmware);
  final ESC_FIRMWARE firmware;

  bool _atLeast(ESC_FIRMWARE min) => firmware != ESC_FIRMWARE.UNSUPPORTED && firmware.index >= min.index;

  /// app_balance_conf exists (removed from the firmware in 6.05).
  bool get hasBalanceApp => firmware != ESC_FIRMWARE.UNSUPPORTED && !_atLeast(ESC_FIRMWARE.FW6_5);
  /// l_battery_regen_cut_start/end (6.05+).
  bool get hasRegenCutoff => _atLeast(ESC_FIRMWARE.FW6_5);
  /// Temperature limits are stored as whole degrees (6.05+).
  bool get tempsAreWholeDegrees => _atLeast(ESC_FIRMWARE.FW6_5);
  /// bms.vmin/vmax_limit_* (6.05+).
  bool get hasBmsVoltageLimits => _atLeast(ESC_FIRMWARE.FW6_5);
  /// foc_offsets_cal_on_boot flag (5.3 up to 6.05).
  bool get hasOffsetsCalOnBoot => _atLeast(ESC_FIRMWARE.FW5_3) && !hasOffsetsCalMode;
  /// foc_offsets_cal_mode bitmask replaces foc_offsets_cal_on_boot (6.06+).
  bool get hasOffsetsCalMode => _atLeast(ESC_FIRMWARE.FW6_6);
  /// app_adc_conf.buttons bitmask replaces cc/rev_button_inverted (6.0+).
  bool get adcButtonsBitmask => _atLeast(ESC_FIRMWARE.FW6_0);

  /// The FOC sensor modes this firmware's datatypes.h declares, in wire order:
  /// HFI_START arrived in 5.3, HFI_V2..V5 in 6.0 and ENCODER_AB in 7.00.
  /// Unsupported firmware gets the full list so a stale value still renders.
  List<mc_foc_sensor_mode> get sensorModes {
    final List<mc_foc_sensor_mode> all = mc_foc_sensor_mode.values;
    int count = all.length;
    if (firmware == ESC_FIRMWARE.UNSUPPORTED) {
      count = all.length;
    } else if (_atLeast(ESC_FIRMWARE.FW7_0)) {
      count = 10;
    } else if (_atLeast(ESC_FIRMWARE.FW6_0)) {
      count = 9;
    } else if (_atLeast(ESC_FIRMWARE.FW5_3)) {
      count = 5;
    } else {
      count = 4;
    }
    return all.take(count).toList();
  }
}

class ESCTelemetry {
  ESCTelemetry();
  //FW 5
  double v_in = 0;
  double temp_mos = 0;
  double temp_mos_1 = 0;
  double temp_mos_2 = 0;
  double temp_mos_3 = 0;
  double temp_motor = 0;
  double current_motor = 0;
  double current_in = 0;
  double foc_id = 0;
  double foc_iq = 0;
  double rpm = 0;
  double duty_now = 0;
  double amp_hours = 0;
  double amp_hours_charged = 0;
  double watt_hours = 0;
  double watt_hours_charged = 0;
  int tachometer = 0;
  int tachometer_abs = 0;
  double position = 0;
  mc_fault_code fault_code = mc_fault_code.FAULT_CODE_NONE;
  int vesc_id = 0;
  double vd = 0;
  double vq = 0;

  //NOTE: Extras for COMM_GET_VALUES_SETUP
  double speed = 0;
  double battery_level = 0;
  int num_vescs = 0;
  double battery_wh = 0;
}

class ESCProfile {
  ESCProfile({this.profileName = "Unnamed"});
  // For user interaction
  String profileName;
  double speedKmh = 32.0;
  double speedKmhRev = -32.0;
  // VESC based ESC variables :smirk:
  double l_current_min_scale = 1.0;
  double l_current_max_scale = 1.0;
  double l_watt_min = 0.0;
  double l_watt_max = 0.0;
}



class ESCFirmware {
  ESCFirmware();
  int fw_version_major = 0;
  int fw_version_minor = 0;
  String hardware_name = "loading...";
}

class ESCFault {
  int faultCode = 0;
  int faultCount = 0;
  int escID = 0;
  DateTime? firstSeen;
  DateTime? lastSeen;

  ESCFault({this.faultCode = 0, this.faultCount = 0, this.escID = 0, this.firstSeen, this.lastSeen});

  String toString() {
    return "${faultCodeName(this.faultCode)} was seen ${this.faultCount} time${this.faultCount!=1?"s":""} on ESC ${this.escID} at ${this.firstSeen.toString().substring(0,19)}${this.faultCount > 1 ? " until ${this.lastSeen.toString().substring(11,19)}" : ""}";
  }

  TableRow toTableRow() {
    return TableRow(children: [
      Text(faultCodeName(this.faultCode)),
      Text(this.faultCount.toString()),
      Text(this.escID.toString()),
      Text(this.firstSeen.toString()),
      Text(this.lastSeen.toString())
    ]);
  }
}

class ESCHelper {
  static final SerializeFirmware60 _fw60 = SerializeFirmware60();

  /// Configuration serializer per firmware release. 6.02 shares the 6.00 layout.
  static final Map<ESC_FIRMWARE, EscConfigSerializer> serializers = {
    ESC_FIRMWARE.FW5_1: SerializeFirmware51(),
    ESC_FIRMWARE.FW5_2: SerializeFirmware52(),
    ESC_FIRMWARE.FW5_3: SerializeFirmware53(),
    ESC_FIRMWARE.FW6_0: _fw60,
    ESC_FIRMWARE.FW6_2: _fw60,
    ESC_FIRMWARE.FW6_5: SerializeFirmware65(),
    ESC_FIRMWARE.FW6_6: SerializeFirmware66(),
    ESC_FIRMWARE.FW7_0: SerializeFirmware70(),
  };

  static EscConfigSerializer serializerFor(ESC_FIRMWARE firmware) {
    final EscConfigSerializer? serializer = serializers[firmware];
    if (serializer == null) {
      throw StateError("unsupported ESC firmware $firmware");
    }
    return serializer;
  }

  /// Maps the version reported by COMM_FW_VERSION to a supported release.
  /// Unknown 7.x minors use the 7.00 layout (the signature check still guards
  /// against a changed layout); unknown 5.x/6.x minors and other majors are
  /// unsupported because their layouts changed at almost every release.
  static ESC_FIRMWARE firmwareFor(int major, int minor) {
    if (major == 5 && minor == 1) return ESC_FIRMWARE.FW5_1;
    if (major == 5 && minor == 2) return ESC_FIRMWARE.FW5_2;
    if (major == 5 && minor == 3) return ESC_FIRMWARE.FW5_3;
    if (major == 6 && minor == 0) return ESC_FIRMWARE.FW6_0;
    if (major == 6 && minor == 2) return ESC_FIRMWARE.FW6_2;
    if (major == 6 && minor == 5) return ESC_FIRMWARE.FW6_5;
    if (major == 6 && minor == 6) return ESC_FIRMWARE.FW6_6;
    if (major == 7) {
      if (minor != 0) {
        globalLogger.w("firmwareFor: firmware $major.$minor is newer than this build knows; using the 7.00 layout");
      }
      return ESC_FIRMWARE.FW7_0;
    }
    return ESC_FIRMWARE.UNSUPPORTED;
  }

  /// "6.05" style label for a reported version.
  static String firmwareLabel(int major, int minor) => "$major.${minor.toString().padLeft(2, '0')}";


  List<ESCFault> processFaults(int faultCount, Uint8List payload) {
    //globalLogger.f(payload);
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

    // The hardware name is a NUL-terminated string of arbitrary length; read up
    // to the terminator (bounded by the payload) without padding with NULs.
    int end = index;
    while (end < payload.length && payload[end] != 0) {
      end++;
    }
    firmwarePacket.hardware_name = String.fromCharCodes(payload, index, end);

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
    telemetryPacket.fault_code = faultCodeFromWire(payload[index++]);
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
    telemetryPacket.fault_code = faultCodeFromWire(payload[index++]);
    telemetryPacket.vesc_id = payload[index++];
    telemetryPacket.num_vescs = payload[index++];
    telemetryPacket.battery_wh = buffer_get_float32(payload, index, 1000.0); index += 4;

    return telemetryPacket;
  }

  APPCONF processAPPCONF(Uint8List buffer, ESC_FIRMWARE escFirmwareVersion) => serializerFor(escFirmwareVersion).processAPPCONF(buffer);

  ByteData serializeAPPCONF(APPCONF conf, ESC_FIRMWARE escFirmwareVersion) => serializerFor(escFirmwareVersion).serializeAPPCONF(conf);

  MCCONF processMCCONF(Uint8List buffer, ESC_FIRMWARE escFirmwareVersion) => serializerFor(escFirmwareVersion).processMCCONF(buffer);

  ByteData serializeMCCONF(MCCONF conf, ESC_FIRMWARE escFirmwareVersion) => serializerFor(escFirmwareVersion).serializeMCCONF(conf);

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

