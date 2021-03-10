import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:freesk8_mobile/globalUtilities.dart';
import '../subViews/rideLogViewer.dart';
import 'package:rxdart/rxdart.dart';
import '../hardwareSupport/escHelper/escHelper.dart';

class RideLogChartData {
  final DateTime dateTime;
  final TimeSeriesESC escData;

  RideLogChartData(this.dateTime,this.escData);
}

class RideLogViewChartOverlay extends StatefulWidget {
  RideLogViewChartOverlay({this.eventObservable, this.imperialDistance});
  final PublishSubject<RideLogChartData> eventObservable;
  final bool imperialDistance;
  RideLogViewChartOverlayState createState() => new RideLogViewChartOverlayState(this.eventObservable);
}

class RideLogViewChartOverlayState extends State<RideLogViewChartOverlay> {

  DateTime selectedDateTime;
  TimeSeriesESC selectedESCData;

  StreamSubscription<RideLogChartData> subscription;
  PublishSubject<RideLogChartData> eventObservable;

  RideLogViewChartOverlayState(PublishSubject<RideLogChartData> eventObservable) {
    this.eventObservable = eventObservable;

    subscription = this.eventObservable.listen((value) {
      reloadData(value);
    });
  }

  // As the StreamSubscription receives data from the PublishSubject update the state of this widget
  void reloadData(RideLogChartData eventObject) {
    if(eventObject!=null) {
      setState(() {
        selectedDateTime = eventObject.dateTime;
        selectedESCData = eventObject.escData;
        print(eventObject);
      });
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    if (selectedDateTime == null) {
      return Container();
    }

    String tempMotor = "${selectedESCData.tempMotor == null ? "--" : selectedESCData.tempMotor}";
    if (selectedESCData.tempMotor2 != null) {
      tempMotor += ", ${selectedESCData.tempMotor2}";
    }
    String tempMosfet = "${selectedESCData.tempMosfet == null ? "--" : selectedESCData.tempMosfet}";
    if (selectedESCData.tempMosfet2 != null) {
      tempMosfet += ", ${selectedESCData.tempMosfet2}";
    }
    String currentMotor = "${selectedESCData.currentMotor == null ? "--" : selectedESCData.currentMotor} A";
    if (selectedESCData.currentMotor2 != null) {
      currentMotor += ", ${selectedESCData.currentMotor2} A";
    }
    String currentInput = "${selectedESCData.currentInput == null ? "--" : selectedESCData.currentInput} A";
    if (selectedESCData.currentInput2 != null) {
      currentInput += ", ${selectedESCData.currentInput2} A";
    }

    return Container(
      padding: EdgeInsets.fromLTRB(0, 3, 0, 3),
      width: 200,

      color: Colors.black.withOpacity(0.85),
      child: GestureDetector(onTap: (){
          setState(() {
            selectedDateTime = null;
          });
        }
        ,child: Column(
          children: <Widget>[
            Text("${selectedDateTime.toIso8601String().substring(0,19)}"),
            selectedESCData.faultCode != null ? Text("${mc_fault_code.values[selectedESCData.faultCode].toString().substring(14)}", style: TextStyle(fontSize: 8),) : Container(),
            Container(
                padding: EdgeInsets.only(left: 5),
                child: Table(  //border: TableBorder.all(color: Colors.white),
                  children: [
                  TableRow( children: [
                    Text("VDC"),
                    Text("${selectedESCData.voltage != null ? selectedESCData.voltage : "--"}", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("MotorTemp"),
                    Text(tempMotor, textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("ESCTemp"),
                    Text(tempMosfet, textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Duty"),
                    Text("${doublePrecision(selectedESCData.dutyCycle * 100, 2)} %", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Motor"),
                    Text(currentMotor, textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Input"),
                    Text(currentInput, textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Speed"),
                    Text("${selectedESCData.speed != null ? selectedESCData.speed : "--"}", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Wh/${widget.imperialDistance ? "mile" : "km"}"),
                    Text("${selectedESCData.consumption != null ? selectedESCData.consumption : "--"}", textAlign: TextAlign.center),
                  ]),
                ],)
            ),
          ]

      ),)

    );
  }
}