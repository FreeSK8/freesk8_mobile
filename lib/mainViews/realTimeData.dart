import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';

import '../hardwareSupport/dieBieMSHelper.dart';
import '../hardwareSupport/escHelper/escHelper.dart';

import '../globalUtilities.dart';
import '../components/userSettings.dart';

import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../widgets/flutterMap.dart'; import 'package:latlong/latlong.dart';

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

  static List<double> motorCurrentGraphPoints = [];

  static double averageVoltageInput;

  static ESCTelemetry escTelemetry;

  double batteryRemaining;

  bool showWhWithRegen = true;
  bool showVoltsPerCell = false;
  bool hideMap = false;
  double fontSizeValues = 30;


  double calculateSpeedKph(double eRpm) {
    double ratio = 1.0 / widget.currentSettings.settings.gearRatio;
    int minutesToHour = 60;
    double ratioRpmSpeed = (ratio * minutesToHour * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles / 2) * 1e6);
    double speed = eRpm * ratioRpmSpeed;
    return doublePrecision(speed, 1);
  }

  double calculateDistanceKm(double eCount) {
    double ratio = 1.0 / widget.currentSettings.settings.gearRatio;
    double ratioPulseDistance = (ratio * widget.currentSettings.settings.wheelDiameterMillimeters * pi) / ((widget.currentSettings.settings.motorPoles * 3) * 1000000);
    double distance = eCount * ratioPulseDistance;
    return double.parse((distance).toStringAsFixed(2));
  }

  double calculateEfficiency(double distance) {
    double wh = (escTelemetry.watt_hours - escTelemetry.watt_hours_charged) / distance;
    if (wh.isNaN || wh.isInfinite) {
      wh = 0;
    }
    return double.parse((wh).toStringAsFixed(2));

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
                        Text(" Cell ${i + 1}"),

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
                  //TODO: Hiding SOC if value is 50% because the FlexiBMS always reports 50
                  Text(" ${widget.dieBieMSTelemetry.packVoltage} ${widget.dieBieMSTelemetry.soc != 50 ? "(${widget.dieBieMSTelemetry.soc}%)" : ""}", textScaleFactor: 1.25,)
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
                                    new AlwaysStoppedAnimation<Color>(Colors.orangeAccent) :
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
                            "  ${formatTriple.format(widget.dieBieMSTelemetry.cellVoltage[index].abs())} V",
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

    //TODO: Using COMM_GET_VALUE_SETUP for RT so map is not actually needed
    if (widget.telemetryMap.length == 0) {
      escTelemetry = new ESCTelemetry();
    } else {
      escTelemetry = widget.telemetryMap.values.first;
    }

    double tempMosfet = widget.currentSettings.settings.useFahrenheit ? cToF(escTelemetry.temp_mos) : escTelemetry.temp_mos;
    double tempMotor = widget.currentSettings.settings.useFahrenheit ? cToF(escTelemetry.temp_motor) : escTelemetry.temp_motor;

    double mosfetTempMapped = (escTelemetry.temp_mos - 45) / (90 - 45); // 45C min, 90C max
    double motorTempMapped = (escTelemetry.temp_motor - 45) / (90 - 45); // 45C min, 90C max
    Color colorMosfet = multiColorLerp(Colors.green, Colors.yellow, Colors.red, mosfetTempMapped);
    Color colorMotor = multiColorLerp(Colors.green, Colors.yellow, Colors.red, motorTempMapped);
    String temperatureMosfet = widget.currentSettings.settings.useFahrenheit ? "$tempMosfet F" : "$tempMosfet C";
    String temperatureMotor = widget.currentSettings.settings.useFahrenheit ? "$tempMotor F" : "$tempMotor C";

    double speedMaxFromERPM = calculateSpeedKph(widget.currentSettings.settings.maxERPM);
    if (speedMaxFromERPM > 142) speedMaxFromERPM = 142; //~88mph
    double speedMax = widget.currentSettings.settings.useImperial ? kphToMph(speedMaxFromERPM) : speedMaxFromERPM;
    double speedNow = widget.currentSettings.settings.useImperial ? kphToMph(calculateSpeedKph(escTelemetry.rpm)) : calculateSpeedKph(escTelemetry.rpm);

    double distanceTraveled = escTelemetry.tachometer_abs / 1000.0;
    if (widget.currentSettings.settings.useImperial) distanceTraveled = kmToMile(distanceTraveled);
    distanceTraveled = doublePrecision(distanceTraveled, 2);
    String distance = widget.currentSettings.settings.useImperial ? "$distanceTraveled mi" : "$distanceTraveled km";

    double efficiency = calculateEfficiency(distanceTraveled);
    String efficiencyGaugeLabel = widget.currentSettings.settings.useImperial ? "Wh/mi" : "Wh/km";

    double powerMax = widget.currentSettings.settings.batterySeriesCount * widget.currentSettings.settings.batteryCellMaxVoltage;
    double powerMinimum = widget.currentSettings.settings.batterySeriesCount * widget.currentSettings.settings.batteryCellMinVoltage;

    if (widget.deviceIsConnected) {
      averageVoltageInput ??= escTelemetry.v_in; // Set to current value if null
      if (averageVoltageInput == 0.0) { // Set to minimum if zero
        averageVoltageInput = powerMinimum;
      } else {
        // Smooth voltage input value from ESC
        averageVoltageInput = (0.25 * doublePrecision(escTelemetry.v_in, 1)) + (0.75 * averageVoltageInput);
      }
    } else {
      averageVoltageInput = 0; // Set to zero when disconnected
    }

    // Set initial batteryRemaining value
    if (batteryRemaining == null) {
      if (escTelemetry.battery_level != null) {
        batteryRemaining = escTelemetry.battery_level * 100;
      } else {
        batteryRemaining = 0;
      }
    }

    // Smooth battery remaining from ESC
    if (escTelemetry.battery_level != null) {
      batteryRemaining = (0.25 * escTelemetry.battery_level * 100) + (0.75 * batteryRemaining);
      if (batteryRemaining < 0.0) {
        globalLogger.e("Battery Remaining $batteryRemaining battery_level ${escTelemetry.battery_level} v_in ${escTelemetry.v_in}");
        batteryRemaining = 0;
      }
      if(batteryRemaining > 100.0) {
        batteryRemaining = 100.0;
      }
    }

    //globalLogger.wtf("W: ${MediaQuery.of(context).size.width} H: ${MediaQuery.of(context).size.height}");

    Color boxBgColor = Theme.of(context).dialogBackgroundColor;
    double cellVoltage = escTelemetry.v_in / widget.currentSettings.settings.batterySeriesCount;

    // Compute color for cell voltage
    final double voltageMapped = (cellVoltage - widget.currentSettings.settings.batteryCellMinVoltage) / (widget.currentSettings.settings.batteryCellMaxVoltage - widget.currentSettings.settings.batteryCellMinVoltage);
    Color colorCellVoltage = multiColorLerp(Colors.red, Colors.yellow, Colors.green, voltageMapped);

    final bool landscapeView = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final int boxSpacing = 5;
    double boxInnerPadding;
    double boxWidth;
    if (landscapeView) {
      boxInnerPadding = 4;
      boxWidth = MediaQuery.of(context).size.width / (hideMap ? 4 : 6) - boxSpacing;
    } else {
      boxInnerPadding = hideMap ? 15 : 2;
      boxWidth = MediaQuery.of(context).size.width / 3 - boxSpacing;
    }


    BoxDecoration boxDecoration = BoxDecoration(
        color: Theme.of(context).dialogBackgroundColor,
        borderRadius: BorderRadius.circular(5),

        gradient: LinearGradient(
          tileMode: TileMode.repeated,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.9, 1.0],
          colors: [
            Theme.of(context).dialogBackgroundColor,
            Theme.of(context).dialogBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        )
    );

    Widget childWhTotal = GestureDetector(
      onTap: () {
        setState(() {
          showWhWithRegen = !showWhWithRegen;
        });
      },
      child: Container(
          decoration: boxDecoration,
          width: boxWidth,
          child: Padding(
              padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
              child: showWhWithRegen ? Column(
                children: [
                  Text("Wh Total"),
                  Text("${doublePrecision(escTelemetry.watt_hours - escTelemetry.watt_hours_charged, 1)}", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                ],
              ) :  Column(
                children: [
                  Text("Wh Used"),
                  Text("${doublePrecision(escTelemetry.watt_hours, 1)}", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                ],
              )
          )),
    );

    Widget childDutyCycle = Container(
      decoration: boxDecoration,
      width: boxWidth,
      child: Padding(
          padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
          child: Column(
            children: [
              Text("Duty Cycle"),
              Text("${(escTelemetry.duty_now * 100).toInt()}%", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
            ],
          )),
    );

    Widget childBatteryCurrent = Container(
        decoration: boxDecoration,
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: Column(
              children: [
                Text("Battery Current"),
                FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text("${doublePrecision(escTelemetry.current_in, 1)} A", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                ),
              ],
            )));

    Widget childMotorCurrent = Container(
        decoration: boxDecoration,
        width: boxWidth,
        child: Padding(
          padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
          child: Column(
            children: [
              Text("Motor Current"),
              FittedBox(
                fit: BoxFit.fitWidth,
                child: Text("${doublePrecision(escTelemetry.current_motor, 1)} A", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ));

    Widget childOdometer = Container(
        decoration: boxDecoration,
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: Column(
              children: [
                Text("Odometer"),
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("$distance", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                ),
              ],
            )));

    Widget childConsumption = Container(
        decoration: boxDecoration,
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: Column(
              children: [
                Text("$efficiencyGaugeLabel"),
                Text("$efficiency", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
              ],
            )));

    Widget childBattery = Container(
        decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(5),

            gradient: LinearGradient(
              tileMode: TileMode.repeated,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.4, 1.0],
              colors: [
                Theme.of(context).dialogBackgroundColor,
                Theme.of(context).dialogBackgroundColor,
                colorCellVoltage,
              ],
            )
        ),
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showVoltsPerCell = !showVoltsPerCell;
                });
              },
              child: showVoltsPerCell ? Column(
                children: [
                  Text("Voltage/Cell"),
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("${doublePrecision(escTelemetry.v_in / widget.currentSettings.settings.batterySeriesCount, 2)} V", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                  ),
                ],
              ) : Column(
                children: [
                  Text("Battery"),
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("${doublePrecision(escTelemetry.v_in, 1)} V", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )));

    Widget childMosfetTemp = Container(
        decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(5),

            gradient: LinearGradient(
              tileMode: TileMode.repeated,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.4, 1.0],
              colors: [
                Theme.of(context).dialogBackgroundColor,
                Theme.of(context).dialogBackgroundColor,
                colorMosfet,
              ],
            )
        ),
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: Column(
              children: [
                Text("ESC Temp"),
                FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text("$temperatureMosfet", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                ),
              ],
            )));

    Widget childMotorTemp = Container(
        decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(5),

            gradient: LinearGradient(
              tileMode: TileMode.repeated,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.4, 1.0],
              colors: [
                Theme.of(context).dialogBackgroundColor,
                Theme.of(context).dialogBackgroundColor,
                colorMotor,
              ],
            )
        ),
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: Column(
              children: [
                Text("Motor Temp"),
                FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text("$temperatureMotor", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                ),
              ],
            )));

    // Return Widget Tree
    if (landscapeView) {
      // Landscape Layout
      return Row(
        children: [
          Spacer(),
          Column(
            children: [
              Spacer(),
              Container(
                width: MediaQuery.of(context).size.width * 0.25,
                height: MediaQuery.of(context).size.height * 0.45,
                child: Stack(
                  children: [
                    Positioned(
                        left:10,
                        child: Column(children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                fontSizeValues += 1.0;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.add_circle_outline, color: Theme.of(context).dialogBackgroundColor),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                fontSizeValues -= 1.0;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.remove_circle, color: Theme.of(context).dialogBackgroundColor),
                          ),
                        ],)
                    ),
                    Positioned(
                        top: 0,
                        right: 0,
                        child: escTelemetry.fault_code == mc_fault_code.FAULT_CODE_NONE ? Icon(Icons.check_circle_outline, color: Colors.green,) : Icon(Icons.warning, color: Colors.red)
                    ),
                    Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        escTelemetry.fault_code == mc_fault_code.FAULT_CODE_NONE ? Text("Speed") : Text("${escTelemetry.fault_code.toString().split('.')[1].substring(11)}"),
                        FittedBox(
                            fit: BoxFit.fitWidth,
                            child: Text("$speedNow", style: TextStyle(fontSize: 90, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                        ),
                      ],
                    ),)
                  ],
                ),
              ),


              Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Duty Cycle"),
                  Text("${(escTelemetry.duty_now * 100).toInt()}%", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                ],
              ),
              Spacer(),
            ],
          ),
          Spacer(),
          Column(
            children: [
              Spacer(),
              childBattery,

              Spacer(),
              childWhTotal,

              Spacer(),
              childMotorCurrent,

              Spacer(),
              childBatteryCurrent,
              Spacer(),
            ],
          ),
          Spacer(),
          Column(
            children: [
              Spacer(),
              childOdometer,

              Spacer(),
              childConsumption,

              Spacer(),
              childMosfetTemp,

              Spacer(),
              childMotorTemp,
              Spacer(),
            ],
          ),
          Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                hideMap = !hideMap;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                  color: boxBgColor,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15))
              ),
              height: MediaQuery.of(context).size.height,
              child: RotatedBox(quarterTurns: 3, child: Text("${hideMap ? "Show Map" : "Hide Map"}", textAlign: TextAlign.center,),),
            ),
          ),

          hideMap ? Container() :
          Container(
            width: MediaQuery.of(context).size.width * 0.30,
            child: new FlutterMapWidget(routeTakenLocations: widget.routeTakenLocations,),
          )

        ],
      );
    } else {
      // Portrait Layout
      return Column(
        children: [
          Spacer(),
          Row(
            children: [
              Spacer(),
              Container(
                height: MediaQuery.of(context).size.width * 0.4,
                width: MediaQuery.of(context).size.width * 0.75,
                child: Stack(
                  children: [

                    Positioned(
                        left:0,
                        child: Row(children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                fontSizeValues -= 1.0;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.remove_circle, color: Theme.of(context).dialogBackgroundColor),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                fontSizeValues += 1.0;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.add_circle_outline, color: Theme.of(context).dialogBackgroundColor),
                          )
                        ],)
                    ),
                    Positioned(
                        top: 0,
                        right: 0,
                        child: escTelemetry.fault_code == mc_fault_code.FAULT_CODE_NONE ? Icon(Icons.check_circle_outline, color: Colors.green,) : Icon(Icons.warning, color: Colors.red)
                    ),
                    Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        escTelemetry.fault_code == mc_fault_code.FAULT_CODE_NONE ? Text("Speed") : Text("${escTelemetry.fault_code.toString().split('.')[1].substring(11)}"),
                        FittedBox(
                            fit: BoxFit.fitWidth,
                            child: Text("$speedNow", style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                        ),
                      ],
                    ))
                  ],
                ),
              ),

              Spacer(),

            ],
          ),
          Spacer(),
          Row(
              children: [
                Spacer(),
                childDutyCycle,
                Spacer(),
                childMotorCurrent,
                Spacer(),
                childOdometer,
                Spacer(),
              ]
          ),
          Spacer(),
          Row(
              children: [
                Spacer(),
                childWhTotal,
                Spacer(),
                childBatteryCurrent,
                Spacer(),
                childConsumption,
                Spacer(),
              ]
          ),
          Spacer(),
          Row(
              children: [
                Spacer(),
                childBattery,
                Spacer(),
                childMosfetTemp,
                Spacer(),
                childMotorTemp,
                Spacer(),
              ]
          ),
          Spacer(),
          Column(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    hideMap = !hideMap;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                      color: boxBgColor,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15))
                  ),
                  width: MediaQuery.of(context).size.width,
                  child: RotatedBox(quarterTurns: 0, child: Text("${hideMap ? "Show Map" : "Hide Map"}", textAlign: TextAlign.center,),),
                )
              ),
              hideMap ? Container() :
              Container(
                height: MediaQuery.of(context).size.width * 0.6,
                width: MediaQuery.of(context).size.width,
                child: new FlutterMapWidget(routeTakenLocations: widget.routeTakenLocations,),
              ),
            ],
          ),

        ],
      );
    }
  }
}
