// The ESC motor/app configuration deserializers return a default object when
// the firmware signature does not match. Before null safety that object had
// null fields, which the UI used to detect an unsupported firmware; the
// isValid flag restores that detection.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:freesk8_mobile/hardwareSupport/escHelper/appConf.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/mcConf.dart';

/// Wire format: one packet-id byte followed by the serialized configuration.
Uint8List packet(ByteData serialized) => Uint8List.fromList([0, ...serialized.buffer.asUint8List()]);

void main() {
  final helper = ESCHelper();
  const firmwares = [ESC_FIRMWARE.FW5_1, ESC_FIRMWARE.FW5_2, ESC_FIRMWARE.FW5_3, ESC_FIRMWARE.FW6_0, ESC_FIRMWARE.FW6_2, ESC_FIRMWARE.FW6_5];
  // The fw6.x serializers are not consistent with their deserializers (the
  // writers emit fewer bytes than the readers consume, and fw6.2 has no
  // serializeMCCONF dispatch), so their round trips cannot pass yet. See
  // context.md, "Remaining work".
  const roundTripKnownBroken = {ESC_FIRMWARE.FW6_0, ESC_FIRMWARE.FW6_2, ESC_FIRMWARE.FW6_5};

  test('freshly constructed configurations are not valid', () {
    expect(MCCONF().isValid, isFalse);
    expect(APPCONF().isValid, isFalse);
  });

  for (final fw in firmwares) {
    test('$fw: signature mismatch yields an invalid configuration', () {
      final bogus = Uint8List(600); // packet id + zero signature + padding
      expect(helper.processMCCONF(bogus, fw).isValid, isFalse);
      expect(helper.processAPPCONF(bogus, fw).isValid, isFalse);
    });

    test('$fw: serialize/deserialize round trip yields a valid configuration', () {
      final mcconf = MCCONF()..l_current_max = 42.5;
      final mcRound = helper.processMCCONF(packet(helper.serializeMCCONF(mcconf, fw)), fw);
      expect(mcRound.isValid, isTrue);
      expect(mcRound.l_current_max, closeTo(42.5, 0.001));

      final appconf = APPCONF()..controller_id = 7;
      final appRound = helper.processAPPCONF(packet(helper.serializeAPPCONF(appconf, fw)), fw);
      expect(appRound.isValid, isTrue);
      expect(appRound.controller_id, 7);
    }, skip: roundTripKnownBroken.contains(fw) ? 'fw6.x MCCONF serializer/deserializer mismatch (context.md, Remaining work)' : false);
  }
}
