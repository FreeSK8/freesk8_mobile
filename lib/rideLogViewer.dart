import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:freesk8_mobile/rideLogViewChartOverlay.dart';
import 'package:latlong/latlong.dart';
import 'package:freesk8_mobile/databaseAssistant.dart';
import 'package:freesk8_mobile/file_manager.dart';

import 'package:charts_flutter/flutter.dart' as charts;

import 'package:freesk8_mobile/userSettings.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart';

import 'dart:math' show cos, sqrt, asin;

double roundDouble(double value, int places){
  double mod = pow(10.0, places);
  return ((value * mod).round().toDouble() / mod);
}

class RideLogViewerArguments {
  final UserSettings userSettings;
  final String logFilePath;

  RideLogViewerArguments(this.logFilePath,this.userSettings);
}

class RideLogViewer extends StatefulWidget {
  RideLogViewer();

  RideLogViewerState createState() => new RideLogViewerState();

  static const String routeName = "/ridelogviewer";
}

class RideLogViewerState extends State<RideLogViewer> {
  final GlobalKey<State> _keyLoader = new GlobalKey<State>();
  RideLogViewerArguments myArguments;
  String thisRideLog = "";
  List<String> thisRideLogEntries;
  List<LatLng> _positionEntries;

  RideLogChartData currentSelection;

  PublishSubject<RideLogChartData> eventObservable = new PublishSubject();

  showConfirmationDialog(BuildContext context) {
    Widget cancelButton = FlatButton(
      child: Text("Cancel"),
      onPressed: () {
        Navigator.of(context).pop();
      },
    );
    Widget continueButton = FlatButton(
      child: Text("Delete"),
      onPressed: () async {
        //Remove from Database
        await DatabaseAssistant.dbRemoveLog(myArguments.logFilePath);
        //Remove from Filesystem
        await FileManager.eraseLogFile(myArguments.logFilePath);
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("Delete file?"),
      content: Text("Are you sure you want to permanently erase this log?"),
      actions: [
        cancelButton,
        continueButton,
      ],
    );

    // Show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  double calculateDistance(LatLng pointA, LatLng pointB){
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((pointB.latitude - pointA.latitude) * p)/2 +
        c(pointA.latitude * p) * c(pointB.latitude * p) *
            (1 - c((pointB.longitude - pointA.longitude) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  /// Create time series data for chart using ESC values
  static List<charts.Series<TimeSeriesESC, DateTime>> _createChartingData( List<TimeSeriesESC> values, List<int> escIDsInLog ) {
      List<charts.Series<TimeSeriesESC, DateTime>> chartData = new List();

      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'VIN',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.voltage,
        data: values,
      ));
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Motor Temp',
        colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.tempMotor,
        data: values,
      ));

      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor2 Temp',
          colorFn: (_, __) => charts.MaterialPalette.gray.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMotor2,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Mosfet Temp',
        colorFn: (_, __) => charts.MaterialPalette.deepOrange.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet,
        data: values,
      ));
      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Mosfet2 Temp',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet2,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Duty',
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.dutyCycle * 100,
        data: values,
      ));
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Motor Current',
        colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.currentMotor,
        data: values,
      ));
      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor2 Current',
          colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentMotor2,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Input Current',
        colorFn: (_, __) => charts.MaterialPalette.pink.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.currentInput,
        data: values,
      ));
      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Input2 Current',
          colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentInput2,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Speed',
        colorFn: (_, __) => charts.MaterialPalette.white,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.speed,
        data: values,
      ));

      return chartData;
    }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    eventObservable?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: rideLogViewer");

    eventObservable.add(currentSelection);

    //GPS calculations
    double gpsDistance = 0;
    double gpsAverageSpeed = 0;
    double gpsMaxSpeed = 0;
    DateTime gpsStartTime;
    DateTime gpsEndTime;
    Duration gpsDuration = Duration(seconds:0);
    String gpsDistanceStr = "N/A";

    //Charting and data
    List<TimeSeriesESC> escTimeSeriesData = new List<TimeSeriesESC>();
    List<charts.Series> seriesList;
    int faultCodeCount = 0;

    //Mapping
    thisRideLogEntries = new List<String>();
    _positionEntries = new List<LatLng>();

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    print("arguments passed to creation: $myArguments");
    if(myArguments == null){
      return Container();
    }

    //Load log file from received arguments
    if( thisRideLog == "" ) {
      FileManager.openLogFile(myArguments.logFilePath).then((value){
        print("opening log file");
        setState(() {
          thisRideLog = value;
        });
      });
    }

    // Parse lines of log file as CSV
    List<int> escIDsInLog = new List();
    thisRideLogEntries = thisRideLog.split("\n");
    print("rideLogViewer rideLogEntry count: ${thisRideLog.length}");
    for(int i=0; i<thisRideLogEntries.length; ++i) {
      final entry = thisRideLogEntries[i].split(",");

      if(entry.length > 1){ // entry[0] = Time, entry[1] = Data type
        ///GPS position entry
        if(entry[1] == "position") {
          //DateTime, 'position', lat, lon, accuracy, altitude, speed, speedAccuracy
          LatLng thisPosition = new LatLng(double.parse(entry[2]),double.parse(entry[3]));
          if ( _positionEntries.length > 0){
            gpsDistance += calculateDistance(_positionEntries.last, thisPosition);
          }
          _positionEntries.add(thisPosition);
          if (gpsStartTime == null) {gpsStartTime = DateTime.tryParse(entry[0]);}
          gpsEndTime = DateTime.tryParse(entry[0]);
          double thisSpeed = double.tryParse(entry[6]);
          gpsAverageSpeed += thisSpeed;
          if (thisSpeed > gpsMaxSpeed) {gpsMaxSpeed = thisSpeed;}
        }
        ///ESC Values
        else if (entry[1] == "values" && entry.length > 9) {
          //[2020-05-19T13:46:28.8, values, 12.9, -99.9, 29.0, 0.0, 0.0, 0.0, 0.0, 11884, 102]
          DateTime thisDt = DateTime.parse(entry[0]);
          int thisESCID = int.parse(entry[10]);

          if (!escIDsInLog.contains(thisESCID)) {
            print("Adding ESC ID $thisESCID to list of known ESC IDs in this data set");
            escIDsInLog.add(thisESCID);
          }

          bool foundEntry = false;
          escTimeSeriesData.forEach((element) {
            if (element.time == thisDt) {
              foundEntry = true;
              switch(escIDsInLog.indexOf(thisESCID)) {
                case 0:
                // Primary ESC
                //TODO: consider what to do. nothing. update. or start dealing with milliseconds
                  break;
                case 1:
                // Second ESC in multiESC configuration
                  element.tempMotor2 = double.tryParse(entry[3]);
                  element.tempMosfet2 = double.tryParse(entry[4]);
                  element.currentMotor2 = double.tryParse(entry[6]);
                  element.currentInput2 = double.tryParse(entry[7]);
                  break;
                case 2:
                // Third ESC in multiESC configuration
                  element.tempMotor3 = double.tryParse(entry[3]);
                  element.tempMosfet3 = double.tryParse(entry[4]);
                  element.currentMotor3 = double.tryParse(entry[6]);
                  element.currentInput3 = double.tryParse(entry[7]);
                  break;
                case 3:
                // Fourth ESC in multiESC configuration
                  element.tempMotor4 = double.tryParse(entry[3]);
                  element.tempMosfet4 = double.tryParse(entry[4]);
                  element.currentMotor4 = double.tryParse(entry[6]);
                  element.currentInput4 = double.tryParse(entry[7]);
                  break;
                default:
                // Shit this was not supposed to happen
                  print("Shit this was not supposed to happen. There appears to be a 5th ESC ID in the log file: $escIDsInLog");
                  break;
              }
            }
          });

          if (!foundEntry && thisESCID == escIDsInLog[0]) {
            escTimeSeriesData.add(new TimeSeriesESC( time: thisDt, //Date Time
              voltage: double.tryParse(entry[2]), //Voltage
              tempMotor: double.tryParse(entry[3]), //Motor Temp
              tempMosfet: double.tryParse(entry[4]), //Mosfet Temp
              dutyCycle: double.tryParse(entry[5]), //Duty Cycle
              currentMotor: double.tryParse(entry[6]), //Motor Current
              currentInput: double.tryParse(entry[7]), //Input Current
              speed: myArguments.userSettings.settings.useImperial ? _kphToMph(_calculateSpeedKph(double.tryParse(entry[8]))) : _calculateSpeedKph(double.tryParse(entry[8])), //Speed
              distance: myArguments.userSettings.settings.useImperial ? _kmToMile(_calculateDistanceKm(double.tryParse(entry[9]))) : _calculateDistanceKm(double.tryParse(entry[9])), //Distance
            ));
          }
        }
        ///Fault codes
        else if (entry[1] == "fault") {
          //TODO: improve fault display handling
          ++faultCodeCount;
        }
      }
    }
    print("rideLogViewer rideLogEntry iteration complete");

    if(_positionEntries.length > 1) {
      // Calculate GPS statistics
      gpsDuration = gpsEndTime.difference(gpsStartTime);
      gpsAverageSpeed /= _positionEntries.length;
      gpsAverageSpeed = roundDouble(gpsAverageSpeed, 2);
      gpsDistanceStr = myArguments.userSettings.settings.useImperial ? "${roundDouble(_kmToMile(gpsDistance), 2)} miles" : "${roundDouble(gpsDistance, 2)} km";
    }


    print("rideLogViewer creating chart data");
    // Create charting data from ESC time series data
    seriesList = _createChartingData(escTimeSeriesData, escIDsInLog);
    print("rideLogViewer creating map polyline");
    // Create polyline to display GPS route on map
    Polyline routePolyLine = new Polyline(points: _positionEntries, strokeWidth: 3, color: Colors.red);

    // Parse title from filename passed via arguments
    String filename = myArguments.logFilePath.substring(myArguments.logFilePath.lastIndexOf("/") + 1);
    String pageTitle = "${filename.substring(0,10)} @ ${filename.substring(11,19)}";

    ///Generate ride statistics
    double _maxSpeed = 0.0;
    double _avgSpeed = 0.0;
    double _maxAmpsBattery = 0.0;
    double _maxAmpsMotor = 0.0;
    for(int i=0; i<escTimeSeriesData.length;++i) {
      if(escTimeSeriesData[i].speed > _maxSpeed){
        _maxSpeed = escTimeSeriesData[i].speed;
      }
      _avgSpeed += escTimeSeriesData[i].speed;
      if(escTimeSeriesData[i].currentInput > _maxAmpsBattery){
        _maxAmpsBattery = escTimeSeriesData[i].currentInput;
      }
      if(escTimeSeriesData[i].currentMotor > _maxAmpsMotor){
        _maxAmpsMotor = escTimeSeriesData[i].currentMotor;
      }
    }
    String distance = "N/A";
    Duration duration = Duration(seconds:0);
    if(escTimeSeriesData.length > 0) {
      distance = myArguments.userSettings.settings.useImperial ? "${escTimeSeriesData.last.distance} miles" : "${escTimeSeriesData.last.distance} km";
      duration = escTimeSeriesData.last.time.difference(escTimeSeriesData.first.time);

      _avgSpeed /= escTimeSeriesData.length;
      _avgSpeed = roundDouble(_avgSpeed, 2);
    }
    String maxSpeed = myArguments.userSettings.settings.useImperial ? "$_maxSpeed mph" : "$_maxSpeed kph";
    String avgSpeed = myArguments.userSettings.settings.useImperial ? "$_avgSpeed mph" : "$_avgSpeed kph";

    // Remove loading dialog since the user has no control
    if(_keyLoader.currentContext != null)
      Navigator.of(_keyLoader.currentContext,rootNavigator: true).pop();

    print("rideLogViewer statistics generated");

    ///Build Widget
    return Scaffold(
      appBar: AppBar(
        title: Row(children: <Widget>[
          Icon( Icons.map,
          size: 35.0,
          color: Colors.blue,
          ),
          Text(pageTitle),
        ],),
      ),
      body: SlidingUpPanel(
          minHeight: 160,
          maxHeight: 420,
          color: Theme.of(context).primaryColor,
          panel: Column(
            children: <Widget>[
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.arrow_drop_up),
                  Icon(Icons.arrow_drop_down),
                ],),


              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Column(children: <Widget>[
                    Text("Top Speed"),
                    Icon(Icons.arrow_upward),
                    escTimeSeriesData.length > 0 ? Text(maxSpeed) : Text(gpsMaxSpeed.toString())
                  ],),
                  SizedBox(width: 10,),
                  Column(children: <Widget>[
                    Text("Average Speed"),
                    Icon(Icons.trending_up),
                    escTimeSeriesData.length > 0 ? Text(avgSpeed) : Text(gpsAverageSpeed.toString())
                  ],),
                  SizedBox(width: 10,),
                  Column(children: <Widget>[
                    Text("Distance Traveled"),
                    Icon(Icons.place),
                    escTimeSeriesData.length > 0 ? Text(distance) : Text(gpsDistanceStr)
                  ],),


                ],
              ),

              SizedBox(height: 12,),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Column(children: <Widget>[
                    Text("Max Amps"),
                    Icon(Icons.battery_charging_full),
                    Text(_maxAmpsBattery.toString())
                  ],),
                  SizedBox(width: 10,),
                  Column(children: <Widget>[
                    Text("Max Amps Motor"),
                    Icon(Icons.slow_motion_video),
                    Text(_maxAmpsMotor.toString())
                  ],),
                  SizedBox(width: 10,),
                  Column(children: <Widget>[
                    Text("Duration"),
                    Icon(Icons.watch_later),
                    escTimeSeriesData.length > 0 ?
                      Text(duration.toString().substring(0,duration.toString().lastIndexOf(".")))
                        :
                    Text(gpsDuration.toString().substring(0,gpsDuration.toString().lastIndexOf(".")))
                  ],),


                ],
              ),

              SizedBox(height: 12,),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  faultCodeCount > 0 ?
                  Column(children: <Widget>[
                    Text("Fault codes"),
                    Icon(Icons.error_outline, color: Colors.red,),
                    Text("$faultCodeCount fault(s)"),
                  ],)
                      :
                  Column(children: <Widget>[
                    Text("Fault codes"),
                    Icon(Icons.check_circle_outline, color: Colors.green,),
                    Text("$faultCodeCount faults"),
                  ],)
                ],
              ),

              Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    RaisedButton(
                        child: Text("Delete log"),
                        onPressed: () async {
                          //confirm with user
                          showConfirmationDialog(context);
                        }),

                    SizedBox(width: 10,),

                    RaisedButton(
                        child: Text("Share Log"),
                        onPressed: () async {
                          String fileSummary = 'Robogotchi gotchi!';
                          fileSummary += "\nTop Speed: $maxSpeed";
                          fileSummary += "\nAvg Speed: $avgSpeed";
                          fileSummary += "\nDistance: $distance";
                          fileSummary += "\nBattery Amps: $_maxAmpsBattery";
                          fileSummary += "\nMotor Amps: $_maxAmpsMotor";
                          fileSummary += "\nDuration: ${duration.toString().substring(0,duration.toString().lastIndexOf("."))}";
                          fileSummary += "\n\nValues Format: DateTime, Voltage, Motor Temp, Mosfet Temp, DutyCycle, Motor Current, Battery Current, eRPM, eDistance, ESC ID";
                          fileSummary += "\nPosition Format: latitude, longitude, sats_in_view, altitude, speed";
                          await Share.file('FreeSK8Log', filename, utf8.encode(thisRideLog), 'text/csv', text: fileSummary);
                        }),
                  ],),



              Expanded(child:
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Text(thisRideLog.substring(0,thisRideLog.length > 10240 ? 10240 : thisRideLog.length ), softWrap: false,),
                )
              ),
            ],
          ),

          body: Container(
            child: Center(
              child: Column(
                // center the children
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[

                  //MediaQuery.of(context).size.width / 3 * 2

                  _positionEntries.length > 0 ?
                    SizedBox(height: 175,
                      child: FlutterMap(
                        options: new MapOptions(
                          center: _positionEntries.first,
                          zoom: 13.0,
                        ),
                        layers: [
                          new TileLayerOptions(
                              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                              subdomains: ['a', 'b', 'c']
                          ),
                          new MarkerLayerOptions(
                            markers: [
                              new Marker(
                                width: 160.0,
                                height: 160.0,
                                point: _positionEntries.first,
                                builder: (ctx) =>
                                new Container(
                                  margin: EdgeInsets.fromLTRB(0, 0, 0, 80),
                                  child: new Image(image: AssetImage("assets/home_map_marker.png")),
                                ),
                              ),
                              new Marker(
                                width: 160.0,
                                height: 160.0,
                                point: _positionEntries.last,
                                builder: (ctx) =>
                                new Container(
                                  margin: EdgeInsets.fromLTRB(0, 0, 0, 80),
                                  child: new Image(image: AssetImage("assets/skating_pin.png")),
                                ),
                              ),
                            ],
                          ),
                          new PolylineLayerOptions(
                              polylines: [routePolyLine]
                          )
                        ],
                      ),
                    ) :
                  SizedBox(height: 25, child: Text("GPS Data Not Recorded")),

                  Expanded( child:
                    Stack( children: <Widget>[

                      charts.TimeSeriesChart(
                        seriesList,
                        animate: false,
                        /// Set zeroBound to false or we have lots of empty space in chart
                        primaryMeasureAxis: new charts.NumericAxisSpec(
                            tickProviderSpec: new charts.BasicNumericTickProviderSpec(zeroBound: false)),
                        //TODO: Customize the domainAxis tickFormatterSpec causes PanAndZoomBehavior to stop working, WHY?
                        /*
                        domainAxis: new charts.DateTimeAxisSpec(
                            tickFormatterSpec: new charts.AutoDateTimeTickFormatterSpec(
                                minute: new charts.TimeFormatterSpec(
                                  format: 'HH:mm', // or even HH:mm here too
                                  transitionFormat: 'HH:mm',
                                ),
                            )
                        ),
                        */
                        behaviors: [
                          //TODO: "PanAndZoomBehavior()" causes "Exception caught by gesture" : "Bad state: No element" but works
                          //TODO: charts.PointRenderer() line 255. Add: if (!componentBounds.containsPoint(point)) continue;
                          //TODO: https://github.com/janstol/charts/commit/899476a06875422aafde82376cdf57ba0c2e65a5
                          new charts.PanAndZoomBehavior(),
                          new charts.SeriesLegend(desiredMaxColumns:3, position: charts.BehaviorPosition.bottom, cellPadding: EdgeInsets.all(5.0) ),
                        ],
                        /// Using selection model to generate value overlay
                        selectionModels: [
                          charts.SelectionModelConfig(
                              changedListener: (charts.SelectionModel model) {
                                if(model.hasDatumSelection) {
                                  currentSelection = new RideLogChartData(model.selectedDatum.first.datum.time,  model.selectedDatum.first.datum);
                                  eventObservable.add(currentSelection);
                                  eventObservable.publish();
                                }
                              }
                          )

                        ],
                      ),


                      //TODO: would be cool to position this near the user input
                      Positioned(
                        bottom: 21,
                        right: 5,
                        child: RideLogViewChartOverlay(eventObservable: eventObservable,),
                      ),


                    ],),),

                  SizedBox(height: 250,), //This is the height of the slide drawer on the bottom, do not remove

                ],
              ),
            ),
          ),


      )
    );
  }

  double _calculateSpeedKph(double eRpm) {
    double ratio = myArguments.userSettings.settings.pulleyMotorToothCount / myArguments.userSettings.settings.pulleyWheelToothCount;
    int minutesToHour = 60;
    double ratioRpmSpeed = (ratio * minutesToHour * myArguments.userSettings.settings.wheelDiameterMillimeters * pi) / ((myArguments.userSettings.settings.motorPoles / 2) * 1000000);
    double speed = eRpm * ratioRpmSpeed;
    return double.parse((speed).toStringAsFixed(2));
  }
  double _kphToMph(double kph) {
    double speed = 0.621371 * kph;
    return double.parse((speed).toStringAsFixed(2));
  }
  double _calculateDistanceKm(double eCount) {
    double ratio = myArguments.userSettings.settings.pulleyMotorToothCount / myArguments.userSettings.settings.pulleyWheelToothCount;
    double ratioPulseDistance = (ratio * myArguments.userSettings.settings.wheelDiameterMillimeters * pi) / ((myArguments.userSettings.settings.motorPoles * 3) * 1000000);
    double distance = eCount * ratioPulseDistance;
    return double.parse((distance).toStringAsFixed(2));
  }
  double _kmToMile(double km) {
    double distance = 0.621371 * km;
    return double.parse((distance).toStringAsFixed(2));
  }
}
/// Simple time series data type.
class TimeSeriesESC {
  final DateTime time;
  final double voltage;
  final double tempMotor;
  double tempMotor2;
  double tempMotor3;
  double tempMotor4;
  final double tempMosfet;
  double tempMosfet2;
  double tempMosfet3;
  double tempMosfet4;
  final double dutyCycle;
  final double currentMotor;
  double currentMotor2;
  double currentMotor3;
  double currentMotor4;
  final double currentInput;
  double currentInput2;
  double currentInput3;
  double currentInput4;
  final double speed;
  final double distance;

  TimeSeriesESC({
      this.time,
      this.voltage,
      this.tempMotor,
      this.tempMotor2,
      this.tempMotor3,
      this.tempMotor4,
      this.tempMosfet,
      this.tempMosfet2,
      this.tempMosfet3,
      this.tempMosfet4,
      this.dutyCycle,
      this.currentMotor,
      this.currentMotor2,
      this.currentMotor3,
      this.currentMotor4,
      this.currentInput,
      this.currentInput2,
      this.currentInput3,
      this.currentInput4,
      this.speed,
      this.distance,
  });
}
/*
class CustomCircleSymbolRenderer extends charts.CircleSymbolRenderer {
  @override
  void paint(charts.ChartCanvas canvas, Rectangle<num> bounds, {List<int> dashPattern, Color fillColor, Color strokeColor, double strokeWidthPx}) {
    super.paint(canvas, bounds, dashPattern: dashPattern, fillColor: fillColor, strokeColor: strokeColor, strokeWidthPx: strokeWidthPx);
    canvas.drawRect(
        Rectangle(bounds.left - 5, bounds.top - 30, bounds.width + 10, bounds.height + 10),
        fill: Color.white
    );
    var textStyle = style.TextStyle();
    textStyle.color = charts.Color.black;
    textStyle.fontSize = 15;
    canvas.drawText(
        TextElement("1", style: textStyle),
        (bounds.left).round(),
        (bounds.top - 28).round()
    );
  }
}

 */