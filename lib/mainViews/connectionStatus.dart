import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:duration_picker/duration_picker.dart';

import '../globalUtilities.dart';

import '../hardwareSupport/escHelper/escHelper.dart';
import '../components/userSettings.dart';

enum RobogotchiAlertReasons {
  NONE,
  GOTCHI_FAULT,
  ESC_FAULT,
  BLE_FAIL, // Not reported
  BLE_SUCCESS, // Not reported
  STORAGE_LIMIT,
  ESC_TEMP,
  MOTOR_TEMP,
  VOLTAGE_LOW,
}

class RobogotchiStatus {
  bool isLogging;
  int faultCount;
  int faultCode;
  int percentFree;
  int fileCount;
  int gpsFix;
  int gpsSatellites;
  int melodySnoozeSeconds;
  RobogotchiAlertReasons lastPriorityAlertReason;
  RobogotchiStatus(){
    isLogging = null;
    faultCount = 0;
    faultCode = 0;
    percentFree = 0;
    fileCount = 0;
    gpsFix = 0;
    gpsSatellites = 0;
    melodySnoozeSeconds = 0;
    lastPriorityAlertReason = RobogotchiAlertReasons.NONE;
  }
}

class ConnectionStatus extends StatelessWidget {

  ConnectionStatus(
      {
        Key key,
        this.active: false,
        this.bleDevicesGrid,
        this.currentDevice,
        this.currentFirmware,
        @required this.userSettings,
        @required this.onChanged,
        this.robogotchiVersion,
        this.imageBoardAvatar,
        this.gotchiStatus,
        this.connectedVehicleOdometer,
        this.connectedVehicleConsumption,
        this.theTXLoggerCharacteristic,
        this.unexpectedDisconnect,
        this.delayedTabControllerIndexChange,
      } ) : super(key: key);

  final ESCFirmware currentFirmware;
  final UserSettings userSettings;
  final BluetoothDevice currentDevice;
  final GridView bleDevicesGrid;
  final bool active;
  final ValueChanged<bool> onChanged;
  final String robogotchiVersion;
  final MemoryImage imageBoardAvatar;
  final RobogotchiStatus gotchiStatus;
  final double connectedVehicleOdometer;
  final double connectedVehicleConsumption;
  final BluetoothCharacteristic theTXLoggerCharacteristic;
  final bool unexpectedDisconnect;
  final ValueChanged<int> delayedTabControllerIndexChange;

  void _handleTap() {
    onChanged(!active);
  }

  @override
  Widget build(BuildContext context) {
    print("Build: ConnectionStatus");
    if (active == true) {
      return bleDevicesGrid;
    } else if (currentDevice != null) {
      return Container(
        child: Center(
          child: Column(
            // center the children
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              gotchiStatus.isLogging != null ? Divider(thickness: 2,) : Container(),
              gotchiStatus.isLogging != null ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  //
                  GestureDetector(
                      onTap: () {
                        delayedTabControllerIndexChange(controllerViewLogging);
                      },
                      child: Column(
                        children: [
                          Icon(gotchiStatus.isLogging ? Icons.save_outlined : Icons.save, color: gotchiStatus.isLogging ? Colors.orange: Colors.green),
                          Text("${gotchiStatus.isLogging ? "Logging":"Log Idle"}"), //TODO: show if sync in progress
                          Text("${gotchiStatus.fileCount} ${gotchiStatus.fileCount == 1 ? "file":"files"}"),
                          Text("${gotchiStatus.percentFree}% Free"),
                        ],
                      )
                  ),

                  GestureDetector(
                      onTap: (){
                        theTXLoggerCharacteristic.write(utf8.encode("faults~"));
                      },
                      child: Column(
                        children: [
                          Icon(gotchiStatus.faultCount > 0 ? Icons.error : Icons.check_circle, color: gotchiStatus.faultCount > 0 ? Colors.red : Colors.greenAccent, size: 25),
                          Text("${gotchiStatus.faultCount} ${gotchiStatus.faultCount == 1 ? "fault" : "faults"}"),
                          Text("FW: $robogotchiVersion"),
                          Text("")
                        ],
                      )
                  ),

                  GestureDetector(
                      onTap: () async {
                        if (gotchiStatus.melodySnoozeSeconds > 0) {
                          sendBLEData(theTXLoggerCharacteristic, utf8.encode("snooze,0~"), false);
                          return;
                        }
                        var resultingDuration = await showDurationPicker(
                          context: context,
                          initialTime: Duration(seconds: 0),
                          decoration: new BoxDecoration(
                            shape: BoxShape.rectangle,
                            color: Theme.of(context).dialogBackgroundColor,
                            borderRadius: new BorderRadius.all(new Radius.circular(32.0)),
                          ),
                        );
                        if (resultingDuration != null) {
                          sendBLEData(theTXLoggerCharacteristic, utf8.encode("snooze,${resultingDuration.inSeconds}~"), false);
                        }
                      },
                      child: Column(
                        children: [
                          Icon(gotchiStatus.melodySnoozeSeconds > 0 ? Icons.notifications_off : Icons.notifications_active, color: gotchiStatus.melodySnoozeSeconds > 0 ? Colors.grey : Colors.blue, size: 25),
                          Text(gotchiStatus.melodySnoozeSeconds > 0 ? "${prettyPrintDuration(new Duration(seconds: gotchiStatus.melodySnoozeSeconds))}" : "Audio On"),
                          Text(gotchiStatus.lastPriorityAlertReason != RobogotchiAlertReasons.NONE ? gotchiStatus.lastPriorityAlertReason.toString().substring(23) : "No alerts"),
                          Text(""),
                        ],
                      )
                  ),

                  Column(
                    children: [
                      Icon(Icons.satellite, color: gotchiStatus.gpsFix > 0 ? Colors.blue : Colors.grey),
                      Text("${gotchiStatus.gpsFix > 0 ? "GPS OK": "No Fix"}"),
                      Text("Sats: ${gotchiStatus.gpsSatellites}"),
                      Text("")
                    ],
                  )
                ],
              ) : Container(),

              gotchiStatus.isLogging != null ? Divider(thickness: 2,) : Container(),

              Text("Connected to"),
              Text(userSettings.settings.boardAlias != null ? userSettings.settings.boardAlias : "unnamed",style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

              Flexible(child: CircleAvatar(
                backgroundImage: imageBoardAvatar != null ? imageBoardAvatar : AssetImage('assets/FreeSK8_Mobile.jpg'),
                maxRadius: 125,
                backgroundColor: Colors.white,
              )),

              Text(currentDevice.name == '' ? '(unknown device)' : currentDevice.name),

              gotchiStatus.isLogging != null ?
              Text("Distance Logged ${doublePrecision(userSettings.settings.useImperial ? kmToMile(connectedVehicleOdometer) : connectedVehicleOdometer, 2)} ${userSettings.settings.useImperial ? "miles" : "km"}") : Container(),

              gotchiStatus.isLogging != null ?
              Text("Average Consumption ${doublePrecision(connectedVehicleConsumption, 2)} wh/${userSettings.settings.useImperial ? "mile" : "km"}") : Container(),

              //Text(currentDevice.id.toString()),

              Text("ESC Hardware: ${currentFirmware.hardware_name}"),
              Text("ESC Firmware: ${currentFirmware.fw_version_major}.${currentFirmware.fw_version_minor}"),


              ElevatedButton(
                  child: Text("Disconnect"),
                  // On press of the button
                  onPressed: () {
                    // Scan for BLE devices
                    _handleTap();
                  }),

              SizedBox(height:5),

            ],
          ),
        ),
      );
    } else {
      return Container(
        child: Center(
          child: Column(
            // center the children
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                unexpectedDisconnect ? Icons.bluetooth_disabled : Icons.bluetooth,
                size: 160.0,
                color: unexpectedDisconnect ? Colors.yellow : Colors.red,
              ),
              unexpectedDisconnect ? Text("Disconnected") : Text("No connection"),
              ElevatedButton(
                  child: Text(active ? "Stop Scan" : "Scan Bluetooth"),
                  // On press of the button
                  onPressed: () {
                    // Scan for BLE devices
                    _handleTap();
                  }),
            ],
          ),
        ),
      );
    }
  }
}
