// Regression tests for ESCHelper.processFirmware hardware-name decoding.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';

Uint8List firmwarePayload(String name, {bool terminated = true}) {
  // COMM_FW_VERSION reply: [packet id, major, minor, name..., 0, ...]
  return Uint8List.fromList([
    0,
    6,
    2,
    ...name.codeUnits,
    if (terminated) 0,
  ]);
}

void main() {
  final helper = ESCHelper();

  test('short hardware name has no trailing NUL padding', () {
    final fw = helper.processFirmware(firmwarePayload('HW_60'));
    expect(fw.fw_version_major, 6);
    expect(fw.fw_version_minor, 2);
    expect(fw.hardware_name, 'HW_60');
    expect(fw.hardware_name.contains('\u0000'), isFalse);
  });

  test('hardware name longer than 30 characters is decoded intact', () {
    const longName = 'FreeSK8-Very-Long-Hardware-Name-Rev-2024';
    expect(longName.length, greaterThan(30));
    final fw = helper.processFirmware(firmwarePayload(longName));
    expect(fw.hardware_name, longName);
  });

  test('unterminated hardware name does not read past the payload', () {
    final fw = helper.processFirmware(firmwarePayload('HW_75', terminated: false));
    expect(fw.hardware_name, 'HW_75');
  });
}
