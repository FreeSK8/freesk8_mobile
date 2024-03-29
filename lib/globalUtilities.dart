import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:logger/logger.dart';

import 'components/crc16.dart';
import 'hardwareSupport/escHelper/dataTypes.dart';

import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:latlong2/latlong.dart';

void setLandscapeOrientation({bool enabled}) {
  SystemChrome.setPreferredOrientations(
      enabled ? [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ] : [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]
  );
}

// Google Chart Colors
var googleChartsDefaultColors = [0xff3366cc,
  0xffdc3912,
  0xffff9900,
  0xff109618,
  0xff990099,
  0xff0099c6,
  0xffdd4477,
  0xff66aa00,
  0xffb82e2e,
  0xff316395,
  0xff994499,
  0xff22aa99,
  0xffaaaa11,
  0xff6633cc,
  0xffe67300,
  0xff8b0707,
  0xff651067,
  0xff329262,
  0xff5574a6,
  0xff3b3eac,
  0xffb77322,
  0xff16d620,
  0xffb91383,
  0xfff4359e,
  0xff9c5935,
  0xffa9c413,
  0xff2a778d,
  0xff668d1c,
  0xffbea413,
  0xff0c5922,
  0xff743411];

Color multiColorLerp(Color colorA, Color colorB, Color colorC, double value) {
  value = value.clamp(0.0, 1.0);
  Color result;
  if (value < 0.5) {
    result = HSVColor.lerp(
        HSVColor.fromColor(colorA),
        HSVColor.fromColor(colorB),
        value * 2).toColor();
  }
  else {
    result = HSVColor.lerp(
        HSVColor.fromColor(colorB),
        HSVColor.fromColor(colorC),
        value * 2 - 1).toColor();
  }
  return result;
}

List<double> normalize(List<double> array) {
  final lower = array.reduce(min);
  final upper = array.reduce(max);
  final List<double> normalized = [];

  array.forEach((element) => element < 0
      ? normalized.add(-(element / lower))
      : normalized.add(element / upper));

  return normalized;
}

List<double> normalizeToGroup(List<double> array, List<List<double>> group) {
  double lower = 0;
  double upper = 0;
  group.forEach((element) {
    final minimum = element.reduce(min);
    final maximum = element.reduce(max);
    if (minimum < lower) lower = minimum;
    if (maximum > upper) upper = maximum;
  });

  final List<double> normalized = [];

  array.forEach((element) => element < 0
      ? normalized.add(-(element / lower))
      : normalized.add(element / upper));

  return normalized;
}

class Dialogs {
  static Future<void> showPleaseWaitDialog(
      BuildContext context, GlobalKey key) async {
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new WillPopScope(
              onWillPop: () async => false,
              child: SimpleDialog(
                  key: key,
                  backgroundColor: Colors.black54,
                  children: <Widget>[
                    Center(
                      child: Column(children: [
                        Icon(Icons.watch_later, size: 80,),
                        SizedBox(height: 10,),
                        Text("Please Wait....")
                      ]),
                    )
                  ]));
        });
  }

  static Future<void> showFOCDialog(
      BuildContext context, GlobalKey key) async {
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new WillPopScope(
              onWillPop: () async => false,
              child: SimpleDialog(
                  key: key,
                  backgroundColor: Colors.black54,
                  children: <Widget>[
                    Center(
                      child: Column(children: [
                        Icon(Icons.watch_later, size: 80,),
                        SizedBox(height: 10,),
                        Text("Please Wait...."),
                        Text("Be sure the wheels are off the ground!")
                      ]),
                    )
                  ]));
        });
  }
}

double calculateGPSDistance(LatLng pointA, LatLng pointB){
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 - c((pointB.latitude - pointA.latitude) * p)/2 +
      c(pointA.latitude * p) * c(pointB.latitude * p) *
          (1 - c((pointB.longitude - pointA.longitude) * p))/2;
  return 12742 * asin(sqrt(a));
}

void copyDirectory(Directory source, Directory destination) =>
    source.listSync(recursive: false)
        .forEach((var entity) {
      if (entity is Directory) {
        var newDirectory = Directory(path.join(destination.absolute.path, path.basename(entity.path)));
        newDirectory.createSync();

        copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        print(entity);
        entity.copySync(path.join(destination.path, path.basename(entity.path)));
      }
    });

// Define the TabController's indexes
final int controllerViewConnection = 0;
final int controllerViewRealTime = 1;
final int controllerViewLogging = 2;
final int controllerViewConfiguration = 3;

// Format a duration to look nice as a string
prettyPrintDuration(Duration d) => d.toString().split('.').first.padLeft(8, "0");

// RegExp for FilteringTextInputFormatter that allows only positive decimal values
final RegExp formatPositiveDouble = RegExp(r'^[+-]?([0-9]+([.,][0-9]*)?|[.,][0-9]+)$');

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
  List<DropdownMenuItem<ListItem>> items = [];
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
  int errorLimiter = 30;
  int packetLength = data.length;
  int bytesSent = 0;
  while (bytesSent < packetLength) {
    int endByte = bytesSent + 20;
    if (endByte > packetLength) {
      endByte = packetLength;
    }
    try {
      await txCharacteristic.write(
          data.buffer.asUint8List().sublist(bytesSent, endByte),
          withoutResponse: withoutResponse);
    } on PlatformException catch (err) {
      //TODO: Assuming err.code will always be "write_characteristic_error"
      if (--errorLimiter == 0) {
        globalLogger.e("sendBLEData: Write to characteristic exhausted all attempts. Data not sent. ${txCharacteristic.toString()}");
        return Future.value(false);
      } else {
        //TODO: Observed "write_characteristic_error, no instance of BluetoothGatt, have you connected first?" (believed to be resolved)
        //globalLogger.wtf(err);
        continue; // Try again without incrementing bytesSent
      }
    } catch (e) {
      globalLogger.w("sendBLEData: Exception ${e.toString()}");

      if (--errorLimiter == 0) {
        globalLogger.e("sendBLEData: Write to characteristic exhausted all attempts. Data not sent. ${txCharacteristic.toString()}");
        return Future.value(false);
      } else {
        continue; // Try again without incrementing bytesSent
      }
    }
    bytesSent += 20;
    await Future.delayed(const Duration(milliseconds: 30), () {});
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

double cToF(double c, {int places = 2}) {
  double temp = (c * 1.8) + 32;
  return doublePrecision(temp, places);
}

double eRPMToKph(double eRPM, double gearRatio, int wheelDiameterMillimeters, int motorPoles) {
  double ratio = 1.0 / gearRatio;
  int minutesToHour = 60;
  double ratioRpmSpeed = (ratio * minutesToHour * wheelDiameterMillimeters * pi) / ((motorPoles / 2) * 1e6);
  double speed = eRPM * ratioRpmSpeed;
  return doublePrecision(speed, 2);
}

double eDistanceToKm(double eCount, double gearRatio, int wheelDiameterMillimeters, int motorPoles) {
  double ratio = 1.0 / gearRatio;
  double ratioPulseDistance = (ratio * wheelDiameterMillimeters * pi) / ((motorPoles * 3) * 1e6);
  double distance = eCount * ratioPulseDistance;
  return doublePrecision(distance, 2);
}

Future<dynamic> genericConfirmationDialog(BuildContext context, Widget cancelButton, Widget continueButton, String alertTitle, Widget alertBody) {
  // set up the AlertDialog
  AlertDialog alert = AlertDialog(
    shape: RoundedRectangleBorder (
        borderRadius: BorderRadius.all(Radius.circular(10))
    ),
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
        shape: RoundedRectangleBorder (
            borderRadius: BorderRadius.all(Radius.circular(10))
        ),
        title: Text(alertTitle),
        content: SingleChildScrollView(
          child: alertBody
        ),
        actions: <Widget>[
          TextButton(
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