import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

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

Future<void> sendBLEData(BluetoothCharacteristic txCharacteristic, Uint8List data, BluetoothDevice device) async
{
  dynamic errorCheck = 0;
  while (errorCheck != null && device != null) {
    errorCheck = null;
    await txCharacteristic.write(data).catchError((error){
      errorCheck = error;
      print("sendBLEData: Exception: $errorCheck");
    });
  }
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