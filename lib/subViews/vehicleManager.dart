
import 'dart:io';
import 'dart:math'; //TODO: replace with uuid

import 'package:flutter/material.dart';
import 'package:freesk8_mobile/components/databaseAssistant.dart';
import 'package:freesk8_mobile/components/userSettings.dart';
import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/mainViews/test.dart';

class VehicleManagerArguments {
  final String connectedDeviceID;
  final NavigatorState navigatorState;

  VehicleManagerArguments(this.connectedDeviceID, this.navigatorState);
}

class VehicleManager extends StatefulWidget {
  @override
  VehicleManagerState createState() => VehicleManagerState();

  static const String routeName = "/vehiclemanager";
}

class VehicleManagerState extends State<VehicleManager> {
  static Widget bodyWidget;
  VehicleManagerArguments myArguments;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    bodyWidget = null;
    super.dispose();
  }

  void _retireVehicle(String deviceID) async {
    await genericConfirmationDialog(myArguments.navigatorState.context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(myArguments.navigatorState.context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(myArguments.navigatorState.context).pop();
        String newID = "R*${Random().nextInt(65535*2)}"; //TODO: generate UUID with uuid pub package
        await DatabaseAssistant.dbAssociateVehicle(deviceID, newID);
        await UserSettings.associateDevice(deviceID, newID);
        _reloadBody();
      },
    ), "Retire Vehicle", Text("Are you sure you want to retire the selected vehicle? Nothing will be erased"));
  }

  void _recruitVehicle(String deviceID) async {
    await genericConfirmationDialog(myArguments.navigatorState.context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(myArguments.navigatorState.context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(myArguments.navigatorState.context).pop();
        String newID = myArguments.connectedDeviceID;
        await DatabaseAssistant.dbAssociateVehicle(deviceID, newID);
        await UserSettings.associateDevice(deviceID, newID);
        _reloadBody();
      },
    ), "Adopt Vehicle", Text("Assign connected device to selected vehicle?"));
  }

  void _removeVehicle(String deviceID) async {
    await genericConfirmationDialog(myArguments.navigatorState.context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(myArguments.navigatorState.context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(myArguments.navigatorState.context).pop();
        await DatabaseAssistant.dbRemoveVehicle(deviceID);
        await UserSettings.removeDevice(deviceID);
        _reloadBody();
      },
    ), "Remove Vehicle", Text("Remove the selected vehicle and all of it's data?"));
  }

  void _buildBody(BuildContext context) async {
    List<Widget> listChildren = [];


    List<String> knownDevices = await UserSettings.getKnownDevices();
    bool currentDeviceKnown = knownDevices.contains(myArguments.connectedDeviceID);
    globalLogger.w("connected device is in known devices? $currentDeviceKnown Connected device: ${myArguments.connectedDeviceID}");
    if (!currentDeviceKnown && myArguments.connectedDeviceID != null) {
      listChildren.add(Center(child: Text("Warning, connected device does not belong to a vehicle!", style: TextStyle(color: Colors.yellow),),));
      listChildren.add(Center(child: Text("Please adopt a vehicle below", style: TextStyle(color: Colors.yellow),),));
    }
    List<UserSettingsStructure> settings = [];
    List<double> distances = [];
    List<double> consumptions = [];
    UserSettings mySettings = new UserSettings();
    for (int i=0; i<knownDevices.length; ++i) {
      if (await mySettings.loadSettings(knownDevices[i])) {
        settings.add(new UserSettingsStructure.fromValues(mySettings.settings));
        distances.add(await  DatabaseAssistant.dbGetOdometer(knownDevices[i]));
        consumptions.add(await  DatabaseAssistant.dbGetConsumption(knownDevices[i],false));
        //TODO: table
        listChildren.add(Row(
          children: [
            //TODO: Editable board avatar
            FutureBuilder<String>(
                future: UserSettings.getBoardAvatarPath(knownDevices[i]),
                builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                  return CircleAvatar(
                      backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                      radius: 25,
                      backgroundColor: Colors.white);
                }),
            SizedBox(width: 10),
            //Text("${settings[i].batterySeriesCount}S"),
            //SizedBox(width: 10),
            //TODO: Editable board name
            Text("${settings[i].boardAlias}"),
            //Text("${settings[i].deviceID.substring(0,8)}"),

            Spacer(),
            Text("${doublePrecision(distances[i], 2)} km", style: TextStyle(fontSize: 10)),
            SizedBox(width: 10),
            Text("${doublePrecision(consumptions[i], 2)} wh/km", style: TextStyle(fontSize: 10)),
            SizedBox(width: 10),
            // Show if the listed device is the one we are connected to
            myArguments.connectedDeviceID == settings[i].deviceID ? Icon(Icons.bluetooth_connected) : Container(),
            myArguments.connectedDeviceID == settings[i].deviceID ? GestureDetector(child: Icon(Icons.remove_circle), onTap: (){_retireVehicle(settings[i].deviceID);}) : Container(),

            // Show if vehicle has been retired from service
            settings[i].deviceID.startsWith("R*") ? Icon(Icons.bedtime_outlined, color: Colors.grey) : Container(),

            // Allow any vehicle to be adopted/recruited if we are not currently connected to a known device
            currentDeviceKnown == false || myArguments.connectedDeviceID == null ? GestureDetector(child: Icon(Icons.family_restroom), onTap: (){_recruitVehicle(settings[i].deviceID);}) : Container(),

            // Allow any disconnected vehicle to be removed
            myArguments.connectedDeviceID != settings[i].deviceID ? GestureDetector(child: Icon(Icons.delete_forever), onTap: (){_removeVehicle(settings[i].deviceID);}) : Container(),
            SizedBox(width: 10),
          ],
        ));
      } else {
        globalLogger.e("help!");
      }
    }
    bodyWidget = ListView(children: listChildren,);
    globalLogger.wtf("hi");
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (BuildContext context) => VehicleManager(), settings: RouteSettings(arguments: myArguments)));
    return;
  }

  void _reloadBody() {
    bodyWidget = null;
    // Reload view, tricky eh?
    myArguments.navigatorState.pushReplacement(MaterialPageRoute(builder: (BuildContext context) => VehicleManager(), settings: RouteSettings(arguments: myArguments)));
  }

  @override
  Widget build(BuildContext context) {
    print("Building vehicleManager");

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No Arguments"));
    }

    if (bodyWidget == null) {
      _buildBody(context);
    }
    return Scaffold(
      appBar: AppBar(
        title: Row(children: <Widget>[
          Icon( Icons.list_alt,
            size: 35.0,
            color: Colors.blue,
          ),
          Text("Vehicle Manager"),
        ],),
      ),
      body: bodyWidget == null ? Container(child: Text("Loading")) : bodyWidget,
    );
  }
}
