import 'dart:async';

import 'package:flutter/material.dart';
import 'package:freesk8_mobile/rideLogViewer.dart';
import 'package:rxdart/rxdart.dart';

class RideLogChartData {
  final DateTime dateTime;
  final TimeSeriesESC escData;

  RideLogChartData(this.dateTime,this.escData);
}

class RideLogViewChartOverlay extends StatefulWidget {
  RideLogViewChartOverlay({this.eventObservable});
  final PublishSubject<RideLogChartData> eventObservable;
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
    return Container(
      height: 130,
      width: 155,

      color: Colors.black.withOpacity(0.85),
      child: GestureDetector(onTap: (){
          setState(() {
            selectedDateTime = null;
          });
        }
        ,child: Column(
          children: <Widget>[
            Text("${selectedDateTime.toIso8601String().substring(0,19)}"),
            Container(
                padding: EdgeInsets.only(left: 5),
                child: Table(  //border: TableBorder.all(color: Colors.white),
                  children: [
                  TableRow( children: [
                    Text("VDC"),
                    Text("${selectedESCData.voltage}", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("MotorTemp"),
                    Text("${selectedESCData.tempMotor}", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("ESCTemp"),
                    Text("${selectedESCData.tempMosfet}", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Duty"),
                    Text("${(selectedESCData.dutyCycle * 100).toInt()} %", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Motor"),
                    Text("${selectedESCData.currentMotor} A", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Battery"),
                    Text("${selectedESCData.currentInput} A", textAlign: TextAlign.center),
                  ]),
                  TableRow( children: [
                    Text("Speed"),
                    Text("${selectedESCData.speed}", textAlign: TextAlign.center),
                  ]),
                ],)
            ),
          ]

      ),)

    );
  }
}