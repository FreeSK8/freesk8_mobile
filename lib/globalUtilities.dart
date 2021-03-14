import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:logger/logger.dart';

import 'components/crc16.dart';
import 'hardwareSupport/escHelper/dataTypes.dart';

Uint8List simpleVESCRequest(int messageIndex, {int optionalCANID}) {
  bool sendCAN = optionalCANID != null;
  var byteData = new ByteData(sendCAN ? 8:6); //<start><payloadLen><packetID><crc1><crc2><end>
  byteData.setUint8(0, 0x02);
  byteData.setUint8(1, sendCAN ? 0x03 : 0x01); // Data length
  if (sendCAN) {
    byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
    byteData.setUint8(3, optionalCANID);
  }
  byteData.setUint8(sendCAN ? 4:2, messageIndex);
  int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, sendCAN ? 3:1);
  byteData.setUint16(sendCAN ? 5:3, checksum);
  byteData.setUint8(sendCAN ? 7:5, 0x03); //End of packet

  return byteData.buffer.asUint8List();
}

//TODO: This allows logging in release mode and that's supposedly not cool
//see https://pub.dev/packages/logger#logfilter
class MyFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}
Logger globalLogger = Logger(printer: PrettyPrinter(methodCount: 0), filter: MyFilter());

class Pair<T1, T2> {
  final T1 first;
  final T2 second;

  Pair(this.first, this.second);
}

class ListItem {
  int value;
  String name;

  ListItem(this.value, this.name);
}

List<DropdownMenuItem<ListItem>> buildDropDownMenuItems(List listItems) {
  List<DropdownMenuItem<ListItem>> items = List();
  for (ListItem listItem in listItems) {
    items.add(
      DropdownMenuItem(
        child: Text(listItem.name),
        value: listItem,
      ),
    );
  }
  return items;
}

/// Best method I've derived to ensure data is sent via BLE
/// @param txCharacteristic; The discovered BLE characteristic to write to
/// @param data; Byte data to transmit
/// @param withoutResponse; Write is not guaranteed and will return immediately with success
/// Returns false if write attempt fails
/// Returns true on success
Future<bool> sendBLEData(BluetoothCharacteristic txCharacteristic, Uint8List data, bool withoutResponse) async
{
  dynamic errorCheck = 0;
  int errorLimiter = 10;
  while (errorCheck != null && --errorLimiter > 0) {
    errorCheck = null;
    await txCharacteristic.write(data, withoutResponse: withoutResponse).catchError((error){
      errorCheck = error;
      globalLogger.w("sendBLEData: Exception: $errorCheck");
    });
  }
  if(errorLimiter<0) {
    globalLogger.e("sendBLEData: Write to characteristic exhausted all attempts. Data not sent. ${txCharacteristic.toString()}");
    return Future.value(false);
  }
  return Future.value(true);
}

double kmToMile(double km) {
  double distance = 0.621371 * km;
  return doublePrecision(distance, 2);
}

double mileToKm(double mile) {
  double distance = mile / 0.621371;
  return doublePrecision(distance, 2);
}

double eRPMToKph(double eRpm, double gearRatio, int wheelDiameterMillimeters, int motorPoles) {
  double ratio = 1.0 / gearRatio;
  int minutesToHour = 60;
  double ratioRpmSpeed = (ratio * minutesToHour * wheelDiameterMillimeters * pi) / ((motorPoles / 2) * 1000000);
  double speed = eRpm * ratioRpmSpeed;
  return doublePrecision(speed, 2);
}

double eDistanceToKm(double eCount, double gearRatio, int wheelDiameterMillimeters, int motorPoles) {
  double ratio = 1.0 / gearRatio;
  double ratioPulseDistance = (ratio * wheelDiameterMillimeters * pi) / ((motorPoles * 3) * 1000000);
  double distance = eCount * ratioPulseDistance;
  return doublePrecision(distance, 2);
}

Future<dynamic> genericConfirmationDialog(BuildContext context, Widget cancelButton, Widget continueButton, String alertTitle, Widget alertBody) {
  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    title: Text(alertTitle),
    content: alertBody,
    actions: [
      cancelButton,
      continueButton,
    ],
  );

  // Show the dialog
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

Future<void> genericAlert(BuildContext context, String alertTitle, Widget alertBody, String alertButtonLabel) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(alertTitle),
        content: SingleChildScrollView(
          child: alertBody
        ),
        actions: <Widget>[
          FlatButton(
            child: Text(alertButtonLabel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

double doublePrecision(double val, int places) {
  double mod = pow(10.0, places);
  return ((val * mod).round().toDouble() / mod);
}

class NumberTextInputFormatter extends TextInputFormatter {
  NumberTextInputFormatter({this.decimalRange}) : assert(decimalRange == null || decimalRange > 0);

  final int decimalRange;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    TextEditingValue _newValue = this.sanitize(newValue);
    String text = _newValue.text;

    if (decimalRange == null) {
      return _newValue;
    }

    if (text == '.') {
      return TextEditingValue(
        text: '0.',
        selection: _newValue.selection.copyWith(baseOffset: 2, extentOffset: 2),
        composing: TextRange.empty,
      );
    }

    return this.isValid(text) ? _newValue : oldValue;
  }

  bool isValid(String text) {
    int dots = '.'.allMatches(text).length;

    if (dots == 0) {
      return true;
    }

    if (dots > 1) {
      return false;
    }

    return text.substring(text.indexOf('.') + 1).length <= decimalRange;
  }

  TextEditingValue sanitize(TextEditingValue value) {
    if (false == value.text.contains('-')) {
      return value;
    }

    String text = '-' + value.text.replaceAll('-', '');

    return TextEditingValue(text: text, selection: value.selection, composing: TextRange.empty);
  }
}