
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:freesk8_mobile/components/userSettings.dart';

import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/hardwareSupport/dieBieMSHelper.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

///
/// Asymmetric sigmoidal approximation
/// https://www.desmos.com/calculator/oyhpsu8jnw
///
/// c - c / [1 + (k*x/v)^4.5]^3
///
double sigmoidal(double voltage, double minVoltage, double maxVoltage) {

  double result = 101 - (101 / pow(1 + pow(1.33 * (voltage - minVoltage)/(maxVoltage - minVoltage) ,4.5), 3));

  double normalized = result >= 100 ? 1.0 : result / 100;
  if (normalized.isNaN) {
    globalLogger.d("realTimeData::sigmoidal: Returning Zero: $voltage V, $minVoltage min, $maxVoltage max");
    normalized = 0;
  }
  return normalized;
}

class SmartBMSArguments {

  final Stream dataStream;
  final BluetoothCharacteristic theTXCharacteristic;
  final UserSettings myUserSettings;
  final ValueChanged<int> changeSmartBMSID;




  SmartBMSArguments({
    @required this.dataStream,
    @required this.theTXCharacteristic,
    @required this.myUserSettings,
    @required this.changeSmartBMSID,


  });
}

class SmartBMSViewer extends StatefulWidget {
  @override
  SmartBMSViewerState createState() => SmartBMSViewerState();

  static const String routeName = "/smartbms";
}

class SmartBMSViewerState extends State<SmartBMSViewer> {
  bool changesMade = false; //TODO: remove if unused

  static SmartBMSArguments myArguments;

  static StreamSubscription<DieBieMSTelemetry> bmsTelemetrySubscription;

  DieBieMSTelemetry bmsTelemetry = new DieBieMSTelemetry();

  static int _smartBMSID = 10;

  static Timer telemetryTimer;

  @override
  void initState() {

    telemetryTimer?.cancel();
    telemetryTimer = new Timer.periodic(Duration(seconds:1), (Timer t) => requestTelemetry());
    super.initState();
  }

  @override
  void dispose() {
    bmsTelemetrySubscription?.cancel();
    bmsTelemetrySubscription = null;

    telemetryTimer?.cancel();
    telemetryTimer = null;

    super.dispose();
  }


  void requestTelemetry() async {
    /// Request BMS Telemetry
    Uint8List packet = simpleVESCRequest(COMM_PACKET_ID.COMM_GET_VALUES.index, optionalCANID: _smartBMSID);

    if (!await sendBLEData(myArguments.theTXCharacteristic, packet, true)) {
      globalLogger.e("_requestTelemetry() failed");
    }
  }

  Future<Widget> _buildBody(BuildContext context) async {
    
    setLandscapeOrientation(enabled: false);
    var formatTriple = new NumberFormat("##0.000", "en_US");
    return SlidingUpPanel(
        color: Theme.of(context).primaryColor,
        minHeight: 40,
        maxHeight: MediaQuery.of(context).size.height - 150,
        panel: Column(
          children: <Widget>[
            Container(
              height: 25,
              color: Theme.of(context).highlightColor,
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.arrow_drop_up),
                    Icon(Icons.arrow_drop_down),
                  ]),
            ),
            Expanded(
                child: ListView.builder(
                  primary: false,
                  padding: EdgeInsets.all(5),
                  itemCount: bmsTelemetry.noOfCells,
                  itemBuilder: (context, i) {
                    Widget rowIcon;
                    if (bmsTelemetry.cellVoltage[i] == bmsTelemetry.cellVoltageAverage){
                      rowIcon = Transform.rotate(
                        angle: 1.5707,
                        child: Icon(Icons.pause_circle_outline),
                      );
                    } else if (bmsTelemetry.cellVoltage[i] < bmsTelemetry.cellVoltageAverage){
                      rowIcon = Icon(Icons.remove_circle_outline);
                    } else {
                      rowIcon = Icon(Icons.add_circle_outline);
                    }

                    //Sometimes we get a bad parse or bad data from DieBieMS and slider value will not be in min/max range
                    double voltage = bmsTelemetry.cellVoltage[i] - bmsTelemetry.cellVoltageAverage;
                    if (voltage < -bmsTelemetry.cellVoltageMismatch || voltage > bmsTelemetry.cellVoltageMismatch) {
                      return Container();
                    }
                    else return Row(

                      children: <Widget>[
                        rowIcon,
                        Text(" Cell ${i + 1}"),

                        Expanded(child: Slider(
                          onChanged: (newValue){},
                          inactiveColor: Colors.red,
                          value: bmsTelemetry.cellVoltage[i] - bmsTelemetry.cellVoltageAverage,
                          min: -bmsTelemetry.cellVoltageMismatch,
                          max: bmsTelemetry.cellVoltageMismatch,
                        ),),
                        Text("${formatTriple.format(bmsTelemetry.cellVoltage[i])}"),
                      ],


                    );
                  },
                )
            ),
          ],
        ),
        body: Stack(children: <Widget>[

          Center(child:
          Column(children: <Widget>[
            Table(children: [
              TableRow(children: [
                Text("Pack Voltage: ", textAlign: TextAlign.right,textScaleFactor: 1.25,),
                //TODO: Hiding SOC if value is 50% because the FlexiBMS always reports 50
                Text(" ${bmsTelemetry.packVoltage} ${bmsTelemetry.soc != 50 ? "(${bmsTelemetry.soc}%)" : ""}", textScaleFactor: 1.25,)
              ]),
              TableRow(children: [
                Text("Pack Current: ", textAlign: TextAlign.right,),
                Text(" ${formatTriple.format(bmsTelemetry.packCurrent)} A")
              ]),
              TableRow(children: [
                Text("Cell Voltage Average: ", textAlign: TextAlign.right,),
                Text(" ${formatTriple.format(bmsTelemetry.cellVoltageAverage)} V")
              ]),
              TableRow(children: [
                Text("Cell Voltage High: ", textAlign: TextAlign.right,),
                Text(" ${formatTriple.format(bmsTelemetry.cellVoltageHigh)} V")
              ]),

              TableRow(children: [
                Text("Cell Voltage Low: ", textAlign: TextAlign.right,),
                Text(" ${formatTriple.format(bmsTelemetry.cellVoltageLow)} V")
              ]),
              TableRow(children: [
                Text("Cell Voltage Mismatch: ", textAlign: TextAlign.right,),
                Text(" ${formatTriple.format(bmsTelemetry.cellVoltageMismatch)} V")
              ]),
              TableRow(children: [
                Text("Battery Temp High: ", textAlign: TextAlign.right,),
                Text(" ${bmsTelemetry.tempBatteryHigh} C")
              ]),
              TableRow(children: [
                Text("Battery Temp Average: ", textAlign: TextAlign.right,),
                Text(" ${bmsTelemetry.tempBatteryAverage} C")
              ]),
              TableRow(children: [
                Text("BMS Temp High: ", textAlign: TextAlign.right,),
                Text(" ${bmsTelemetry.tempBMSHigh} C")
              ]),
              TableRow(children: [
                Text("BMS Temp Average: ", textAlign: TextAlign.right,),
                Text(" ${bmsTelemetry.tempBMSAverage} C")
              ]),
            ],),

            Expanded(child: GridView.builder(
              primary: true,
              itemCount: bmsTelemetry.noOfCells,
              gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 3, crossAxisSpacing: 1, mainAxisSpacing: 1),
              itemBuilder: (BuildContext context, int index) {
                return new Card(
                  shadowColor: Colors.transparent,
                  child: new GridTile(
                      child: new Stack(children: <Widget>[
                        new SizedBox(height: 42,

                            child: new ClipRRect(
                              borderRadius: new BorderRadius.only(topLeft: new Radius.circular(10), topRight: new Radius.circular(10)),
                              child: new LinearProgressIndicator(
                                  backgroundColor: Colors.grey,
                                  valueColor: bmsTelemetry.cellVoltage[index] < 0 ?
                                  new AlwaysStoppedAnimation<Color>(Colors.orangeAccent) :
                                  new AlwaysStoppedAnimation<Color>(Colors.lightGreen),
                                  value: sigmoidal(
                                      bmsTelemetry.cellVoltage[index].abs(),
                                      myArguments.myUserSettings.settings.batteryCellMinVoltage,
                                      myArguments.myUserSettings.settings.batteryCellMaxVoltage)
                              ),
                            )
                        ),
                        new Positioned(
                            top: 5, child: new Text(
                          "  ${formatTriple.format(bmsTelemetry.cellVoltage[index].abs())} V",
                          style: TextStyle(color: Colors.black),
                          textScaleFactor: 1.25,)),
                        new Positioned(bottom: 2, child: new Text("  Cell ${index + 1}")),
                        new ClipRRect(
                            borderRadius: new BorderRadius.circular(10),
                            child: new Container(
                              decoration: new BoxDecoration(
                                color: Colors.transparent,
                                border: new Border.all(color: Theme.of(context).accentColor, width: 3.0),
                                borderRadius: new BorderRadius.circular(10.0),
                              ),
                            )
                        ),
                        /*
                        new Positioned(
                          right: -5,
                          top: 15,
                          child: new SizedBox(
                            height: 30,
                            width: 10,
                            child: new Container(
                              decoration: new BoxDecoration(
                                color: Colors.red,
                                border: new Border.all(color: Colors.red, width: 3.0),
                                borderRadius: new BorderRadius.circular(10.0),
                              ),
                            )
                          ),
                        )
                        */
                      ],)

                  ),
                );
              },
            )),
            SizedBox(
              height: 25, //NOTE: We want empty space below the gridView for the SlidingUpPanel's handle
            )
          ])
          ),


          Positioned(
              left: 0,
              top: 0,
              child: SizedBox(
                  width: 42,
                  child: GestureDetector(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.device_hub),
                          Text("CAN"),
                          Text("ID ${_smartBMSID}")
                        ]
                    ),
                    onTap: (){
                      myArguments.changeSmartBMSID(_smartBMSID == 10 ? 11 : 10);
                    },
                  )
              )
          ),
        ],)
    );

  }

  @override
  Widget build(BuildContext context) {
    print("Building Template");

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No Arguments"));
    }

    if(bmsTelemetrySubscription == null) {
      bmsTelemetrySubscription = myArguments.dataStream.listen((value) {
        globalLogger.i("Stream Data Received");
        setState(() {
          // Update widget value
          bmsTelemetry = value;
        });
      });
    }

    return new WillPopScope(
      onWillPop: () async => false,
      child: new Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon( Icons.battery_charging_full,
              size: 35.0,
              color: Colors.blue,
            ),
            SizedBox(width: 3),
            Text("SmartBMS Viewer"),
          ],),
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: (){
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
