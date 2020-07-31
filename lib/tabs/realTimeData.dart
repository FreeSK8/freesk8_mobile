import 'dart:math';
import 'package:flutter/material.dart';

import 'package:freesk8_mobile/escHelper.dart';
import 'package:freesk8_mobile/userSettings.dart';

import 'package:flutter_thermometer/label.dart';
import 'package:flutter_thermometer/scale.dart';

import 'flutterMap.dart'; import 'package:latlong/latlong.dart';

import 'package:flutter_gauge/flutter_gauge.dart';
import 'package:flutter_thermometer/thermometer_widget.dart';

import 'package:oscilloscope/oscilloscope.dart';

class RealTimeData extends StatefulWidget {

  RealTimeData({this.routeTakenLocations, this.telemetryPacket, @required this.currentSettings, this.startStopTelemetryFunc});

  final List<LatLng> routeTakenLocations;
  final UserSettings currentSettings;
  final ESCTelemetry telemetryPacket;
  final ValueChanged<bool> startStopTelemetryFunc;

  RealTimeDataState createState() => new RealTimeDataState();

  static const String routeName = "/realtime";
}

class RealTimeDataState extends State<RealTimeData> {

  static List<double> motorCurrentGraphPoints = List();

  static double doubleItemWidth = 150; //This changes on widget build

  double maxPossibleSpeedKph() {
    double maxRPM = widget.currentSettings.settings.motorKV * widget.currentSettings.settings.batterySeriesCount * widget.currentSettings.settings.batteryCellMaxVoltage;
    double ratio = widget.currentSettings.settings.pulleyMotorToothCount / widget.currentSettings.settings.pulleyWheelToothCount;
    int minutesToHour = 60;
    double ratioRpmSpeed = (ratio * minutesToHour * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / 1000000;
    double speed = maxRPM * ratioRpmSpeed * 0.85;
    return double.parse((speed).toStringAsFixed(2));
  }

  double calculateSpeedKph(double eRpm) {
    double ratio = widget.currentSettings.settings.pulleyMotorToothCount / widget.currentSettings.settings.pulleyWheelToothCount;
    int minutesToHour = 60;
    double ratioRpmSpeed = (ratio * minutesToHour * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles / 2) * 1000000);
    double speed = eRpm * ratioRpmSpeed;
    return double.parse((speed).toStringAsFixed(2));
  }

  double calculateDistanceKm(double eCount) {
    double ratio = widget.currentSettings.settings.pulleyMotorToothCount / widget.currentSettings.settings.pulleyWheelToothCount;
    double ratioPulseDistance = (ratio * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles * 3) * 1000000);
    double distance = eCount * ratioPulseDistance;
    return double.parse((distance).toStringAsFixed(2));
  }

  double calculateEfficiencyKm(double kmTraveled) {
    double whKm = (widget.telemetryPacket.watt_hours - widget.telemetryPacket.watt_hours_charged) / kmTraveled;
    if (whKm.isNaN || whKm.isInfinite) {
      whKm = 0;
    }
    return double.parse((whKm).toStringAsFixed(2));

  }

  double kphToMph(double kph) {
    double speed = 0.621371 * kph;
    return double.parse((speed).toStringAsFixed(2));
  }

  double kmToMile(double km) {
    double distance = 0.621371 * km;
    return double.parse((distance).toStringAsFixed(2));
  }

  double mmToFeet(double mm) {
    double distance = 0.00328084 * mm;
    return double.parse((distance).toStringAsFixed(2));
  }

  double cToF(double c) {
    double temp = (c * 1.8) + 32;
    return double.parse((temp).toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    print("initState: realTimeData");
    widget.startStopTelemetryFunc(false); //Start the telemetry timer
  }

  @override
  void dispose() {
    widget.startStopTelemetryFunc(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: RealTimeData");
    doubleItemWidth = MediaQuery.of(context).size.width /2 - 10;

    //TODO: testing oscope package
    motorCurrentGraphPoints.add( widget.telemetryPacket.current_motor );
    if(motorCurrentGraphPoints.length > doubleItemWidth * 0.75) motorCurrentGraphPoints.removeAt(0);

    double tempMosfet = widget.currentSettings.settings.useFahrenheit ? cToF(widget.telemetryPacket.temp_mos) : widget.telemetryPacket.temp_mos;
    double tempMotor = widget.currentSettings.settings.useFahrenheit ? cToF(widget.telemetryPacket.temp_motor) : widget.telemetryPacket.temp_motor;
    // Around -99.9 is the value received if there is no/faulty temp sensor, Set to 0 so the gauges don't shit themselves
    if (tempMotor < -32) { tempMotor = 0; }

    String temperatureMosfet = widget.currentSettings.settings.useFahrenheit ? "$tempMosfet F" : "$tempMosfet C";
    String temperatureMosfet1 = widget.currentSettings.settings.useFahrenheit ? "${cToF(widget.telemetryPacket.temp_mos_1)} F" : "${widget.telemetryPacket.temp_mos_1} C";
    String temperatureMosfet2 = widget.currentSettings.settings.useFahrenheit ? "${cToF(widget.telemetryPacket.temp_mos_2)} F" : "${widget.telemetryPacket.temp_mos_2} C";
    String temperatureMosfet3 = widget.currentSettings.settings.useFahrenheit ? "${cToF(widget.telemetryPacket.temp_mos_3)} F" : "${widget.telemetryPacket.temp_mos_3} C";
    String temperatureMotor = widget.currentSettings.settings.useFahrenheit ? "$tempMotor F" : "$tempMotor C";

    double speedMax = widget.currentSettings.settings.useImperial ? kphToMph(maxPossibleSpeedKph()) : maxPossibleSpeedKph();
    double speedNow = widget.currentSettings.settings.useImperial ? kphToMph(calculateSpeedKph(widget.telemetryPacket.rpm)) : calculateSpeedKph(widget.telemetryPacket.rpm);
    //String speed = widget.currentSettings.settings.useImperial ? "$speedNow mph" : "$speedNow kph";

    //String distance = widget.currentSettings.settings.useImperial ? "${kmToMile(widget.telemetryPacket.tachometer_abs / 1000.0)} miles" : "${widget.telemetryPacket.tachometer_abs / 1000.0} km";
    double distanceTraveled = calculateDistanceKm(widget.telemetryPacket.tachometer_abs * 1.0);
    String distance = widget.currentSettings.settings.useImperial ? "${kmToMile(distanceTraveled)} miles" : "$distanceTraveled km";


    double efficiencyKm = calculateEfficiencyKm(distanceTraveled);
    double efficiencyGauge = widget.currentSettings.settings.useImperial ? kmToMile(efficiencyKm) : efficiencyKm;
    String efficiencyGaugeLabel = widget.currentSettings.settings.useImperial ? "Efficiency Wh/Mi" : "Efficiency Wh/Km";
    //String efficiency = widget.currentSettings.settings.useImperial ? "${kmToMile(efficiencyKm)} Wh/Mi" : "$efficiencyKm Wh/Km";

    double powerMax = widget.currentSettings.settings.batterySeriesCount * widget.currentSettings.settings.batteryCellMaxVoltage;
    double powerMinimum = widget.currentSettings.settings.batterySeriesCount * widget.currentSettings.settings.batteryCellMinVoltage;
    double powerRemaining = widget.telemetryPacket.v_in - powerMinimum;
    double percentRemaining = (powerRemaining / (powerMax - powerMinimum)) * 100;
    //print("POWER min $powerMinimum current ${widget.telemetryPacket.v_in} remaining $powerRemaining percentage $percentRemaining");
    if(percentRemaining<0.0) {percentRemaining = 0.0;}


    FlutterGauge _gaugeDutyCycle = FlutterGauge(handSize: 30,index: widget.telemetryPacket.duty_now * 100,fontFamily: "Courier", start:-100, end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));
    //TODO: if speed is less than start value of gauge this will error
    FlutterGauge _gaugeSpeed = FlutterGauge(numberInAndOut: NumberInAndOut.inside, index: speedNow, start: -5, end: speedMax.ceil().toInt(),counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.none,number: Number.all);

    FlutterGauge _gaugePowerRemaining = FlutterGauge(inactiveColor: Colors.red,activeColor: Colors.black,numberInAndOut: NumberInAndOut.inside, index: percentRemaining,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.secondsAndMinute,number: Number.all);
    FlutterGauge _gaugeVolts = FlutterGauge(inactiveColor: Colors.red,activeColor: Colors.black,hand: Hand.short,index: widget.telemetryPacket.v_in,fontFamily: "Courier",start: powerMinimum.floor().toInt(), end: powerMax.ceil().toInt(),number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));
    //TODO: scale efficiency and adjust end value for imperial users
    FlutterGauge _gaugeEfficiency = FlutterGauge(reverseDial: true, reverseDigits: true, hand: Hand.short,index: efficiencyGauge,fontFamily: "Courier",start: 0, end: 42,number: Number.endAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));

    Oscilloscope scopeOne = Oscilloscope(
      backgroundColor: Colors.transparent,
      traceColor: Theme.of(context).accentColor,
      yAxisMax: 5.0,
      yAxisMin: -5.0,
      dataSet: motorCurrentGraphPoints,
    );

    //FlutterGauge _gauge3 = FlutterGauge(handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,));
    //FlutterGauge _gauge6 = FlutterGauge(numberInAndOut: NumberInAndOut.inside, index: doodie,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.none,number: Number.all);
    //FlutterGauge _gauge8 = FlutterGauge(inactiveColor: Theme.of(context).accentColor,activeColor: Theme.of(context).primaryColor,handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.none,secondsMarker: SecondsMarker.minutes,isCircle: false,hand: Hand.none,counterAlign: CounterAlign.center,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),isDecimal: false,);

    //double doodie = 50;
    //FlutterGauge _gauge1 = FlutterGauge(index: doodie,hand: Hand.short,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),);
    //FlutterGauge _gauge2 = FlutterGauge(index: doodie,hand: Hand.short,number: Number.none,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),);
      //FlutterGauge _gauge3 = FlutterGauge(handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,));
    //FlutterGauge _gauge4 = FlutterGauge(handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,hand: Hand.short,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 22,));
    //FlutterGauge _gauge5 = FlutterGauge(inactiveColor: Theme.of(context).disabledColor,activeColor: Theme.of(context).indicatorColor,handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.none,secondsMarker: SecondsMarker.minutes,isCircle: true,hand: Hand.none,counterAlign: CounterAlign.center,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 30,),isDecimal: false,);
      //FlutterGauge _gauge6 = FlutterGauge(numberInAndOut: NumberInAndOut.inside, index: doodie,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.none,number: Number.all);
    //FlutterGauge _gauge7 = FlutterGauge(handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,hand: Hand.short,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 22,));
      //FlutterGauge _gauge8 = FlutterGauge(inactiveColor: Theme.of(context).accentColor,activeColor: Theme.of(context).primaryColor,handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.none,secondsMarker: SecondsMarker.minutes,isCircle: false,hand: Hand.none,counterAlign: CounterAlign.center,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),isDecimal: false,);
    //FlutterGauge _gauge9 = FlutterGauge(numberInAndOut: NumberInAndOut.inside, index: doodie,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.none,number: Number.all);
    //FlutterGauge _gauge10 = FlutterGauge(numberInAndOut: NumberInAndOut.outside, index: doodie,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),widthCircle: 25,secondsMarker: SecondsMarker.none,number: Number.all,hand: Hand.short);
    //FlutterGauge _gauge11 = FlutterGauge(handSize: 30,index: doodie,fontFamily: "Iran",end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute, counterStyle:TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,));
    //FlutterGauge _gauge12 = FlutterGauge(numberInAndOut: NumberInAndOut.outside, index: doodie,counterStyle: TextStyle(color: Theme.of(context).textTheme.title.color,fontSize: 25,),widthCircle: 25,secondsMarker: SecondsMarker.none,number: Number.all);


    //print(MediaQuery.of(context).size.height);
    //print(MediaQuery.of(context).size.width);

    // Build widget
    return Container(
      child: Center(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: <Widget>[

            Row(children: <Widget>[
              Column(
                children: <Widget>[
                  Center(child:Text("Duty Cycle")),
                  Container(width: doubleItemWidth, child: _gaugeDutyCycle)
                ]),

              Column(
                  children: <Widget>[
                    Center(child:Text("Speed")),
                    Container(width: doubleItemWidth, child: _gaugeSpeed)
                  ]),],),

            Row(children: <Widget>[
              Column(
                  children: <Widget>[
                    Center(child:Text("Power Remaining")),
                    Container(width: doubleItemWidth, child: _gaugePowerRemaining)
                  ]),

              Column(
                  children: <Widget>[
                    Center(child:Text("Volts")),
                    Container(width: doubleItemWidth, child: _gaugeVolts)
                  ]),
            ],),

            Row(children: <Widget>[
              Column(
                  children: <Widget>[
                    Center(child:Text(efficiencyGaugeLabel)),
                    Container(width: doubleItemWidth, child: _gaugeEfficiency)
                  ]),

              Column(  children: <Widget>[
                Center(child:Text("Mosfet")),
                Text(temperatureMosfet),
                SizedBox(
                    height:doubleItemWidth * 0.75,
                    width: doubleItemWidth,
                    child: Thermometer(
                      value: tempMosfet,
                      minValue: 0,
                      maxValue: widget.currentSettings.settings.useFahrenheit ? cToF(65) : 65,
                      label: widget.currentSettings.settings.useFahrenheit ? ThermometerLabel.farenheit():ThermometerLabel.celsius(),
                      scale: widget.currentSettings.settings.useFahrenheit ? IntervalScaleProvider(20) : IntervalScaleProvider(10),
                      mercuryColor: Colors.pink,
                      outlineColor: Theme.of(context).textTheme.bodyText1.color,
                    )
                ),
              ]),
            ],),

            Row(children: <Widget>[
              Column( children: <Widget>[
                Center(child:Text("Motor")),
                Text(temperatureMotor),
                SizedBox(
                    height: doubleItemWidth * 0.75,
                    width:doubleItemWidth,
                    child: Thermometer(
                      value: tempMotor,
                      minValue: 0,
                      maxValue: widget.currentSettings.settings.useFahrenheit ? cToF(85) : 85,
                      label: widget.currentSettings.settings.useFahrenheit ? ThermometerLabel.farenheit():ThermometerLabel.celsius(),
                      scale: widget.currentSettings.settings.useFahrenheit ? IntervalScaleProvider(30) : IntervalScaleProvider(20),
                      mercuryColor: Colors.pink,
                      outlineColor: Theme.of(context).textTheme.bodyText1.color,
                    )
                ),
              ]),

              Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Center( child:Text("Motor Current")),
                    Text(widget.telemetryPacket.current_motor.toString()),
                    SizedBox(width: doubleItemWidth, height: doubleItemWidth, child: scopeOne),
                  ]),
            ],),




            Table(children: [
              TableRow(children: [
                Text("Distance Traveled: ", textAlign: TextAlign.right,),
                Text(" $distance")
              ]),

              TableRow(children: [
                Text("Battery Current Now: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryPacket.current_in} A")
              ]),
              TableRow(children: [
                Text("Amp Hours: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryPacket.amp_hours} Ah")
              ]),
              TableRow(children: [
                Text("Amp Hours Charged: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryPacket.amp_hours_charged} Ah")
              ]),
              TableRow(children: [
                Text("Watt Hours: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryPacket.watt_hours} Wh")
              ]),
              TableRow(children: [
                Text("Watt Hours Charged: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryPacket.watt_hours_charged} Wh")
              ]),
              /*
              TableRow(children: [
                Text("Mosfet 1 Temperature: ", textAlign: TextAlign.right,),
                Text(" $temperatureMosfet1")
              ]),
              TableRow(children: [
                Text("Mosfet 2 Temperature: ", textAlign: TextAlign.right,),
                Text(" $temperatureMosfet2")
              ]),
              TableRow(children: [
                Text("Mosfet 3 Temperature: ", textAlign: TextAlign.right,),
                Text(" $temperatureMosfet3")
              ]),
              */
              TableRow(children: [
                Text("Last ESC ID: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryPacket.vesc_id}")
              ]),
              TableRow(children: [
                Text("Fault Now: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryPacket.fault_code.index}")
              ]),
            ],),


            //Row(children: <Widget>[SizedBox(height: 100, width: 100, child:scopeOne,)]),
            //Center(child:LinearProgressIndicator(value:widget.telemetryPacket.duty_now)),
            ////Center(child:Text("temp_mos $temperatureMosfet")),
            ////Center(child:Text("temp_motor $temperatureMotor")),
            //Center(child:Text("current_motor ${widget.telemetryPacket.current_motor}")),
            //////Center(child:Text("current_in ${widget.telemetryPacket.current_in}")),
            //Center(child:Text("foc_id ${widget.telemetryPacket.foc_id}")),
            //Center(child:Text("foc_iq ${widget.telemetryPacket.foc_iq}")),
            ////Center(child:Text("duty_now ${widget.telemetryPacket.duty_now}")),
            //Center(child:Text("erpm ${widget.telemetryPacket.rpm}")),
            ////Center(child:Text("speed $speed")),
            ////Center(child:Text("v_in ${widget.telemetryPacket.v_in}")),
            //////Center(child:Text("amp_hours ${widget.telemetryPacket.amp_hours}")),
            //////Center(child:Text("amp_hours_charged ${widget.telemetryPacket.amp_hours_charged}")),
            //////Center(child:Text("watt_hours ${widget.telemetryPacket.watt_hours}")),
            //////Center(child:Text("watt_hours_charged ${widget.telemetryPacket.watt_hours_charged}")),
            //Center(child:Text("tachometer ${widget.telemetryPacket.tachometer}")),
            //Center(child:Text("tachometer_abs ${widget.telemetryPacket.tachometer_abs}")),
            /////Center(child:Text("distance $distance")),
            //Center(child:Text("efficiency $efficiency")),
            //////Center(child:Text("fault_code ${widget.telemetryPacket.fault_code}")),
            //Center(child:Text("position ${widget.telemetryPacket.position}")),
            //////Center(child:Text("vesc_id ${widget.telemetryPacket.vesc_id}")),
            //////Center(child:Text("temp_mos_1 $temperatureMosfet1")),
            //////Center(child:Text("temp_mos_2 $temperatureMosfet2")),
            //////Center(child:Text("temp_mos_3 $temperatureMosfet3")),
            //Center(child:Text("vd ${widget.telemetryPacket.vd}")),
            //Center(child:Text("vq ${widget.telemetryPacket.vq}")),


            ///FlutterMapWidget
            Container(
              height: MediaQuery.of(context).size.height / 2,
              child: Center(
                  child: new FlutterMapWidget(routeTakenLocations: widget.routeTakenLocations,)
                    //child: googleMapPage,
                )
              ),


          ],
        ),
      ),
    );
  }
}
