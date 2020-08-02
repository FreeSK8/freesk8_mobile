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
  DieBieMSViewerArguments myArguments;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: dieBieMSViewer");
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
            Text("DieBieMS..fancy"),
          ],),
        ),
        body:
        Center(child:
          Column(children: <Widget>[
            Text("Pack Voltage: ${myArguments.telemetry.packVoltage}"),
            Text("Pack Current: ${myArguments.telemetry.packCurrent}"),
            Text("Cell Voltage High: ${myArguments.telemetry.cellVoltageHigh}"),
            Text("Cell Voltage Average: ${myArguments.telemetry.cellVoltageAverage}"),
            Text("Cell Voltage Low: ${myArguments.telemetry.cellVoltageLow}"),
            Text("Cell Voltage Mismatch: ${myArguments.telemetry.cellVoltageMismatch}"),
            Text("Battery Temp High: ${myArguments.telemetry.tempBatteryHigh}"),
            Text("Battery Temp Average: ${myArguments.telemetry.tempBatteryAverage}"),
            Text("BMS Temp High: ${myArguments.telemetry.tempBMSHigh}"),
            Text("BMS Temp Average: ${myArguments.telemetry.tempBMSAverage}"),

            Expanded(child: GridView.builder(
              itemCount: myArguments.telemetry.noOfCells,
              gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3),
              itemBuilder: (BuildContext context, int index) {
                return new Card(
                  child: new GridTile(
                    footer: new Text("Cell $index"),
                    child: new Text(myArguments.telemetry.cellVoltage[index].toString()),
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