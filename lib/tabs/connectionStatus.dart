import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:freesk8_mobile/escHelper.dart';
import 'package:freesk8_mobile/userSettings.dart';

class RobogotchiStatus {
  bool isLogging;
  int faultCount;
  int faultCode;
  int percentFree;
  int fileCount;
  int gpsFix;
  int gpsSatellites;
  RobogotchiStatus(){
    isLogging = null;
    faultCount = 0;
    faultCode = 0;
    percentFree = 0;
    fileCount = 0;
    gpsFix = 0;
    gpsSatellites = 0;
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
        this.theTXLoggerCharacteristic,
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
  final BluetoothCharacteristic theTXLoggerCharacteristic;

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
              gotchiStatus.isLogging != null ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Icon(gotchiStatus.isLogging ? Icons.save_outlined : Icons.save, color: gotchiStatus.isLogging ? Colors.orange: Colors.green),
                      Text("${gotchiStatus.isLogging ? "Logging":"Log Idle"}"), //TODO: show if sync in progress
                      Text("${gotchiStatus.fileCount} ${gotchiStatus.fileCount == 1 ? "file":"files"}"),
                      Text("${gotchiStatus.percentFree}% Free"),

                    ],
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

              CircleAvatar(
                backgroundImage: imageBoardAvatar != null ? imageBoardAvatar : AssetImage('assets/FreeSK8_Mobile.jpg'),
                radius: 125,
                backgroundColor: Colors.white,
              ),

              Text(currentDevice.name == '' ? '(unknown device)' : currentDevice.name),

              //Text(currentDevice.id.toString()),

              Text("ESC Hardware: ${currentFirmware.hardware_name}"),
              Text("ESC Firmware: ${currentFirmware.fw_version_major}.${currentFirmware.fw_version_minor}"),


              RaisedButton(
                  child: Text("Disconnect"),
                  // On press of the button
                  onPressed: () {
                    // Scan for BLE devices
                    _handleTap();
                  }),
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
                Icons.bluetooth,
                size: 160.0,
                color: Colors.red,
              ),
              Text("No connection"),
              RaisedButton(
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
