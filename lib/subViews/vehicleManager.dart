
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:freesk8_mobile/components/databaseAssistant.dart';
import 'package:freesk8_mobile/components/userSettings.dart';
import 'package:freesk8_mobile/globalUtilities.dart';

import 'package:uuid/uuid.dart';

import 'package:charts_flutter/flutter.dart' as charts;

class VehicleManagerArguments {
  final String connectedDeviceID;

  VehicleManagerArguments(this.connectedDeviceID);
}

/// Sample linear data type.
class DataTrend {
  final int index;
  final double distance;
  final double energy;
  final double duration;
  final double speed;

  DataTrend(this.index, this.distance, this.energy, this.duration, this.speed);
}

class VehicleManager extends StatefulWidget {
  @override
  VehicleManagerState createState() => VehicleManagerState();

  static const String routeName = "/vehiclemanager";
}

class VehicleManagerState extends State<VehicleManager> {
  bool changesMadeToVehicle = false;
  VehicleManagerArguments myArguments;
  int trendDays = 7;
  bool loadingTrends = false;

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

  /// Create carting series
  static List<charts.Series<DataTrend, int>> _createChartData(List<double> distances, List<double> energies, List<double> durations, List<double> speeds) {

    double energy_avg = (energies.reduce((value, element) => value + element) / energies.length);
    energies.forEach((element) {element -= energy_avg;});
    energies = normalize(energies);

    double distance_avg = (distances.reduce((value, element) => value + element) / distances.length);
    distances.forEach((element) {element -= distance_avg;});
    distances = normalize(distances);

    double duration_avg = (durations.reduce((value, element) => value + element) / durations.length);
    durations.forEach((element) {element -= duration_avg;});
    durations = normalize(durations);

    double speed_avg = (speeds.reduce((value, element) => value + element) / speeds.length);
    speeds.forEach((element) {element -= speed_avg;});
    speeds = normalize(speeds);

    List<DataTrend> data = [];
    for (int i=0; i<distances.length; ++i) {
      data.add(new DataTrend(i, distances[i], energies[i], durations[i], speeds[i]));
    }

    return [
      new charts.Series<DataTrend, int>(
        id: "Speed",
        colorFn: (_, __) => charts.MaterialPalette.white,
        domainFn: (DataTrend trend, _) => trend.index,
        measureFn: (DataTrend trend, _) => trend.speed,
        data: data,
      ),

      new charts.Series<DataTrend, int>(
        id: "Energy",
        colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        domainFn: (DataTrend trend, _) => trend.index,
        measureFn: (DataTrend trend, _) => trend.energy,
        data: data,
      ),

      new charts.Series<DataTrend, int>(
        id: "Distance",
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
        domainFn: (DataTrend trend, _) => trend.index,
        measureFn: (DataTrend trend, _) => trend.distance,
        data: data,
      ),

      new charts.Series<DataTrend, int>(
        id: "Duration",
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (DataTrend trend, _) => trend.index,
        measureFn: (DataTrend trend, _) => trend.duration,
        data: data,
      ),

    ];
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

                Text("Trending statistics:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),

                Row(children: [
                  Text("Weekly"),
                  Radio(
                    value: 7,
                    groupValue: trendDays,
                    onChanged: (int value){
                      setState(() {
                        loadingTrends = true;
                        trendDays = value;
                      });
                    },
                  ),

                  Text("Monthly"),
                  Radio(
                    value: 30,
                    groupValue: trendDays,
                    onChanged: (int value){
                      setState(() {
                        loadingTrends = true;
                        trendDays = value;
                      });
                    },
                  ),
                ],),

                Row(children: [
                  Text("Distance", style: TextStyle(fontSize: 10, color: Colors.green)),
                  Text(" Duration", style: TextStyle(fontSize: 10, color: Colors.blue)),
                  Text(" Energy", style: TextStyle(fontSize: 10, color: Colors.red)),
                  Text(" Speed", style: TextStyle(fontSize: 10, color: Colors.white)),
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
    List<double> maxAmpsBattery = [];
    List<double> maxAmpsMotors = [];
    List<double> maxSpeed = [];
    List<double> maxSpeedGPS = [];
    List<List<double>> trendDistanceWeekly = [];
    List<List<double>> trendEnergyWeekly = [];
    List<List<double>> trendDurationWeekly = [];
    List<List<double>> trendSpeedWeekly = [];
    UserSettings mySettings = new UserSettings();
    for (int i=0; i<knownDevices.length; ++i) {
      if (await mySettings.loadSettings(knownDevices[i])) {
        settings.add(new UserSettingsStructure.fromValues(mySettings.settings));
        distances.add(await DatabaseAssistant.dbGetOdometer(knownDevices[i], mySettings.settings.useGPSData));
        consumptions.add(await DatabaseAssistant.dbGetConsumption(knownDevices[i], mySettings.settings.useImperial, mySettings.settings.useGPSData));
        maxAmpsBattery.add(await DatabaseAssistant.getMaxValue(knownDevices[i], "max_amps_battery"));
        maxAmpsMotors.add(await DatabaseAssistant.getMaxValue(knownDevices[i], "max_amps_motors"));
        maxSpeed.add(await DatabaseAssistant.getMaxValue(knownDevices[i], "max_speed"));
        maxSpeedGPS.add(await DatabaseAssistant.getMaxValue(knownDevices[i], "max_speed_gps"));


        //NOTE: Trending last 7 days for the past 6 months (26 weeks) or 1 months for the past 12 months
        List<double> trendingLineDistance = [];
        List<double> trendingLineEnergy = [];
        List<double> trendingLineDuration = [];
        List<double> trendingLineSpeed = [];
        DateTime trendDate = DateTime.now();
        int numWindows = trendDays == 7 ? 26 : 12; // Display 6 months for weekly and 1 year for monthly
        for (int j=0; j<numWindows; ++j) {
          trendingLineDistance.insert(0, await DatabaseAssistant.getRangedValue(knownDevices[i], "distance_km", Duration(days: trendDays), trendDate, false));
          trendingLineEnergy.insert(0, await DatabaseAssistant.getRangedValue(knownDevices[i], "watt_hours", Duration(days: trendDays), trendDate, false));
          trendingLineDuration.insert(0, await DatabaseAssistant.getRangedValue(knownDevices[i], "duration_seconds", Duration(days: trendDays), trendDate, false));
          //TODO: max_speed_gps would be cool but that stat hasn't been around long enough to use
          trendingLineSpeed.insert(0, await DatabaseAssistant.getRangedValue(knownDevices[i], "max_speed", Duration(days: trendDays), trendDate, false));
          trendDate = trendDate.subtract(Duration(days: trendDays));
        }
        loadingTrends = false;
        trendDistanceWeekly.add(trendingLineDistance);
        trendEnergyWeekly.add(trendingLineEnergy);
        trendDurationWeekly.add(trendingLineDuration);
        trendSpeedWeekly.add(trendingLineSpeed);


        // Determine actions list for Slidable
        List<Widget> actionsList = [];
        if (myArguments.connectedDeviceID == settings[i].deviceID) {
          actionsList.add(
              Padding(
                padding: EdgeInsets.only(bottom:5, top: 5),
                child: IconSlideAction(
                    caption: 'Retire',
                    color: Colors.blue,
                    icon: Icons.bedtime,
                    onTap: () async {
                      _retireVehicle(settings[i].deviceID);
                    } // Merge onTap
                ),
              )
          );
        }
        // Allow any vehicle to be adopted/recruited if we are not currently connected to a known device
        if (!currentDeviceKnown && myArguments.connectedDeviceID != null) {
          actionsList.add(
              Padding(
                padding: EdgeInsets.only(bottom:5, top: 5),
                child: IconSlideAction(
                    caption: 'Adopt',
                    color: Colors.indigo,
                    icon: Icons.family_restroom,
                    onTap: () async {
                      _recruitVehicle(settings[i].deviceID);
                    } // Merge onTap
                ),
              )
          );
        }

        // Add a Row for each Vehicle we load
        Widget listChild = Slidable(
          key: Key("$i"),
          actionPane: SlidableDrawerActionPane(),
          actionExtentRatio: 0.25,
          child: Container(
            decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(5)
            ),
            child: Row(

              children: [
                SizedBox(width: 5),
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
                Container(
                  color: Colors.green,
                  child: Row(children: [

                  ],),
                ),
                Column(children: [
                  Row(children: [

                    // Show if the listed device is the one we are connected to
                    myArguments.connectedDeviceID == settings[i].deviceID ? Icon(Icons.bluetooth_connected, color: Colors.grey) : Container(),
                    // Show if vehicle has been retired from service
                    settings[i].deviceID.startsWith("R*") ? Icon(Icons.bedtime_outlined, color: Colors.grey) : Container(),

                    Text("${settings[i].boardAlias}"), //TODO: Editable board name
                  ],),

                  Text("${settings[i].batterySeriesCount}S ${settings[i].wheelDiameterMillimeters}mm ${settings[i].gearRatio}:1", style: TextStyle(fontSize: 10, color: Colors.grey),),
                  SizedBox(width: 140, height: 75, child: new charts.LineChart(
                    _createChartData(trendDistanceWeekly[i], trendEnergyWeekly[i], trendDurationWeekly[i], trendSpeedWeekly[i]),
                    animate: false,
                    primaryMeasureAxis: new charts.NumericAxisSpec(showAxisLine: false, renderSpec: new charts.NoneRenderSpec()),
                    domainAxis: new charts.NumericAxisSpec(showAxisLine: false, renderSpec: new charts.NoneRenderSpec()),
                    layoutConfig: new charts.LayoutConfig(
                        leftMarginSpec: new charts.MarginSpec.fixedPixel(0),
                        topMarginSpec: new charts.MarginSpec.fixedPixel(0),
                        rightMarginSpec: new charts.MarginSpec.fixedPixel(0),
                        bottomMarginSpec: new charts.MarginSpec.fixedPixel(0)),
                  ),),
                  SizedBox(height: 5),
                ],
                    crossAxisAlignment: CrossAxisAlignment.start),


                Spacer(),
                Column(children: [
                  SizedBox(height: 10),
                  Text("${settings[i].useImperial ? kmToMile(distances[i]) : doublePrecision(distances[i], 2)} ${settings[i].useImperial ? "mi" : "km"}"),
                  Text("${doublePrecision(consumptions[i], 2)} ${settings[i].useImperial ? "wh/mi" : "wh/km"}"),
                  Text("${maxSpeed[i]} top kph"),
                  Text("${maxAmpsBattery[i]}A batt max"),
                  Text("${maxAmpsMotors[i]}A motor max"),
                  SizedBox(height: 10),
                ],crossAxisAlignment: CrossAxisAlignment.end),

                SizedBox(width: 5),

              ],
            ),),

          // Computed above
          actions: actionsList,

          secondaryActions: myArguments.connectedDeviceID != settings[i].deviceID ? <Widget>[
            // Allow any disconnected vehicle to be removed
            Padding(
              padding: EdgeInsets.only(bottom:5, top: 5),
              child: IconSlideAction(
                caption: 'Delete',
                color: Colors.red,
                icon: Icons.delete,
                onTap: () async {
                  _removeVehicle(settings[i].deviceID);
                },
              ),
            ),
          ] : <Widget>[],
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
              if (snapshot.hasData && !loadingTrends) {
                return snapshot.data;
              } else {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  Text("Loading.... Please wait 🙏"),
                  SizedBox(height: 10),
                  Center(child: CircularProgressIndicator())
                ],);
              }
            }
        ),
      ),
    );
  }
}
