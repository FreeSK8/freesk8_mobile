
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:freesk8_mobile/components/databaseAssistant.dart';
import 'package:freesk8_mobile/components/userSettings.dart';
import 'package:freesk8_mobile/globalUtilities.dart';

class VehicleManager extends StatefulWidget {
  @override
  VehicleManagerState createState() => VehicleManagerState();

  static const String routeName = "/vehiclemanager";
}

class VehicleManagerState extends State<VehicleManager> {
  static Widget bodyWidget;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    bodyWidget = null;
    super.dispose();
  }

  void _buildBody(BuildContext context) async {
    List<Widget> listChildren = [];

    List<String> knownDevices = await UserSettings.getKnownDevices();
    List<UserSettingsStructure> settings = [];
    List<double> distances = [];
    List<double> consumptions = [];
    UserSettings mySettings = new UserSettings();
    for (int i=0; i<knownDevices.length; ++i) {
      if (await mySettings.loadSettings(knownDevices[i])) {
        settings.add(mySettings.settings);
        distances.add(await  DatabaseAssistant.dbGetOdometer(knownDevices[i]));
        consumptions.add(await  DatabaseAssistant.dbGetConsumption(knownDevices[i],false));
        //TODO: table
        listChildren.add(Row(
          children: [
            FutureBuilder<String>(
                future: UserSettings.getBoardAvatarPath(knownDevices[i]),
                builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                  return CircleAvatar(
                      backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                      radius: 25,
                      backgroundColor: Colors.white);
                }),
            SizedBox(width: 10),
            Text("${settings[i].batterySeriesCount}S"),
            SizedBox(width: 10),
            Text("${settings[i].boardAlias}"),

            Spacer(),
            Text("${doublePrecision(distances[i], 2)} km"),
            SizedBox(width: 10),
            Text("${doublePrecision(consumptions[i], 2)} wh/km"),
            SizedBox(width: 10),
            Icon(Icons.not_interested),
            SizedBox(width: 10),
            Icon(Icons.delete_forever)
          ],
        ));
      } else {
        globalLogger.e("help!");
      }
    }
    bodyWidget = ListView(children: listChildren,);
    globalLogger.wtf("hi");
    Future.delayed(Duration(milliseconds: 100), (){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (BuildContext context) => VehicleManager()));
    });
    return;
  }

  @override
  Widget build(BuildContext context) {
    print("Building vehicleManager");

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
