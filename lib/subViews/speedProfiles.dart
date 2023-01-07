
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:freesk8_mobile/components/crc16.dart';
import 'package:freesk8_mobile/components/userSettings.dart';

import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/mcConf.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'escProfileEditor.dart';

class SpeedProfileArguments {

  final BluetoothCharacteristic theTXCharacteristic;
  final MCCONF escMotorConfiguration;
  final UserSettings myUserSettings;

  SpeedProfileArguments({
    @required this.theTXCharacteristic,
    @required this.escMotorConfiguration,
    @required this.myUserSettings,
  });
}

class SpeedProfilesEditor extends StatefulWidget {
  @override
  SpeedProfilesEditorState createState() => SpeedProfilesEditorState();

  static const String routeName = "/speedprofiles";
}

class SpeedProfilesEditorState extends State<SpeedProfilesEditor> {
  bool changesMade = false; //TODO: remove if unused

  static SpeedProfileArguments myArguments;

  bool _applyESCProfilePermanently;

  @override
  void initState() {

    _applyESCProfilePermanently = false;
    super.initState();
  }

  @override
  void dispose() {


    super.dispose();
  }

  void setMCCONFTemp(bool persistentChange, ESCProfile escProfile) {

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
    byteData.setFloat32(15, escProfile.speedKmhRev / 3.6); //kph to m/s
    byteData.setFloat32(19, escProfile.speedKmh / 3.6); //kph to m/s
    byteData.setFloat32(23, myArguments.escMotorConfiguration.l_min_duty);
    byteData.setFloat32(27, myArguments.escMotorConfiguration.l_max_duty);
    if (escProfile.l_watt_min != 0.0){
      byteData.setFloat32(31, escProfile.l_watt_min);
    } else {
      byteData.setFloat32(31, myArguments.escMotorConfiguration.l_watt_min);
    }
    if (escProfile.l_watt_max != 0.0){
      byteData.setFloat32(35, escProfile.l_watt_max);
    } else {
      byteData.setFloat32(35, myArguments.escMotorConfiguration.l_watt_max);
    }
    int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, 37);
    byteData.setUint16(39, checksum);
    byteData.setUint8(41, 0x03); //End of packet

    sendBLEData(myArguments.theTXCharacteristic, byteData.buffer.asUint8List(), true).then((sendResult){
      if (sendResult) globalLogger.d('COMM_SET_MCCONF_TEMP_SETUP sent');
      else globalLogger.d('COMM_SET_MCCONF_TEMP_SETUP failed to send');
    });
  }

  Future<Widget> _buildBody(BuildContext context) async {

    ///ESC Speed Profiles
    return Center(
      child: Column(
        children: <Widget>[
          Icon(
            Icons.timer,
            size: 60.0,
            color: Colors.blue,
          ),
          Center(child:Text("Speed Profiles")),

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

                          ElevatedButton(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text("Reset "),
                                Icon(Icons.flip_camera_android),
                              ],),
                            onPressed: () async {
                              //TODO: reset values
                              await ESCHelper.setESCProfile(i, ESCHelper.getESCProfileDefaults(i));
                              setState(() {

                              });
                            },
                            style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.grey[100];
                              }
                              return Colors.transparent;
                            })),
                          ),
                          ElevatedButton(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text("Edit "),
                                Icon(Icons.edit),
                              ],),
                            onPressed: () async {
                              // navigate to the editor
                              final result = await Navigator.of(context).pushNamed(ESCProfileEditor.routeName, arguments: ESCProfileEditorArguments(myArguments.theTXCharacteristic, await ESCHelper.getESCProfile(i), i, myArguments.myUserSettings.settings.useImperial));
                              setState(() {
                                // Update UI in case changes were made
                              });
                            },
                            style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.grey[100];
                              }
                              return Colors.transparent;
                            })),
                          ),
                          ElevatedButton(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text("Apply "),
                                Icon(Icons.exit_to_app),
                              ],),
                            onPressed: () async {
                              setMCCONFTemp(_applyESCProfilePermanently, await ESCHelper.getESCProfile(i));
                            },
                            style: ButtonStyle(backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.grey[100];
                              }
                              return Colors.transparent;
                            })),
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
                                Text("${myArguments.myUserSettings.settings.useImperial ? kmToMile(snapshot.data.speedKmh) : snapshot.data.speedKmh} ${myArguments.myUserSettings.settings.useImperial ? "mph" : "km/h"}")
                              ]),
                              TableRow(children: [
                                Text("Speed Reverse", textAlign: TextAlign.right),
                                Text(":"),
                                Text("${myArguments.myUserSettings.settings.useImperial ? kmToMile(snapshot.data.speedKmhRev) : snapshot.data.speedKmhRev} ${myArguments.myUserSettings.settings.useImperial ? "mph" : "km/h"}")
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
            height: 100,
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


              ],
            ),
          )
        ],
      ),
    );

  }

  @override
  Widget build(BuildContext context) {
    print("Building Template");

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No Arguments"));
    }

    return new WillPopScope(
      onWillPop: () async => false,
      child: new Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon( Icons.timer,
              size: 35.0,
              color: Colors.blue,
            ),
            SizedBox(width: 3),
            Text("Speed Profiles"),
          ],),
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: (){
              Navigator.of(context).pop(changesMade);
            },
          ),
        ),
        body: FutureBuilder<Widget>(
            future: _buildBody(context),
            builder: (context, AsyncSnapshot<Widget> snapshot) {
              if (snapshot.hasData) {
                return snapshot.data;
              } else {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Loading...."),
                    SizedBox(height: 10),
                    Center(child: SpinKitRipple(color: Colors.white,)),
                    Text("Please wait 🙏"),
                  ],);
              }
            }
        ),
      ),
    );
  }
}
