
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:freesk8_mobile/components/databaseAssistant.dart';
import 'package:freesk8_mobile/components/userSettings.dart';
import 'package:freesk8_mobile/globalUtilities.dart';

import 'package:uuid/uuid.dart';

class VehicleManagerArguments {
  final String connectedDeviceID;

  VehicleManagerArguments(this.connectedDeviceID);
}

class VehicleManager extends StatefulWidget {
  @override
  VehicleManagerState createState() => VehicleManagerState();

  static const String routeName = "/vehiclemanager";
}

class VehicleManagerState extends State<VehicleManager> {
  bool changesMadeToVehicle = false;
  VehicleManagerArguments myArguments;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _retireVehicle(String deviceID) async {
    changesMadeToVehicle = true;
    await genericConfirmationDialog(context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        var uuid = Uuid();
        Navigator.of(context).pop();
        String newID = "R*${uuid.v4().toString()}"; // Generate unique retirement ID
        await DatabaseAssistant.dbAssociateVehicle(deviceID, newID);
        await UserSettings.associateDevice(deviceID, newID);
        setState(() {});
      },
    ), "Retire Vehicle", Text("Are you sure you want to retire the selected vehicle? The connected bluetooth device will no longer be associated with this vehicle. Nothing will be erased."));
  }

  void _recruitVehicle(String deviceID) async {
    changesMadeToVehicle = true;
    await genericConfirmationDialog(context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(context).pop();
        String newID = myArguments.connectedDeviceID;
        await DatabaseAssistant.dbAssociateVehicle(deviceID, newID);
        await UserSettings.associateDevice(deviceID, newID);
        setState(() {});
      },
    ), "Adopt Vehicle", Text("Assign connected bluetooth device to selected vehicle?"));
  }

  void _removeVehicle(String deviceID) async {
    await genericConfirmationDialog(context, TextButton(
      child: Text("NO"),
      onPressed: () {
        Navigator.of(context).pop();
      },
    ), TextButton(
      child: Text("YES"),
      onPressed: () async {
        Navigator.of(context).pop();
        await DatabaseAssistant.dbRemoveVehicle(deviceID);
        await UserSettings.removeDevice(deviceID);
        setState(() {});
      },
    ), "Remove Vehicle", Text("Remove the selected vehicle and all of it's data?"));
  }

  Future<Widget> _buildBody(BuildContext context) async {
    Widget bodyWidget;

    List<Widget> listChildren = [];
    List<String> knownDevices = await UserSettings.getKnownDevices();
    bool currentDeviceKnown = knownDevices.contains(myArguments.connectedDeviceID);
    globalLogger.w("connected device is in known devices? $currentDeviceKnown Connected device: ${myArguments.connectedDeviceID}");

    listChildren.add(SizedBox(height: 10));
    listChildren.add(
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(image: AssetImage("assets/dri_icon.png"),height: 100),
              Column(children: [
                Text("Actions available:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Row(children: [
                  Icon(Icons.remove_circle),
                  Text("Retire"),
                  SizedBox(width: 3),
                  Icon(Icons.delete_forever),
                  Text("Erase"),
                  SizedBox(width: 4),
                  Icon(Icons.family_restroom),
                  Text("Adopt")
                ],),

                Text("Status icons:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
                Row(children: [
                  Icon(Icons.bedtime_outlined, color: Colors.grey),
                  Text("Retired"),
                  SizedBox(width: 4),
                  Icon(Icons.bluetooth_connected, color: Colors.grey),
                  Text("Connected")
                ],),

              ])
            ])
    );

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
        distances.add(await DatabaseAssistant.dbGetOdometer(knownDevices[i], mySettings.settings.useGPSData));
        consumptions.add(await DatabaseAssistant.dbGetConsumption(knownDevices[i], mySettings.settings.useImperial, mySettings.settings.useGPSData));
        // Add a Row for each Vehicle we load
        Widget listChild = Row(
          children: [
            //TODO: Editable board avatar
            FutureBuilder<String>(
                future: UserSettings.getBoardAvatarPath(knownDevices[i]),
                builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                  return CircleAvatar(
                      backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.png'),
                      radius: 42,
                      backgroundColor: Colors.white);
                }),
            SizedBox(width: 10),
            Column(children: [
              Text("${settings[i].boardAlias}"), //TODO: Editable board name
              Text("${settings[i].batterySeriesCount}S ${settings[i].wheelDiameterMillimeters}mm ${settings[i].gearRatio}:1"),
              Text("${settings[i].deviceID}", style: TextStyle(fontSize: 4),),
            ],
            crossAxisAlignment: CrossAxisAlignment.start),


            Spacer(),
            Column(children: [
              Text("${settings[i].useImperial ? kmToMile(distances[i]) : doublePrecision(distances[i], 2)} ${settings[i].useImperial ? "mi" : "km"}"),
              Text("${doublePrecision(consumptions[i], 2)} ${settings[i].useImperial ? "wh/mi" : "wh/km"}"),
            ],crossAxisAlignment: CrossAxisAlignment.end),

            SizedBox(width: 10),
            // Show if the listed device is the one we are connected to
            myArguments.connectedDeviceID == settings[i].deviceID ? Icon(Icons.bluetooth_connected, color: Colors.grey) : Container(),
            myArguments.connectedDeviceID == settings[i].deviceID ? GestureDetector(child: Icon(Icons.remove_circle), onTap: (){_retireVehicle(settings[i].deviceID);}) : Container(),

            // Show if vehicle has been retired from service
            settings[i].deviceID.startsWith("R*") ? Icon(Icons.bedtime_outlined, color: Colors.grey) : Container(),

            // Allow any vehicle to be adopted/recruited if we are not currently connected to a known device
            !currentDeviceKnown && myArguments.connectedDeviceID != null ? GestureDetector(child: Icon(Icons.family_restroom), onTap: (){_recruitVehicle(settings[i].deviceID);}) : Container(),

            // Allow any disconnected vehicle to be removed
            myArguments.connectedDeviceID != settings[i].deviceID ? GestureDetector(child: Icon(Icons.delete_forever), onTap: (){_removeVehicle(settings[i].deviceID);}) : Container(),
            SizedBox(width: 10),
          ],
        );

        if (myArguments.connectedDeviceID == settings[i].deviceID) {
          // This item is the connected device
          // Add it to the top
          listChildren.insert(2, listChild);
        } else if (knownDevices[i] != "defaults"){
          // Add any device that isn't our built in "defaults" profile
          listChildren.add(listChild);
        }
      } else {
        globalLogger.e("help!");
      }
    }
    bodyWidget = ListView.separated(
      separatorBuilder: (BuildContext context, int index) {
        return SizedBox(
          height: 5,
        );
      },
      itemCount: listChildren.length,
      itemBuilder: (_, i) => listChildren[i],
    );

    return bodyWidget;
  }

  @override
  Widget build(BuildContext context) {
    print("Building vehicleManager");

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
            Icon( Icons.list_alt,
              size: 35.0,
              color: Colors.blue,
            ),
            SizedBox(width: 3),
            Text("FreeSK8 Garage"),
          ],),
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(changesMadeToVehicle),
          ),
        ),
        body: FutureBuilder<Widget>(
            future: _buildBody(context),
            builder: (context, AsyncSnapshot<Widget> snapshot) {
              if (snapshot.hasData) {
                return snapshot.data;
              } else {
                return Center(child: CircularProgressIndicator());
              }
            }
        ),
      ),
    );
  }
}
