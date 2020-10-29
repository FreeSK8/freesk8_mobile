import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:freesk8_mobile/escProfileEditor.dart';
import 'package:freesk8_mobile/globalUtilities.dart';

import 'package:freesk8_mobile/userSettings.dart';
import 'package:freesk8_mobile/focWizard.dart';
import 'package:freesk8_mobile/escHelper.dart';
import 'package:freesk8_mobile/bleHelper.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ESK8Configuration extends StatefulWidget {
  ESK8Configuration({
    @required this.myUserSettings,
    this.currentDevice,
    this.showESCProfiles,
    this.theTXCharacteristic,
    this.escMotorConfiguration,
    this.onExitProfiles,
    this.onAutoloadESCSettings, //TODO: this might be removable
    this.showESCConfigurator,
    this.discoveredCANDevices,
    this.closeESCConfigurator,
    this.updateCachedAvatar
  });
  final UserSettings myUserSettings;
  final BluetoothDevice currentDevice;
  final bool showESCProfiles;
  final BluetoothCharacteristic theTXCharacteristic;
  final MCCONF escMotorConfiguration;
  final ValueChanged<bool> onExitProfiles;
  final ValueChanged<bool> onAutoloadESCSettings;
  final bool showESCConfigurator;
  final List<int> discoveredCANDevices;
  final ValueChanged<bool> closeESCConfigurator;
  final ValueChanged<bool> updateCachedAvatar;
  ESK8ConfigurationState createState() => new ESK8ConfigurationState();

  static const String routeName = "/settings";
}

class ESK8ConfigurationState extends State<ESK8Configuration> {

  bool _applyESCProfilePermanently;

  int _selectedCANFwdID;
  int _invalidCANID;

  bool _writeESCInProgress;

  Future getImage(bool fromUserGallery) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    File temporaryImage = await ImagePicker.pickImage(source: fromUserGallery ? ImageSource.gallery : ImageSource.camera, maxWidth: 640, maxHeight: 640);


    if (temporaryImage != null) {
      // We have a new image, capture for display and update the settings in memory
      String newPath = "${documentsDirectory.path}/avatars/${widget.currentDevice.id}";
      File finalImage = await File(newPath).create(recursive: true);
      temporaryImage.copySync(newPath);
      print("Board avatar file destination: ${finalImage.path}");

      setState(() {
        //NOTE: A FileImage is the fastest way to load these images but because
        //      it's cached they will only update once. Unless you explicitly
        //      clear the imageCache
        // Clear the imageCache for FileImages used in rideLogging.dart
        imageCache.clear();
        imageCache.clearLiveImages();

        widget.myUserSettings.settings.boardAvatarPath = "/avatars/${widget.currentDevice.id}";
      });
    }
  }

  final tecBoardAlias = TextEditingController();

  final tecBatterySeriesCount = TextEditingController();
  final tecBatteryCapacityAh = TextEditingController();
  final tecWheelDiameterMillimeters = TextEditingController();
  final tecMotorPoles = TextEditingController();
  final tecGearRatio = TextEditingController();

  final tecCurrentMax = TextEditingController();
  final tecCurrentMin = TextEditingController();
  final tecInCurrentMax = TextEditingController();
  final tecInCurrentMin = TextEditingController();
  final tecABSCurrentMax = TextEditingController();

  final tecMaxERPM = TextEditingController();
  final tecMinERPM = TextEditingController();

  final tecMinVIN = TextEditingController();
  final tecMaxVIN = TextEditingController();
  final tecBatteryCutStart = TextEditingController();
  final tecBatteryCutEnd = TextEditingController();

  final tecTempFETStart = TextEditingController();
  final tecTempFETEnd = TextEditingController();
  final tecTempMotorStart = TextEditingController();
  final tecTempMotorEnd = TextEditingController();

  final tecWattMin = TextEditingController();
  final tecWattMax = TextEditingController();
  final tecCurrentMinScale = TextEditingController();
  final tecCurrentMaxScale = TextEditingController();

  final tecDutyStart = TextEditingController();

  @override
  void initState() {
    super.initState();

    _applyESCProfilePermanently = false;
    _writeESCInProgress = false;

    //TODO: these try parse can return null.. then the device will remove null because it's not a number
    tecBoardAlias.addListener(() { widget.myUserSettings.settings.boardAlias = tecBoardAlias.text; });

    // TextEditingController Listeners for ESC Configurator
    tecBatterySeriesCount.addListener(() { widget.escMotorConfiguration.si_battery_cells = int.tryParse(tecBatterySeriesCount.text); });
    tecBatteryCapacityAh.addListener(() { widget.escMotorConfiguration.si_battery_ah = doublePrecision(double.tryParse(tecBatteryCapacityAh.text), 2) ; });
    tecWheelDiameterMillimeters.addListener(() { widget.escMotorConfiguration.si_wheel_diameter = doublePrecision(double.tryParse(tecWheelDiameterMillimeters.text) / 1000.0, 2); });
    tecMotorPoles.addListener(() { widget.escMotorConfiguration.si_motor_poles = int.tryParse(tecMotorPoles.text); });
    tecGearRatio.addListener(() { widget.escMotorConfiguration.si_gear_ratio = doublePrecision(double.tryParse(tecGearRatio.text), 1); });
    tecCurrentMax.addListener(() { widget.escMotorConfiguration.l_current_max = doublePrecision(double.tryParse(tecCurrentMax.text), 1); });
    tecCurrentMin.addListener(() {
      double newValue = double.tryParse(tecCurrentMin.text);
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_current_min = doublePrecision(newValue, 1);
    });
    tecInCurrentMax.addListener(() { widget.escMotorConfiguration.l_in_current_max = doublePrecision(double.tryParse(tecInCurrentMax.text), 1); });
    tecInCurrentMin.addListener(() {
      double newValue = double.tryParse(tecInCurrentMin.text);
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_in_current_min = doublePrecision(newValue, 1);
    });
    tecABSCurrentMax.addListener(() { widget.escMotorConfiguration.l_abs_current_max = doublePrecision(double.tryParse(tecABSCurrentMax.text), 1); });
    tecMaxERPM.addListener(() { widget.escMotorConfiguration.l_max_erpm = int.tryParse(tecMaxERPM.text).toDouble(); });
    tecMinERPM.addListener(() {
      double newValue = double.tryParse(tecMinERPM.text);
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_min_erpm = newValue;
    });
    tecMinVIN.addListener(() { widget.escMotorConfiguration.l_min_vin = doublePrecision(double.tryParse(tecMinVIN.text), 1); });
    tecMaxVIN.addListener(() { widget.escMotorConfiguration.l_max_vin = doublePrecision(double.tryParse(tecMaxVIN.text), 1); });
    tecBatteryCutStart.addListener(() { widget.escMotorConfiguration.l_battery_cut_start = doublePrecision(double.tryParse(tecBatteryCutStart.text), 1); });
    tecBatteryCutEnd.addListener(() { widget.escMotorConfiguration.l_battery_cut_end = doublePrecision(double.tryParse(tecBatteryCutEnd.text), 1); });
    tecTempFETStart.addListener(() { widget.escMotorConfiguration.l_temp_fet_start = doublePrecision(double.tryParse(tecTempFETStart.text), 1); });
    tecTempFETEnd.addListener(() { widget.escMotorConfiguration.l_temp_fet_end = doublePrecision(double.tryParse(tecTempFETEnd.text), 1); });
    tecTempMotorStart.addListener(() { widget.escMotorConfiguration.l_temp_motor_start = doublePrecision(double.tryParse(tecTempMotorStart.text), 1); });
    tecTempMotorEnd.addListener(() { widget.escMotorConfiguration.l_temp_motor_end = doublePrecision(double.tryParse(tecTempMotorEnd.text), 1); });
    tecWattMin.addListener(() {
      double newValue = double.tryParse(tecWattMin.text);
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
      widget.escMotorConfiguration.l_watt_min = doublePrecision(newValue, 1);
    });
    tecWattMax.addListener(() { widget.escMotorConfiguration.l_watt_max = doublePrecision(double.tryParse(tecWattMax.text), 1); });
    tecCurrentMinScale.addListener(() {
      double newValue = double.tryParse(tecCurrentMinScale.text);
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escMotorConfiguration.l_current_min_scale = doublePrecision(newValue, 2);
    });
    tecCurrentMaxScale.addListener(() {
      double newValue = double.tryParse(tecCurrentMaxScale.text);
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escMotorConfiguration.l_current_max_scale = doublePrecision(newValue, 2);
    });
    tecDutyStart.addListener(() {
      double newValue = double.tryParse(tecDutyStart.text);
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      widget.escMotorConfiguration.l_duty_start = doublePrecision(newValue, 2);
    });
  }


  @override
  void dispose() {
    super.dispose();

    tecBoardAlias.dispose();

    tecBatterySeriesCount.dispose();
    tecBatteryCapacityAh.dispose();
    tecWheelDiameterMillimeters.dispose();
    tecMotorPoles.dispose();
    tecGearRatio.dispose();

    tecCurrentMax.dispose();
    tecCurrentMin.dispose();
    tecInCurrentMax.dispose();
    tecInCurrentMin.dispose();
    tecABSCurrentMax.dispose();
    tecMaxERPM.dispose();
    tecMinERPM.dispose();
    tecMinVIN.dispose();
    tecMaxVIN.dispose();
    tecBatteryCutStart.dispose();
    tecBatteryCutEnd.dispose();
    tecTempFETStart.dispose();
    tecTempFETEnd.dispose();
    tecTempMotorStart.dispose();
    tecTempMotorEnd.dispose();
    tecWattMin.dispose();
    tecWattMax.dispose();
    tecCurrentMinScale.dispose();
    tecCurrentMaxScale.dispose();
    tecDutyStart.dispose();
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

  void requestMCCONFCAN(int canID) {
    var byteData = new ByteData(8);
    byteData.setUint8(0, 0x02);
    byteData.setUint8(1, 0x03);
    byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
    byteData.setUint8(3, canID);
    byteData.setUint8(4, COMM_PACKET_ID.COMM_GET_MCCONF.index);
    int checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, 3);
    byteData.setUint16(5, checksum);
    byteData.setUint8(7, 0x03); //End of packet

    widget.theTXCharacteristic.write(byteData.buffer.asUint8List()).then((value){
      print('COMM_GET_MCCONF requested from CAN ID $canID');
      //TODO: indicate we are waiting for ESC response?
    }).catchError((e){
      print("COMM_GET_MCCONF: Exception: $e");
    });
  }

  void saveMCCONF(int optionalCANID) async {
    if (_writeESCInProgress) {
      print("WARNING: esk8Configuration: saveMCCONF: _writeESCInProgress is true. Save aborted.");
      return;
    }

    // Protect from interrupting a previous write attempt
    _writeESCInProgress = true;
    ESCHelper escHelper = new ESCHelper();
    ByteData serializedMcconf = escHelper.serializeMCCONF(widget.escMotorConfiguration);

    // Compute sizes and track buffer position
    int packetIndex = 0;
    int packetLength = 7; //<start><length><length> <command id><command data*><crc><crc><end>
    int payloadSize = serializedMcconf.lengthInBytes + 1; //<command id>
    if (optionalCANID != null) {
      packetLength += 2; //<canfwd><canid>
      payloadSize += 2;
    }
    packetLength += serializedMcconf.lengthInBytes; // Command Data

    // Prepare BLE request
    ByteData blePacket = new ByteData(packetLength);
    blePacket.setUint8(packetIndex++, 0x03); // Start of >255 byte packet
    blePacket.setUint16(packetIndex, payloadSize); packetIndex += 2; // Length of data
    if (optionalCANID != null) {
      blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_FORWARD_CAN.index); // CAN FWD
      blePacket.setUint8(packetIndex++, optionalCANID); // CAN ID
    }
    blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_SET_MCCONF.index); // Command ID
    //Copy serialized motor configuration to blePacket
    for (int i=0;i<serializedMcconf.lengthInBytes;++i) {
      blePacket.setInt8(packetIndex++, serializedMcconf.getInt8(i));
    }
    int checksum = BLEHelper.crc16(blePacket.buffer.asUint8List(), 3, payloadSize);
    blePacket.setUint16(packetIndex, checksum); packetIndex += 2;
    blePacket.setUint8(packetIndex, 0x03); //End of packet

    print("packet len $packetLength, payload size $payloadSize, packet index $packetIndex");

    /*
    * TODO: determine the best way to deliver this data to the ESC
    * TODO: The ESC does not like two big chunks and sometimes small chunks fails
    * TODO: this is the only thing that works
    */
    // Send in small chunks?
    int bytesSent = 0;
    while (bytesSent < packetLength) {
      int endByte = bytesSent + 20;
      if (endByte > packetLength) {
        endByte = packetLength;
      }
      widget.theTXCharacteristic.write(blePacket.buffer.asUint8List().sublist(bytesSent,endByte), withoutResponse: true);
      bytesSent += 20;
      await Future.delayed(const Duration(milliseconds: 30), () {});
    }
    print("COMM_SET_MCCONF bytes were blasted to ESC =/");

    /*
    * TODO: Flutter Blue cannot send more than 244 bytes in a message
    * TODO: This does not work
    // Send in two big chunks?
    widget.theTXCharacteristic.write(blePacket.buffer.asUint8List().sublist(0,240)).then((value){
      Future.delayed(const Duration(milliseconds: 250), () {
        widget.theTXCharacteristic.write(blePacket.buffer.asUint8List().sublist(240));
        print("COMM_SET_MCCONF sent to ESC");
      });

    }).catchError((e){
      print("COMM_SET_MCCONF: Exception: $e");
    });
*/

    // Finish with this save attempt
    _writeESCInProgress = false;
  }

  @override
  Widget build(BuildContext context) {
    print("Build: ESK8Configuration");
    if (widget.showESCProfiles) {
      ///ESC Speed Profiles
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
                              Navigator.of(context).pushNamed(ESCProfileEditor.routeName, arguments: ESCProfileEditorArguments(widget.theTXCharacteristic, await ESCHelper.getESCProfile(i), i, widget.myUserSettings.settings.useImperial));
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
                                  Text("${widget.myUserSettings.settings.useImperial ? kmToMile(snapshot.data.speedKmh) : snapshot.data.speedKmh} ${widget.myUserSettings.settings.useImperial ? "mph" : "km/h"}")
                                ]),
                                TableRow(children: [
                                  Text("Speed Reverse", textAlign: TextAlign.right),
                                  Text(":"),
                                  Text("${widget.myUserSettings.settings.useImperial ? kmToMile(snapshot.data.speedKmhRev) : snapshot.data.speedKmhRev} ${widget.myUserSettings.settings.useImperial ? "mph" : "km/h"}")
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
      // Check if we are building with an invalid motor configuration (signature mismatch)
      if (widget.escMotorConfiguration == null || widget.escMotorConfiguration.si_battery_ah == null) {
        // Invalid MCCONF received
        _invalidCANID = _selectedCANFwdID; // Store invalid ID
        _selectedCANFwdID = null; // Clear selected CAN device
        widget.onAutoloadESCSettings(true); // Request primary ESC configuration
        return Column( // This view will be replaced when ESC responds with valid configuration
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(
                Icons.settings_applications,
                size: 80.0,
                color: Colors.blue,
              ),
              Text("ESC\nConfigurator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
            ],),

            Icon(Icons.file_download),
            Text("Missing Motor Configuration from the ESC"),
            Text("If this problem persists you may need to restart the application")
          ],
        );
      }

      // Prepare text editing controllers
      tecBatterySeriesCount.text = widget.escMotorConfiguration.si_battery_cells.toString();
      tecBatterySeriesCount.selection = TextSelection.fromPosition(TextPosition(offset: tecBatterySeriesCount.text.length));
      tecBatteryCapacityAh.text = doublePrecision(widget.escMotorConfiguration.si_battery_ah,2).toString();
      tecBatteryCapacityAh.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCapacityAh.text.length));
      tecWheelDiameterMillimeters.text = (widget.escMotorConfiguration.si_wheel_diameter * 1000.0).toInt().toString();
      tecWheelDiameterMillimeters.selection = TextSelection.fromPosition(TextPosition(offset: tecWheelDiameterMillimeters.text.length));
      tecMotorPoles.text = widget.escMotorConfiguration.si_motor_poles.toString();
      tecMotorPoles.selection = TextSelection.fromPosition(TextPosition(offset: tecMotorPoles.text.length));
      tecGearRatio.text = widget.escMotorConfiguration.si_gear_ratio.toString();
      tecGearRatio.selection = TextSelection.fromPosition(TextPosition(offset: tecGearRatio.text.length));

      // Populate text editing controllers
      tecCurrentMax.text = widget.escMotorConfiguration.l_current_max.toString();
      tecCurrentMin.text = widget.escMotorConfiguration.l_current_min.toString();
      tecInCurrentMax.text = widget.escMotorConfiguration.l_in_current_max.toString();
      tecInCurrentMin.text = widget.escMotorConfiguration.l_in_current_min.toString();
      tecABSCurrentMax.text = widget.escMotorConfiguration.l_abs_current_max.toString();
      tecMaxERPM.text = widget.escMotorConfiguration.l_max_erpm.toInt().toString();
      tecMinERPM.text = widget.escMotorConfiguration.l_min_erpm.toInt().toString();
      tecMinVIN.text = widget.escMotorConfiguration.l_min_vin.toString();
      tecMaxVIN.text = widget.escMotorConfiguration.l_max_vin.toString();
      tecBatteryCutStart.text = widget.escMotorConfiguration.l_battery_cut_start.toString();
      tecBatteryCutEnd.text = widget.escMotorConfiguration.l_battery_cut_end.toString();
      tecTempFETStart.text = widget.escMotorConfiguration.l_temp_fet_start.toString();
      tecTempFETEnd.text = widget.escMotorConfiguration.l_temp_fet_end.toString();
      tecTempMotorStart.text = widget.escMotorConfiguration.l_temp_motor_start.toString();
      tecTempMotorEnd.text = widget.escMotorConfiguration.l_temp_motor_end.toString();
      tecWattMin.text = widget.escMotorConfiguration.l_watt_min.toString();
      tecWattMax.text = widget.escMotorConfiguration.l_watt_max.toString();
      tecCurrentMinScale.text = widget.escMotorConfiguration.l_current_min_scale.toString();
      tecCurrentMaxScale.text = widget.escMotorConfiguration.l_current_max_scale.toString();
      tecDutyStart.text = widget.escMotorConfiguration.l_duty_start.toString();

      // Set cursor position to end of text editing controllers
      tecCurrentMax.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMax.text.length));
      tecCurrentMin.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMin.text.length));
      tecInCurrentMax.selection = TextSelection.fromPosition(TextPosition(offset: tecInCurrentMax.text.length));
      tecInCurrentMin.selection = TextSelection.fromPosition(TextPosition(offset: tecInCurrentMin.text.length));
      tecABSCurrentMax.selection = TextSelection.fromPosition(TextPosition(offset: tecABSCurrentMax.text.length));
      tecMaxERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecMaxERPM.text.length));
      tecMinERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecMinERPM.text.length));
      tecMinVIN.selection = TextSelection.fromPosition(TextPosition(offset: tecMinVIN.text.length));
      tecMaxVIN.selection = TextSelection.fromPosition(TextPosition(offset: tecMaxVIN.text.length));
      tecBatteryCutStart.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCutStart.text.length));
      tecBatteryCutEnd.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCutEnd.text.length));
      tecTempFETStart.selection = TextSelection.fromPosition(TextPosition(offset: tecTempFETStart.text.length));
      tecTempFETEnd.selection = TextSelection.fromPosition(TextPosition(offset: tecTempFETEnd.text.length));
      tecTempMotorStart.selection = TextSelection.fromPosition(TextPosition(offset: tecTempMotorStart.text.length));
      tecTempMotorEnd.selection = TextSelection.fromPosition(TextPosition(offset: tecTempMotorEnd.text.length));
      tecWattMin.selection = TextSelection.fromPosition(TextPosition(offset: tecWattMin.text.length));
      tecWattMax.selection = TextSelection.fromPosition(TextPosition(offset: tecWattMax.text.length));
      tecCurrentMinScale.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMinScale.text.length));
      tecCurrentMaxScale.selection = TextSelection.fromPosition(TextPosition(offset: tecCurrentMaxScale.text.length));
      tecDutyStart.selection = TextSelection.fromPosition(TextPosition(offset: tecDutyStart.text.length));

      // Build ESC Configurator
      return Container(
          padding: EdgeInsets.all(10),
          child: Stack(children: <Widget>[
            Center(
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
                    Center(child: Column( children: <Widget>[
                      Text("Discovered CAN ID(s)"),
                      SizedBox(
                        height: 50,
                        child: GridView.builder(
                          primary: false,
                          itemCount: widget.discoveredCANDevices.length,
                          gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2, crossAxisSpacing: 1, mainAxisSpacing: 1),
                          itemBuilder: (BuildContext context, int index) {
                            bool isCANIDSelected = false;
                            if (_selectedCANFwdID == widget.discoveredCANDevices[index]) {
                              isCANIDSelected = true;
                            }
                            String invalidDevice = "";
                            if (_invalidCANID == widget.discoveredCANDevices[index]) {
                              invalidDevice = " (Invalid)";
                            }
                            return new Card(
                              shadowColor: Colors.transparent,
                              child: new GridTile(
                                // GestureDetector to switch the currently selected CAN Forward ID
                                  child: new GestureDetector(
                                    onTap: (){
                                      if (isCANIDSelected) {
                                        setState(() {
                                          // Clear CAN Forward
                                          _selectedCANFwdID = null;
                                          // Request primary ESC settings
                                          widget.onAutoloadESCSettings(true);
                                          Scaffold
                                              .of(context)
                                              .showSnackBar(SnackBar(content: Text("Requesting ESC configuration from primary ESC")));
                                        });
                                      } else {
                                        if (_invalidCANID != widget.discoveredCANDevices[index]) {
                                          setState(() {
                                            _selectedCANFwdID = widget.discoveredCANDevices[index];
                                            // Request MCCONF from CAN device
                                            requestMCCONFCAN(_selectedCANFwdID);
                                            Scaffold
                                                .of(context)
                                                .showSnackBar(SnackBar(content: Text("Requesting ESC configuration from CAN ID $_selectedCANFwdID")));
                                          });
                                        }

                                      }
                                    },
                                    child: Stack(
                                      children: <Widget>[



                                        new Center(child: Text("${widget.discoveredCANDevices[index]}${isCANIDSelected?" (Active)":""}$invalidDevice"),),
                                        new ClipRRect(
                                            borderRadius: new BorderRadius.circular(10),
                                            child: new Container(
                                              decoration: new BoxDecoration(
                                                color: isCANIDSelected ? Theme.of(context).focusColor : Colors.transparent,
                                              ),
                                            )
                                        )


                                      ],
                                    ),
                                  )
                              ),
                            );
                          },
                        ),
                      )
                    ],)
                    ),

                    Center(child:
                    Column(children: <Widget>[
                      Text("ESC Information"),
                      RaisedButton(
                          child: Text("Request from ESC${_selectedCANFwdID != null ? "/CAN $_selectedCANFwdID" : ""}"),
                          onPressed: () {
                            if (widget.currentDevice != null) {
                              setState(() {
                                if ( _selectedCANFwdID != null ) {
                                  requestMCCONFCAN(_selectedCANFwdID);
                                  Scaffold
                                      .of(context)
                                      .showSnackBar(SnackBar(content: Text("Requesting ESC configuration from CAN ID $_selectedCANFwdID")));
                                } else {
                                  widget.onAutoloadESCSettings(true);
                                  Scaffold
                                      .of(context)
                                      .showSnackBar(SnackBar(content: Text("Requesting ESC configuration")));
                                }
                              });
                            }
                          })
                    ],)
                    ),

                    //TODO: consider all unused struct members again
                    //Text("${widget.escMotorConfiguration.motor_type}"),
                    //Text("${widget.escMotorConfiguration.sensor_mode}"),

                    SwitchListTile(
                      title: Text("Reverse Motor (${widget.escMotorConfiguration.m_invert_direction})"),
                      value: widget.escMotorConfiguration.m_invert_direction,
                      onChanged: (bool newValue) { setState((){widget.escMotorConfiguration.m_invert_direction = newValue;}); },
                      secondary: const Icon(Icons.sync),
                    ),

                    DropdownButton(
                        value: widget.escMotorConfiguration.si_battery_type.index,
                        items: [
                          DropdownMenuItem(
                            child: Text("Battery Type: Li-ion 3.0/4.2V"),
                            value: 0,
                          ),
                          DropdownMenuItem(
                            child: Text("Battery Type: LiFePO₄ 2.6/3.6V"),
                            value: 1,
                          ),
                          DropdownMenuItem(
                              child: Text("Battery Type: Lead Acid"),
                              value: 2
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            widget.escMotorConfiguration.si_battery_type = BATTERY_TYPE.values[value];
                          });
                        }),

                    DropdownButton(
                        value: widget.escMotorConfiguration.foc_sensor_mode.index,
                        items: [
                          DropdownMenuItem(
                            child: Text("FOC_SENSOR_MODE_SENSORLESS"),
                            value: 0,
                          ),
                          DropdownMenuItem(
                            child: Text("FOC_SENSOR_MODE_ENCODER"),
                            value: 1,
                          ),
                          DropdownMenuItem(
                              child: Text("FOC_SENSOR_MODE_HALL"),
                              value: 2
                          ),
                          DropdownMenuItem(
                              child: Text("FOC_SENSOR_MODE_HFI"),
                              value: 3
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            widget.escMotorConfiguration.foc_sensor_mode = mc_foc_sensor_mode.values[value];
                          });
                        }),



                    TextField(
                        controller: tecBatterySeriesCount,
                        decoration: new InputDecoration(labelText: "Battery Series Count"),
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter.digitsOnly
                        ]
                    ),
                    TextField(
                        controller: tecBatteryCapacityAh,
                        decoration: new InputDecoration(labelText: "Battery Capacity (Ah)"),
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
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),






                    TextField(
                        controller: tecCurrentMax,
                        decoration: new InputDecoration(labelText: "Max Current (Amps)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecCurrentMin,
                        decoration: new InputDecoration(labelText: "Max Current Regen (Amps)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          NumberTextInputFormatter() //This allows for negative doubles
                        ]
                    ),
                    TextField(
                        controller: tecInCurrentMax,
                        decoration: new InputDecoration(labelText: "Battery Max Current (Amps)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecInCurrentMin,
                        decoration: new InputDecoration(labelText: "Battery Max Current Regen (Amps)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          NumberTextInputFormatter() //This allows for negative doubles
                        ]
                    ),
                    TextField(
                        controller: tecABSCurrentMax,
                        decoration: new InputDecoration(labelText: "ABS Max Current (Amps)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),

                    TextField(
                        controller: tecMaxERPM,
                        decoration: new InputDecoration(labelText: "Max ERPM"),
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter.digitsOnly
                        ]
                    ),
                    TextField(
                        controller: tecMinERPM,
                        decoration: new InputDecoration(labelText: "Min ERPM"),
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),

                    TextField(
                        controller: tecMinVIN,
                        decoration: new InputDecoration(labelText: "Minimum Voltage Input"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecMaxVIN,
                        decoration: new InputDecoration(labelText: "Maximum Voltage Input"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),

                    TextField(
                        controller: tecBatteryCutStart,
                        decoration: new InputDecoration(labelText: "Battery Cutoff Start (Volts)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecBatteryCutEnd,
                        decoration: new InputDecoration(labelText: "Battery Cutoff End (Volts)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecTempFETStart,
                        decoration: new InputDecoration(labelText: "ESC Temperature Cutoff Start (Celsius)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecTempFETEnd,
                        decoration: new InputDecoration(labelText: "ESC Temperature Cutoff End (Celsius)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecTempMotorStart,
                        decoration: new InputDecoration(labelText: "Motor Temperature Cutoff Start (Celsius)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecTempMotorEnd,
                        decoration: new InputDecoration(labelText: "Motor Temperature Cutoff End (Celsius)"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),

                    TextField(
                        controller: tecWattMin,
                        decoration: new InputDecoration(labelText: "Maximum Braking Wattage"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          NumberTextInputFormatter() //This allows for negative doubles
                        ]
                    ),
                    TextField(
                        controller: tecWattMax,
                        decoration: new InputDecoration(labelText: "Maximum Wattage"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecCurrentMinScale,
                        decoration: new InputDecoration(labelText: "Min Current Scale"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecCurrentMaxScale,
                        decoration: new InputDecoration(labelText: "Max Current Scale"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),
                    TextField(
                        controller: tecDutyStart,
                        decoration: new InputDecoration(labelText: "Duty Cycle Current Limit Start"),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: <TextInputFormatter>[
                          WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                        ]
                    ),

                    //Text(" ${widget.escMotorConfiguration.}"),

                    RaisedButton(
                        child: Text("Save to ESC${_selectedCANFwdID != null ? "/CAN $_selectedCANFwdID" : ""}"),
                        onPressed: () {
                          if (widget.currentDevice != null) {
                            //setState(() {
                            // Save motor configuration; CAN FWD ID can be null
                            saveMCCONF(_selectedCANFwdID);
                            //TODO: Not going to notify the user because sometimes saveMCCONF fails and they have to try again
                            /*
                            // Notify user
                            if ( _selectedCANFwdID != null ) {
                              Scaffold
                                  .of(context)
                                  .showSnackBar(SnackBar(content: Text("Saving ESC configuration to CAN ID $_selectedCANFwdID")));
                            } else {
                              Scaffold
                                  .of(context)
                                  .showSnackBar(SnackBar(content: Text("Saving ESC configuration")));
                            }
                             */
                            //});
                          }
                        }),

                    Divider(height: 10,),
                    Center(child: Text("Additional Tools"),),
                    Row( mainAxisAlignment: MainAxisAlignment.spaceBetween ,
                      children: <Widget>[
                        RaisedButton(
                          //TODO: quick pair for CAN FWD device?
                            child: Row(children: <Widget>[
                              Icon(Icons.settings_remote),
                              Text("nRF Quick Pair")
                            ],),
                            onPressed: () {
                              // Don't write if not connected
                              if (widget.theTXCharacteristic != null) {
                                var byteData = new ByteData(10); //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
                                byteData.setUint8(0, 0x02);
                                byteData.setUint8(1, 0x05);
                                byteData.setUint8(2, COMM_PACKET_ID.COMM_NRF_START_PAIRING.index);
                                byteData.setUint32(3, 10000); //milliseconds
                                int checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, 5);
                                byteData.setUint16(7, checksum);
                                byteData.setUint8(9, 0x03); //End of packet

                                //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
                                widget.theTXCharacteristic.write(byteData.buffer.asUint8List()).then((value){
                                  print('You have 10 seconds to power on your remote!');
                                }).catchError((e){
                                  print("nRF Quick Pair: Exception: $e");
                                });
                              } else {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text("nRF Quick Pair"),
                                      content: Text("Oops. Try connecting to your board first."),
                                    );
                                  },
                                );
                              }
                            }),

                        RaisedButton(
                            child: Row(children: <Widget>[
                              Icon(Icons.donut_large),
                              Text("FOC Wizard")
                            ],),
                            onPressed: () {
                              if(widget.theTXCharacteristic == null) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text("Connection Required =("),
                                      content: Text("This feature requires an active connection."),
                                    );
                                  },
                                );
                                return;
                              }
                              setState(() {
                                // navigate to the route
                                Navigator.of(context).pushNamed(ConfigureESC.routeName, arguments: FOCWizardArguments(widget.theTXCharacteristic, null));
                              });
                            })

                      ],)


                  ],
                ),
              ),
            ),

            Positioned(
                right: 0,
                top: 0,
                child: IconButton(onPressed: (){print("User Close ESC Configurator"); widget.closeESCConfigurator(true);},icon: Icon(Icons.clear),)
            ),
          ],)
      );
    }

    tecBoardAlias.text = widget.myUserSettings.settings.boardAlias;
    tecBoardAlias.selection = TextSelection.fromPosition(TextPosition(offset: tecBoardAlias.text.length));


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
                          Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Take "),Icon(Icons.camera_alt),],),

                          onPressed: () {
                            getImage(false);
                          }),
                    ),
                    SizedBox(
                      width: 125,
                      child:  RaisedButton(
                          child:
                          Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Select "),Icon(Icons.filter),],),

                          onPressed: () {
                            getImage(true);
                          }),
                    )
                  ],),

                  SizedBox(width: 15),
                  FutureBuilder<Directory>(
                      future: getApplicationDocumentsDirectory(),
                      builder: (BuildContext context, AsyncSnapshot<Directory> snapshot) {
                        if(snapshot.connectionState == ConnectionState.waiting){
                          return Container();
                        }
                        return CircleAvatar(
                            backgroundImage: widget.myUserSettings.settings.boardAvatarPath != null ? FileImage(File("${snapshot.data.path}${widget.myUserSettings.settings.boardAvatarPath}")) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                            radius: 100,
                            backgroundColor: Colors.white);
                      }),

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
                          // NOTE: Board avatar is updated with the image picker
                          await widget.myUserSettings.saveSettings();

                          widget.updateCachedAvatar(true);

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
