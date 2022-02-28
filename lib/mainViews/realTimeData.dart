import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../hardwareSupport/escHelper/escHelper.dart';

import '../globalUtilities.dart';
import '../components/userSettings.dart';

import '../widgets/flutterMap.dart'; import 'package:latlong2/latlong.dart';

class RealTimeData extends StatefulWidget {

  RealTimeData(
      { this.routeTakenLocations,
        this.telemetryMap,
        @required this.currentSettings,
        this.startStopTelemetryFunc,

        this.deviceIsConnected,
      });

  final List<LatLng> routeTakenLocations;
  final UserSettings currentSettings;
  final Map<int, ESCTelemetry> telemetryMap;
  final ValueChanged<bool> startStopTelemetryFunc;

  final bool deviceIsConnected;

  RealTimeDataState createState() => new RealTimeDataState();

  static const String routeName = "/realtime";
}

class RealTimeDataState extends State<RealTimeData> {

  static List<double> motorCurrentGraphPoints = [];

  static double averageVoltageInput;

  static ESCTelemetry escTelemetry;

  double batteryRemaining;

  double rangeEstimateAverage;

  bool showWhWithRegen = true;
  int showPowerState = 0;
  bool showVoltsPerCell = false;
  bool showBatteryPercentage = false;
  bool showRangeEstimate = false;
  bool hideMap = false;
  bool settingsLoaded = false;

  bool allowFontResize = false;
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

  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    showWhWithRegen = prefs.getBool('rtShowWhWithRegen') ?? showWhWithRegen;
    showVoltsPerCell = prefs.getBool('rtShowVoltsPerCell') ?? showVoltsPerCell;
    showBatteryPercentage = prefs.getBool('rtShowBatteryPercentage') ?? showBatteryPercentage;
    showRangeEstimate = prefs.getBool('rtShowRangeEstimate') ?? showRangeEstimate;
    hideMap = prefs.getBool('rtShowMap') ?? hideMap;

    Future.delayed(Duration(milliseconds: 250), (){
      setState(() {
        showPowerState = showBatteryPercentage ? 2 : showVoltsPerCell ? 1 : 0;
        settingsLoaded = true;
      });
    });
  }

  void saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('rtShowWhWithRegen', showWhWithRegen);
    await prefs.setBool('rtShowVoltsPerCell', showVoltsPerCell);
    await prefs.setBool('rtShowBatteryPercentage', showBatteryPercentage);
    await prefs.setBool('rtShowRangeEstimate', showRangeEstimate);
    await prefs.setBool('rtShowMap', hideMap);
  }

  @override
  void initState() {
    super.initState();
    globalLogger.d("initState: realTimeData");
    loadSettings();
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

    double escSpeed = escTelemetry.speed;
    if (escSpeed == null) escSpeed = 0;
    double speedNow = widget.currentSettings.settings.useImperial ? kphToMph(calculateSpeedKph(escSpeed)) : escSpeed;

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
      batteryRemaining = (0.1 * escTelemetry.battery_level * 100) + (0.9 * batteryRemaining);
      if (batteryRemaining < 0.0) {
        globalLogger.e("Battery Remaining $batteryRemaining battery_level ${escTelemetry.battery_level} v_in ${escTelemetry.v_in}");
        batteryRemaining = 0;
      }
      if(batteryRemaining > 100.0) {
        batteryRemaining = 100.0;
      }
    }

    // Estimate range
    double rangeEstimate = (escTelemetry.battery_wh ?? 1) * (batteryRemaining / 100 ?? 1) / efficiency;
    if (rangeEstimateAverage == null) rangeEstimateAverage = rangeEstimate;
    if (rangeEstimate.isNaN || rangeEstimate.isInfinite) {
      rangeEstimate = 0;
      rangeEstimateAverage = 0;
    } else {
      rangeEstimateAverage = rangeEstimate * 0.1 + rangeEstimateAverage * 0.9;
    }

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
        saveSettings();
      },
      child: Container(
          decoration: boxDecoration,
          width: boxWidth,
          child: Padding(
              padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
              child: showWhWithRegen ? Column(
                children: [
                  FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text("Wh Total")),
                  FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text("${doublePrecision(escTelemetry.watt_hours - escTelemetry.watt_hours_charged, 1)}", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold))),
                ],
              ) :  Column(
                children: [
                  FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text("Wh Used")),
                  FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text("${doublePrecision(escTelemetry.watt_hours, 1)}", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold))),
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
              FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text("Duty Cycle")),
              FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text("${(escTelemetry.duty_now * 100).toInt()}%", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold))),
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
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("Battery Current")),
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
              FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text("Motor Current")),
              FittedBox(
                fit: BoxFit.fitWidth,
                child: Text("${doublePrecision(escTelemetry.current_motor, 1)} A", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ));

    Widget childOdometer = GestureDetector(
        onTap: () {
          setState(() {
            showRangeEstimate = !showRangeEstimate;
          });
          saveSettings();
        },
        child: Container(
        decoration: boxDecoration,
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: showRangeEstimate ? Column(
              children: [
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("Range")),
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("${doublePrecision(rangeEstimateAverage, 1)} ${widget.currentSettings.settings.useImperial ? "mi": "km"}", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                ),
              ],
            ) : Column(
              children: [
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("Odometer")),
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("$distance", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                ),
              ],
            )
        )));

    Widget childConsumption = Container(
        decoration: boxDecoration,
        width: boxWidth,
        child: Padding(
            padding: EdgeInsets.only(top: boxInnerPadding, bottom: boxInnerPadding),
            child: Column(
              children: [
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("$efficiencyGaugeLabel")),
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("$efficiency", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold))),
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
                  switch (++showPowerState) {
                    case 1:
                      showVoltsPerCell = true;
                      showBatteryPercentage = false;
                      break;
                    case 2:
                      showVoltsPerCell = false;
                      showBatteryPercentage = true;
                      break;
                    case 0:
                    default:
                      showVoltsPerCell = false;
                      showBatteryPercentage = false;
                      showPowerState = 0;
                  }
                });
                saveSettings();
              },
              child: showVoltsPerCell ? Column(
                children: [
                  FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text("Voltage/Cell")),
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("${doublePrecision(escTelemetry.v_in / widget.currentSettings.settings.batterySeriesCount, 2)} V", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                  ),
                ],
              ) : showBatteryPercentage ? Column(
                children: [
                  FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text("Battery")),
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("${batteryRemaining.toInt()} %", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                  ),
                ],
              ) : Column(
                children: [
                  FittedBox(
                      fit: BoxFit.fitWidth,
                      child: Text("Battery")),
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
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("ESC Temp")),
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
                FittedBox(
                    fit: BoxFit.fitWidth,
                    child: Text("Motor Temp")),
                FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text("$temperatureMotor", style: TextStyle(fontSize: fontSizeValues, fontWeight: FontWeight.bold)),
                ),
              ],
            )));

    if (settingsLoaded == false) {
      return Column(children: [
        Text("Fetching preferences")
      ],
      mainAxisAlignment: MainAxisAlignment.center,);
    }

    setLandscapeOrientation(enabled: true);

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
                    //TODO: remove font resizing
                    allowFontResize ? Positioned(
                        left:10,
                        child: Column(children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (++fontSizeValues > 50) fontSizeValues = 50;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.add_circle_outline, color: Theme.of(context).dialogBackgroundColor),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (--fontSizeValues < 14) fontSizeValues = 14;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.remove_circle, color: Theme.of(context).dialogBackgroundColor),
                          ),
                        ],)
                    ) : Container(),
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
                            child: Text("${doublePrecision(speedNow, 1)}", style: TextStyle(fontSize: 90, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
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
              saveSettings();
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
                    //TODO: remove font resizing
                    allowFontResize ? Positioned(
                        left:0,
                        child: Row(children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (--fontSizeValues < 14) fontSizeValues = 14;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.remove_circle, color: Theme.of(context).dialogBackgroundColor),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (++fontSizeValues > 50) fontSizeValues = 50;
                              });
                              globalLogger.d("Font Size: $fontSizeValues Screen W: ${MediaQuery.of(context).size.width.toInt()} H: ${MediaQuery.of(context).size.height.toInt()}");
                            },
                            child: Icon(Icons.add_circle_outline, color: Theme.of(context).dialogBackgroundColor),
                          )
                        ],)
                    ) : Container(),
                    Positioned(
                        top: 0,
                        right: 0,
                        child: escTelemetry.fault_code == mc_fault_code.FAULT_CODE_NONE ? Icon(Icons.check_circle_outline, color: Colors.green,) : Icon(Icons.warning, color: Colors.red)
                    ),
                    Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        escTelemetry.fault_code == mc_fault_code.FAULT_CODE_NONE ? Text("Speed") : Text("${escTelemetry.fault_code.toString().split('.')[1].substring(11)}"),
                        GestureDetector(onLongPress: (){
                          setState(() {
                            allowFontResize = !allowFontResize;
                          });
                        }, child: FittedBox(
                            fit: BoxFit.fitWidth,
                            child: Text("${doublePrecision(speedNow, 1)}", style: TextStyle(fontSize: 100, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
                        )),
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
                  saveSettings();
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
