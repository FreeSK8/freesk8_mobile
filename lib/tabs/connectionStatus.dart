import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:freesk8_mobile/escHelper.dart';
import 'package:freesk8_mobile/userSettings.dart';

import 'dart:io';

class ConnectionStatus extends StatelessWidget {

  ConnectionStatus({Key key, this.active: false, this.bleDevicesGrid, this.currentDevice, this.currentFirmware, @required this.userSettings, @required this.onChanged, this.robogotchiVersion})
      : super(key: key);

  final ESCFirmware currentFirmware;
  final UserSettings userSettings;
  final BluetoothDevice currentDevice;
  final GridView bleDevicesGrid;
  final bool active;
  final ValueChanged<bool> onChanged;
  final String robogotchiVersion;

  void _handleTap() {
    onChanged(!active);
  }

  @override
  Widget build(BuildContext context) {
    print("Build: ConnectionStatus");
    if (active == true) {
      return bleDevicesGrid;
    } else if (currentDevice != null) {
      File imageBoardAvatar;
      if (userSettings.isKnownDevice()) {
        imageBoardAvatar = userSettings.settings.boardAvatarPath != null ? File(userSettings.settings.boardAvatarPath) : null;
      }
      return Container(
        child: Center(
          child: Column(
            // center the children
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text("Connected to"),
              Text(userSettings.settings.boardAlias != null ? userSettings.settings.boardAlias : "unnamed",style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),

              CircleAvatar(
                backgroundImage: imageBoardAvatar != null ? FileImage(imageBoardAvatar) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                radius: 150,
                backgroundColor: Colors.white,
              ),

              Text(currentDevice.name == '' ? '(unknown device)' : currentDevice.name),

              //Text(currentDevice.id.toString()),
              robogotchiVersion != null ? Text("Robogotchi Firmware: $robogotchiVersion") : Container(),

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
