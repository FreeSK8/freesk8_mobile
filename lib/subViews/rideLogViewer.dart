import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import '../globalUtilities.dart';
import '../widgets/rideLogViewChartOverlay.dart';
import 'package:latlong/latlong.dart';
import '../components/databaseAssistant.dart';
import '../components/fileManager.dart';

import 'package:charts_flutter/flutter.dart' as charts;

import '../components/userSettings.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart';

import '../hardwareSupport/escHelper/escHelper.dart';
import '../hardwareSupport/escHelper/dataTypes.dart';

class RideLogViewerArguments {
  final UserSettings userSettings;
  final LogInfoItem logFileInfo;
  final FileImage imageBoardAvatar;

  RideLogViewerArguments(this.logFileInfo,this.userSettings, this.imageBoardAvatar);
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
  MapController _mapController = new MapController();
  List<Marker> mapMakers = [];

  RideLogChartData currentSelection;

  PublishSubject<RideLogChartData> eventObservable = new PublishSubject();

  /// Create time series data for chart using ESC values
  static List<charts.Series<TimeSeriesESC, DateTime>> _createChartingData( List<TimeSeriesESC> values, List<int> escIDsInLog, int faultCodeCount, bool imperialDistance ) {
      List<charts.Series<TimeSeriesESC, DateTime>> chartData = [];

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
        id: 'MotorTemp',
        displayName: 'Motor Temp',
        colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.tempMotor,
        data: values,
      ));

      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor2Temp',
          displayName: 'Motor2 Temp',
          colorFn: (_, __) => charts.MaterialPalette.gray.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMotor2,
          data: values,
        ));
      }
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor3Temp',
          displayName: 'Motor3 Temp',
          colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMotor3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor4Temp',
          displayName: 'Motor4 Temp',
          colorFn: (_, __) => charts.MaterialPalette.gray.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMotor4,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'MosfetTemp',
        displayName: 'Mosfet Temp',
        colorFn: (_, __) => charts.MaterialPalette.deepOrange.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet,
        data: values,
      ));
      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Mosfet2Temp',
          displayName: 'Mosfet2 Temp',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet2,
          data: values,
        ));
      }
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Mosfet3Temp',
          displayName: 'Mosfet3 Temp',
          colorFn: (_, __) => charts.MaterialPalette.deepOrange.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Mosfet4Temp',
          displayName: 'Mosfet4 Temp',
          colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.tempMosfet4,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'DutyCycle',
        displayName: 'Duty Cycle',
        colorFn: (_, __) => charts.MaterialPalette.green.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.dutyCycle * 100.0,
        data: values,
      ));
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'MotorCurrent',
        displayName: 'Motor Current',
        colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.currentMotor,
        data: values,
      ));
      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor2Current',
          displayName: 'Motor2 Current',
          colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentMotor2,
          data: values,
        ));
      }
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor3Current',
          displayName: 'Motor3 Current',
          colorFn: (_, __) => charts.MaterialPalette.purple.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentMotor3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Motor4Current',
          displayName: 'Motor4 Current',
          colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentMotor4,
          data: values,
        ));
      }
      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'InputCurrent',
        displayName: 'Input Current',
        colorFn: (_, __) => charts.MaterialPalette.pink.shadeDefault,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.currentInput,
        data: values,
      ));
      if (escIDsInLog.length > 1) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Input2Current',
          displayName: 'Input2 Current',
          colorFn: (_, __) => charts.MaterialPalette.cyan.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentInput2,
          data: values,
        ));
      }
      if (escIDsInLog.length > 3) {
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Input3Current',
          displayName: 'Input3 Current',
          colorFn: (_, __) => charts.MaterialPalette.pink.shadeDefault,
          domainFn: (TimeSeriesESC escData, _) => escData.time,
          measureFn: (TimeSeriesESC escData, _) => escData.currentInput3,
          data: values,
        ));
        chartData.add(charts.Series<TimeSeriesESC, DateTime>(
          id: 'Input4Current',
          displayName: 'Input4 Current',
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

      chartData.add(charts.Series<TimeSeriesESC, DateTime>(
        id: 'Consumption',
        displayName: 'Wh/${imperialDistance ? "mile" : "km"}',
        colorFn: (_, __) => charts.MaterialPalette.yellow.shadeDefault.lighter,
        domainFn: (TimeSeriesESC escData, _) => escData.time,
        measureFn: (TimeSeriesESC escData, _) => escData.consumption,
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
        //globalLogger.d("updated fault");
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
        globalLogger.d("nearest $desiredTime is ${gpsLatLngMap.entries.elementAt(i).key}");
        return gpsLatLngMap.entries.elementAt(i).value;
      }
    }

    globalLogger.d("selectNearestGPSPoint: Returning last point =(");
    return gpsLatLngMap.entries.last.value;
  }

  void _buildDialog(String title, TimeSeriesESC eventData, DateTime logStart, bool useFahrenheit) {
    double _batteryAmps = eventData.currentInput;
    if(eventData.currentInput != null && eventData.currentInput2 != null){
      _batteryAmps = doublePrecision(eventData.currentInput + eventData.currentInput2, 1);
    }
    if(eventData.currentInput != null && eventData.currentInput2 != null && eventData.currentInput3 != null && eventData.currentInput4 != null){
      _batteryAmps = doublePrecision(eventData.currentInput + eventData.currentInput2 + eventData.currentInput3 + eventData.currentInput4, 1);
    }

    List<TableRow> tableChildren = [];
    tableChildren.add(TableRow(children: [
      Icon(Icons.watch),
      Text("${prettyPrintDuration(eventData.time.difference(logStart))}",
          textAlign: TextAlign.center)]));
    tableChildren.add(TableRow(children: [
      Transform.rotate(angle: 3.14159, child: Icon(Icons.av_timer),),
      Text("${eventData.speed}${myArguments.userSettings.settings.useImperial ? "mph" : "kph"}",
          textAlign: TextAlign.center)]));
    tableChildren.add(TableRow(children: [
      Icon(Icons.rotate_right),
      Text("Duty ${(eventData.dutyCycle * 100).toInt()}%",
          textAlign: TextAlign.center)]));
    tableChildren.add(TableRow(children: [
      Icon(Icons.battery_charging_full),
      Text("${_batteryAmps}A",
          textAlign: TextAlign.center) ]));
    tableChildren.add(TableRow(children: [
      Icon(Icons.slow_motion_video),
      Text("M1 ${eventData.currentMotor}A",
          textAlign: TextAlign.center)]));
    if (eventData.currentMotor2 != null) tableChildren.add(TableRow(children: [
      Icon(Icons.slow_motion_video),
      Text("M2 ${eventData.currentMotor2}A",
          textAlign: TextAlign.center)]));
    if (eventData.currentMotor3 != null) tableChildren.add(TableRow(children: [
      Icon(Icons.slow_motion_video),
      Text("M3 ${eventData.currentMotor3}A",
          textAlign: TextAlign.center)]));
    if (eventData.currentMotor4 != null) tableChildren.add(TableRow(children: [
      Icon(Icons.slow_motion_video),
      Text("M4 ${eventData.currentMotor4}A",
          textAlign: TextAlign.center)]));
    tableChildren.add(TableRow(children: [
      Icon(Icons.local_fire_department),
      Text("ESC1 ${eventData.tempMosfet}°${useFahrenheit ? "F" : "C"}",
          textAlign: TextAlign.center)]));
    if (eventData.tempMosfet2 != null) tableChildren.add(TableRow(children: [
      Icon(Icons.local_fire_department),
      Text("ESC2 ${eventData.tempMosfet2}°${useFahrenheit ? "F" : "C"}",
          textAlign: TextAlign.center)]));
    if (eventData.tempMosfet3 != null) tableChildren.add(TableRow(children: [
      Icon(Icons.local_fire_department),
      Text("ESC3 ${eventData.tempMosfet3}°${useFahrenheit ? "F" : "C"}",
          textAlign: TextAlign.center)]));
    if (eventData.tempMosfet4 != null) tableChildren.add(TableRow(children: [
      Icon(Icons.local_fire_department),
      Text("ESC4 ${eventData.tempMosfet4}°${useFahrenheit ? "F" : "C"}",
          textAlign: TextAlign.center)]));
    if (eventData.faultCode != null) tableChildren.add(TableRow(children: [
      Icon(Icons.warning_amber_outlined),
      Text("${mc_fault_code.values[eventData.faultCode].toString().substring(14)}",
          textAlign: TextAlign.center)]));

    genericAlert(context, title, Column(
      children: [
        Text("${eventData.time.toIso8601String().substring(0,19)}"),
        SizedBox(height: 10),
        Table(
            columnWidths: {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
            },
          children: tableChildren
        )
      ],
    ), "OK");
  }

  @override
  Widget build(BuildContext context) {
    globalLogger.d("Build: rideLogViewer");

    eventObservable.add(currentSelection);

    //GPS calculations
    double gpsDistance = 0;
    double gpsAverageSpeed = 0;
    double gpsMaxSpeed = 0;
    DateTime gpsStartTime;
    DateTime gpsEndTime;
    String gpsDistanceStr = "N/A";

    //Charting and data
    List<TimeSeriesESC> escTimeSeriesList = [];
    Map<DateTime, TimeSeriesESC> escTimeSeriesMap = new Map();
    List<charts.Series> seriesList;
    int faultCodeCount = 0;
    double distanceStartPrimary;
    double distanceEndPrimary;
    double wattHoursStartPrimary;
    double wattHoursRegenStartPrimary;
    int outOfOrderESCRecords = 0;
    int outOfOrderGPSRecords = 0;
    String outOfOrderESCFirstMessage;
    String outOfOrderGPSFirstMessage;
    bool _useGPSData = false;

    // Fault tracking
    DateTime lastReportedFaultDt;
    List<charts.RangeAnnotationSegment> faultRangeAnnotations = [];
    List<ESCFault> faultsObserved = [];

    //Mapping
    thisRideLogEntries = [];
    _positionEntries = [];
    Map<DateTime, LatLng> gpsLatLngMap = new Map();
    Map<DateTime, LatLng> gpsLatLngRejectMap = new Map();

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container();
    }

    // Allow user to prefer GPS distance and speed vs the ESC
    _useGPSData = myArguments.userSettings.settings.useGPSData;

    //Load log file from received arguments
    if( thisRideLog == "" ) {
      FileManager.openLogFile(myArguments.logFileInfo.logFilePath).then((value){
        //globalLogger.wtf("opening log file");
        setState(() {
          thisRideLog = value;
        });
      }).onError((error, stackTrace){
        globalLogger.e("rideLogViewer: openLogFile Exception: ${error.toString()}");
        print(stackTrace);
      });
      return Container(); //NOTE: after setState with file contents we'll show the widget tree
    }

    // Parse lines of log file as CSV
    List<int> escIDsInLog = [];
    thisRideLogEntries = thisRideLog.split("\n");
    globalLogger.d("rideLogViewer rideLogEntry count: ${thisRideLog.length}");
    int fileLoggingRateHz = 1;
    int fileMultiESCMode = 0;
    for(int i=0; i<thisRideLogEntries.length; ++i) {
      final entry = thisRideLogEntries[i].split(",");

      //TODO: Parse out header entries. We now have good information here so we don't have to leverage userSettings
      if(entry.length > 1){ // entry[0] = Time, entry[1] = Data type
        if (entry[0] == "header") {
          if (entry[1] == "esc_hz") {
            fileLoggingRateHz = int.parse(entry[2]);
            globalLogger.d("Parsed: ${thisRideLogEntries[i]}");
          }
          if (entry[1] == "multi_esc_mode") {
            fileMultiESCMode = int.parse(entry[2]);
            globalLogger.d("Parsed: ${thisRideLogEntries[i]}");
          }
        }
        ///GPS position entry
        else if(entry[1] == "gps" && entry.length >= 6) {
          //dt,gps,satellites,altitude,speed,latitude,longitude
          LatLng thisPosition = new LatLng(double.parse(entry[5]),double.parse(entry[6]));
          if ( _positionEntries.length > 0){
            gpsDistance += calculateGPSDistance(_positionEntries.last, thisPosition);
          }
          _positionEntries.add(thisPosition);
          DateTime thisGPSTime = DateTime.tryParse(entry[0]).add((DateTime.now().timeZoneOffset));
          // Sanity check on GPS time please
          if (thisGPSTime.isBefore(DateTime(2000))) {
            globalLogger.w("rideLogViewer:thisRideLogEntry: GPS DateTime was out of bounds! ${entry[0]} -> ${thisGPSTime.toString()}");
            continue;
          }
          // Set the GPS start time if null
          gpsStartTime ??= thisGPSTime;
          // Set the GPS end time to the last message parsed
          gpsEndTime = thisGPSTime;
          double thisSpeed = double.tryParse(entry[4]);
          gpsAverageSpeed += thisSpeed;
          if (thisSpeed > gpsMaxSpeed) {gpsMaxSpeed = thisSpeed;}

          // Watch for OoO records
          if (gpsLatLngMap.isNotEmpty && gpsLatLngMap.keys.last.isAfter(thisGPSTime)) {
            ++outOfOrderGPSRecords;
            outOfOrderGPSFirstMessage ??= "GPS out of order: Now $thisGPSTime Previous ${gpsLatLngMap.keys.last}";
            //globalLogger.wtf("GPS out of order: Now $thisGPSTime Previous ${gpsLatLngMap.keys.last}; Skipping record");
            gpsLatLngRejectMap[thisGPSTime] = thisPosition;
            continue;
          }

          if (gpsLatLngMap[thisGPSTime] != null) {
            globalLogger.w("GPS timeslot already reported: $thisGPSTime value ${gpsLatLngMap[thisGPSTime]} replaced with $thisPosition");
          }
          // Map DateTime to LatLng
          gpsLatLngMap[thisGPSTime] = thisPosition;

          if (myArguments.userSettings.settings.useGPSData) {
            // Create TimeSeriesESC object if needed
            if (escTimeSeriesMap[thisGPSTime] == null){
              escTimeSeriesMap[thisGPSTime] = TimeSeriesESC(time: thisGPSTime, dutyCycle: 0);
            }
            escTimeSeriesMap[thisGPSTime].speed = myArguments.userSettings.settings.useImperial ? kmToMile(thisSpeed) : thisSpeed;
          }
        }
        ///ESC Values
        else if (entry[1] == "esc" && entry.length >= 14) {
          //dt,esc,esc_id,voltage,motor_temp,esc_temp,duty_cycle,motor_current,battery_current,watt_hours,watt_hours_regen,e_rpm,e_distance,fault
          DateTime thisDt = DateTime.parse(entry[0]).add((DateTime.now().timeZoneOffset));
          int thisESCID = int.parse(entry[2]);

          // Watch for OoO records, Validating by the second (subtract milliseconds)
          if (escTimeSeriesMap.isNotEmpty && escTimeSeriesMap.keys.last.subtract(Duration(milliseconds: escTimeSeriesMap.keys.last.millisecond)).isAfter(thisDt)) {
            ++outOfOrderESCRecords;
            outOfOrderESCFirstMessage ??= "ESC out of order: $thisDt Previous ${escTimeSeriesMap.keys.last}";
            //globalLogger.wtf("ESC out of order: Now $thisDt Previous ${escTimeSeriesMap.keys.last}");
          }

          if (!escIDsInLog.contains(thisESCID)) {
            globalLogger.d("Adding ESC ID $thisESCID to list of known ESC IDs in this data set");
            escIDsInLog.add(thisESCID);
          }

          // Create TimeSeriesESC object at thisDt if needed
          if (escTimeSeriesMap[thisDt] == null) {
            escTimeSeriesMap[thisDt] = TimeSeriesESC(time: thisDt, dutyCycle: 0);
          }
          // If TimeSeriesESC exists at thisDt we (((((might be))))) looking at multiple samples per second
          else {
            // Check if this is ESC2,3,4 and if ESC has data at time slot already
            bool incrementTimeSlot = true; // Assume we are to increment the time slot
            // If thisESCID's data has not been populated for thisDt set incrementTimeSlot to false
            switch(escIDsInLog.indexOf(thisESCID)) {
              case 0:
                if (escTimeSeriesMap[thisDt].tempMosfet == null) incrementTimeSlot = false;
                break;
              case 1:
                if (escTimeSeriesMap[thisDt].tempMosfet2 == null) incrementTimeSlot = false;
                break;
              case 2:
                if (escTimeSeriesMap[thisDt].tempMosfet3 == null) incrementTimeSlot = false;
                break;
              case 3:
                if (escTimeSeriesMap[thisDt].tempMosfet4 == null) incrementTimeSlot = false;
                break;
            }
            // Increment the sub second timestamp by the logging rate
            if (incrementTimeSlot == true) {
              // Add milliseconds to >1Hz ESC data
              while(escTimeSeriesMap[thisDt] != null) {
                thisDt = thisDt.add(Duration(milliseconds: 1000~/fileLoggingRateHz < 1000 ? 1000~/fileLoggingRateHz : 20));
                if (escTimeSeriesMap[thisDt] == null) {
                  escTimeSeriesMap[thisDt] = TimeSeriesESC(time: thisDt, dutyCycle: 0);
                  break;
                }
              }
            }
          } // TimeSeriesESC ready at thisDt

          // Populate TimeSeriesESC
          switch(escIDsInLog.indexOf(thisESCID)) {
            case 0:
            // Primary ESC
              escTimeSeriesMap[thisDt].voltage = double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMotor = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[5]), places: 1) : double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].dutyCycle = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentMotor = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput = double.tryParse(entry[8]);
              if (!myArguments.userSettings.settings.useGPSData) escTimeSeriesMap[thisDt].speed = myArguments.userSettings.settings.useImperial ? kmToMile(_calculateSpeedKph(double.tryParse(entry[11]))) : _calculateSpeedKph(double.tryParse(entry[11]));
              escTimeSeriesMap[thisDt].distance = myArguments.userSettings.settings.useImperial ? kmToMile(_calculateDistanceKm(double.tryParse(entry[12]))) : _calculateDistanceKm(double.tryParse(entry[12]));
              if (distanceStartPrimary == null) {
                distanceStartPrimary = escTimeSeriesMap[thisDt].distance;
                distanceEndPrimary = escTimeSeriesMap[thisDt].distance;
              } else {
                distanceEndPrimary = escTimeSeriesMap[thisDt].distance;
              }

              // Compute consumption over time
              //TODO: this is only for a single ESC. This may get complicated for dual/quad. Multiplying for now
              double wattHoursNow = double.tryParse(entry[9]);
              double wattHoursRegenNow = double.tryParse(entry[10]);
              wattHoursStartPrimary ??= wattHoursNow;
              wattHoursRegenStartPrimary ??= wattHoursRegenNow;

              double wattHours = (wattHoursNow - wattHoursStartPrimary) - (wattHoursRegenNow - wattHoursRegenStartPrimary);
              double totalDistance = distanceEndPrimary - distanceStartPrimary;
              double consumption = wattHours / totalDistance;
              if (consumption.isNaN || consumption.isInfinite || totalDistance < 0.25) {
                escTimeSeriesMap[thisDt].consumption = null;
              } else escTimeSeriesMap[thisDt].consumption = doublePrecision(consumption, 2);
              //if (totalDistance < 0.9)
                //print("whNow $wattHoursNow whStart $wattHoursStartPrimary whRegenNow $wattHoursRegenNow whRegenStart $wattHoursRegenStartPrimary wh $wattHours td $totalDistance consumption $consumption");

              break;
            case 1:
            // Second ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor2 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet2 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[5]), places: 1) : double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor2 = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput2 = double.tryParse(entry[8]);
              break;
            case 2:
            // Third ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor3 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet3 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[5]), places: 1) : double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor3 = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput3 = double.tryParse(entry[8]);
              break;
            case 3:
            // Fourth ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor4 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].tempMosfet4 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[5]), places: 1) : double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor4 = double.tryParse(entry[7]);
              escTimeSeriesMap[thisDt].currentInput4 = double.tryParse(entry[8]);
              break;
            default:
            // Shit this was not supposed to happen
              globalLogger.wtf("Shit this was not supposed to happen. There appears to be a 5th ESC ID in the log file: $escIDsInLog");
              break;
          }

        }
        ///Fault codes
        else if (entry[1] == "err" || entry[1] == "fault" && entry.length >= 5) {
          //dt,err,fault_name,fault_code,esc_id
          // Count total fault messages
          ++faultCodeCount;

          // Parse time of event for tracking
          DateTime thisDt = DateTime.tryParse(entry[0]).add((DateTime.now().timeZoneOffset));
          int thisFaultCode = int.parse(entry[3]);
          int escID = int.parse(entry[4]);

          // Track faults for faults observed report
          bool isNew = true;
          faultsObserved.forEach((element) {
            if (element.faultCode == thisFaultCode && element.escID == escID) {
              //globalLogger.d("this fault is old");
              isNew = false;
            }
          });
          if (isNew) {
            //globalLogger.d("adding $thisFaultCode $escID");
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
                    TimeSeriesESC _tsFault = escTimeSeriesMap[thisDt];
                    _buildDialog("Fault", _tsFault, escTimeSeriesMap.values.first.time, myArguments.userSettings.settings.useFahrenheit);
                  },
                  child: Image(image: AssetImage("assets/map_fault.png")),
                ),
              ),
            ));

            // Update lastReportedFaultDt
            lastReportedFaultDt = thisDt;
          }
        }
        //TODO: NOTE: Early beta tester file format follows:
        //TODO: We'll want to dispose of position/values entries eventually
        else if(entry[1] == "position" && entry.length >= 6) {
          //DateTime, 'position', lat, lon, accuracy, altitude, speed, speedAccuracy
          LatLng thisPosition = new LatLng(double.parse(entry[2]),double.parse(entry[3]));
          if ( _positionEntries.length > 0){
            gpsDistance += calculateGPSDistance(_positionEntries.last, thisPosition);
          }
          _positionEntries.add(thisPosition);
          DateTime thisGPSTime = DateTime.tryParse(entry[0]).add((DateTime.now().timeZoneOffset));
          // Set the GPS start time if null
          gpsStartTime ??= thisGPSTime;
          // Set the GPS end time to the last message parsed
          gpsEndTime = thisGPSTime;
          double thisSpeed = double.tryParse(entry[6]);
          gpsAverageSpeed += thisSpeed;
          if (thisSpeed > gpsMaxSpeed) {gpsMaxSpeed = thisSpeed;}
          // Map DateTime to LatLng
          gpsLatLngMap[thisGPSTime] = thisPosition;

          if (myArguments.userSettings.settings.useGPSData) {
            // Create TimeSeriesESC object if needed
            if (escTimeSeriesMap[thisGPSTime] == null){
              escTimeSeriesMap[thisGPSTime] = TimeSeriesESC(time: thisGPSTime, dutyCycle: 0);
            }
            escTimeSeriesMap[thisGPSTime].speed = myArguments.userSettings.settings.useImperial ? kmToMile(thisSpeed) : thisSpeed;
          }
        }
        else if (entry[1] == "values" && entry.length >= 10) {
          //[2020-05-19T13:46:28.8, values, 12.9, -99.9, 29.0, 0.0, 0.0, 0.0, 0.0, 11884, 102]
          DateTime thisDt = DateTime.parse(entry[0]).add((DateTime.now().timeZoneOffset));
          int thisESCID = int.parse(entry[10]);

          if (!escIDsInLog.contains(thisESCID)) {
            globalLogger.d("Adding ESC ID $thisESCID to list of known ESC IDs in this data set");
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
              escTimeSeriesMap[thisDt].tempMotor = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[3]), places: 1) : double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].dutyCycle = double.tryParse(entry[5]);
              escTimeSeriesMap[thisDt].currentMotor = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput = double.tryParse(entry[7]);
              if (!myArguments.userSettings.settings.useGPSData) escTimeSeriesMap[thisDt].speed = myArguments.userSettings.settings.useImperial ? kmToMile(_calculateSpeedKph(double.tryParse(entry[8]))) : _calculateSpeedKph(double.tryParse(entry[8]));
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
              escTimeSeriesMap[thisDt].tempMotor2 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[3]), places: 1) : double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet2 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].currentMotor2 = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput2 = double.tryParse(entry[7]);
              break;
            case 2:
            // Third ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor3 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[3]), places: 1) : double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet3 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].currentMotor3 = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput3 = double.tryParse(entry[7]);
              break;
            case 3:
            // Fourth ESC in multiESC configuration
              escTimeSeriesMap[thisDt].tempMotor4 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[3]), places: 1) : double.tryParse(entry[3]);
              escTimeSeriesMap[thisDt].tempMosfet4 = myArguments.userSettings.settings.useFahrenheit ? cToF(double.tryParse(entry[4]), places: 1) : double.tryParse(entry[4]);
              escTimeSeriesMap[thisDt].currentMotor4 = double.tryParse(entry[6]);
              escTimeSeriesMap[thisDt].currentInput4 = double.tryParse(entry[7]);
              break;
            default:
            // Shit this was not supposed to happen
              globalLogger.e("Shit this was not supposed to happen. There appears to be a 5th ESC ID in the log file: $escIDsInLog");
              break;
          }

        }
      }
    } // escTimeSeriesMap created from thisRideLogEntries
    globalLogger.d("rideLogViewer rideLogEntry iteration complete");

    // Notify debugger if OoO records were observed in this file
    if (outOfOrderESCRecords > 0){
      globalLogger.w("$outOfOrderESCRecords ESC records were out of order: First notice: $outOfOrderESCFirstMessage");
    }
    if (outOfOrderGPSRecords > 0){
      globalLogger.w("$outOfOrderGPSRecords GPS records were out of order: First notice: $outOfOrderGPSFirstMessage");
    }

    // Convert ESC data map into a list
    // Sorting in case we have experienced out of order records
    var sortedESCMapKeysTEST = escTimeSeriesMap.keys.toList()..sort();
    sortedESCMapKeysTEST.forEach((element) {
      var value = escTimeSeriesMap[element];
      // Multiply consumption by number of ESCs for smooth chart line
      //TODO: This is not the most accurate way to represent consumption for multiple ESCs
      if(value.consumption != null) {
        value.consumption *= escIDsInLog.length;
      }
      // Add to list
      escTimeSeriesList.add(value);
    });
    //TODO: not clearing because I want to color a polyline... escTimeSeriesMap.clear();
    globalLogger.d("rideLogViewer escTimeSeriesList length is ${escTimeSeriesList.length}");

    ///Generate ride statistics
    double _maxSpeed = 0.0;
    double _avgSpeed = 0.0;
    double _avgSpeedMoving = 0.0;
    int _avgSpeedNonZeroEntries = 0;
    double _maxAmpsBattery = 0.0;
    double _maxAmpsMotor = 0.0;
    TimeSeriesESC _tsESCMaxSpeed;
    double _maxESCTempObserved = -1.0;
    TimeSeriesESC _tsESCMaxESCTemp;
    TimeSeriesESC _tsESCMaxBatteryAmps;
    TimeSeriesESC _tsESCMaxMotorAmps;
    for(int i=0; i<escTimeSeriesList.length;++i) {
      if(escTimeSeriesList[i].speed != null && escTimeSeriesList[i].speed > _maxSpeed){
        _maxSpeed = escTimeSeriesList[i].speed;
        // Store time series moment for map point generation and data popup
        _tsESCMaxSpeed = escTimeSeriesList[i];
      }
      if (escTimeSeriesList[i].speed != null && escTimeSeriesList[i].speed != 0) {
        _avgSpeed += escTimeSeriesList[i].speed;
        ++_avgSpeedNonZeroEntries;
      }

      // Max Battery Current
      if(escTimeSeriesList[i].currentInput != null && escTimeSeriesList[i].currentInput > _maxAmpsBattery){
        _maxAmpsBattery = escTimeSeriesList[i].currentInput;
        _tsESCMaxBatteryAmps = escTimeSeriesList[i];
      }
      if(escTimeSeriesList[i].currentInput != null && escTimeSeriesList[i].currentInput2 != null && escTimeSeriesList[i].currentInput + escTimeSeriesList[i].currentInput2 > _maxAmpsBattery){
        _maxAmpsBattery = doublePrecision(escTimeSeriesList[i].currentInput +  escTimeSeriesList[i].currentInput2, 1);
        _tsESCMaxBatteryAmps = escTimeSeriesList[i];
      }
      if(escTimeSeriesList[i].currentInput != null && escTimeSeriesList[i].currentInput2 != null && escTimeSeriesList[i].currentInput3 != null && escTimeSeriesList[i].currentInput4 != null &&
          escTimeSeriesList[i].currentInput + escTimeSeriesList[i].currentInput2 + escTimeSeriesList[i].currentInput3 + escTimeSeriesList[i].currentInput4 > _maxAmpsBattery){
        _maxAmpsBattery = doublePrecision(escTimeSeriesList[i].currentInput +  escTimeSeriesList[i].currentInput2 + escTimeSeriesList[i].currentInput3 + escTimeSeriesList[i].currentInput4, 1);
        _tsESCMaxBatteryAmps = escTimeSeriesList[i];
      }

      // Max Motor Current
      if(escTimeSeriesList[i].currentMotor != null && escTimeSeriesList[i].currentMotor > _maxAmpsMotor){
        _maxAmpsMotor = escTimeSeriesList[i].currentMotor;
        _tsESCMaxMotorAmps = escTimeSeriesList[i];
      }
      if(escTimeSeriesList[i].currentMotor != null && escTimeSeriesList[i].currentMotor2 != null && escTimeSeriesList[i].currentMotor + escTimeSeriesList[i].currentMotor2 > _maxAmpsMotor){
        _maxAmpsMotor = doublePrecision(escTimeSeriesList[i].currentMotor + escTimeSeriesList[i].currentMotor2, 1);
        _tsESCMaxMotorAmps = escTimeSeriesList[i];
      }
      if(escTimeSeriesList[i].currentMotor != null && escTimeSeriesList[i].currentMotor2 != null && escTimeSeriesList[i].currentMotor3 != null && escTimeSeriesList[i].currentMotor4 != null &&
          escTimeSeriesList[i].currentMotor + escTimeSeriesList[i].currentMotor2 + escTimeSeriesList[i].currentMotor3 + escTimeSeriesList[i].currentMotor4 > _maxAmpsMotor){
        _maxAmpsMotor = doublePrecision(escTimeSeriesList[i].currentMotor + escTimeSeriesList[i].currentMotor2 + escTimeSeriesList[i].currentMotor3 + escTimeSeriesList[i].currentMotor4, 1);
        _tsESCMaxMotorAmps = escTimeSeriesList[i];
      }

      // Monitor Max ESC Temp
      if(escTimeSeriesList[i].tempMosfet != null && escTimeSeriesList[i].tempMosfet > _maxESCTempObserved){
        // Store time series moment for map point generation and data popup
        _tsESCMaxESCTemp = escTimeSeriesList[i];
        _maxESCTempObserved = escTimeSeriesList[i].tempMosfet;
      }
      if(escTimeSeriesList[i].tempMosfet2 != null && escTimeSeriesList[i].tempMosfet2 > _maxESCTempObserved){
        // Store time series moment for map point generation and data popup
        _tsESCMaxESCTemp = escTimeSeriesList[i];
        _maxESCTempObserved = escTimeSeriesList[i].tempMosfet2;
      }
      if(escTimeSeriesList[i].tempMosfet3 != null && escTimeSeriesList[i].tempMosfet3 > _maxESCTempObserved){
        // Store time series moment for map point generation and data popup
        _tsESCMaxESCTemp = escTimeSeriesList[i];
        _maxESCTempObserved = escTimeSeriesList[i].tempMosfet3;
      }
      if(escTimeSeriesList[i].tempMosfet4 != null && escTimeSeriesList[i].tempMosfet4 > _maxESCTempObserved){
        // Store time series moment for map point generation and data popup
        _tsESCMaxESCTemp = escTimeSeriesList[i];
        _maxESCTempObserved = escTimeSeriesList[i].tempMosfet4;
      }
    } //iterate escTimeSeriesList

    //TODO: Reduce number of ESC points to keep things moving on phones
    //TODO: We will need to know the logging rate in the file (use fileLoggingRateHz)
    int escTimeSeriesListOriginalLength = escTimeSeriesList.length; // Capture unmodified length for average computation
    while(escTimeSeriesList.length > 1200) {
      int pos = 0;
      for (int i=0; i<escTimeSeriesList.length; ++i, ++pos) {
        escTimeSeriesList[pos] = escTimeSeriesList[i++]; // Increment i
        // Check next record that we intend to remove for a fault or value of importance
        if ( i < escTimeSeriesList.length &&
            ( escTimeSeriesList[i].faultCode != null ||
                escTimeSeriesList[i] == _tsESCMaxSpeed ||
                escTimeSeriesList[i] == _tsESCMaxMotorAmps ||
                escTimeSeriesList[i] == _tsESCMaxBatteryAmps ||
                escTimeSeriesList[i] == _tsESCMaxESCTemp
            )
        ) {
          // Keep the next record because it contains a fault or value of importance
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
      globalLogger.d("rideLogViewer reduced escTimeSeriesList length to ${escTimeSeriesList.length}");
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
      //NOTE: If a ride was merged but the end->start GPS positions differ the re-calculated values will be wrong
      //NOTE: Some old database entries did not have GPS avg speed, max speed and distance entries and will be -1
      /// Average Speed
      if (myArguments.logFileInfo.avgSpeedGPS != -1.0) {
        // Use database statistics
        gpsAverageSpeed = myArguments.logFileInfo.avgSpeedGPS;
      } else {
        // Calculate GPS statistics
        gpsAverageSpeed /= _positionEntries.length;
        gpsAverageSpeed = doublePrecision(gpsAverageSpeed, 2);
      }
      /// Distance
      if (myArguments.logFileInfo.distanceGPS != -1.0) {
        gpsDistanceStr = myArguments.userSettings.settings.useImperial ? "${doublePrecision(kmToMile(myArguments.logFileInfo.distanceGPS), 2)} miles" : "${doublePrecision(myArguments.logFileInfo.distanceGPS, 2)} km";
      } else {
        gpsDistanceStr = myArguments.userSettings.settings.useImperial ? "${doublePrecision(kmToMile(gpsDistance), 2)} miles" : "${doublePrecision(gpsDistance, 2)} km";
      }
    }


    globalLogger.d("rideLogViewer creating chart data");
    // Create charting data from ESC time series data
    seriesList = _createChartingData(escTimeSeriesList, escIDsInLog, faultCodeCount, myArguments.userSettings.settings.useImperial);

    // Capture filename passed via arguments
    String filename = myArguments.logFileInfo.logFilePath.substring(myArguments.logFileInfo.logFilePath.lastIndexOf("/") + 1);



    // Add map marker for Max Battery Amps
    if(_tsESCMaxBatteryAmps != null && gpsLatLngMap.length > 0) {
      // Add fault marker to map
      mapMakers.add(new Marker(
        width: 50.0,
        height: 50.0,
        point: selectNearestGPSPoint(_tsESCMaxBatteryAmps.time,gpsLatLngMap),
        builder: (ctx) =>
        new Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 25),
          child: GestureDetector(
            onTap: (){
              _buildDialog("Max Battery Amps", _tsESCMaxBatteryAmps, escTimeSeriesList.first.time, myArguments.userSettings.settings.useFahrenheit);
            },
            child: Image(image: AssetImage("assets/map_max_amps.png")),
          ),
        ),
      ));
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
              _buildDialog("Max ESC Temperature", _tsESCMaxESCTemp, escTimeSeriesList.first.time, myArguments.userSettings.settings.useFahrenheit);
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
              _buildDialog("Top Speed", _tsESCMaxSpeed, escTimeSeriesList.first.time, myArguments.userSettings.settings.useFahrenheit);
            },
            child: Image(image: AssetImage("assets/map_top_speed.png")),
          ),
        ),
      ));
    }
    globalLogger.d("rideLogViewer creating map polyline from ${_positionEntries.length} points");

    //TODO: color polyline based on stats other than speed
    List<Polyline> polylineList = [];
    if (gpsLatLngMap.values.length > 0) {
      // Sorting in case we have experienced out of order records
      var sortedGPSMapKeysTEST = gpsLatLngMap.keys.toList()..sort();
      LatLng lastPoint = gpsLatLngMap[sortedGPSMapKeysTEST.first];
      sortedGPSMapKeysTEST.forEach((element) {
        var value = gpsLatLngMap[element];
        var key = element;
        Color thisColor = Colors.black;
        //TODO: Reduce number of GPS points to keep things moving on phones
        if (calculateGPSDistance(lastPoint, value) > 0.01) {
          // Compute color for this section of the route
          if (escTimeSeriesMap[key] != null && escTimeSeriesMap[key].speed != null && _maxSpeed > 0.0) {
            double normalizedSpeed = escTimeSeriesMap[key].speed.abs() / _maxSpeed;
            if (normalizedSpeed < 0.5) thisColor = Color.lerp(Colors.blue[700], Colors.yellowAccent, normalizedSpeed);
            else thisColor = Color.lerp(Colors.yellowAccent, Colors.redAccent[700], normalizedSpeed);
          }
          // Add colored polyline from last section to this one
          polylineList.add(Polyline(points: [lastPoint, value], strokeWidth: 4, color: thisColor));
          // Capture last point added
          lastPoint = value;
        }
      });
    }

    if (gpsLatLngRejectMap.values.length > 0) {
      // Sorting in case we have experienced out of order records
      var sortedGPSMapKeysTEST = gpsLatLngRejectMap.keys.toList()..sort();
      LatLng lastPoint = gpsLatLngRejectMap[sortedGPSMapKeysTEST.first];
      sortedGPSMapKeysTEST.forEach((element) {
        var value = gpsLatLngRejectMap[element];
        var key = element;
        Color thisColor = Colors.black;
        //TODO: Reduce number of GPS points to keep things moving on phoness
        if (calculateGPSDistance(lastPoint, value) > 0.01) {
          // Compute color for this section of the route
          if (escTimeSeriesMap[key] != null && escTimeSeriesMap[key].speed != null && _maxSpeed > 0.0) {
            double normalizedSpeed = escTimeSeriesMap[key].speed.abs() / _maxSpeed;
            if (normalizedSpeed < 0.5) thisColor = Color.lerp(Colors.blue[700], Colors.yellowAccent, normalizedSpeed);
            else thisColor = Color.lerp(Colors.yellowAccent, Colors.redAccent[700], normalizedSpeed);
          }
          // Add colored polyline from last section to this one
          polylineList.add(Polyline(points: [lastPoint, value], strokeWidth: 4, color: thisColor));
          // Capture last point added
          lastPoint = value;
        }
      });
    }

    String distance = "N/A";
    Duration duration = Duration(seconds:0);
    if(escTimeSeriesList.length > 0) {
      double totalDistance = myArguments.userSettings.settings.useImperial ? kmToMile(myArguments.logFileInfo.distance) : myArguments.logFileInfo.distance;
      distance = myArguments.userSettings.settings.useImperial ? "$totalDistance miles" : "$totalDistance km";
      duration = escTimeSeriesList.last.time.difference(escTimeSeriesList.first.time);

      // Compute average moving speed
      if (_avgSpeedNonZeroEntries > 0) {
        _avgSpeedMoving =  _avgSpeed / _avgSpeedNonZeroEntries;
        _avgSpeedMoving = doublePrecision(_avgSpeedMoving, 2);
      }

      // Compute average overall speed
      _avgSpeed /= escTimeSeriesListOriginalLength;
      _avgSpeed = doublePrecision(_avgSpeed, 2);
    }
    String maxSpeed = myArguments.userSettings.settings.useImperial ? "$_maxSpeed mph" : "$_maxSpeed kph";
    String avgSpeed = myArguments.userSettings.settings.useImperial ? "$_avgSpeed mph" : "$_avgSpeed kph";
    String avgSpeedMoving = myArguments.userSettings.settings.useImperial ? "$_avgSpeedMoving mph" : "$_avgSpeedMoving kph";

    // Remove loading dialog since the user has no control
    if(_keyLoader.currentContext != null)
      Navigator.of(_keyLoader.currentContext,rootNavigator: true).pop();

    globalLogger.d("rideLogViewer statistics generated");

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

    /// Compute consumption
    double consumption = 0;
    double consumptionDistance;
    if (myArguments.logFileInfo.wattHoursTotal != -1 && distanceEndPrimary != null && distanceStartPrimary != null) {

      if (_useGPSData) {
        consumptionDistance = myArguments.userSettings.settings.useImperial ? kmToMile(gpsDistance) : gpsDistance;
      } else {
        consumptionDistance = myArguments.userSettings.settings.useImperial ? kmToMile(myArguments.logFileInfo.distance) : myArguments.logFileInfo.distance;
      }
      consumption = (myArguments.logFileInfo.wattHoursTotal - myArguments.logFileInfo.wattHoursRegenTotal) / consumptionDistance;
    }
    if (consumption.isNaN || consumption.isInfinite) {
      consumption = 0;
    }
    consumption = doublePrecision(consumption, 2);
    globalLogger.d("Consumption: wh${myArguments.logFileInfo.wattHoursTotal} whRegen${myArguments.logFileInfo.wattHoursRegenTotal} dEnd $distanceEndPrimary dStart $distanceStartPrimary compD $consumptionDistance GPS $_useGPSData imperial ${myArguments.userSettings.settings.useImperial} consumption $consumption");

    /// Add empty current position marker to the mapMarkers list
    //NOTE: Being the final entry this will be removed with user selection
    mapMakers.add(new Marker(
      width: 50.0,
      height: 50.0,
      point: new LatLng(0,0),
      builder: (ctx) =>
      new Container(),
    ));

    ///Build Widget
    return Scaffold(
      appBar: AppBar(
        title: Row(children: <Widget>[
          Text(myArguments.logFileInfo.dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)),
          Spacer(),
          ClipRRect(
            borderRadius: new BorderRadius.circular(10),
            child: Image(width: 40, height: 40, image: AssetImage('assets/FreeSK8_Icon_Dark.png'),
              color: Color(0xffffffff).withOpacity(0.1),
              colorBlendMode: BlendMode.softLight,),
          ),
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
                    escTimeSeriesList.length > 0 ? Text(avgSpeedMoving) : Text(gpsAverageSpeed.toString())
                  ],),
                  SizedBox(width: 10,),
                  Column(children: <Widget>[
                    Text("Distance Traveled"),
                    myArguments.userSettings.settings.useGPSData ? Icon(Icons.gps_fixed) : Icon(Icons.gps_not_fixed),
                    escTimeSeriesList.length > 0 ? _useGPSData ? Text(gpsDistanceStr) : Text(distance) : Text(gpsDistanceStr)
                  ],),


                ],
              ),

              SizedBox(height: 12,),
              Row(mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  myArguments.logFileInfo.wattHoursTotal != -1.0 && distanceEndPrimary != null ? Column(children: <Widget>[
                    Text("${escIDsInLog.length == 1 ? "Single" : escIDsInLog.length == 2 ? "Dual" : "Quad"}"),
                    Icon(Icons.local_gas_station),
                    Text("$consumption Wh/${myArguments.userSettings.settings.useImperial ? "mile" : "km"}")
                  ],) : Container(),
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
                    Text("${prettyPrintDuration(Duration(seconds: myArguments.logFileInfo.durationSeconds))}")
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
                      List<Widget> children = [];
                      faultsObserved.forEach((element) {
                        children.add(Text(element.toString()));
                        children.add(Text(""));
                        shareData += element.toString() + "\n\n";
                      });
                      //genericAlert(context, "Faults observed", Column(children: children), "OK");
                      genericConfirmationDialog(context, TextButton(
                        child: Text("Copy / Share"),
                        onPressed: () {
                          Share.text('Faults observed', shareData, 'text/plain');
                        },
                      ), TextButton(
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
                  ElevatedButton(
                      child: Text("Delete log"),
                      onPressed: () async {
                        //confirm with user
                        genericConfirmationDialog(
                            context,
                            TextButton(
                              child: Text("Cancel"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text("Delete"),
                              onPressed: () async {
                                //Remove from Database
                                await DatabaseAssistant.dbRemoveLog(myArguments.logFileInfo.logFilePath);
                                //Remove from Filesystem
                                await FileManager.eraseLogFile(myArguments.logFileInfo.logFilePath);
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              },
                            ),
                            "Delete file?",
                            Text("Are you sure you want to permanently erase this log?")
                        );
                      }),

                  SizedBox(width: 10,),

                  ElevatedButton(
                      child: Text("Share Log"),
                      onPressed: () async {
                        String fileSummary = 'Robogotchi gotchi!';
                        fileSummary += "\nTop Speed: $maxSpeed";
                        fileSummary += "\nAvg Moving Speed: $avgSpeedMoving";
                        fileSummary += "\nAvg Speed: $avgSpeed";
                        fileSummary += "\nDistance: $distance";
                        if (myArguments.logFileInfo.wattHoursTotal != -1.0 && distanceEndPrimary != null) {
                          fileSummary += "\nConsumption: $consumption Wh/${myArguments.userSettings.settings.useImperial ? "mile" : "km"}";
                          fileSummary += "\nWatt Hours: ${doublePrecision(myArguments.logFileInfo.wattHoursTotal, 2)}";
                          fileSummary += "\nWatt Hours Regen: ${doublePrecision(myArguments.logFileInfo.wattHoursRegenTotal, 2)}";
                        }
                        fileSummary += "\nBattery Amps: ${doublePrecision(_maxAmpsBattery, 1)}";
                        fileSummary += "\nMotor Amps: ${doublePrecision(_maxAmpsMotor, 1)}";
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
                        bounds: LatLngBounds.fromPoints(_positionEntries),
                        boundsOptions: FitBoundsOptions(padding: EdgeInsets.all(20)),
                      ),
                      layers: [
                        new TileLayerOptions(
                            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                            subdomains: ['a', 'b', 'c']
                        ),

                        new PolylineLayerOptions(
                            polylines: polylineList
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

                      // Customize the domainAxis tickFormatterSpec
                      domainAxis: new charts.DateTimeAxisSpec(
                          viewport: new charts.DateTimeExtents(start: escTimeSeriesList.first.time, end: escTimeSeriesList.last.time),
                          tickFormatterSpec: new charts.AutoDateTimeTickFormatterSpec(
                            minute: new charts.TimeFormatterSpec(
                              format: 'HH:mm:ss', // or even HH:mm here too
                              transitionFormat: 'HH:mm:ss',
                            ),
                          )
                      ),

                      behaviors: [
                        //TODO: Revisit: https://github.com/janstol/charts/commit/899476a06875422aafde82376cdf57ba0c2e65a5
                        new charts.SlidingViewport(),
                        new charts.PanAndZoomBehavior(),
                        new charts.PanBehavior(),

                        new charts.SeriesLegend(
                            desiredMaxColumns: MediaQuery.of(context).size.width ~/ 125,
                            position: charts.BehaviorPosition.bottom,
                            cellPadding: EdgeInsets.all(4.0),
                            defaultHiddenSeries: ['DutyCycle', 'Motor2Temp', 'Motor2Current', 'MotorCurrent', 'MotorTemp', 'Consumption']
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
                                if (gpsLatLngMap.length > 0 && _mapController != null) {
                                  LatLng closestMapPoint = selectNearestGPSPoint(model.selectedDatum.first.datum.time, gpsLatLngMap);
                                  // Before redrawing the map lets move the last (user selection) marker
                                  mapMakers.removeLast();
                                  mapMakers.add(new Marker(
                                    width: 50.0,
                                    height: 50.0,
                                    point: closestMapPoint,
                                    builder: (ctx) =>
                                    new Container(
                                      margin: EdgeInsets.fromLTRB(0, 0, 0, 10),
                                      child: CircleAvatar(
                                        backgroundImage: myArguments.userSettings.settings.boardAvatarPath != null ? myArguments.imageBoardAvatar : AssetImage('assets/FreeSK8_Mobile.png'),
                                        radius: 10,
                                        backgroundColor: Colors.white
                                      )
                                    ),
                                  ));
                                  _mapController.move(closestMapPoint, _mapController.zoom);
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
                      ],

                      defaultRenderer: charts.LineRendererConfig(
                        includePoints: false,
                        strokeWidthPx: 3,
                      ),

                    ),


                    //TODO: would be cool to position this near the user input
                    Positioned(
                      bottom: 21,
                      right: 5,
                      child: RideLogViewChartOverlay(eventObservable: eventObservable, imperialDistance: myArguments.userSettings.settings.useImperial),
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
  double consumption;
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
      this.consumption,
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