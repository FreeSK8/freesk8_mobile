// Every supported firmware release: signature check, serialized size, field
// round trips and tolerant enum decoding, driven by the layout tables that
// tool/esc_serializers/generate.py emits next to the generated serializers.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:freesk8_mobile/hardwareSupport/escHelper/appConf.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/mcConf.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/serialization/escConfigSerializer.dart';

const Map<ESC_FIRMWARE, String> layoutLabel = {
  ESC_FIRMWARE.FW5_1: '5.1',
  ESC_FIRMWARE.FW5_2: '5.2',
  ESC_FIRMWARE.FW5_3: '5.3',
  ESC_FIRMWARE.FW6_0: '6.0',
  ESC_FIRMWARE.FW6_2: '6.0',
  ESC_FIRMWARE.FW6_5: '6.05',
  ESC_FIRMWARE.FW6_6: '6.06',
  ESC_FIRMWARE.FW7_0: '7.0',
};

/// Wire format: one packet-id byte followed by the serialized configuration.
Uint8List packet(ByteData serialized) => Uint8List.fromList([0, ...serialized.buffer.asUint8List(serialized.offsetInBytes, serialized.lengthInBytes)]);

class Layout {
  Layout(this.json);
  final Map<String, dynamic> json;

  List<Map<String, dynamic>> fields(String kind) => (json[kind]['fields'] as List).cast<Map<String, dynamic>>();
  int size(String kind) => json[kind]['size'] as int;
  int signature(String kind) => json[kind]['signature'] as int;
  bool has(String kind, String dartPath) => fields(kind).any((f) => f['dart'] == dartPath);
  List<String> enumMembers(String cEnum) => (json['enums'][cEnum] as List).cast<String>();

  /// Byte offset of a field inside the packet (packet id at 0, signature at 1..4).
  int packetOffset(String kind, String dartPath) {
    int offset = 1 + 4;
    for (final f in fields(kind)) {
      if (f['dart'] == dartPath) return offset;
      offset += f['size'] as int;
    }
    throw StateError('$dartPath not in $kind layout');
  }
}

void main() {
  final helper = ESCHelper();

  for (final fw in ESC_FIRMWARE.values.where((f) => f != ESC_FIRMWARE.UNSUPPORTED)) {
    final EscConfigSerializer serializer = ESCHelper.serializerFor(fw);
    final Layout layout = Layout(jsonDecode(File('tool/esc_serializers/layouts/${layoutLabel[fw]}.json').readAsStringSync()));

    group('$fw', () {
      test('the sensor modes offered in the motor editor are the ones this firmware declares', () {
        expect(FirmwareFeatures(fw).sensorModes.map((m) => m.name).toList(), layout.enumMembers('mc_foc_sensor_mode'));
      });

      test('freshly constructed configurations are not valid', () {
        expect(MCCONF().isValid, isFalse);
        expect(APPCONF().isValid, isFalse);
      });

      test('signature mismatch yields an invalid configuration', () {
        final bogus = Uint8List(600);
        expect(helper.processMCCONF(bogus, fw).isValid, isFalse);
        expect(helper.processAPPCONF(bogus, fw).isValid, isFalse);
      });

      test('serialized sizes and signatures match the firmware layout', () {
        expect(serializer.mcconfSize, layout.size('mcconf'));
        expect(serializer.appconfSize, layout.size('appconf'));
        expect(serializer.mcconfSignature, layout.signature('mcconf'));
        expect(serializer.appconfSignature, layout.signature('appconf'));
        final mc = helper.serializeMCCONF(MCCONF(), fw);
        final app = helper.serializeAPPCONF(APPCONF(), fw);
        expect(mc.lengthInBytes, layout.size('mcconf'));
        expect(app.lengthInBytes, layout.size('appconf'));
        expect(mc.getUint32(0), serializer.mcconfSignature);
        expect(app.getUint32(0), serializer.appconfSignature);
      });

      test('MCCONF round trip preserves representative fields of every kind', () {
        final conf = MCCONF()
          ..l_current_max = 42.5 // float32_auto
          ..l_temp_fet_start = 85 // float16 on 5.x/6.0, whole degrees (u8) on 6.05+
          ..l_slow_abs_current = true // bool
          ..hall_table[1] = -1 // int8
          ..foc_sensor_mode = mc_foc_sensor_mode.FOC_SENSOR_MODE_HALL // enum
          ..si_battery_cells = 12 // u8
          ..si_wheel_diameter = 0.09 // float32_auto
          ..si_battery_ah = 12.5;
        if (layout.has('mcconf', 'foc_sat_comp')) conf.foc_sat_comp = 0.123; // float16/1000
        if (layout.has('mcconf', 'bms.soc_limit_start')) conf.bms.soc_limit_start = 0.25; // float16/1000
        if (layout.has('mcconf', 'bms.limit_mode')) conf.bms.limit_mode = 2;
        if (layout.has('mcconf', 'bms.fwd_can_mode')) conf.bms.fwd_can_mode = BMS_FWD_CAN_MODE.BMS_FWD_CAN_MODE_ANY; // last field
        if (layout.has('mcconf', 'foc_encoder_ratio')) conf.foc_encoder_ratio = 7.0;
        if (layout.has('mcconf', 'l_battery_regen_cut_start')) conf.l_battery_regen_cut_start = 50.4; // float16/10
        if (layout.has('mcconf', 'foc_offsets_cal_mode')) conf.foc_offsets_cal_mode = 3;
        if (layout.has('mcconf', 'foc_hfi_amb_mode')) conf.foc_hfi_amb_mode = mc_foc_hfi_amb_mode.FOC_AMB_MODE_D_DOUBLE_PULSE;
        if (layout.has('mcconf', 'foc_mag_vd_max')) conf.foc_mag_vd_max = 0.5;

        final round = helper.processMCCONF(packet(helper.serializeMCCONF(conf, fw)), fw);
        expect(round.isValid, isTrue);
        expect(round.l_current_max, closeTo(42.5, 1e-4));
        expect(round.l_temp_fet_start, closeTo(85, 1e-4));
        expect(round.l_slow_abs_current, isTrue);
        expect(round.hall_table[1], -1);
        expect(round.foc_sensor_mode, mc_foc_sensor_mode.FOC_SENSOR_MODE_HALL);
        expect(round.si_battery_cells, 12);
        expect(round.si_wheel_diameter, closeTo(0.09, 1e-6));
        expect(round.si_battery_ah, closeTo(12.5, 1e-4));
        if (layout.has('mcconf', 'foc_sat_comp')) expect(round.foc_sat_comp, closeTo(0.123, 1e-6));
        if (layout.has('mcconf', 'bms.soc_limit_start')) expect(round.bms.soc_limit_start, closeTo(0.25, 1e-6));
        if (layout.has('mcconf', 'bms.limit_mode')) expect(round.bms.limit_mode, 2);
        if (layout.has('mcconf', 'bms.fwd_can_mode')) expect(round.bms.fwd_can_mode, BMS_FWD_CAN_MODE.BMS_FWD_CAN_MODE_ANY);
        if (layout.has('mcconf', 'foc_encoder_ratio')) expect(round.foc_encoder_ratio, closeTo(7.0, 1e-6));
        if (layout.has('mcconf', 'l_battery_regen_cut_start')) expect(round.l_battery_regen_cut_start, closeTo(50.4, 1e-6));
        if (layout.has('mcconf', 'foc_offsets_cal_mode')) expect(round.foc_offsets_cal_mode, 3);
        if (layout.has('mcconf', 'foc_hfi_amb_mode')) expect(round.foc_hfi_amb_mode, mc_foc_hfi_amb_mode.FOC_AMB_MODE_D_DOUBLE_PULSE);
        if (layout.has('mcconf', 'foc_mag_vd_max')) expect(round.foc_mag_vd_max, closeTo(0.5, 1e-4));
      });

      test('APPCONF round trip preserves representative fields of every kind', () {
        final conf = APPCONF()
          ..controller_id = 7 // u8
          ..timeout_msec = 1234 // uint32
          ..timeout_brake_current = 3.5 // float32_auto
          ..app_to_use = app_use.APP_UART // enum
          ..app_ppm_conf.hyst = 0.15
          ..imu_conf.gyro_offsets[2] = 1.5; // last block of the struct
        if (layout.has('appconf', 'app_to_use')) conf.app_to_use = app_use.APP_UART;
        if (layout.has('appconf', 'app_ppm_conf.ctrl_type')) conf.app_ppm_conf.ctrl_type = ppm_control_type.PPM_CTRL_TYPE_CURRENT_NOREV_BRAKE;
        if (layout.has('appconf', 'app_chuk_conf.coast_brake_level')) conf.app_chuk_conf.coast_brake_level = 0.123;

        final round = helper.processAPPCONF(packet(helper.serializeAPPCONF(conf, fw)), fw);
        expect(round.isValid, isTrue);
        expect(round.controller_id, 7);
        expect(round.timeout_msec, 1234);
        expect(round.timeout_brake_current, closeTo(3.5, 1e-4));
        expect(round.app_to_use, app_use.APP_UART);
        expect(round.app_ppm_conf.hyst, closeTo(0.15, 1e-6));
        expect(round.imu_conf.gyro_offsets[2], closeTo(1.5, 1e-6));
        if (layout.has('appconf', 'app_ppm_conf.ctrl_type')) expect(round.app_ppm_conf.ctrl_type, ppm_control_type.PPM_CTRL_TYPE_CURRENT_NOREV_BRAKE);
        if (layout.has('appconf', 'app_chuk_conf.coast_brake_level')) expect(round.app_chuk_conf.coast_brake_level, closeTo(0.123, 1e-6));
      });

      test('an enum wire value this build does not know falls back instead of throwing', () {
        final bytes = packet(helper.serializeMCCONF(MCCONF(), fw));
        bytes[layout.packetOffset('mcconf', 'foc_sensor_mode')] = 0xFF;
        final round = helper.processMCCONF(bytes, fw);
        expect(round.isValid, isTrue);
        expect(round.foc_sensor_mode, mc_foc_sensor_mode.values.first);
      });

      test('app_use survives the firmware 6.05 index shift', () {
        final conf = APPCONF()..app_to_use = app_use.APP_PAS;
        final bytes = packet(helper.serializeAPPCONF(conf, fw));
        final wire = bytes[layout.packetOffset('appconf', 'app_to_use')];
        // APP_BALANCE was removed from the middle of the enum in 6.05, so PAS
        // moved from wire index 10 to 9.
        expect(wire, fw.index >= ESC_FIRMWARE.FW6_5.index ? 9 : 10);
        expect(helper.processAPPCONF(bytes, fw).app_to_use, app_use.APP_PAS);
      }, skip: layout.has('appconf', 'app_to_use') && !layout.fields('appconf').any((f) => f['dart'] == 'app_pas_conf.ctrl_type') ? 'no PAS app on this firmware' : false);
    });
  }

  test('firmware 6.05 does not accept the balance app; it is written as APP_NONE', () {
    final conf = APPCONF()..app_to_use = app_use.APP_BALANCE;
    final round = helper.processAPPCONF(packet(helper.serializeAPPCONF(conf, ESC_FIRMWARE.FW6_5)), ESC_FIRMWARE.FW6_5);
    expect(round.isValid, isTrue);
    expect(round.app_to_use, app_use.APP_NONE);
  });

  test('firmware 6.02 uses the 6.00 serializer', () {
    expect(identical(ESCHelper.serializerFor(ESC_FIRMWARE.FW6_2), ESCHelper.serializerFor(ESC_FIRMWARE.FW6_0)), isTrue);
  });

  test('unsupported firmware has no serializer', () {
    expect(() => ESCHelper.serializerFor(ESC_FIRMWARE.UNSUPPORTED), throwsStateError);
  });
}
