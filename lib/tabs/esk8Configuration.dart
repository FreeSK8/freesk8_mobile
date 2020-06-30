import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:freesk8_mobile/userSettings.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';

class ESK8Configuration extends StatefulWidget {
  ESK8Configuration({@required this.myUserSettings, this.currentDevice});
  final UserSettings myUserSettings;
  final BluetoothDevice currentDevice;
  ESK8ConfigurationState createState() => new ESK8ConfigurationState();

  static const String routeName = "/settings";
}

class ESK8ConfigurationState extends State<ESK8Configuration> {

  File _imageBoardAvatar;

  Future getImage() async {
    var image = await ImagePicker.pickImage(source: ImageSource.camera, maxWidth: 640, maxHeight: 640);

    if ( image != null ) {
      setState(() {
        _imageBoardAvatar = image;
        widget.myUserSettings.settings.boardAvatarPath = _imageBoardAvatar.path;
      });
    }
  }

  final tecBoardAlias = TextEditingController();
  final tecBatterySeriesCount = TextEditingController();
  final tecBatteryCellmAH = TextEditingController();
  final tecBatteryCellMinVoltage = TextEditingController();
  final tecBatteryCellMaxVoltage = TextEditingController();
  final tecWheelDiameterMillimeters = TextEditingController();
  final tecPulleyMotorToothCount = TextEditingController();
  final tecPulleyWheelToothCount = TextEditingController();
  final tecMotorKV = TextEditingController();
  final tecMotorPoles = TextEditingController();

  @override
  void initState() {
    super.initState();

    //TODO: these try parse can return null.. then the device will remove null because it's not a number
    tecBoardAlias.addListener(() { widget.myUserSettings.settings.boardAlias = tecBoardAlias.text; });
    tecBatterySeriesCount.addListener(() { widget.myUserSettings.settings.batterySeriesCount = int.tryParse(tecBatterySeriesCount.text); });
    tecBatteryCellmAH.addListener(() { widget.myUserSettings.settings.batteryCellmAH = int.tryParse(tecBatteryCellmAH.text); });
    tecBatteryCellMinVoltage.addListener(() { widget.myUserSettings.settings.batteryCellMinVoltage = double.tryParse(tecBatteryCellMinVoltage.text); });
    tecBatteryCellMaxVoltage.addListener(() { widget.myUserSettings.settings.batteryCellMaxVoltage = double.tryParse(tecBatteryCellMaxVoltage.text); });
    tecWheelDiameterMillimeters.addListener(() { widget.myUserSettings.settings.wheelDiameterMillimeters = int.tryParse(tecWheelDiameterMillimeters.text); });
    tecPulleyMotorToothCount.addListener(() { widget.myUserSettings.settings.pulleyMotorToothCount = int.tryParse(tecPulleyMotorToothCount.text); });
    tecPulleyWheelToothCount.addListener(() { widget.myUserSettings.settings.pulleyWheelToothCount = int.tryParse(tecPulleyWheelToothCount.text); });
    tecMotorKV.addListener(() { widget.myUserSettings.settings.motorKV = int.tryParse(tecMotorKV.text); });
    tecMotorPoles.addListener(() { widget.myUserSettings.settings.motorPoles = int.tryParse(tecMotorPoles.text); });
  }


  @override
  void dispose() {
    super.dispose();

    tecBoardAlias.dispose();
    tecBatterySeriesCount.dispose();
    tecBatteryCellmAH.dispose();
    tecBatteryCellMinVoltage.dispose();
    tecBatteryCellMaxVoltage.dispose();
    tecWheelDiameterMillimeters.dispose();
    tecPulleyMotorToothCount.dispose();
    tecPulleyWheelToothCount.dispose();
    tecMotorKV.dispose();
    tecMotorPoles.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: ESK8Configuration");

    tecBoardAlias.text = widget.myUserSettings.settings.boardAlias;
    if (widget.myUserSettings.settings.boardAvatarPath != null) _imageBoardAvatar = File(widget.myUserSettings.settings.boardAvatarPath);
    tecBatterySeriesCount.text = widget.myUserSettings.settings.batterySeriesCount.toString();
    tecBatteryCellmAH.text = widget.myUserSettings.settings.batteryCellmAH.toString();
    tecBatteryCellMinVoltage.text = widget.myUserSettings.settings.batteryCellMinVoltage.toString();
    tecBatteryCellMaxVoltage.text = widget.myUserSettings.settings.batteryCellMaxVoltage.toString();
    tecWheelDiameterMillimeters.text = widget.myUserSettings.settings.wheelDiameterMillimeters.toString();
    tecPulleyMotorToothCount.text = widget.myUserSettings.settings.pulleyMotorToothCount.toString();
    tecPulleyWheelToothCount.text = widget.myUserSettings.settings.pulleyWheelToothCount.toString();
    tecMotorKV.text = widget.myUserSettings.settings.motorKV.toString();
    tecMotorPoles.text = widget.myUserSettings.settings.motorPoles.toString();

    return Container(
      //padding: EdgeInsets.all(5),
      child: Center(
        child: GestureDetector(
            onTap: () {
              // Hide the keyboard
              FocusScope.of(context).requestFocus(new FocusNode());
            },
            child: ListView(
              padding: EdgeInsets.all(10),
              children: <Widget>[
                Icon(
                  Icons.settings,
                  size: 160.0,
                  color: Colors.blue,
                ),
                Center(child:Text("Configuration of things")),

                SwitchListTile(
                  title: Text("Display imperial distances"),
                  value: widget.myUserSettings.settings.useImperial,
                  onChanged: (bool newValue) { setState((){widget.myUserSettings.settings.useImperial = newValue;}); },
                  secondary: const Icon(Icons.power_input),
                ),
                SwitchListTile(
                  title: Text("Display fahrenheit temperatures"),
                  value: widget.myUserSettings.settings.useFahrenheit,
                  onChanged: (bool newValue) { setState((){widget.myUserSettings.settings.useFahrenheit = newValue;}); },
                  secondary: const Icon(Icons.wb_sunny),
                ),


                Column(
                    children: <Widget>[
                      Center(child: CircleAvatar(
                          backgroundImage: _imageBoardAvatar != null ? FileImage(_imageBoardAvatar) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                          radius: 100,
                          backgroundColor: Colors.white)
                      ),
                      SizedBox(
                        width: 125,
                        child:  RaisedButton(
                            child:
                              Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Change "),Icon(Icons.camera_alt),],),

                            onPressed: () {
                              getImage();
                            }),
                      )
                    ]

                ),



                TextField(
                    controller: tecBoardAlias,
                    decoration: new InputDecoration(labelText: "Board Name / Alias"),
                    keyboardType: TextInputType.text,
                ),
                TextField(
                  controller: tecBatterySeriesCount,
                  decoration: new InputDecoration(labelText: "Battery Series Count"),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    WhitelistingTextInputFormatter.digitsOnly
                  ]
                ),
                TextField(
                    controller: tecBatteryCellmAH,
                    decoration: new InputDecoration(labelText: "Battery Cell mAH"),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      WhitelistingTextInputFormatter.digitsOnly
                    ]
                ),
                TextField(
                    controller: tecBatteryCellMinVoltage,
                    decoration: new InputDecoration(labelText: "Battery Cell Minimum Voltage"),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                    ]
                ),
                TextField(
                    controller: tecBatteryCellMaxVoltage,
                    decoration: new InputDecoration(labelText: "Battery Cell Maximum Voltage"),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                    ]
                ),
                TextField(
                  controller: tecWheelDiameterMillimeters,
                  decoration: new InputDecoration(labelText: "Wheel Diameter in Millimeters"),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    WhitelistingTextInputFormatter.digitsOnly
                  ],
              ),
                TextField(
                  controller: tecPulleyMotorToothCount,
                  decoration: new InputDecoration(labelText: "Motor Pulley Tooth Count"),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    WhitelistingTextInputFormatter.digitsOnly
                  ],
              ),
                TextField(
                  controller: tecPulleyWheelToothCount,
                  decoration: new InputDecoration(labelText: "Wheel Pulley Tooth Count"),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    WhitelistingTextInputFormatter.digitsOnly
                  ],
              ),
                TextField(
                    controller: tecMotorKV,
                    decoration: new InputDecoration(labelText: "Motor kV"),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      WhitelistingTextInputFormatter.digitsOnly
                    ]
                ),
                TextField(
                    controller: tecMotorPoles,
                    decoration: new InputDecoration(labelText: "Motor Poles"),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      WhitelistingTextInputFormatter.digitsOnly
                    ]
                ),
                RaisedButton(
                  child: Text("Save Settings"),
                  onPressed: () async {
                    FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                    try {
                      if (tecBoardAlias.text.length < 1) tecBoardAlias.text = "Unnamed";
                      widget.myUserSettings.settings.boardAlias = tecBoardAlias.text;
                      widget.myUserSettings.settings.boardAvatarPath = _imageBoardAvatar != null ? _imageBoardAvatar.path : null;
                      widget.myUserSettings.settings.batterySeriesCount = int.parse(tecBatterySeriesCount.text);
                      widget.myUserSettings.settings.batteryCellmAH = int.parse(tecBatteryCellmAH.text);
                      widget.myUserSettings.settings.batteryCellMinVoltage = double.parse(tecBatteryCellMinVoltage.text);
                      widget.myUserSettings.settings.batteryCellMaxVoltage = double.parse(tecBatteryCellMaxVoltage.text);
                      widget.myUserSettings.settings.wheelDiameterMillimeters = int.parse(tecWheelDiameterMillimeters.text);
                      widget.myUserSettings.settings.pulleyMotorToothCount = int.parse(tecPulleyMotorToothCount.text);
                      widget.myUserSettings.settings.pulleyWheelToothCount = int.parse(tecPulleyWheelToothCount.text);
                      widget.myUserSettings.settings.motorKV = int.parse(tecMotorKV.text);
                      widget.myUserSettings.settings.motorPoles = int.parse(tecMotorPoles.text);
                      await widget.myUserSettings.saveSettings();

                    } catch (e) {
                      print("Save Settings Exception $e");
                      Scaffold
                          .of(context)
                          .showSnackBar(SnackBar(content: Text('Sorry friend. Save settings failed =(')));
                    }
                    Scaffold
                        .of(context)
                        .showSnackBar(SnackBar(content: Text('Settings saved')));
                  }),
                RaisedButton(
                  child: Text("Reload Settings"),
                  onPressed: () {
                    setState(() {
                      widget.myUserSettings.reloadSettings();
                      Scaffold
                          .of(context)
                          .showSnackBar(SnackBar(content: Text('Settings loaded from last state')));
                    });
                  }),
            ],
          ),
        ),
      )
    );
  }
}
