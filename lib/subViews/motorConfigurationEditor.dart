
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:freesk8_mobile/components/crc16.dart';

import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/mcConf.dart';


import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:freesk8_mobile/subViews/focWizard.dart';


class MotorConfigurationArguments {

  final Stream dataStream;
  final BluetoothCharacteristic theTXCharacteristic;
  final MCCONF motorConfiguration;
  final List<int> discoveredCANDevices;
  final ESC_FIRMWARE escFirmwareVersion;

  MotorConfigurationArguments({
    @required this.dataStream,
    @required this.theTXCharacteristic,
    @required this.motorConfiguration,
    @required this.discoveredCANDevices,
    @required this.escFirmwareVersion
  });
}

class MotorConfigurationEditor extends StatefulWidget {
  @override
  MotorConfigurationEditorState createState() => MotorConfigurationEditorState();

  static const String routeName = "/motorconfiguration";
}

class MotorConfigurationEditorState extends State<MotorConfigurationEditor> {
  bool changesMade = false; //TODO: remove if unused

  static MotorConfigurationArguments myArguments;

  static StreamSubscription<MCCONF> streamSubscription;
  static BluetoothCharacteristic theTXCharacteristic;
  static List<int> discoveredCANDevices;


  int _selectedCANFwdID;
  int _invalidCANID;

  bool _writeESCInProgress = false;

  static ESC_FIRMWARE escFirmwareVersion;
  static MCCONF escMotorConfiguration;
  MCCONF _mcconfClipboard;
  
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
    // TextEditingController Listeners for Motor Configuration
    tecBatterySeriesCount.addListener(() {escMotorConfiguration.si_battery_cells = int.tryParse(tecBatterySeriesCount.text); });
    tecBatteryCapacityAh.addListener(() {escMotorConfiguration.si_battery_ah = doublePrecision(double.tryParse(tecBatteryCapacityAh.text.replaceFirst(',', '.')), 2); });
    tecWheelDiameterMillimeters.addListener(() {
      try {
       escMotorConfiguration.si_wheel_diameter = doublePrecision(double.tryParse(tecWheelDiameterMillimeters.text.replaceFirst(',', '.')) / 1000.0, 3);
      } catch (e) {}
    });
    tecMotorPoles.addListener(() {escMotorConfiguration.si_motor_poles = int.tryParse(tecMotorPoles.text); });
    tecGearRatio.addListener(() {escMotorConfiguration.si_gear_ratio = doublePrecision(double.tryParse(tecGearRatio.text.replaceFirst(',', '.')), 3); });
    tecCurrentMax.addListener(() {escMotorConfiguration.l_current_max = doublePrecision(double.tryParse(tecCurrentMax.text.replaceFirst(',', '.')), 1); });
    tecCurrentMin.addListener(() {
      double newValue = double.tryParse(tecCurrentMin.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
     escMotorConfiguration.l_current_min = doublePrecision(newValue, 1);
    });
    tecInCurrentMax.addListener(() {escMotorConfiguration.l_in_current_max = doublePrecision(double.tryParse(tecInCurrentMax.text.replaceFirst(',', '.')), 1); });
    tecInCurrentMin.addListener(() {
      double newValue = double.tryParse(tecInCurrentMin.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
     escMotorConfiguration.l_in_current_min = doublePrecision(newValue, 1);
    });
    tecABSCurrentMax.addListener(() {escMotorConfiguration.l_abs_current_max = doublePrecision(double.tryParse(tecABSCurrentMax.text.replaceFirst(',', '.')), 1); });
    tecMaxERPM.addListener(() {escMotorConfiguration.l_max_erpm = int.tryParse(tecMaxERPM.text.replaceFirst(',', '.')).toDouble(); });
    tecMinERPM.addListener(() {
      double newValue = double.tryParse(tecMinERPM.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
     escMotorConfiguration.l_min_erpm = newValue;
    });
    tecMinVIN.addListener(() {escMotorConfiguration.l_min_vin = doublePrecision(double.tryParse(tecMinVIN.text.replaceFirst(',', '.')), 1); });
    tecMaxVIN.addListener(() {escMotorConfiguration.l_max_vin = doublePrecision(double.tryParse(tecMaxVIN.text.replaceFirst(',', '.')), 1); });
    tecBatteryCutStart.addListener(() {escMotorConfiguration.l_battery_cut_start = doublePrecision(double.tryParse(tecBatteryCutStart.text.replaceFirst(',', '.')), 1); });
    tecBatteryCutEnd.addListener(() {escMotorConfiguration.l_battery_cut_end = doublePrecision(double.tryParse(tecBatteryCutEnd.text.replaceFirst(',', '.')), 1); });
    tecTempFETStart.addListener(() {escMotorConfiguration.l_temp_fet_start = doublePrecision(double.tryParse(tecTempFETStart.text.replaceFirst(',', '.')), 1); });
    tecTempFETEnd.addListener(() {escMotorConfiguration.l_temp_fet_end = doublePrecision(double.tryParse(tecTempFETEnd.text.replaceFirst(',', '.')), 1); });
    tecTempMotorStart.addListener(() {escMotorConfiguration.l_temp_motor_start = doublePrecision(double.tryParse(tecTempMotorStart.text.replaceFirst(',', '.')), 1); });
    tecTempMotorEnd.addListener(() {escMotorConfiguration.l_temp_motor_end = doublePrecision(double.tryParse(tecTempMotorEnd.text.replaceFirst(',', '.')), 1); });
    tecWattMin.addListener(() {
      double newValue = double.tryParse(tecWattMin.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>0.0) newValue *= -1; //Ensure negative
     escMotorConfiguration.l_watt_min = doublePrecision(newValue, 1);
    });
    tecWattMax.addListener(() {escMotorConfiguration.l_watt_max = doublePrecision(double.tryParse(tecWattMax.text.replaceFirst(',', '.')), 1); });
    tecCurrentMinScale.addListener(() {
      double newValue = double.tryParse(tecCurrentMinScale.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
     escMotorConfiguration.l_current_min_scale = doublePrecision(newValue, 2);
    });
    tecCurrentMaxScale.addListener(() {
      double newValue = double.tryParse(tecCurrentMaxScale.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
     escMotorConfiguration.l_current_max_scale = doublePrecision(newValue, 2);
    });
    tecDutyStart.addListener(() {
      double newValue = double.tryParse(tecDutyStart.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue>1.0) newValue = 1.0; //Ensure under 1.0
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
     escMotorConfiguration.l_duty_start = doublePrecision(newValue, 2);
    });
    super.initState();
  }

  @override
  void dispose() {
    streamSubscription?.cancel();
    streamSubscription = null;

    escMotorConfiguration = null;

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

    super.dispose();
  }

  void requestMCCONF({int optionalCANID}) async {
    Uint8List packet = simpleVESCRequest(COMM_PACKET_ID.COMM_GET_MCCONF.index, optionalCANID: optionalCANID);

    // Request MCCONF from the ESC
    globalLogger.i("requestMCCONF: requesting motor configuration");
    if (!await sendBLEData(theTXCharacteristic, packet, false)) {
      globalLogger.e("requestMCCONF: failed to request motor configuration");
    }
  }

  void saveMCCONF(int optionalCANID) async {
    if (_writeESCInProgress) {
      globalLogger.w("WARNING: esk8Configuration: saveMCCONF: _writeESCInProgress is true. Save aborted.");
      return;
    }

    // Protect from interrupting a previous write attempt
    _writeESCInProgress = true;
    ESCHelper escHelper = new ESCHelper();
    ByteData serializedMcconf = escHelper.serializeMCCONF(escMotorConfiguration, escFirmwareVersion);

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
    int checksum = CRC16.crc16(blePacket.buffer.asUint8List(), 3, payloadSize);
    blePacket.setUint16(packetIndex, checksum); packetIndex += 2;
    blePacket.setUint8(packetIndex, 0x03); //End of packet

    await sendBLEData(theTXCharacteristic, blePacket.buffer.asUint8List(), true);

    // Finish with this save attempt
    _writeESCInProgress = false;
  }

  Future<Widget> _buildBody(BuildContext context) async {
    // Check if we are building with an invalid motor configuration (signature mismatch)
    if (escMotorConfiguration == null || escMotorConfiguration.si_battery_ah == null) {
      // Invalid MCCONF received
      _invalidCANID = _selectedCANFwdID; // Store invalid ID
      _selectedCANFwdID = null; // Clear selected CAN device
      requestMCCONF(); // Request primary ESC configuration
      return Column( // This view will be replaced when ESC responds with valid configuration
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Icon(
              Icons.settings_applications,
              size: 80.0,
              color: Colors.blue,
            ),
            Text("Motor\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
          ],),

          Icon(Icons.file_download),
          Text("Missing Motor Configuration from the ESC"),
          Text("If this problem persists you may need to restart the application")
        ],
      );
    }

    // Prepare text editing controllers
    tecBatterySeriesCount.text =escMotorConfiguration.si_battery_cells.toString();
    tecBatterySeriesCount.selection = TextSelection.fromPosition(TextPosition(offset: tecBatterySeriesCount.text.length));
    tecBatteryCapacityAh.text = doublePrecision(escMotorConfiguration.si_battery_ah,2).toString();
    tecBatteryCapacityAh.selection = TextSelection.fromPosition(TextPosition(offset: tecBatteryCapacityAh.text.length));
    tecWheelDiameterMillimeters.text = doublePrecision(escMotorConfiguration.si_wheel_diameter * 1000.0, 3).toInt().toString();
    tecWheelDiameterMillimeters.selection = TextSelection.fromPosition(TextPosition(offset: tecWheelDiameterMillimeters.text.length));
    tecMotorPoles.text =escMotorConfiguration.si_motor_poles.toString();
    tecMotorPoles.selection = TextSelection.fromPosition(TextPosition(offset: tecMotorPoles.text.length));
    tecGearRatio.text = doublePrecision(escMotorConfiguration.si_gear_ratio, 3).toString();
    tecGearRatio.selection = TextSelection.fromPosition(TextPosition(offset: tecGearRatio.text.length));

    // Populate text editing controllers
    tecCurrentMax.text = doublePrecision(escMotorConfiguration.l_current_max, 1).toString();
    tecCurrentMin.text = doublePrecision(escMotorConfiguration.l_current_min, 1).toString();
    tecInCurrentMax.text = doublePrecision(escMotorConfiguration.l_in_current_max, 1).toString();
    tecInCurrentMin.text = doublePrecision(escMotorConfiguration.l_in_current_min, 1).toString();
    tecABSCurrentMax.text = doublePrecision(escMotorConfiguration.l_abs_current_max, 1).toString();
    tecMaxERPM.text =escMotorConfiguration.l_max_erpm.toInt().toString();
    tecMinERPM.text =escMotorConfiguration.l_min_erpm.toInt().toString();
    tecMinVIN.text = doublePrecision(escMotorConfiguration.l_min_vin, 1).toString();
    tecMaxVIN.text = doublePrecision(escMotorConfiguration.l_max_vin, 1).toString();
    tecBatteryCutStart.text = doublePrecision(escMotorConfiguration.l_battery_cut_start, 1).toString();
    tecBatteryCutEnd.text = doublePrecision(escMotorConfiguration.l_battery_cut_end, 1).toString();
    tecTempFETStart.text = doublePrecision(escMotorConfiguration.l_temp_fet_start, 1).toString();
    tecTempFETEnd.text = doublePrecision(escMotorConfiguration.l_temp_fet_end, 1).toString();
    tecTempMotorStart.text = doublePrecision(escMotorConfiguration.l_temp_motor_start, 1).toString();
    tecTempMotorEnd.text = doublePrecision(escMotorConfiguration.l_temp_motor_end, 1).toString();
    tecWattMin.text = doublePrecision(escMotorConfiguration.l_watt_min, 1).toString();
    tecWattMax.text = doublePrecision(escMotorConfiguration.l_watt_max, 1).toString();
    tecCurrentMinScale.text = doublePrecision(escMotorConfiguration.l_current_min_scale, 2).toString();
    tecCurrentMaxScale.text = doublePrecision(escMotorConfiguration.l_current_max_scale, 2).toString();
    tecDutyStart.text = doublePrecision(escMotorConfiguration.l_duty_start, 2).toString();

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
      child: GestureDetector(
        onTap: () {
          // Hide the keyboard
          FocusScope.of(context).requestFocus(new FocusNode());
        },
        child: Column(
          children: [
            Column(
              children: [
                SizedBox(height: 5,),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Icon(
                    Icons.settings_applications,
                    size: 80.0,
                    color: Colors.blue,
                  ),
                  Text("Motor\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                ],),

                SizedBox(height:10),
                Center(child: Column( children: <Widget>[
                  Text("Discovered Devices"),
                  SizedBox(
                    height: 50,
                    child: GridView.builder(
                      primary: false,
                      itemCount: discoveredCANDevices.length + 1, //NOTE: +1 to add the Direct ESC
                      gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2, crossAxisSpacing: 1, mainAxisSpacing: 1),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return new Card(
                            shadowColor: Colors.transparent,
                            child: new GridTile(
                              // GestureDetector to switch the currently selected CAN Forward ID
                                child: new GestureDetector(
                                  onTap: (){
                                    setState(() {
                                      // Clear CAN Forward
                                      _selectedCANFwdID = null;
                                      // Request primary ESC settings
                                      requestMCCONF();
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                          SnackBar(
                                            content: Text("Requesting ESC configuration from primary ESC"),
                                            duration: Duration(seconds: 1),
                                          ));
                                    });
                                  },
                                  child: Stack(
                                    children: <Widget>[



                                      new Center(child: Text(_selectedCANFwdID == null ? "Direct (Active)" :"Direct", style: TextStyle(fontSize: 12))),
                                      new ClipRRect(
                                          borderRadius: new BorderRadius.circular(10),
                                          child: new Container(
                                            decoration: new BoxDecoration(
                                              color: _selectedCANFwdID == null ? Theme.of(context).focusColor : Colors.transparent,
                                            ),
                                          )
                                      )


                                    ],
                                  ),
                                )
                            ),
                          );
                        }
                        bool isCANIDSelected = false;
                        if (_selectedCANFwdID == discoveredCANDevices[index-1]) {
                          isCANIDSelected = true;
                        }
                        String invalidDevice = "";
                        if (_invalidCANID == discoveredCANDevices[index-1]) {
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
                                      requestMCCONF();
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                          SnackBar(
                                            content: Text("Requesting ESC configuration from primary ESC"),
                                            duration: Duration(seconds: 1),
                                          ));
                                    });
                                  } else {
                                    if (_invalidCANID != discoveredCANDevices[index-1]) {
                                      setState(() {
                                        _selectedCANFwdID = discoveredCANDevices[index-1];
                                        // Request MCCONF from CAN device
                                        requestMCCONF(optionalCANID: _selectedCANFwdID);
                                        ScaffoldMessenger
                                            .of(context)
                                            .showSnackBar(
                                            SnackBar(
                                              content: Text("Requesting ESC configuration from CAN ID $_selectedCANFwdID"),
                                              duration: Duration(seconds: 1),
                                            ));
                                      });
                                    }
                                  }
                                },
                                child: Stack(
                                  children: <Widget>[



                                    new Center(child: Text("${discoveredCANDevices[index-1]}${isCANIDSelected?" (Active)":""}$invalidDevice", style: TextStyle(fontSize: 12)),),
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
              ],
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(30, 0, 30, 0),
                children: <Widget>[






                  //TODO: consider all unused struct members again
                  //Text("${escMotorConfiguration.motor_type}"),
                  //Text("${escMotorConfiguration.sensor_mode}"),

                  SwitchListTile(
                    title: Text("Reverse Motor (${escMotorConfiguration.m_invert_direction})"),
                    value:escMotorConfiguration.m_invert_direction,
                    onChanged: (bool newValue) { setState((){escMotorConfiguration.m_invert_direction = newValue;}); },
                    secondary: const Icon(Icons.sync),
                  ),

                  DropdownButton(
                      value:escMotorConfiguration.si_battery_type.index,
                      items: [
                        DropdownMenuItem(
                          child: Text("Battery Type: Li-ion 3.0/4.2V"),
                          value: BATTERY_TYPE.BATTERY_TYPE_LIION_3_0__4_2.index,
                        ),
                        DropdownMenuItem(
                          child: Text("Battery Type: LiFePO₄ 2.6/3.6V"),
                          value: BATTERY_TYPE.BATTERY_TYPE_LIIRON_2_6__3_6.index,
                        ),
                        DropdownMenuItem(
                            child: Text("Battery Type: Lead Acid"),
                            value: BATTERY_TYPE.BATTERY_TYPE_LEAD_ACID.index
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          escMotorConfiguration.si_battery_type = BATTERY_TYPE.values[value];
                        });
                      }),

                  DropdownButton(
                      value:escMotorConfiguration.foc_sensor_mode.index,
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
                          escMotorConfiguration.foc_sensor_mode = mc_foc_sensor_mode.values[value];
                        });
                      }),



                  TextField(
                      controller: tecBatterySeriesCount,
                      decoration: new InputDecoration(labelText: "Battery Series Count"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ]
                  ),
                  TextField(
                      controller: tecBatteryCapacityAh,
                      decoration: new InputDecoration(labelText: "Battery Capacity (Ah)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                    controller: tecWheelDiameterMillimeters,
                    decoration: new InputDecoration(labelText: "Wheel Diameter in Millimeters"),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly
                    ],
                  ),
                  TextField(
                      controller: tecMotorPoles,
                      decoration: new InputDecoration(labelText: "Motor Poles"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ]
                  ),
                  TextField(
                      controller: tecGearRatio,
                      decoration: new InputDecoration(labelText: "Gear Ratio"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),






                  TextField(
                      controller: tecCurrentMax,
                      decoration: new InputDecoration(labelText: "Motor Current Max (Amps)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecCurrentMin,
                      decoration: new InputDecoration(labelText: "Motor Current Max Brake (Amps)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        NumberTextInputFormatter() //This allows for negative doubles
                      ]
                  ),
                  TextField(
                      controller: tecInCurrentMax,
                      decoration: new InputDecoration(labelText: "Battery Current Max (Amps)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecInCurrentMin,
                      decoration: new InputDecoration(labelText: "Battery Current Max Regen (Amps)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        NumberTextInputFormatter() //This allows for negative doubles
                      ]
                  ),
                  TextField(
                      controller: tecABSCurrentMax,
                      decoration: new InputDecoration(labelText: "Absolute Maximum Current (Amps)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),

                  TextField(
                      controller: tecMaxERPM,
                      decoration: new InputDecoration(labelText: "Max ERPM"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ]
                  ),
                  TextField(
                      controller: tecMinERPM,
                      decoration: new InputDecoration(labelText: "Min ERPM"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),

                  TextField(
                      controller: tecMinVIN,
                      decoration: new InputDecoration(labelText: "Minimum Voltage Input"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecMaxVIN,
                      decoration: new InputDecoration(labelText: "Maximum Voltage Input"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),

                  TextField(
                      controller: tecBatteryCutStart,
                      decoration: new InputDecoration(labelText: "Battery Cutoff Start (Volts)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecBatteryCutEnd,
                      decoration: new InputDecoration(labelText: "Battery Cutoff End (Volts)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecTempFETStart,
                      decoration: new InputDecoration(labelText: "ESC Temperature Cutoff Start (Celsius)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecTempFETEnd,
                      decoration: new InputDecoration(labelText: "ESC Temperature Cutoff End (Celsius)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecTempMotorStart,
                      decoration: new InputDecoration(labelText: "Motor Temperature Cutoff Start (Celsius)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecTempMotorEnd,
                      decoration: new InputDecoration(labelText: "Motor Temperature Cutoff End (Celsius)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
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
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecCurrentMinScale,
                      decoration: new InputDecoration(labelText: "Min Current Scale"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecCurrentMaxScale,
                      decoration: new InputDecoration(labelText: "Max Current Scale"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecDutyStart,
                      decoration: new InputDecoration(labelText: "Duty Cycle Current Limit Start"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),

                  //Text(" ${escMotorConfiguration.}"),

                  Divider(height: 10,),
                  Center(child: Text("Manage Settings"),),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      ElevatedButton(
                          child: Row(
                            children: [
                              Icon(Icons.copy),
                              Text("Copy")
                            ],
                          ),
                          onPressed: () {
                            setState(() {
                              _mcconfClipboard =escMotorConfiguration;
                              ScaffoldMessenger
                                  .of(context)
                                  .showSnackBar(
                                  SnackBar(
                                    content: Text("Motor Configuration Copied"),
                                    duration: Duration(seconds: 1),
                                  ));
                            });
                          }),
                      ElevatedButton(
                          child: Text("Reload from ESC"),
                          onPressed: () {
                            //TODO: if (widget.currentDevice != null) {
                            {
                              setState(() {
                                if ( _selectedCANFwdID != null ) {
                                  requestMCCONF(optionalCANID: _selectedCANFwdID);
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                      SnackBar(
                                        content: Text("Requesting ESC configuration from CAN ID $_selectedCANFwdID"),
                                        duration: Duration(seconds: 1),
                                      ));
                                } else {
                                  requestMCCONF();
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                      SnackBar(
                                        content: Text("Requesting ESC configuration"),
                                        duration: Duration(seconds: 1),
                                      ));
                                }
                              });
                            }
                          }),
                      ElevatedButton(
                          child: Row(
                            children: [
                              Icon(Icons.paste),
                              Text("Paste")
                            ],
                          ),
                          onPressed: () {
                            if (_mcconfClipboard != null) {
                              // Paste editor values to current motor configuration
                              escMotorConfiguration.si_battery_type = _mcconfClipboard.si_battery_type;
                              escMotorConfiguration.si_battery_cells = _mcconfClipboard.si_battery_cells;
                              escMotorConfiguration.si_battery_ah = _mcconfClipboard.si_battery_ah;
                              escMotorConfiguration.si_wheel_diameter = _mcconfClipboard.si_wheel_diameter;
                              escMotorConfiguration.si_motor_poles = _mcconfClipboard.si_motor_poles;
                              escMotorConfiguration.si_gear_ratio = _mcconfClipboard.si_gear_ratio;
                              escMotorConfiguration.l_current_max = _mcconfClipboard.l_current_max;
                              escMotorConfiguration.l_current_min = _mcconfClipboard.l_current_min;
                              escMotorConfiguration.l_in_current_max = _mcconfClipboard.l_in_current_max;
                              escMotorConfiguration.l_in_current_min = _mcconfClipboard.l_in_current_min;
                              escMotorConfiguration.l_abs_current_max = _mcconfClipboard.l_abs_current_max;
                              escMotorConfiguration.l_max_erpm = _mcconfClipboard.l_max_erpm;
                              escMotorConfiguration.l_min_erpm = _mcconfClipboard.l_min_erpm;
                              escMotorConfiguration.l_min_vin = _mcconfClipboard.l_min_vin;
                              escMotorConfiguration.l_max_vin = _mcconfClipboard.l_max_vin;
                              escMotorConfiguration.l_battery_cut_start = _mcconfClipboard.l_battery_cut_start;
                              escMotorConfiguration.l_battery_cut_end = _mcconfClipboard.l_battery_cut_end;
                              escMotorConfiguration.l_temp_fet_start = _mcconfClipboard.l_temp_fet_start;
                              escMotorConfiguration.l_temp_fet_end = _mcconfClipboard.l_temp_fet_end;
                              escMotorConfiguration.l_temp_motor_start = _mcconfClipboard.l_temp_motor_start;
                              escMotorConfiguration.l_temp_motor_end = _mcconfClipboard.l_temp_motor_end;
                              escMotorConfiguration.l_watt_min = _mcconfClipboard.l_watt_min;
                              escMotorConfiguration.l_watt_max = _mcconfClipboard.l_watt_max;
                              escMotorConfiguration.l_current_min_scale = _mcconfClipboard.l_current_min_scale;
                              escMotorConfiguration.l_current_max_scale = _mcconfClipboard.l_current_max_scale;
                              escMotorConfiguration.l_duty_start = _mcconfClipboard.l_duty_start;
                              // Notify User
                              setState(() {
                                ScaffoldMessenger
                                    .of(context)
                                    .showSnackBar(
                                    SnackBar(
                                      content: Text("Motor Configuration Pasted"),
                                      duration: Duration(seconds: 1),
                                    ));
                              });
                            } else {
                              setState(() {
                                ScaffoldMessenger
                                    .of(context)
                                    .showSnackBar(
                                    SnackBar(
                                      content: Text("Please Copy the before using Paste"),
                                      duration: Duration(seconds: 1),
                                    ));
                              });
                            }
                          })
                    ],),

                  ElevatedButton(
                      child: Text("Save to ESC${_selectedCANFwdID != null ? "/CAN $_selectedCANFwdID" : ""}"),
                      onPressed: () {
                        //TODO: if (widget.currentDevice != null) {
                        {
                          // Save motor configuration; CAN FWD ID can be null
                          saveMCCONF(_selectedCANFwdID);
                          //NOTE: Not going to notify the user because sometimes saveMCCONF fails and they have to try again
                        }
                      },
                      onLongPress: () {
                        _writeESCInProgress = false;
                        // Save motor configuration; CAN FWD ID can be null
                        saveMCCONF(_selectedCANFwdID);
                      },
                  ),

                  Divider(height: 10,),
                  Center(child: Text("Additional Tools"),),
                  Row( mainAxisAlignment: MainAxisAlignment.spaceBetween ,
                    children: <Widget>[
                      ElevatedButton(
                          child: Row(children: <Widget>[
                            Icon(Icons.donut_large),
                            Text("FOC Wizard")
                          ],),
                          onPressed: () {
                            if(theTXCharacteristic == null) {
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
                              Navigator.of(context).pushNamed(FOCWizard.routeName, arguments: FOCWizardArguments(theTXCharacteristic, null));
                            });
                          })

                    ],)


                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Building MotorConfigurationEditor");

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No Arguments"));
    }
    // Prepare objects for use in this widget
    if(streamSubscription == null) {
      streamSubscription = myArguments.dataStream.listen((value) {
        globalLogger.i("Stream Data Received");
        setState(() {
          escMotorConfiguration = value;
        });
      });
    }
    if (theTXCharacteristic == null) {
      theTXCharacteristic = myArguments.theTXCharacteristic;
    }
    if (discoveredCANDevices == null) {
      discoveredCANDevices = myArguments.discoveredCANDevices;
    }
    if (escMotorConfiguration == null) {
      escMotorConfiguration = myArguments.motorConfiguration;
    }
    escFirmwareVersion = myArguments.escFirmwareVersion;

    
    return new WillPopScope(
      onWillPop: () async => false,
      child: new Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon( Icons.settings_applications,
              size: 35.0,
              color: Colors.blue,
            ),
            SizedBox(width: 3),
            Text("Motor Configuration"),
          ],),
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: (){
              //TODO: check if changes were made without saving
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
