import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:freesk8_mobile/globalUtilities.dart';
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

import 'package:freesk8_mobile/escHelper.dart';

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
  List<Marker> mapMakers = new List();

  RideLogChartData currentSelection;

  PublishSubject<RideLogChartData> eventObservable = new PublishSubject();

  double calculateDistance(LatLng pointA, LatLng pointB){
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((pointB.latitude - pointA.latitude) * p)/2 +
        c(pointA.latitude * p) * c(pointB.latitude * p) *
            (1 - c((pointB.longitude - pointA.longitude) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  /// Create time series data for chart using ESC values
  static List<charts.Series<TimeSeriesESC, DateTime>> _createChartingData( List<TimeSeriesESC> values, List<int> escIDsInLog, int faultCodeCount ) {
      List<charts.Series<TimeSeriesESC, DateTime>> chartData = new List();

      /* Good example but not necessary
      if (faultCodeCount > 0) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Faults',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault.lighter,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.faultCode,
          data: values,
        )// Configure our custom bar target renderer for this series.
          ..setAttribute(charts.rendererIdKey, 'faultArea'));
      }
      */
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Battery',
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
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor3 Temp',
          colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMotor3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor4 Temp',
          colorFn: (_, __) => charts.MaterialPalette.gray.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMotor4,
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
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Mosfet3 Temp',
          colorFn: (_, __) => charts.MaterialPalette.deepOrange.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Mosfet4 Temp',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet4,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Duty Cycle',
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
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor3 Current',
          colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentMotor3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor4 Current',
          colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentMotor4,
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
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Input3 Current',
          colorFn: (_, __) => charts.MaterialPalette.pink.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentInput3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Input4 Current',
          colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentInput4,
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

  void updateFault(List<ESCFault> faults, int faultCode, int escID, DateTime dateTime) {
    faults.forEach((element) {
      if (element.faultCode == faultCode && element.escID == escID) {
        print("updated fault");
        ++element.faultCount;
        element.lastSeen = dateTime;
      }
    });
  }

  LatLng selectNearestGPSPoint(DateTime desiredTime, Map<DateTime, LatLng> gpsLatLngMap) {
    if (gpsLatLngMap[desiredTime] != null) {
      return gpsLatLngMap[desiredTime];
    }

    for (int i=0; i<gpsLatLngMap.length; ++i) {
      if (gpsLatLngMap.entries.elementAt(i).key.isAfter(desiredTime)) {
        print("nearest $desiredTime is ${gpsLatLngMap.entries.elementAt(i).key}");
        return gpsLatLngMap.entries.elementAt(i).value;
      }
    }

    print("selectNearestGPSPoint: Returning last point =(");
    return gpsLatLngMap.entries.last.value;
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
    List<TimeSeriesESC> escTimeSeriesList = new List<TimeSeriesESC>();
    Map<DateTime, TimeSeriesESC> escTimeSeriesMap = new Map();
    List<charts.Series> seriesList;
    int faultCodeCount = 0;
    double distanceStartPrimary;
    double distanceEndPrimary;

    // Fault tracking
    DateTime lastReportedFaultDt;
    List<charts.RangeAnnotationSegment> faultRangeAnnotations = new List();
    List<ESCFault> faultsObserved = new List();

    //Mapping
    thisRideLogEntries = new List<String>();
    _positionEntries = new List<LatLng>();
    Map<DateTime, LatLng> gpsLatLngMap = new Map();
    MapController _mapController = new MapController();

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

      if(entry.length > 1 && entry[0] != "header"){ // entry[0] = Time, entry[1] = Data type
        ///GPS position entry
        if(entry[1] == "gps") {
          //dt,gps,satellites,altitude,speed,latitude,longitude
          LatLng thisPosition = new LatLng(double.parse(entry[5]),double.parse(entry[6]));
          if ( _positionEntries.length > 0){
            gpsDistance += calculateDistance(_positionEntries.last, thisPosition);
          }
          _positionEntries.add(thisPosition);
          DateTime thisGPSTime = DateTime.tryParse(entry[0]);
          // Set the GPS start time if null
          gpsStartTime ??= thisGPSTime;
          // Set the GPS end time to the last message parsed
          gpsEndTime = thisGPSTime;
          double thisSpeed = double.tryParse(entry[4]);
          gpsAverageSpeed += thisSpeed;
          if (thisSpeed > gpsMaxSpeed) {gpsMaxSpeed = thisSpeed;}
          // Map DateTime to LatLng
          gpsLatLngMap[thisGPSTime] = thisPosition;
        }
        ///ESC Values
        else if (entry[1] == "esc" && entry.length >= 14) {
          //dt,esc,esc_id,voltage,motor_temp,esc_temp,duty_cycle,motor_current,battery_current,watt_hours,watt_hours_regen,e_rpm,e_distance,fault
          DateTime thisDt = DateTime.parse(entry[0]);
          int thisESCID = int.parse(entry[2]);

          if (!escIDsInLog.contains(thisESCID)) {
            print("Adding ESC ID $thisESCID to list of known ESC IDs in this data set");
            escIDsInLog.add(thisESCID);
          }

          // Create TimeSeriesESC object if needed
          if (escTimeSeriesMap[thisDt] == null){
            escTimeSeriesMap[thisDt] = TimeSeriesESC(time: thisDt, dutyCycle: 0);
          }

          // Populate TimeSeriesESC
          switch(escIDsInLog.indexOf(thisESCID)) {
            case 0:
            // Primary ESC
              escTimeSeriesMap[thisDt].voltage = double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMotor = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet = double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].dutyCycle = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentMotor = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput = double.tryParse(entry[8]);
              escTimeSeriesMap[thisDt].speed = myArguments.userSettings.settings.useImperial ? kmToMile(_calculateSpeedKph(double.tryParse(entry[11]))) : _calculateSpeedKph(double.tryParse(entry[11]));
              escTimeSeriesMap[thisDt].distance = myArguments.userSettings.settings.useImperial ? kmToMile(_calculateDistanceKm(double.tryParse(entry[12]))) : _calculateDistanceKm(double.tryParse(entry[12]));
              if (distanceStartPrimary == null) {
                distanceStartPrimary = escTimeSeriesMap[thisDt].distance;
                distanceEndPrimary = escTimeSeriesMap[thisDt].distance;
              } else {
                distanceEndPrimary = escTimeSeriesMap[thisDt].distance;
              }
              break;
            case 1:
            // Second ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor2 = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet2 = double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor2 = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput2 = double.tryParse(entry[8]);
              break;
            case 2:
            // Third ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor3 = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet3 = double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor3 = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput3 = double.tryParse(entry[8]);
              break;
            case 3:
            // Fourth ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor4 = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet4 = double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor4 = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput4 = double.tryParse(entry[8]);
              break;
            default:
            // Shit this was not supposed to happen
              print("Shit this was not supposed to happen. There appears to be a 5th ESC ID in the log file: $escIDsInLog");
              break;
          }

        }
        ///Fault codes
        else if (entry[1] == "err" || entry[1] == "fault") {
          //dt,err,fault_name,fault_code,esc_id
          // Count total fault messages
          ++faultCodeCount;

          // Parse time of event for tracking
          DateTime thisDt = DateTime.tryParse(entry[0]);
          int thisFaultCode = int.parse(entry[3]);
          int escID = int.parse(entry[4]);

          // Track faults for faults observed report
          bool isNew = true;
          faultsObserved.forEach((element) {
            if (element.faultCode == thisFaultCode && element.escID == escID) {
              print("this fault is old");
              isNew = false;
            }
          });
          if (isNew) {
            print("adding $thisFaultCode $escID");
            faultsObserved.add(new ESCFault(
              faultCode: thisFaultCode,
              escID: escID,
              faultCount: 1,
              firstSeen: thisDt,
              lastSeen: thisDt,
            ));
          } else {
            updateFault(faultsObserved, thisFaultCode, escID, thisDt);
          }

          // Create TimeSeriesESC object if needed
          if (escTimeSeriesMap[thisDt] == null){
            escTimeSeriesMap[thisDt] = TimeSeriesESC(time: thisDt, dutyCycle: 0);
          }
          // Store the fault code
          escTimeSeriesMap[thisDt].faultCode = thisFaultCode;

          // Add a map point if we have position data and the last reported fault didn't happen in the recent minute
          if (_positionEntries.length > 0 && (lastReportedFaultDt == null || thisDt.minute != lastReportedFaultDt.minute)) {
            // Add fault marker to map
            mapMakers.add(new Marker(
              width: 50.0,
              height: 50.0,
              point: _positionEntries.last,
              builder: (ctx) =>
              new Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
                child: GestureDetector(
                  onTap: (){
                    genericAlert(context, "Fault", Text("${mc_fault_code.values[thisFaultCode].toString().substring(14)} on ESC $escID at ${entry[0]}"), "It's ok?");
                  },
                  child: Image(image: AssetImage("assets/map_fault.png")),
                ),
              ),
            ));

            // Update lastReportedFaultDt
            lastReportedFaultDt = thisDt;
          }
        }
        // TODO: NOTE Early tester file format follows:
        else if(entry[1] == "position") {
          //DateTime, 'position', lat, lon, accuracy, altitude, speed, speedAccuracy
          LatLng thisPosition = new LatLng(double.parse(entry[2]),double.parse(entry[3]));
          if ( _positionEntries.length > 0){
            gpsDistance += calculateDistance(_positionEntries.last, thisPosition);
          }
          _positionEntries.add(thisPosition);
          DateTime thisGPSTime = DateTime.tryParse(entry[0]);
          // Set the GPS start time if null
          gpsStartTime ??= thisGPSTime;
          // Set the GPS end time to the last message parsed
          gpsEndTime = thisGPSTime;
          double thisSpeed = double.tryParse(entry[6]);
          gpsAverageSpeed += thisSpeed;
          if (thisSpeed > gpsMaxSpeed) {gpsMaxSpeed = thisSpeed;}
          // Map DateTime to LatLng
          gpsLatLngMap[thisGPSTime] = thisPosition;
        }
        else if (entry[1] == "values" && entry.length > 9) {
          //[2020-05-19T13:46:28.8, values, 12.9, -99.9, 29.0, 0.0, 0.0, 0.0, 0.0, 11884, 102]
          DateTime thisDt = DateTime.parse(entry[0]);
          int thisESCID = int.parse(entry[10]);

          if (!escIDsInLog.contains(thisESCID)) {
            print("Adding ESC ID $thisESCID to list of known ESC IDs in this data set");
            escIDsInLog.add(thisESCID);
          }

          // Create TimeSeriesESC object if needed
          if (escTimeSeriesMap[thisDt] == null){
            escTimeSeriesMap[thisDt] = TimeSeriesESC(time: thisDt, dutyCycle: 0);
          }

          // Populate TimeSeriesESC
          switch(escIDsInLog.indexOf(thisESCID)) {
            case 0:
            // Primary ESC
              escTimeSeriesMap[thisDt].voltage = double.tryParse(entry[2]);
              escTimeSeriesMap[thisDt].tempMotor = double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].dutyCycle = double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].speed = myArguments.userSettings.settings.useImperial ? kmToMile(_calculateSpeedKph(double.tryParse(entry[8]))) : _calculateSpeedKph(double.tryParse(entry[8]));
              escTimeSeriesMap[thisDt].distance = myArguments.userSettings.settings.useImperial ? kmToMile(_calculateDistanceKm(double.tryParse(entry[9]))) : _calculateDistanceKm(double.tryParse(entry[9]));
              if (distanceStartPrimary == null) {
                distanceStartPrimary = escTimeSeriesMap[thisDt].distance;
                distanceEndPrimary = escTimeSeriesMap[thisDt].distance;
              } else {
                distanceEndPrimary = escTimeSeriesMap[thisDt].distance;
              }
              break;
            case 1:
            // Second ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor2 = double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet2 = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].currentMotor2 = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput2 = double.tryParse(entry[7]);
              break;
            case 2:
            // Third ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor3 = double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet3 = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].currentMotor3 = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput3 = double.tryParse(entry[7]);
              break;
            case 3:
            // Fourth ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor4 = double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet4 = double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].currentMotor4 = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput4 = double.tryParse(entry[7]);
              break;
            default:
            // Shit this was not supposed to happen
              print("Shit this was not supposed to happen. There appears to be a 5th ESC ID in the log file: $escIDsInLog");
              break;
          }

        }
      }
    }
    print("rideLogViewer rideLogEntry iteration complete");
    escTimeSeriesMap.forEach((key, value) {
      escTimeSeriesList.add(value);
    });
    escTimeSeriesMap.clear();
    print("rideLogViewer escTimeSeriesList length is ${escTimeSeriesList.length}");
    //TODO: Reduce number of ESC points to keep things moving on phones
    //TODO: We will need to know the logging rate in the file
    while(escTimeSeriesList.length > 1200) {
      int pos = 0;
      for (int i=0; i<escTimeSeriesList.length; ++i, ++pos) {
        escTimeSeriesList[pos] = escTimeSeriesList[i++]; // Increment i
        // Check next record that we intend to remove for a fault
        if (i<escTimeSeriesList.length && escTimeSeriesList[i].faultCode != null) {
          print("Saving fault record");
          // Keep the next record because it contains a fault
          escTimeSeriesList[++pos] = escTimeSeriesList[i++];
        }
        // Skip some records if we have multiple ESCs of data
        else {
          switch(escIDsInLog.length) {
            case 2:
              ++i;
            break;
            case 4:
              i+=3;
            break;
          }
        }
      }
      escTimeSeriesList.removeRange(pos, escTimeSeriesList.length);
      print("rideLogViewer reduced escTimeSeriesList length to ${escTimeSeriesList.length}");
    }

    // Create fault range annotations for chart
    DateTime faultStart;
    //int faultCode;
    escTimeSeriesList.forEach((element) {
      if (element.faultCode != null && faultStart == null){
        faultStart = element.time;
        //faultCode = element.faultCode;
      }
      else if (element.faultCode == null && faultStart != null) {
        // Create a new annotation
        faultRangeAnnotations.add(new charts.RangeAnnotationSegment(
            faultStart,
            element.time,
            charts.RangeAnnotationAxisType.domain,
            //startLabel: '$faultCode',
            labelAnchor: charts.AnnotationLabelAnchor.end,
            color: charts.MaterialPalette.yellow.shadeDefault.lighter,
            // Override the default vertical direction for domain labels.
            labelDirection: charts.AnnotationLabelDirection.horizontal));
        // Clear faultStart for next possible annotation
        faultStart = null;
      }
    });

    if(_positionEntries.length > 1) {
      // Calculate GPS statistics
      gpsDuration = gpsEndTime.difference(gpsStartTime);
      gpsAverageSpeed /= _positionEntries.length;
      gpsAverageSpeed = doublePrecision(gpsAverageSpeed, 2);
      gpsDistanceStr = myArguments.userSettings.settings.useImperial ? "${doublePrecision(kmToMile(gpsDistance), 2)} miles" : "${doublePrecision(gpsDistance, 2)} km";
    }


    print("rideLogViewer creating chart data");
    // Create charting data from ESC time series data
    seriesList = _createChartingData(escTimeSeriesList, escIDsInLog, faultCodeCount);

    print("rideLogViewer creating map polyline from ${_positionEntries.length} points");
    //TODO: Reduce number of GPS points to keep things moving on phones
    while(_positionEntries.length > 1200) {
      int pos = 0;
      for (int i=0; i<_positionEntries.length; i+=2, ++pos) {
        _positionEntries[pos] = _positionEntries[i];
      }
      _positionEntries.removeRange(pos, _positionEntries.length);
      print("rideLogViewer reduced map polyline to ${_positionEntries.length} points");
    }
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
    TimeSeriesESC _tsESCMaxSpeed;
    TimeSeriesESC _tsESCMaxESCTemp;
    for(int i=0; i<escTimeSeriesList.length;++i) {
      if(escTimeSeriesList[i].speed != null && escTimeSeriesList[i].speed > _maxSpeed){
        _maxSpeed = escTimeSeriesList[i].speed;
        // Store time series moment for map point generation and data popup
        _tsESCMaxSpeed = escTimeSeriesList[i];
      }
      if (escTimeSeriesList[i].speed != null) {
        _avgSpeed += escTimeSeriesList[i].speed;
      }

      // Monitor Battery Current
      if(escTimeSeriesList[i].currentInput != null && escTimeSeriesList[i].currentInput > _maxAmpsBattery){
        _maxAmpsBattery = escTimeSeriesList[i].currentInput;
      }
      // Monitor Motor Current
      if(escTimeSeriesList[i].currentMotor != null && escTimeSeriesList[i].currentMotor > _maxAmpsMotor){
        _maxAmpsMotor = escTimeSeriesList[i].currentMotor;
      }
      // Monitor Max ESC Temp
      if(_tsESCMaxESCTemp == null || escTimeSeriesList[i].tempMosfet != null && escTimeSeriesList[i].tempMosfet > _tsESCMaxESCTemp.tempMosfet){
        // Store time series moment for map point generation and data popup
        _tsESCMaxESCTemp = escTimeSeriesList[i];
      }
    }
    // Add map marker for the hottest ESC temp
    if(_tsESCMaxESCTemp != null && gpsLatLngMap.length > 0) {
      // Add fault marker to map
      mapMakers.add(new Marker(
        width: 50.0,
        height: 50.0,
        point: selectNearestGPSPoint(_tsESCMaxESCTemp.time,gpsLatLngMap),
        builder: (ctx) =>
        new Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 25),
          child: GestureDetector(
            onTap: (){
              genericAlert(context, "Max ESC Temperature", Text("${_tsESCMaxESCTemp.tempMosfet} degrees at ${_tsESCMaxESCTemp.time.toIso8601String().substring(0,19)}"), "Hot dog!");
            },
            child: Image(image: AssetImage("assets/map_max_temp.png")),
          ),
        ),
      ));
    }
    // Add map marker for the fastest speed
    if(_tsESCMaxSpeed != null && gpsLatLngMap.length > 0) {
      // Add fault marker to map
      mapMakers.add(new Marker(
        width: 50.0,
        height: 50.0,
        point: selectNearestGPSPoint(_tsESCMaxSpeed.time,gpsLatLngMap),
        builder: (ctx) =>
        new Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 25),
          child: GestureDetector(
            onTap: (){
              genericAlert(context, "Top Speed", Text("${_tsESCMaxSpeed.speed} ${myArguments.userSettings.settings.useImperial ? "mph" : "kph"} at ${_tsESCMaxSpeed.time.toIso8601String().substring(0,19)}"), "Woo!");
            },
            child: Image(image: AssetImage("assets/map_top_speed.png")),
          ),
        ),
      ));
    }

    String distance = "N/A";
    Duration duration = Duration(seconds:0);
    if(escTimeSeriesList.length > 0) {
      double totalDistance = doublePrecision(distanceEndPrimary - distanceStartPrimary, 2);
      distance = myArguments.userSettings.settings.useImperial ? "$totalDistance miles" : "$totalDistance km";
      duration = escTimeSeriesList.last.time.difference(escTimeSeriesList.first.time);

      _avgSpeed /= escTimeSeriesList.length;
      _avgSpeed = doublePrecision(_avgSpeed, 2);
    }
    String maxSpeed = myArguments.userSettings.settings.useImperial ? "$_maxSpeed mph" : "$_maxSpeed kph";
    String avgSpeed = myArguments.userSettings.settings.useImperial ? "$_avgSpeed mph" : "$_avgSpeed kph";

    // Remove loading dialog since the user has no control
    if(_keyLoader.currentContext != null)
      Navigator.of(_keyLoader.currentContext,rootNavigator: true).pop();

    print("rideLogViewer statistics generated");

    // Add starting and ending map markers to the beginning of the mapMarkers list
    if (_positionEntries.length > 0) {
      mapMakers.insert(0,
          new Marker(
            width: 100.0,
            height: 100.0,
            point: _positionEntries.first,
            builder: (ctx) =>
            new Container(
              margin: EdgeInsets.fromLTRB(0, 0, 0, 50),
              child: new Image(image: AssetImage("assets/map_start.png")),
            ),
          )
      );

      mapMakers.insert(1, new Marker(
        width: 100.0,
        height: 100.0,
        point: _positionEntries.last,
        builder: (ctx) =>
        new Container(
          margin: EdgeInsets.fromLTRB(30, 0, 0, 50),
          child: new Image(image: AssetImage("assets/map_end.png")),
        ),
      ));
    }

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
      body: SafeArea(
        child: SlidingUpPanel(
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
                    escTimeSeriesList.length > 0 ? Text(maxSpeed) : Text(gpsMaxSpeed.toString())
                  ],),
                  SizedBox(width: 10,),
                  Column(children: <Widget>[
                    Text("Average Speed"),
                    Icon(Icons.trending_up),
                    escTimeSeriesList.length > 0 ? Text(avgSpeed) : Text(gpsAverageSpeed.toString())
                  ],),
                  SizedBox(width: 10,),
                  Column(children: <Widget>[
                    Text("Distance Traveled"),
                    Icon(Icons.place),
                    escTimeSeriesList.length > 0 ? Text(distance) : Text(gpsDistanceStr)
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
                    escTimeSeriesList.length > 0 ?
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
                  GestureDetector(
                    onTap: () {
                      String shareData = "";
                      List<Widget> children = new List();
                      faultsObserved.forEach((element) {
                        children.add(Text(element.toString()));
                        children.add(Text(""));
                        shareData += element.toString() + "\n\n";
                      });
                      //genericAlert(context, "Faults observed", Column(children: children), "OK");
                      genericConfirmationDialog(context, FlatButton(
                        child: Text("Copy / Share"),
                        onPressed: () {
                          Share.text('Faults observed', shareData, 'text/plain');
                        },
                      ), FlatButton(
                        child: Text("Close"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ), "Faults observed", Column(children: children, mainAxisSize: MainAxisSize.min,));
                    },
                    child: Column(children: <Widget>[
                      Text("Fault codes"),
                      Icon(Icons.error_outline, color: Colors.red,),
                      Text("$faultCodeCount fault(s)"),
                    ],),
                  )
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
                        genericConfirmationDialog(
                            context,
                            FlatButton(
                              child: Text("Cancel"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            FlatButton(
                              child: Text("Delete"),
                              onPressed: () async {
                                //Remove from Database
                                await DatabaseAssistant.dbRemoveLog(myArguments.logFilePath);
                                //Remove from Filesystem
                                await FileManager.eraseLogFile(myArguments.logFilePath);
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                            ),
                            "Delete file?",
                            Text("Are you sure you want to permanently erase this log?")
                        );
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

                  _positionEntries.length > 0 ?
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: new MapOptions(
                        center: _positionEntries.first,
                        zoom: 13.0,
                      ),
                      layers: [
                        new TileLayerOptions(
                            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: ['a', 'b', 'c']
                        ),

                        new PolylineLayerOptions(
                            polylines: [routePolyLine]
                        ),

                        new MarkerLayerOptions(
                            markers: mapMakers

                        ),
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

                      //NOTE: Customizing the domainAxis tickFormatterSpec causes PanAndZoomBehavior to stop working, WHY?
                      domainAxis: new charts.DateTimeAxisSpec(
                          tickFormatterSpec: new charts.AutoDateTimeTickFormatterSpec(
                            minute: new charts.TimeFormatterSpec(
                              format: 'HH:mm', // or even HH:mm here too
                              transitionFormat: 'HH:mm',
                            ),
                          )
                      ),

                      behaviors: [
                        //TODO: "PanAndZoomBehavior()" causes "Exception caught by gesture" : "Bad state: No element" but works
                        //TODO: charts.PointRenderer() line 255. Add: if (!componentBounds.containsPoint(point)) continue;
                        //TODO: https://github.com/janstol/charts/commit/899476a06875422aafde82376cdf57ba0c2e65a5
                        //NOTE: disabled due to lack of optimization: new charts.PanAndZoomBehavior(),
                        new charts.SeriesLegend(
                            desiredMaxColumns:3,
                            position: charts.BehaviorPosition.bottom,
                            cellPadding: EdgeInsets.all(4.0),
                            defaultHiddenSeries: ['Duty Cycle', 'Motor2 Temp', 'Motor2 Current', 'Motor Current', 'Motor Temp']
                        ),

                        // Define one domain and two measure annotations configured to render
                        // labels in the chart margins.
                        new charts.RangeAnnotation(faultRangeAnnotations)
                      ],
                      /// Using selection model to generate value overlay
                      selectionModels: [
                        charts.SelectionModelConfig(
                            changedListener: (charts.SelectionModel model) {
                              if(model.hasDatumSelection) {
                                currentSelection = new RideLogChartData(model.selectedDatum.first.datum.time,  model.selectedDatum.first.datum);
                                eventObservable.add(currentSelection);
                                eventObservable.publish();
                                // Set the map center to this position in time
                                if (gpsLatLngMap.length > 0) {
                                  _mapController.move(selectNearestGPSPoint(model.selectedDatum.first.datum.time, gpsLatLngMap), _mapController.zoom);
                                }
                              }
                            }
                        )

                      ],

                      customSeriesRenderers: [
                        new charts.LineRendererConfig(
                          // ID used to link series to this renderer.
                            customRendererId: 'faultArea',
                            includeArea: faultCodeCount > 0,
                            stacked: true),
                      ]

                    ),


                    //TODO: would be cool to position this near the user input
                    Positioned(
                      bottom: 21,
                      right: 5,
                      child: RideLogViewChartOverlay(eventObservable: eventObservable,),
                    ),


                  ],),),

                  SizedBox(height: 264 + MediaQuery.of(context).padding.bottom), //This is the space needed for slide drawer on the bottom, do not remove

                ],
              ),
            ),
          ),


        ),
      )
    );
  }

  double _calculateSpeedKph(double eRpm) {
    double ratio = 1.0 / myArguments.userSettings.settings.gearRatio;
    int minutesToHour = 60;
    double ratioRpmSpeed = (ratio * minutesToHour * myArguments.userSettings.settings.wheelDiameterMillimeters * pi) / ((myArguments.userSettings.settings.motorPoles / 2) * 1000000);
    double speed = eRpm * ratioRpmSpeed;
    return double.parse((speed).toStringAsFixed(2));
  }

  double _calculateDistanceKm(double eCount) {
    double ratio = 1.0 / myArguments.userSettings.settings.gearRatio;
    double ratioPulseDistance = (ratio * myArguments.userSettings.settings.wheelDiameterMillimeters * pi) / ((myArguments.userSettings.settings.motorPoles * 3) * 1000000);
    double distance = eCount * ratioPulseDistance;
    return double.parse((distance).toStringAsFixed(2));
  }

}
/// Simple time series data type.
class TimeSeriesESC {
  final DateTime time;
  double voltage;
  double tempMotor;
  double tempMotor2;
  double tempMotor3;
  double tempMotor4;
  double tempMosfet;
  double tempMosfet2;
  double tempMosfet3;
  double tempMosfet4;
  double dutyCycle;
  double currentMotor;
  double currentMotor2;
  double currentMotor3;
  double currentMotor4;
  double currentInput;
  double currentInput2;
  double currentInput3;
  double currentInput4;
  double speed;
  double distance;
  int faultCode;

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
      this.faultCode,
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