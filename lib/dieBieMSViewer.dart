import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'dieBieMSHelper.dart';


class DieBieMSViewerArguments {
  final BluetoothCharacteristic bleTXCharacteristic;
  final DieBieMSTelemetry telemetry;
  DieBieMSViewerArguments(this.bleTXCharacteristic, this.telemetry);
}


class DieBieMSViewer extends StatefulWidget {
  DieBieMSViewer();

  DieBieMSViewerState createState() => new DieBieMSViewerState();

  static const String routeName = "/diebiemsviewer";
}

class DieBieMSViewerState extends State<DieBieMSViewer> {
  static DieBieMSViewerArguments myArguments;
  static DieBieMSTelemetry testTelemetry;
  static Timer refreshTimer;

  @override
  void initState() {
    testTelemetry = new DieBieMSTelemetry();
    super.initState();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshTimer() {
    if(this.mounted) {
      setState(() {

      });
    } else {
      refreshTimer?.cancel();
      refreshTimer = null;
    }
  }
  @override
  Widget build(BuildContext context) {
    print("Build: dieBieMSViewer");

    const duration = const Duration(milliseconds:100);
    refreshTimer = new Timer.periodic(duration, (Timer t) => _refreshTimer());

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container();
    }

    ///Build Widget
    return Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon(Icons.battery_charging_full,
              size: 35.0,
              color: Colors.blue,
            ),
            Text("DieBieMS Status"),
          ],),
        ),
        body:
        Center(child:
          Column(children: <Widget>[
            Text("Pack Voltage: ${testTelemetry.packVoltage}"),
            Text("Pack Current: ${testTelemetry.packCurrent}"),
            Text("Cell Voltage High: ${testTelemetry.cellVoltageHigh}"),
            Text("Cell Voltage Average: ${testTelemetry.cellVoltageAverage}"),
            Text("Cell Voltage Low: ${testTelemetry.cellVoltageLow}"),
            Text("Cell Voltage Mismatch: ${testTelemetry.cellVoltageMismatch}"),
            Text("Battery Temp High: ${testTelemetry.tempBatteryHigh}"),
            Text("Battery Temp Average: ${testTelemetry.tempBatteryAverage}"),
            Text("BMS Temp High: ${testTelemetry.tempBMSHigh}"),
            Text("BMS Temp Average: ${testTelemetry.tempBMSAverage}"),

            Expanded(child: GridView.builder(
              itemCount: testTelemetry.noOfCells,
              gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3),
              itemBuilder: (BuildContext context, int index) {
                return new Card(
                  child: new GridTile(
                    footer: new Text("Cell $index"),
                    child: new Stack(children: <Widget>[

                      new SizedBox(height: 42,child: new LinearProgressIndicator( value: testTelemetry.cellVoltage[index] / 4.2),),
                      new Text(testTelemetry.cellVoltage[index].toString(), style: TextStyle(color: Colors.black)),
                    ],)

                  ),
                );
              },
            )

              ,)
          ])
        )
    );
  }
}