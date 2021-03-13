import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../hardwareSupport/dieBieMSHelper.dart';
import '../hardwareSupport/escHelper/escHelper.dart';
import '../hardwareSupport/escHelper/dataTypes.dart';
import '../globalUtilities.dart';
import '../components/userSettings.dart';

import 'package:flutter_thermometer/label.dart';
import 'package:flutter_thermometer/scale.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';


import '../widgets/flutterMap.dart'; import 'package:latlong/latlong.dart';

import 'package:flutter_gauge/flutter_gauge.dart';
import 'package:flutter_thermometer/thermometer_widget.dart';

import 'package:oscilloscope/oscilloscope.dart';

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

class RealTimeData extends StatefulWidget {

  RealTimeData(
      { this.routeTakenLocations,
        this.telemetryMap,
        @required this.currentSettings,
        this.startStopTelemetryFunc,
        this.showDieBieMS,
        this.dieBieMSTelemetry,
        this.closeDieBieMSFunc,
        this.changeSmartBMSID,
        this.smartBMSID,
        this.deviceIsConnected,
      });

  final List<LatLng> routeTakenLocations;
  final UserSettings currentSettings;
  final Map<int, ESCTelemetry> telemetryMap;
  final ValueChanged<bool> startStopTelemetryFunc;
  final bool showDieBieMS;
  final DieBieMSTelemetry dieBieMSTelemetry;
  final ValueChanged<bool> closeDieBieMSFunc;
  final ValueChanged<int> changeSmartBMSID;
  final int smartBMSID;
  final bool deviceIsConnected;

  RealTimeDataState createState() => new RealTimeDataState();

  static const String routeName = "/realtime";
}

class RealTimeDataState extends State<RealTimeData> {

  static List<double> motorCurrentGraphPoints = List();

  static double doubleItemWidth = 150; //This changes on widget build

  static double averageVoltageInput = 0;

  static ESCTelemetry escTelemetry;

  static double batteryRemaining = 0;

  double calculateSpeedKph(double eRpm) {
    double ratio = 1.0 / widget.currentSettings.settings.gearRatio;
    int minutesToHour = 60;
    double ratioRpmSpeed = (ratio * minutesToHour * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles / 2) * 1000000);
    double speed = eRpm * ratioRpmSpeed;
    return double.parse((speed).toStringAsFixed(2));
  }

  double calculateDistanceKm(double eCount) {
    double ratio = 1.0 / widget.currentSettings.settings.gearRatio;
    double ratioPulseDistance = (ratio * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles * 3) * 1000000);
    double distance = eCount * ratioPulseDistance;
    return double.parse((distance).toStringAsFixed(2));
  }

  double calculateEfficiencyKm(double kmTraveled) {
    double whKm = (escTelemetry.watt_hours - escTelemetry.watt_hours_charged) / kmTraveled;
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
    globalLogger.d("initState: realTimeData");
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
    if(widget.showDieBieMS) {
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
                  itemCount: widget.dieBieMSTelemetry.noOfCells,
                  itemBuilder: (context, i) {
                    Widget rowIcon;
                    if (widget.dieBieMSTelemetry.cellVoltage[i] == widget.dieBieMSTelemetry.cellVoltageAverage){
                      rowIcon = Transform.rotate(
                        angle: 1.5707,
                        child: Icon(Icons.pause_circle_outline),
                      );
                    } else if (widget.dieBieMSTelemetry.cellVoltage[i] < widget.dieBieMSTelemetry.cellVoltageAverage){
                      rowIcon = Icon(Icons.remove_circle_outline);
                    } else {
                      rowIcon = Icon(Icons.add_circle_outline);
                    }

                    //Sometimes we get a bad parse or bad data from DieBieMS and slider value will not be in min/max range
                    double voltage = widget.dieBieMSTelemetry.cellVoltage[i] - widget.dieBieMSTelemetry.cellVoltageAverage;
                    if (voltage < -widget.dieBieMSTelemetry.cellVoltageMismatch || voltage > widget.dieBieMSTelemetry.cellVoltageMismatch) {
                      return Container();
                    }
                    else return Row(

                      children: <Widget>[
                        rowIcon,
                        Text(" Cell $i"),

                        Expanded(child: Slider(
                          onChanged: (newValue){},
                          inactiveColor: Colors.red,
                          value: widget.dieBieMSTelemetry.cellVoltage[i] - widget.dieBieMSTelemetry.cellVoltageAverage,
                          min: -widget.dieBieMSTelemetry.cellVoltageMismatch,
                          max: widget.dieBieMSTelemetry.cellVoltageMismatch,
                        ),),
                        Text("${formatTriple.format(widget.dieBieMSTelemetry.cellVoltage[i])}"),
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
                  Text(" ${widget.dieBieMSTelemetry.packVoltage} (${widget.dieBieMSTelemetry.soc}%)", textScaleFactor: 1.25,)
                ]),
                TableRow(children: [
                  Text("Pack Current: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.packCurrent)} A")
                ]),
                TableRow(children: [
                  Text("Cell Voltage Average: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageAverage)} V")
                ]),
                TableRow(children: [
                  Text("Cell Voltage High: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageHigh)} V")
                ]),

                TableRow(children: [
                  Text("Cell Voltage Low: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageLow)} V")
                ]),
                TableRow(children: [
                  Text("Cell Voltage Mismatch: ", textAlign: TextAlign.right,),
                  Text(" ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltageMismatch)} V")
                ]),
                TableRow(children: [
                  Text("Battery Temp High: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBatteryHigh} C")
                ]),
                TableRow(children: [
                  Text("Battery Temp Average: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBatteryAverage} C")
                ]),
                TableRow(children: [
                  Text("BMS Temp High: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBMSHigh} C")
                ]),
                TableRow(children: [
                  Text("BMS Temp Average: ", textAlign: TextAlign.right,),
                  Text(" ${widget.dieBieMSTelemetry.tempBMSAverage} C")
                ]),
              ],),

              Expanded(child: GridView.builder(
                primary: false,
                itemCount: widget.dieBieMSTelemetry.noOfCells,
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
                                    valueColor: widget.dieBieMSTelemetry.cellVoltage[index] < 0 ?
                                    new AlwaysStoppedAnimation<Color>(Colors.redAccent) :
                                    new AlwaysStoppedAnimation<Color>(Colors.lightGreen),
                                    value: sigmoidal(
                                        widget.dieBieMSTelemetry.cellVoltage[index].abs(),
                                        widget.currentSettings.settings.batteryCellMinVoltage,
                                        widget.currentSettings.settings.batteryCellMaxVoltage)
                                ),
                              )
                          ),
                          new Positioned(
                              top: 5, child: new Text(
                            "  ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltage[index])} V",
                            style: TextStyle(color: Colors.black),
                            textScaleFactor: 1.25,)),
                          new Positioned(bottom: 2, child: new Text("  Cell $index")),
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
              ))
            ])
          ),

          Positioned(
              right: 0,
              top: 0,
              child: IconButton(onPressed: (){widget.closeDieBieMSFunc(true);},icon: Icon(Icons.clear),)
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
                        Text("ID ${widget.smartBMSID}")
                      ]
                  ),
                  onTap: (){
                    widget.changeSmartBMSID(widget.smartBMSID == 10 ? 11 : 10);
                  },
                )
              )
          ),
        ],)
      );
    }

    // Assemble ESC telemetry from all ESCs
    if (widget.telemetryMap.length == 0) {
      escTelemetry = new ESCTelemetry();
    } else {
      escTelemetry = widget.telemetryMap.values.first;
      for (var mapEntry in widget.telemetryMap.entries) {
        if (mapEntry.key != escTelemetry.vesc_id) {
          escTelemetry.amp_hours += mapEntry.value.amp_hours;
          escTelemetry.amp_hours_charged += mapEntry.value.amp_hours_charged;
          escTelemetry.current_in += mapEntry.value.current_in;
          escTelemetry.current_motor += mapEntry.value.current_motor;
          escTelemetry.watt_hours += mapEntry.value.watt_hours;
          escTelemetry.watt_hours_charged += mapEntry.value.watt_hours_charged;
          if (mapEntry.value.fault_code != mc_fault_code.FAULT_CODE_NONE && escTelemetry.fault_code == mc_fault_code.FAULT_CODE_NONE) {
            mapEntry.value.fault_code = escTelemetry.fault_code;
          }
        }
      }
    }

    doubleItemWidth = MediaQuery.of(context).size.width /2 - 10;

    //TODO: testing oscilloscope package
    motorCurrentGraphPoints.add( escTelemetry.current_motor );
    if(motorCurrentGraphPoints.length > doubleItemWidth * 0.75) motorCurrentGraphPoints.removeAt(0);

    double tempMosfet = widget.currentSettings.settings.useFahrenheit ? cToF(escTelemetry.temp_mos) : escTelemetry.temp_mos;
    double tempMotor = widget.currentSettings.settings.useFahrenheit ? cToF(escTelemetry.temp_motor) : escTelemetry.temp_motor;
    // Around -99.9 is the value received if there is no/faulty temp sensor, Set to 0 so the gauges don't shit themselves
    if (tempMotor < -32) { tempMotor = 0; }

    String temperatureMosfet = widget.currentSettings.settings.useFahrenheit ? "$tempMosfet F" : "$tempMosfet C";
    //String temperatureMosfet1 = widget.currentSettings.settings.useFahrenheit ? "${cToF(escTelemetry.temp_mos_1)} F" : "${escTelemetry.temp_mos_1} C";
    //String temperatureMosfet2 = widget.currentSettings.settings.useFahrenheit ? "${cToF(escTelemetry.temp_mos_2)} F" : "${escTelemetry.temp_mos_2} C";
    //String temperatureMosfet3 = widget.currentSettings.settings.useFahrenheit ? "${cToF(escTelemetry.temp_mos_3)} F" : "${escTelemetry.temp_mos_3} C";
    String temperatureMotor = widget.currentSettings.settings.useFahrenheit ? "$tempMotor F" : "$tempMotor C";

    double speedMaxFromERPM = calculateSpeedKph(widget.currentSettings.settings.maxERPM);
    double speedMax = widget.currentSettings.settings.useImperial ? kphToMph(speedMaxFromERPM<80?speedMaxFromERPM:80) : speedMaxFromERPM<80?speedMaxFromERPM:80;
    double speedNow = widget.currentSettings.settings.useImperial ? kphToMph(calculateSpeedKph(escTelemetry.rpm)) : calculateSpeedKph(escTelemetry.rpm);
    //String speed = widget.currentSettings.settings.useImperial ? "$speedNow mph" : "$speedNow kph";

    //String distance = widget.currentSettings.settings.useImperial ? "${kmToMile(escTelemetry.tachometer_abs / 1000.0)} miles" : "${escTelemetry.tachometer_abs / 1000.0} km";
    double distanceTraveled = calculateDistanceKm(escTelemetry.tachometer_abs * 1.0);
    String distance = widget.currentSettings.settings.useImperial ? "${kmToMile(distanceTraveled)} miles" : "$distanceTraveled km";


    double efficiencyKm = calculateEfficiencyKm(distanceTraveled);
    double efficiencyGauge = widget.currentSettings.settings.useImperial ? kmToMile(efficiencyKm) : efficiencyKm;
    String efficiencyGaugeLabel = widget.currentSettings.settings.useImperial ? "Efficiency Wh/Mi" : "Efficiency Wh/Km";
    //String efficiency = widget.currentSettings.settings.useImperial ? "${kmToMile(efficiencyKm)} Wh/Mi" : "$efficiencyKm Wh/Km";

    double powerMax = widget.currentSettings.settings.batterySeriesCount * widget.currentSettings.settings.batteryCellMaxVoltage;
    double powerMinimum = widget.currentSettings.settings.batterySeriesCount * widget.currentSettings.settings.batteryCellMinVoltage;
    if (widget.deviceIsConnected) {
      averageVoltageInput = (0.25 * doublePrecision(escTelemetry.v_in, 1)) + (0.75 * averageVoltageInput);
    } else {
      averageVoltageInput = powerMinimum;
    }

    if (escTelemetry.battery_level != null) {
      batteryRemaining = (0.25 * escTelemetry.battery_level * 100) + (0.75 * batteryRemaining);
    }



    FlutterGauge _gaugeDutyCycle = FlutterGauge(activeColor: Colors.black, handSize: 30,index: escTelemetry.duty_now * 100,fontFamily: "Courier", start:-100, end: 100,number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));
    //TODO: if speed is less than start value of gauge this will error
    FlutterGauge _gaugeSpeed = FlutterGauge(numberInAndOut: NumberInAndOut.inside, index: speedNow, start: -5, end: speedMax.ceil().toInt(),counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.none,number: Number.all);

    FlutterGauge _gaugePowerRemaining = FlutterGauge(inactiveColor: Colors.red,activeColor: Colors.black,numberInAndOut: NumberInAndOut.inside, index: batteryRemaining,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,),widthCircle: 10,secondsMarker: SecondsMarker.secondsAndMinute,number: Number.all);
    FlutterGauge _gaugeVolts = FlutterGauge(inactiveColor: Colors.red,activeColor: Colors.black,hand: Hand.short,index: averageVoltageInput,fontFamily: "Courier",start: powerMinimum.floor().toInt(), end: powerMax.ceil().toInt(),number: Number.endAndCenterAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));
    //TODO: scale efficiency and adjust end value for imperial users
    FlutterGauge _gaugeEfficiency = FlutterGauge(reverseDial: true, reverseDigits: true, hand: Hand.short,index: efficiencyGauge,fontFamily: "Courier",start: 0, end: 42,number: Number.endAndStart,secondsMarker: SecondsMarker.secondsAndMinute,counterStyle: TextStyle(color: Theme.of(context).textTheme.bodyText1.color,fontSize: 25,));

    Oscilloscope scopeOne = Oscilloscope(
      backgroundColor: Colors.transparent,
      traceColor: Theme.of(context).accentColor,
      showYAxis: true,
      yAxisMax: 5.0,
      yAxisMin: -5.0,
      dataSet: motorCurrentGraphPoints,
    );

    //globalLogger.wtf(MediaQuery.of(context).size.height);
    //globalLogger.wtf(MediaQuery.of(context).size.width);

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

              Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Center( child:Text("Motor Current")),
                    Text("${doublePrecision(escTelemetry.current_motor, 2)}"),
                    SizedBox(width: doubleItemWidth, height: doubleItemWidth - 30, child: scopeOne),
                  ]),
            ],),

            Row(children: <Widget>[

              Column(  children: <Widget>[
                Center(child:Text("ESC")),
                Text(temperatureMosfet),
                SizedBox(
                    height:doubleItemWidth * 0.75,
                    width: doubleItemWidth,
                    child: Thermometer(
                      value: tempMosfet,
                      minValue: 0,
                      maxValue: widget.currentSettings.settings.useFahrenheit ? cToF(80) : 80,
                      label: widget.currentSettings.settings.useFahrenheit ? ThermometerLabel.farenheit():ThermometerLabel.celsius(),
                      scale: widget.currentSettings.settings.useFahrenheit ? IntervalScaleProvider(25) : IntervalScaleProvider(15),
                      mercuryColor: Colors.pink,
                      outlineColor: Theme.of(context).textTheme.bodyText1.color,
                    )
                ),
              ]),

              Column( children: <Widget>[
                Center(child:Text("Motor")),
                Text(temperatureMotor),
                SizedBox(
                    height: doubleItemWidth * 0.75,
                    width:doubleItemWidth,
                    child: Thermometer(
                      value: tempMotor,
                      minValue: 0,
                      maxValue: widget.currentSettings.settings.useFahrenheit ? cToF(90) : 90,
                      label: widget.currentSettings.settings.useFahrenheit ? ThermometerLabel.farenheit():ThermometerLabel.celsius(),
                      scale: widget.currentSettings.settings.useFahrenheit ? IntervalScaleProvider(25) : IntervalScaleProvider(15),
                      mercuryColor: Colors.pink,
                      outlineColor: Theme.of(context).textTheme.bodyText1.color,
                    )
                ),
              ]),

            ],),



            SizedBox(height: 10),

            Table(children: [
              TableRow(children: [
                Text("Distance Traveled: ", textAlign: TextAlign.right,),
                Text(" $distance")
              ]),
              TableRow(children: [
                Text("Watt Hours: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.watt_hours, 2)} Wh")
              ]),
              TableRow(children: [
                Text("Watt Hours Charged: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.watt_hours_charged, 2)} Wh")
              ]),


              TableRow(children: [
                Text("Amp Hours: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.amp_hours, 2)} Ah")
              ]),
              TableRow(children: [
                Text("Amp Hours Charged: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.amp_hours_charged, 2)} Ah")
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
                Text("Battery Current Now: ", textAlign: TextAlign.right,),
                Text(" ${doublePrecision(escTelemetry.current_in, 2)} A")
              ]),
              TableRow(children: [
                Text("ESC ID${widget.telemetryMap.length > 1 ? "s":""}: ", textAlign: TextAlign.right,),
                Text(" ${widget.telemetryMap.keys}")
              ]),
              TableRow(children: [
                Text("Fault Now: ", textAlign: TextAlign.right,),
                Text("${escTelemetry.fault_code.index == 0 ? " 0":" Code ${escTelemetry.fault_code.index}"}")
              ]),
            ],),
            escTelemetry.fault_code.index != 0 ? Center(child: Text("${escTelemetry.fault_code.toString().split('.')[1]}")) : Container(),
            SizedBox(height: 10),

            ///FlutterMapWidget
            Text("Mobile device position:"),
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
