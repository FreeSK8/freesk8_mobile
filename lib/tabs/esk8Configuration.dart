import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:freesk8_mobile/escProfileEditor.dart';

import 'package:freesk8_mobile/userSettings.dart';
import 'package:freesk8_mobile/escHelper.dart';
import 'package:freesk8_mobile/bleHelper.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';

class ESK8Configuration extends StatefulWidget {
  ESK8Configuration({
    @required this.myUserSettings,
    this.currentDevice,
    this.showESCProfiles,
    this.theTXCharacteristic,
    this.escMotorConfiguration,
    this.onExitProfiles,
    this.onAutoloadESCSettings, //TODO: this might be removable
    this.showESCConfigurator
  });
  final UserSettings myUserSettings;
  final BluetoothDevice currentDevice;
  final bool showESCProfiles;
  final BluetoothCharacteristic theTXCharacteristic;
  final MCCONF escMotorConfiguration;
  final ValueChanged<bool> onExitProfiles;
  final ValueChanged<bool> onAutoloadESCSettings;
  final bool showESCConfigurator;
  ESK8ConfigurationState createState() => new ESK8ConfigurationState();

  static const String routeName = "/settings";
}

class ESK8ConfigurationState extends State<ESK8Configuration> {

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
  final tecWheelDiameterMillimeters = TextEditingController();
  final tecMotorPoles = TextEditingController();
  final tecGearRatio = TextEditingController();

  @override
  void initState() {
    super.initState();

    _applyESCProfilePermanently = false;

    //TODO: these try parse can return null.. then the device will remove null because it's not a number
    tecBoardAlias.addListener(() { widget.myUserSettings.settings.boardAlias = tecBoardAlias.text; });

    // TEC Listeners for ESC Configurator
    tecBatterySeriesCount.addListener(() { widget.escMotorConfiguration.si_battery_cells = int.tryParse(tecBatterySeriesCount.text); });
    tecBatteryCellmAH.addListener(() { widget.escMotorConfiguration.si_battery_ah = double.tryParse(tecBatteryCellmAH.text) / 1000.0; });
    tecWheelDiameterMillimeters.addListener(() { widget.escMotorConfiguration.si_wheel_diameter = double.tryParse(tecWheelDiameterMillimeters.text) / 1000.0; });
    tecMotorPoles.addListener(() { widget.escMotorConfiguration.si_motor_poles = int.tryParse(tecMotorPoles.text); });
    tecGearRatio.addListener(() { widget.escMotorConfiguration.si_gear_ratio = double.tryParse(tecGearRatio.text); });
  }


  @override
  void dispose() {
    super.dispose();

    tecBoardAlias.dispose();

    tecBatterySeriesCount.dispose();
    tecBatteryCellmAH.dispose();
    tecWheelDiameterMillimeters.dispose();
    tecMotorPoles.dispose();
    tecGearRatio.dispose();
  }

  void setMCCONFTemp(bool persistentChange, ESCProfile escProfile) {
    double speedFactor = ((widget.escMotorConfiguration.si_motor_poles / 2.0) * 60.0 *
        widget.escMotorConfiguration.si_gear_ratio) /
        (widget.escMotorConfiguration.si_wheel_diameter * pi);

    var byteData = new ByteData(42); //<start><payloadLen><payload><crc1><crc2><end>
    byteData.setUint8(0, 0x02); //Start of packet <255 in length
    byteData.setUint8(1, 37); //Payload length
    byteData.setUint8(2, COMM_PACKET_ID.COMM_SET_MCCONF_TEMP_SETUP.index);
    byteData.setUint8(3, persistentChange ? 1 : 0);
    byteData.setUint8(4, 0x01); //Forward to CAN devices =D Hooray
    byteData.setUint8(5, 0x01); //ACK = true
    byteData.setUint8(6, 0x00); //Divide By Controllers = false
    byteData.setFloat32(7, escProfile.l_current_min_scale);
    byteData.setFloat32(11, escProfile.l_current_max_scale);
    byteData.setFloat32(15, escProfile.speedKmhRev / 3.6); //TODO: why does Vedder divide by 3.6?
    byteData.setFloat32(19, escProfile.speedKmh / 3.6); //TODO: why does Vedder divide by 3.6?
    byteData.setFloat32(23, widget.escMotorConfiguration.l_min_duty);
    byteData.setFloat32(27, widget.escMotorConfiguration.l_max_duty);
    if (escProfile.l_watt_min != 0.0){
      byteData.setFloat32(31, escProfile.l_watt_min);
    } else {
      byteData.setFloat32(31, widget.escMotorConfiguration.l_watt_min);
    }
    if (escProfile.l_watt_max != 0.0){
      byteData.setFloat32(35, escProfile.l_watt_max);
    } else {
      byteData.setFloat32(35, widget.escMotorConfiguration.l_watt_max);
    }

    int checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, 37);
    byteData.setUint16(39, checksum);
    byteData.setUint8(41, 0x03); //End of packet

    widget.theTXCharacteristic.write(byteData.buffer.asUint8List()).then((value){
      print('COMM_SET_MCCONF_TEMP_SETUP published');
    }).catchError((e){
      print("COMM_SET_MCCONF_TEMP_SETUP: Exception: $e");
    });

  }

  @override
  Widget build(BuildContext context) {
    print("Build: ESK8Configuration");
    if (widget.showESCProfiles) {
      //TODO: do stuff
      double imperialFactor = widget.myUserSettings.settings.useImperial ? 0.621371192 : 1.0;
      String speedUnit = widget.myUserSettings.settings.useImperial ? "mph" : "km/h";

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
                            onPressed: () async {
                              setMCCONFTemp(_applyESCProfilePermanently, await ESCHelper.getESCProfile(i));
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
                          widget.onExitProfiles(false);
                        })
                  ],)
                ],
              ),
            )
          ],
        ),
      );
    }

    if (widget.showESCConfigurator) {
      tecBatterySeriesCount.text = widget.escMotorConfiguration.si_battery_cells.toString();
      tecBatterySeriesCount.selection = TextSelection.fromPosition(TextPosition(offset: tecBatterySeriesCount.text.length));
      tecBatteryCellmAH.text = (widget.escMotorConfiguration.si_battery_ah * 1000.0).toInt().toString();
      tecBatteryCellmAH.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCellmAH.text.length));
      tecWheelDiameterMillimeters.text = (widget.escMotorConfiguration.si_wheel_diameter * 1000.0).toInt().toString();
      tecWheelDiameterMillimeters.selection = TextSelection.fromPosition(TextPosition(offset: tecWheelDiameterMillimeters.text.length));
      tecMotorPoles.text = widget.escMotorConfiguration.si_motor_poles.toString();
      tecMotorPoles.selection = TextSelection.fromPosition(TextPosition(offset: tecMotorPoles.text.length));
      tecGearRatio.text = widget.escMotorConfiguration.si_gear_ratio.toString();
      tecGearRatio.selection = TextSelection.fromPosition(TextPosition(offset: tecGearRatio.text.length));

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

                  SizedBox(height: 5,),

                  Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                    Icon(
                      Icons.settings_applications,
                      size: 80.0,
                      color: Colors.blue,
                    ),
                    Text("ESC\nConfigurator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                  ],),

                  SizedBox(height:10),
                  Center(child:
                  Column(children: <Widget>[
                    Text("ESC Information"),
                    RaisedButton(
                        child: Text("Request from ESC"),
                        onPressed: () {
                          if (widget.currentDevice != null) {
                            setState(() {
                              widget.onAutoloadESCSettings(true);
                              Scaffold
                                  .of(context)
                                  .showSnackBar(SnackBar(content: Text("Requesting ESC configuration")));
                            });
                          }
                        })
                  ],)
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
                    controller: tecWheelDiameterMillimeters,
                    decoration: new InputDecoration(labelText: "Wheel Diameter in Millimeters"),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      WhitelistingTextInputFormatter.digitsOnly
                    ],
                  ),
                  TextField(
                      controller: tecMotorPoles,
                      decoration: new InputDecoration(labelText: "Motor Poles"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        WhitelistingTextInputFormatter.digitsOnly
                      ]
                  ),
                  TextField(
                      controller: tecGearRatio,
                      decoration: new InputDecoration(labelText: "Gear Ratio"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        WhitelistingTextInputFormatter.digitsOnly
                      ]
                  ),


                  Text("${widget.escMotorConfiguration.si_battery_type}"),

                  Text("Reverse Motor ${widget.escMotorConfiguration.m_invert_direction}"),

                  Text("${widget.escMotorConfiguration.motor_type}"),
                  Text("${widget.escMotorConfiguration.sensor_mode}"),

                  Text("l_current_max ${widget.escMotorConfiguration.l_current_max}"),
                  Text("l_current_min ${widget.escMotorConfiguration.l_current_min}"),
                  Text("l_in_current_max ${widget.escMotorConfiguration.l_in_current_max}"),
                  Text("l_in_current_min ${widget.escMotorConfiguration.l_in_current_min}"),
                  Text("l_abs_current_max ${widget.escMotorConfiguration.l_abs_current_max}"),

                  Text("l_max_erpm ${widget.escMotorConfiguration.l_max_erpm.toInt()}"),
                  Text("l_min_erpm ${widget.escMotorConfiguration.l_min_erpm.toInt()}"),

                  Text("l_min_vin ${widget.escMotorConfiguration.l_min_vin}"),
                  Text("l_max_vin ${widget.escMotorConfiguration.l_max_vin}"),
                  Text("l_battery_cut_start ${widget.escMotorConfiguration.l_battery_cut_start}"),
                  Text("l_battery_cut_end ${widget.escMotorConfiguration.l_battery_cut_end}"),

                  Text("l_temp_fet_start ${widget.escMotorConfiguration.l_temp_fet_start}"),
                  Text("l_temp_fet_end ${widget.escMotorConfiguration.l_temp_fet_end}"),
                  Text("l_temp_motor_start ${widget.escMotorConfiguration.l_temp_motor_start}"),
                  Text("l_temp_motor_end ${widget.escMotorConfiguration.l_temp_motor_end}"),

                  Text("l_watt_min ${widget.escMotorConfiguration.l_watt_min}"),
                  Text("l_watt_max ${widget.escMotorConfiguration.l_watt_max}"),
                  Text("l_current_min_scale ${widget.escMotorConfiguration.l_current_min_scale}"),
                  Text("l_current_max_scale ${widget.escMotorConfiguration.l_current_max_scale}"),

                  Text("l_duty_start ${widget.escMotorConfiguration.l_duty_start}"),
                  //Text(" ${widget.escMotorConfiguration.}"),

                  RaisedButton(
                      child: Text("Save to ESC"),
                      onPressed: () {

                      }),

                ],
              ),
            ),
          )
      );
    }

    tecBoardAlias.text = widget.myUserSettings.settings.boardAlias;
    tecBoardAlias.selection = TextSelection.fromPosition(TextPosition(offset: tecBoardAlias.text.length));
    if (widget.myUserSettings.settings.boardAvatarPath != null) _imageBoardAvatar = File(widget.myUserSettings.settings.boardAvatarPath);



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

                SizedBox(height: 5,),





                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Icon(
                    Icons.settings,
                    size: 80.0,
                    color: Colors.blue,
                  ),
                  Text("Application\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                ],),


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

                TextField(
                  controller: tecBoardAlias,
                  decoration: new InputDecoration(labelText: "Board Name / Alias"),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Column(children: <Widget>[
                    Text("Board Avatar"),
                    SizedBox(
                      width: 125,
                      child:  RaisedButton(
                          child:
                          Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Change "),Icon(Icons.camera_alt),],),

                          onPressed: () {
                            getImage();
                          }),
                    )
                  ],),

                  SizedBox(width: 15),
                  CircleAvatar(
                      backgroundImage: _imageBoardAvatar != null ? FileImage(_imageBoardAvatar) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                      radius: 100,
                      backgroundColor: Colors.white)
                ]),

                SizedBox(height:10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  RaisedButton(
                      child: Text("Revert Settings"),
                      onPressed: () {
                        setState(() {
                          widget.myUserSettings.reloadSettings();
                          Scaffold
                              .of(context)
                              .showSnackBar(SnackBar(content: Text('Application settings loaded from last state')));
                        });
                      }),

                  SizedBox(width:15),

                  RaisedButton(
                      child: Text("Save Settings"),
                      onPressed: () async {
                        FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                        try {
                          if (tecBoardAlias.text.length < 1) tecBoardAlias.text = "Unnamed";
                          widget.myUserSettings.settings.boardAlias = tecBoardAlias.text;
                          widget.myUserSettings.settings.boardAvatarPath = _imageBoardAvatar != null ? _imageBoardAvatar.path : null;
                          await widget.myUserSettings.saveSettings();

                        } catch (e) {
                          print("Save Settings Exception $e");
                          Scaffold
                              .of(context)
                              .showSnackBar(SnackBar(content: Text('Sorry friend. Save settings failed =(')));
                        }
                        Scaffold
                            .of(context)
                            .showSnackBar(SnackBar(content: Text('Application settings saved')));
                      }),


                ],),

            ],
          ),
        ),
      )
    );
  }
}
