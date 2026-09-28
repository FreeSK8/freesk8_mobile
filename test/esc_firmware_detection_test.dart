import 'package:flutter_test/flutter_test.dart';

import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/mcConf.dart';

void main() {
  test('firmwareFor maps reported versions to supported releases', () {
    expect(ESCHelper.firmwareFor(5, 1), ESC_FIRMWARE.FW5_1);
    expect(ESCHelper.firmwareFor(5, 2), ESC_FIRMWARE.FW5_2);
    expect(ESCHelper.firmwareFor(5, 3), ESC_FIRMWARE.FW5_3);
    expect(ESCHelper.firmwareFor(6, 0), ESC_FIRMWARE.FW6_0);
    expect(ESCHelper.firmwareFor(6, 2), ESC_FIRMWARE.FW6_2);
    expect(ESCHelper.firmwareFor(6, 5), ESC_FIRMWARE.FW6_5);
    expect(ESCHelper.firmwareFor(6, 6), ESC_FIRMWARE.FW6_6);
    expect(ESCHelper.firmwareFor(7, 0), ESC_FIRMWARE.FW7_0);
  });

  test('unknown 7.x minors use the 7.00 layout, other unknown versions are unsupported', () {
    expect(ESCHelper.firmwareFor(7, 1), ESC_FIRMWARE.FW7_0);
    expect(ESCHelper.firmwareFor(6, 3), ESC_FIRMWARE.UNSUPPORTED);
    expect(ESCHelper.firmwareFor(6, 7), ESC_FIRMWARE.UNSUPPORTED);
    expect(ESCHelper.firmwareFor(5, 0), ESC_FIRMWARE.UNSUPPORTED);
    expect(ESCHelper.firmwareFor(8, 0), ESC_FIRMWARE.UNSUPPORTED);
  });

  test('firmwareLabel zero-pads the minor like VESC Tool', () {
    expect(ESCHelper.firmwareLabel(6, 5), '6.05');
    expect(ESCHelper.firmwareLabel(7, 0), '7.00');
    expect(ESCHelper.firmwareLabel(5, 3), '5.03');
  });

  test('firmware features follow the release history', () {
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_2).hasBalanceApp, isTrue);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_5).hasBalanceApp, isFalse);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_2).hasRegenCutoff, isFalse);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_5).hasRegenCutoff, isTrue);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_5).hasOffsetsCalMode, isFalse);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_6).hasOffsetsCalMode, isTrue);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW5_3).adcButtonsBitmask, isFalse);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW7_0).adcButtonsBitmask, isTrue);
    expect(FirmwareFeatures(ESC_FIRMWARE.UNSUPPORTED).hasBalanceApp, isFalse);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW5_2).hasOffsetsCalOnBoot, isFalse);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW5_3).hasOffsetsCalOnBoot, isTrue);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_5).hasOffsetsCalOnBoot, isTrue);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_6).hasOffsetsCalOnBoot, isFalse);
    expect(FirmwareFeatures(ESC_FIRMWARE.UNSUPPORTED).hasOffsetsCalOnBoot, isFalse);
  });

  test('sensor mode lists grow with the firmware', () {
    expect(FirmwareFeatures(ESC_FIRMWARE.FW5_1).sensorModes.last, mc_foc_sensor_mode.FOC_SENSOR_MODE_HFI);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW5_3).sensorModes.last, mc_foc_sensor_mode.FOC_SENSOR_MODE_HFI_START);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_0).sensorModes.last, mc_foc_sensor_mode.FOC_SENSOR_MODE_HFI_V5);
    expect(FirmwareFeatures(ESC_FIRMWARE.FW6_6).sensorModes, isNot(contains(mc_foc_sensor_mode.FOC_SENSOR_MODE_ENCODER_AB)));
    expect(FirmwareFeatures(ESC_FIRMWARE.FW7_0).sensorModes.last, mc_foc_sensor_mode.FOC_SENSOR_MODE_ENCODER_AB);
    expect(FirmwareFeatures(ESC_FIRMWARE.UNSUPPORTED).sensorModes, mc_foc_sensor_mode.values);
  });

  test('fault codes newer than this build decode to FAULT_CODE_UNKNOWN', () {
    expect(faultCodeFromWire(0), mc_fault_code.FAULT_CODE_NONE);
    expect(faultCodeFromWire(1), mc_fault_code.FAULT_CODE_OVER_VOLTAGE);
    expect(faultCodeFromWire(33), mc_fault_code.FAULT_CODE_ABS_OVERSPEED);
    expect(faultCodeFromWire(200), mc_fault_code.FAULT_CODE_UNKNOWN);
    expect(faultCodeFromWire(mc_fault_code.FAULT_CODE_UNKNOWN.index), mc_fault_code.FAULT_CODE_UNKNOWN);
    expect(faultCodeName(1), 'FAULT_CODE_OVER_VOLTAGE');
  });
}
