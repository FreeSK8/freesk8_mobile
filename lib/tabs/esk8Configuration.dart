import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:freesk8_mobile/escProfileEditor.dart';
import 'package:freesk8_mobile/main.dart';

import 'package:freesk8_mobile/userSettings.dart';
import 'package:freesk8_mobile/escHelper.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';

class ESK8Configuration extends StatefulWidget {
  ESK8Configuration({
    @required this.myUserSettings,
    this.currentDevice,
    this.showESCProfiles,
    this.theTXCharacteristic,
    this.escMotorConfiguration,
    this.onFinished
  });
  final UserSettings myUserSettings;
  final BluetoothDevice currentDevice;
  final bool showESCProfiles;
  final BluetoothCharacteristic theTXCharacteristic;
  final MCCONF escMotorConfiguration;
  final ValueChanged<bool> onFinished;
  ESK8ConfigurationState createState() => new ESK8ConfigurationState();

  static const String routeName = "/settings";
}

class ESK8ConfigurationState extends State<ESK8Configuration> {

  List<ESCProfile> escProfiles = new List<ESCProfile>();
  File _imageBoardAvatar;
  bool _applyESCProfilePermanently;

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

  static double dp(double val, int places) {
    double mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
  }

  @override
  void initState() {
    super.initState();

    _applyESCProfilePermanently = false;

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

  void _loadProfiles() async {
    escProfiles.clear();
    escProfiles.add(await ESCHelper.getESCProfile(0));
    escProfiles.add(await ESCHelper.getESCProfile(1));
    escProfiles.add(await ESCHelper.getESCProfile(2));
  }
  @override
  Widget build(BuildContext context) {
    print("Build: ESK8Configuration");
    if (widget.showESCProfiles) {
      //TODO: do stuff
      double imperialFactor = widget.myUserSettings.settings.useImperial ? 0.621371192 : 1.0;
      String speedUnit = widget.myUserSettings.settings.useImperial ? "mph" : "km/h";
      double speedFactor = ((widget.escMotorConfiguration.si_motor_poles / 2.0) * 60.0 *
          widget.escMotorConfiguration.si_gear_ratio) /
          (widget.escMotorConfiguration.si_wheel_diameter * pi);

      //TODO: load profiles from SharedPreferences
      //_loadProfiles();
      /*
      List<ESCProfile> escProfiles = new List<ESCProfile>();
      escProfiles.add(new ESCProfile(profileName: "Sean Mode"));
      escProfiles[0].l_current_min_scale = widget.escMotorConfiguration.l_current_min_scale / 2;
      escProfiles[0].l_current_max_scale = widget.escMotorConfiguration.l_current_max_scale / 2;
      //escProfiles[0].l_watt_min = widget.escMotorConfiguration.l_watt_min;
      //escProfiles[0].l_watt_max = widget.escMotorConfiguration.l_watt_max;
      escProfiles[0].l_min_erpm = widget.escMotorConfiguration.l_min_erpm / 4;
      escProfiles[0].l_max_erpm = widget.escMotorConfiguration.l_max_erpm / 4;
      escProfiles[0].l_min_duty = widget.escMotorConfiguration.l_min_duty;
      escProfiles[0].l_max_duty = widget.escMotorConfiguration.l_max_duty;
      escProfiles.add(new ESCProfile(profileName: "Renee Mode"));
      escProfiles[1].l_current_min_scale = widget.escMotorConfiguration.l_current_min_scale * .8;
      escProfiles[1].l_current_max_scale = widget.escMotorConfiguration.l_current_max_scale * .8;
      escProfiles[1].l_watt_min = -5000;
      escProfiles[1].l_watt_max = 5000;
      escProfiles[1].l_min_erpm = widget.escMotorConfiguration.l_min_erpm / 2;
      escProfiles[1].l_max_erpm = widget.escMotorConfiguration.l_max_erpm / 2;
      escProfiles[1].l_min_duty = widget.escMotorConfiguration.l_min_duty;
      escProfiles[1].l_max_duty = widget.escMotorConfiguration.l_max_duty;
      escProfiles.add(new ESCProfile(profileName: "Andrew Mode"));
      escProfiles[2].l_current_min_scale = widget.escMotorConfiguration.l_current_min_scale;
      escProfiles[2].l_current_max_scale = widget.escMotorConfiguration.l_current_max_scale;
      //escProfiles[2].l_watt_min = widget.escMotorConfiguration.l_watt_min;
      //escProfiles[2].l_watt_max = widget.escMotorConfiguration.l_watt_max;
      escProfiles[2].l_min_erpm = widget.escMotorConfiguration.l_min_erpm;
      escProfiles[2].l_max_erpm = widget.escMotorConfiguration.l_max_erpm;
      escProfiles[2].l_min_duty = widget.escMotorConfiguration.l_min_duty;
      escProfiles[2].l_max_duty = widget.escMotorConfiguration.l_max_duty;
      // User data
      escProfiles[0].speedKmh = dp(3.6 * escProfiles[0].l_max_erpm / speedFactor, 1);
      escProfiles[0].speedKmhRev = dp(3.6 * -escProfiles[0].l_max_erpm / speedFactor, 1);
      escProfiles[1].speedKmh = dp(3.6 * escProfiles[1].l_max_erpm / speedFactor, 1);
      escProfiles[1].speedKmhRev = dp(3.6 * -escProfiles[1].l_max_erpm / speedFactor, 1);
      escProfiles[2].speedKmh = dp(3.6 * escProfiles[2].l_max_erpm / speedFactor, 1);
      escProfiles[2].speedKmhRev = dp(3.6 * -escProfiles[2].l_max_erpm / speedFactor, 1);
       */

      return Center(
        child: Column(
          children: <Widget>[
            Icon(
              Icons.timer,
              size: 60.0,
              color: Colors.blue,
            ),
            Center(child:Text("ESC Profiles")),

            Expanded(
              child: ListView.builder(
                primary: false,
                padding: EdgeInsets.all(5),
                itemCount: 3,
                itemBuilder: (context, i) {
                  //TODO: Custom icons!?!
                  Icon rowIcon;
                  switch (i) {
                    case 0:
                      rowIcon = Icon(Icons.filter_1);
                      break;
                    case 1:
                      rowIcon = Icon(Icons.filter_2);
                      break;
                    case 2:
                      rowIcon = Icon(Icons.filter_3);
                      break;
                    case 3:
                      rowIcon = Icon(Icons.filter_4);
                      break;
                    default:
                      rowIcon = Icon(Icons.filter_none);
                      break;
                  }
                  return Column(
                    children: <Widget>[

                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          rowIcon,

                          FutureBuilder<String>(
                              future: ESCHelper.getESCProfileName(i),
                              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                if(snapshot.connectionState == ConnectionState.waiting){
                                  return Center(
                                      child:Text("Loading...")
                                  );
                                }
                                return Text("${snapshot.data}");
                              }),
                          SizedBox(width: 75,),
                          RaisedButton(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text("Edit "),
                                Icon(Icons.edit),
                              ],),
                            onPressed: () async {
                              //TODO: edit
                              // navigate to the editor
                              Navigator.of(context).pushNamed(ESCProfileEditor.routeName, arguments: ESCProfileEditorArguments(widget.theTXCharacteristic, await ESCHelper.getESCProfile(i), i));
                            },
                            color: Colors.transparent,
                          ),
                          RaisedButton(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text("Apply "),
                                Icon(Icons.exit_to_app),
                              ],),
                            onPressed: () {
                              //TODO: set MCCONF
                            },
                            color: Colors.transparent,
                          )
                        ]
                      ),

                      FutureBuilder<ESCProfile>(
                          future: ESCHelper.getESCProfile(i),
                          builder: (BuildContext context, AsyncSnapshot<ESCProfile> snapshot) {
                            if(snapshot.connectionState == ConnectionState.waiting){
                              return Center(
                                  child:Text("Loading...")
                              );
                            }
                            Table thisTableData = new Table(
                              children: [
                                TableRow(children: [
                                  Text("Speed Forward", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${snapshot.data.speedKmh} km/h")
                                ]),
                                TableRow(children: [
                                  Text("Speed Reverse", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${snapshot.data.speedKmhRev} km/h")
                                ]),
                                TableRow(children: [
                                  Text("Current Accel", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${snapshot.data.l_current_max_scale * 100} %")
                                ]),
                                TableRow(children: [
                                  Text("Current Brake", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${snapshot.data.l_current_min_scale * 100} %")
                                ]),

                              ],
                            );

                            if (snapshot.data.l_watt_max != 0.0) {
                              thisTableData.children.add(new TableRow(children: [
                                Text("Max Power Out", textAlign: TextAlign.right),
                                Text(":"),
                                Text("${snapshot.data.l_watt_max} W")
                              ]));
                            }

                            if (snapshot.data.l_watt_min != 0.0) {
                              thisTableData.children.add(new TableRow(children: [
                                Text("Max Power Regen", textAlign: TextAlign.right),
                                Text(":"),
                                Text("${snapshot.data.l_watt_min} W")
                              ]));
                            }
                            return thisTableData;
                          }),
                      SizedBox(height: 20,)
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              height: 115,
              child: ListView(
                padding: EdgeInsets.all(5),
                primary: false,
                children: <Widget>[
                  SwitchListTile(
                    title: Text("Retain profile after ESC is reset?"),
                    value: _applyESCProfilePermanently,
                    onChanged: (bool newValue) { setState((){_applyESCProfilePermanently = newValue;}); },
                    secondary: const Icon(Icons.memory),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                    RaisedButton(child:
                      Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Finished"),Icon(Icons.check),],),
                        onPressed: () {
                          widget.onFinished(false);
                        })
                  ],)
                ],
              ),
            )
          ],
        ),
      );
    }

    tecBoardAlias.text = widget.myUserSettings.settings.boardAlias;
    tecBoardAlias.selection = TextSelection.fromPosition(TextPosition(offset: tecBoardAlias.text.length));
    if (widget.myUserSettings.settings.boardAvatarPath != null) _imageBoardAvatar = File(widget.myUserSettings.settings.boardAvatarPath);
    tecBatterySeriesCount.text = widget.myUserSettings.settings.batterySeriesCount.toString();
    tecBatterySeriesCount.selection = TextSelection.fromPosition(TextPosition(offset: tecBatterySeriesCount.text.length));
    tecBatteryCellmAH.text = widget.myUserSettings.settings.batteryCellmAH.toString();
    tecBatteryCellmAH.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCellmAH.text.length));
    tecBatteryCellMinVoltage.text = widget.myUserSettings.settings.batteryCellMinVoltage.toString();
    tecBatteryCellMinVoltage.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCellMinVoltage.text.length));
    tecBatteryCellMaxVoltage.text = widget.myUserSettings.settings.batteryCellMaxVoltage.toString();
    tecBatteryCellMaxVoltage.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCellMaxVoltage.text.length));
    tecWheelDiameterMillimeters.text = widget.myUserSettings.settings.wheelDiameterMillimeters.toString();
    tecWheelDiameterMillimeters.selection = TextSelection.fromPosition(TextPosition(offset: tecWheelDiameterMillimeters.text.length));
    tecPulleyMotorToothCount.text = widget.myUserSettings.settings.pulleyMotorToothCount.toString();
    tecPulleyMotorToothCount.selection = TextSelection.fromPosition(TextPosition(offset: tecPulleyMotorToothCount.text.length));
    tecPulleyWheelToothCount.text = widget.myUserSettings.settings.pulleyWheelToothCount.toString();
    tecPulleyWheelToothCount.selection = TextSelection.fromPosition(TextPosition(offset: tecPulleyWheelToothCount.text.length));
    tecMotorKV.text = widget.myUserSettings.settings.motorKV.toString();
    tecMotorKV.selection = TextSelection.fromPosition(TextPosition(offset: tecMotorKV.text.length));
    tecMotorPoles.text = widget.myUserSettings.settings.motorPoles.toString();
    tecMotorPoles.selection = TextSelection.fromPosition(TextPosition(offset: tecMotorPoles.text.length));

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
