import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freesk8_mobile/escHelper/appConf.dart';
import 'package:freesk8_mobile/escHelper/mcConf.dart';

import '../globalUtilities.dart';
import './serialization/buffers.dart';
import './serialization/firmware5_1.dart';
import './serialization/firmware5_2.dart';

enum COMM_PACKET_ID {
  COMM_FW_VERSION,
  COMM_JUMP_TO_BOOTLOADER,
  COMM_ERASE_NEW_APP,
  COMM_WRITE_NEW_APP_DATA,
  COMM_GET_VALUES,
  COMM_SET_DUTY,
  COMM_SET_CURRENT,
  COMM_SET_CURRENT_BRAKE,
  COMM_SET_RPM,
  COMM_SET_POS,
  COMM_SET_HANDBRAKE,
  COMM_SET_DETECT,
  COMM_SET_SERVO_POS,
  COMM_SET_MCCONF,
  COMM_GET_MCCONF,
  COMM_GET_MCCONF_DEFAULT,
  COMM_SET_APPCONF,
  COMM_GET_APPCONF,
  COMM_GET_APPCONF_DEFAULT,
  COMM_SAMPLE_PRINT,
  COMM_TERMINAL_CMD,
  COMM_PRINT,
  COMM_ROTOR_POSITION,
  COMM_EXPERIMENT_SAMPLE,
  COMM_DETECT_MOTOR_PARAM,
  COMM_DETECT_MOTOR_R_L,
  COMM_DETECT_MOTOR_FLUX_LINKAGE,
  COMM_DETECT_ENCODER,
  COMM_DETECT_HALL_FOC,
  COMM_REBOOT,
  COMM_ALIVE,
  COMM_GET_DECODED_PPM,
  COMM_GET_DECODED_ADC,
  COMM_GET_DECODED_CHUK,
  COMM_FORWARD_CAN,
  COMM_SET_CHUCK_DATA,
  COMM_CUSTOM_APP_DATA,
  COMM_NRF_START_PAIRING,
  COMM_GPD_SET_FSW,
  COMM_GPD_BUFFER_NOTIFY,
  COMM_GPD_BUFFER_SIZE_LEFT,
  COMM_GPD_FILL_BUFFER,
  COMM_GPD_OUTPUT_SAMPLE,
  COMM_GPD_SET_MODE,
  COMM_GPD_FILL_BUFFER_INT8,
  COMM_GPD_FILL_BUFFER_INT16,
  COMM_GPD_SET_BUFFER_INT_SCALE,
  COMM_GET_VALUES_SETUP,
  COMM_SET_MCCONF_TEMP,
  COMM_SET_MCCONF_TEMP_SETUP,
  COMM_GET_VALUES_SELECTIVE,
  COMM_GET_VALUES_SETUP_SELECTIVE,
  COMM_EXT_NRF_PRESENT,
  COMM_EXT_NRF_ESB_SET_CH_ADDR,
  COMM_EXT_NRF_ESB_SEND_DATA,
  COMM_EXT_NRF_ESB_RX_DATA,
  COMM_EXT_NRF_SET_ENABLED,
  COMM_DETECT_MOTOR_FLUX_LINKAGE_OPENLOOP,
  COMM_DETECT_APPLY_ALL_FOC,
  COMM_JUMP_TO_BOOTLOADER_ALL_CAN,
  COMM_ERASE_NEW_APP_ALL_CAN,
  COMM_WRITE_NEW_APP_DATA_ALL_CAN,
  COMM_PING_CAN,
  COMM_APP_DISABLE_OUTPUT,
  COMM_TERMINAL_CMD_SYNC,
  COMM_GET_IMU_DATA,
  COMM_BM_CONNECT,
  COMM_BM_ERASE_FLASH_ALL,
  COMM_BM_WRITE_FLASH,
  COMM_BM_REBOOT,
  COMM_BM_DISCONNECT,
  COMM_BM_MAP_PINS_DEFAULT,
  COMM_BM_MAP_PINS_NRF5X,
  COMM_ERASE_BOOTLOADER,
  COMM_ERASE_BOOTLOADER_ALL_CAN,
  COMM_PLOT_INIT,
  COMM_PLOT_DATA,
  COMM_PLOT_ADD_GRAPH,
  COMM_PLOT_SET_GRAPH,
  COMM_GET_DECODED_BALANCE,
  COMM_BM_MEM_READ,
  COMM_WRITE_NEW_APP_DATA_LZO,
  COMM_WRITE_NEW_APP_DATA_ALL_CAN_LZO,
  COMM_BM_WRITE_FLASH_LZO,
  COMM_SET_CURRENT_REL,
  COMM_CAN_FWD_FRAME,
  COMM_SET_BATTERY_CUT,
  COMM_SET_BLE_NAME,
  COMM_SET_BLE_PIN,
  COMM_SET_CAN_MODE,
  COMM_GET_IMU_CALIBRATION,
  COMM_GET_MCCONF_TEMP, // Firmware 5.2 added

  // Custom configuration for hardware
  COMM_GET_CUSTOM_CONFIG_XML, // Firmware 5.2 added
  COMM_GET_CUSTOM_CONFIG, // Firmware 5.2 added
  COMM_GET_CUSTOM_CONFIG_DEFAULT, // Firmware 5.2 added
  COMM_SET_CUSTOM_CONFIG, // Firmware 5.2 added

  // BMS commands
  COMM_BMS_GET_VALUES, // Firmware 5.2 added
  COMM_BMS_SET_CHARGE_ALLOWED, // Firmware 5.2 added
  COMM_BMS_SET_BALANCE_OVERRIDE, // Firmware 5.2 added
  COMM_BMS_RESET_COUNTERS, // Firmware 5.2 added
  COMM_BMS_FORCE_BALANCE, // Firmware 5.2 added
  COMM_BMS_ZERO_CURRENT_OFFSET, // Firmware 5.2 added

  // FW updates commands for different HW types
  COMM_JUMP_TO_BOOTLOADER_HW, // Firmware 5.2 added
  COMM_ERASE_NEW_APP_HW, // Firmware 5.2 added
  COMM_WRITE_NEW_APP_DATA_HW, // Firmware 5.2 added
  COMM_ERASE_BOOTLOADER_HW, // Firmware 5.2 added
  COMM_JUMP_TO_BOOTLOADER_ALL_CAN_HW, // Firmware 5.2 added
  COMM_ERASE_NEW_APP_ALL_CAN_HW, // Firmware 5.2 added
  COMM_WRITE_NEW_APP_DATA_ALL_CAN_HW, // Firmware 5.2 added
  COMM_ERASE_BOOTLOADER_ALL_CAN_HW, // Firmware 5.2 added

  COMM_SET_ODOMETER, // Firmware 5.2 added
}

// CAN commands
// From datatypes.h
enum CAN_PACKET_ID {
  CAN_PACKET_SET_DUTY,
  CAN_PACKET_SET_CURRENT,
  CAN_PACKET_SET_CURRENT_BRAKE,
  CAN_PACKET_SET_RPM,
  CAN_PACKET_SET_POS,
  CAN_PACKET_FILL_RX_BUFFER,
  CAN_PACKET_FILL_RX_BUFFER_LONG,
  CAN_PACKET_PROCESS_RX_BUFFER,
  CAN_PACKET_PROCESS_SHORT_BUFFER,
  CAN_PACKET_STATUS,
  CAN_PACKET_SET_CURRENT_REL,
  CAN_PACKET_SET_CURRENT_BRAKE_REL,
  CAN_PACKET_SET_CURRENT_HANDBRAKE,
  CAN_PACKET_SET_CURRENT_HANDBRAKE_REL,
  CAN_PACKET_STATUS_2,
  CAN_PACKET_STATUS_3,
  CAN_PACKET_STATUS_4,
  CAN_PACKET_PING,
  CAN_PACKET_PONG,
  CAN_PACKET_DETECT_APPLY_ALL_FOC,
  CAN_PACKET_DETECT_APPLY_ALL_FOC_RES,
  CAN_PACKET_CONF_CURRENT_LIMITS,
  CAN_PACKET_CONF_STORE_CURRENT_LIMITS,
  CAN_PACKET_CONF_CURRENT_LIMITS_IN,
  CAN_PACKET_CONF_STORE_CURRENT_LIMITS_IN,
  CAN_PACKET_CONF_FOC_ERPMS,
  CAN_PACKET_CONF_STORE_FOC_ERPMS,
  CAN_PACKET_STATUS_5,
  CAN_PACKET_POLL_TS5700N8501_STATUS,
  CAN_PACKET_CONF_BATTERY_CUT,
  CAN_PACKET_CONF_STORE_BATTERY_CUT,
  CAN_PACKET_SHUTDOWN,
  CAN_PACKET_IO_BOARD_ADC_1_TO_4, // Firmware 5.2 added
  CAN_PACKET_IO_BOARD_ADC_5_TO_8, // Firmware 5.2 added
  CAN_PACKET_IO_BOARD_ADC_9_TO_12, // Firmware 5.2 added
  CAN_PACKET_IO_BOARD_DIGITAL_IN, // Firmware 5.2 added
  CAN_PACKET_IO_BOARD_SET_OUTPUT_DIGITAL, // Firmware 5.2 added
  CAN_PACKET_IO_BOARD_SET_OUTPUT_PWM, // Firmware 5.2 added
  CAN_PACKET_BMS_V_TOT, // Firmware 5.2 added
  CAN_PACKET_BMS_I, // Firmware 5.2 added
  CAN_PACKET_BMS_AH_WH, // Firmware 5.2 added
  CAN_PACKET_BMS_V_CELL, // Firmware 5.2 added
  CAN_PACKET_BMS_BAL, // Firmware 5.2 added
  CAN_PACKET_BMS_TEMPS, // Firmware 5.2 added
  CAN_PACKET_BMS_HUM, // Firmware 5.2 added
  CAN_PACKET_BMS_SOC_SOH_TEMP_STAT // Firmware 5.2 added
}

// VESC based ESC faults
// From datatypes.h
enum mc_fault_code {
  FAULT_CODE_NONE,
  FAULT_CODE_OVER_VOLTAGE,
  FAULT_CODE_UNDER_VOLTAGE,
  FAULT_CODE_DRV,
  FAULT_CODE_ABS_OVER_CURRENT,
  FAULT_CODE_OVER_TEMP_FET,
  FAULT_CODE_OVER_TEMP_MOTOR,
  FAULT_CODE_GATE_DRIVER_OVER_VOLTAGE,
  FAULT_CODE_GATE_DRIVER_UNDER_VOLTAGE,
  FAULT_CODE_MCU_UNDER_VOLTAGE,
  FAULT_CODE_BOOTING_FROM_WATCHDOG_RESET,
  FAULT_CODE_ENCODER_SPI,
  FAULT_CODE_ENCODER_SINCOS_BELOW_MIN_AMPLITUDE,
  FAULT_CODE_ENCODER_SINCOS_ABOVE_MAX_AMPLITUDE,
  FAULT_CODE_FLASH_CORRUPTION,
  FAULT_CODE_HIGH_OFFSET_CURRENT_SENSOR_1,
  FAULT_CODE_HIGH_OFFSET_CURRENT_SENSOR_2,
  FAULT_CODE_HIGH_OFFSET_CURRENT_SENSOR_3,
  FAULT_CODE_UNBALANCED_CURRENTS,
  FAULT_CODE_BRK,
  FAULT_CODE_RESOLVER_LOT,
  FAULT_CODE_RESOLVER_DOS,
  FAULT_CODE_RESOLVER_LOS,
  FAULT_CODE_FLASH_CORRUPTION_APP_CFG, // Firmware 5.2 added
  FAULT_CODE_FLASH_CORRUPTION_MC_CFG, // Firmware 5.2 added
  FAULT_CODE_ENCODER_NO_MAGNET // Firmware 5.2 added
}

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
    List<ESCFault> response = new List();
    int index = 0;
    for (int i=0; i<faultCount; ++i) {
      ESCFault fault = new ESCFault();
      fault.faultCode = payload[index++];
      fault.faultCount = buffer_get_uint16(payload, index); index += 2;
      fault.escID = buffer_get_uint16(payload, index); index += 2;
      index += 3; //NOTE: Alignment
      fault.firstSeen = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(payload, index, Endian.little) * 1000, isUtc: true); index += 8;
      fault.lastSeen = new DateTime.fromMillisecondsSinceEpoch(buffer_get_uint64(payload, index, Endian.little) * 1000, isUtc: true); index += 8;
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
    telemetryPacket.position = buffer_get_float32(payload, index, 10.0); index += 4;
    telemetryPacket.vesc_id = payload[index++];
    telemetryPacket.temp_mos_1 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_mos_2 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.temp_mos_3 = buffer_get_float16(payload, index, 10.0); index += 2;
    telemetryPacket.vd = buffer_get_float32(payload, index, 100.0); index += 4;
    telemetryPacket.vq = buffer_get_float32(payload, index, 100.0);

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

