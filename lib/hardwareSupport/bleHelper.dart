import '../components/crc16.dart';
import '../globalUtilities.dart';
import 'dart:typed_data';

class BLEHelper {
  int counter = 0;
  int endMessage = 512;
  bool messageRead = false;
  static Uint8List messageReceived = new Uint8List(512);
  int lenPayload = 0;
  static Uint8List payload = new Uint8List(512);
  int payloadStart = 0;

  Uint8List getMessage()
  {
    return messageReceived;
  }

  Uint8List getPayload()
  {
    return payload;
  }

  void resetPacket() {
    //globalLogger.wtf("Resetting packet");
    messageRead = false;
    counter = 0;
    endMessage = 512;
    for (int i = 0; i < 512; ++i) {
      messageReceived[i] = 0;
      payload[i] = 0;
    }
  }

  bool unpackPayload() {
    int crcMessage = 0; //TODO Uint16 from ffi?
    int crcPayload = 0; //TODO Uint16 from ffi?

    //Rebuild CRC from message
    {
      crcMessage = messageReceived[endMessage - 3] << 8;
      crcMessage |= messageReceived[endMessage - 2];
    }
    //NOTE: these function the same
    {
      //var byteData = new ByteData.view(messageReceived.buffer);
      //crcMessage = byteData.getUint16(endMessage - 3);
    }

    for (int i=0; i<lenPayload; ++i) {
      payload[i] = messageReceived[i+payloadStart];
    }

    crcPayload = CRC16.crc16(payload, 0, lenPayload);

    if (crcPayload == crcMessage) {
      return true;
    } else {
      //globalLogger.w("WARNING: CRC Mismatch: message $crcMessage payload $crcPayload");
      return false;
    }
  }

  int processIncomingBytes(List<int> incomingData) {

    Uint8List bytes = new Uint8List.fromList(incomingData);
    //globalLogger.d("Processing incoming bytes $bytes");

    for (int i = 0; i < bytes.length; ++i) {
      messageReceived[counter++] = bytes[i];

      if (counter == 2) {
        switch (messageReceived[0]) {
          case 2: ///2 is the start of packet that <256 bytes in length
            lenPayload = messageReceived[1];
            endMessage = lenPayload + 5; //+5 = <start><lenPayload><payload><crc><crc><end>
            payloadStart = 2;
            //globalLogger.d("message(short) lenPayload is $lenPayload, endMessage is $endMessage");
            break;
          case 3: ///3 is the start of a packet that is >255 bytes in length
            var byteData = new ByteData.view(bytes.buffer);
            lenPayload = byteData.getInt16(1);
            endMessage = lenPayload + 6; //+5 = <start><lenPayload><lenPayload2><payload><crc><crc><end>
            payloadStart = 3;
            //globalLogger.d("message(long) lenPayload is $lenPayload, endMessage is $endMessage");
            break;
          default:
            //NOTE: If the start of the packet isn't 2 or 3 we are out of alignment
            globalLogger.e("BLE buffer unaligned. Resetting. Data to process was ${bytes.length}bytes ${bytes.toString()}");
            resetPacket();
            return 0;
        }
      }

      if (counter >= messageReceived.length) {
        globalLogger.e("processIncomingBytes::ERROR: Counter has reached the end of messageReceived buffer");
        resetPacket(); //TODO: testing reset here
        break;
      }

      if (counter == endMessage && messageReceived[endMessage - 1] == 3) {
        messageReceived[endMessage] = 0;
        messageRead = true;
        //globalLogger.d("messageRead is now true and counter is $counter");
        break;
      }
    } //--for each incomingData

    bool crcPassed = false;
    if (messageRead == true) {
      crcPassed = unpackPayload();
    }

    if (crcPassed) {
      //globalLogger.d("Message CRC passed. Counter is $counter. MessageReceived[$endMessage -1] is ${messageReceived[endMessage - 1]}");
      return lenPayload;
    } else {
      //globalLogger.d("Message CRC did not pass. Counter is $counter. MessageReceived[$endMessage -1] is ${messageReceived[endMessage - 1]}");
      return 0;
    }
  }
}

