import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:freesk8_mobile/bleHelper.dart';
import 'package:freesk8_mobile/escHelper.dart';

import 'package:freesk8_mobile/globalUtilities.dart';

class FOCWizardArguments {
  final BluetoothCharacteristic txCharacteristic;
  final BLEHelper bleHelper;
  final Uint8List escMotorConfigurationDefaults;

  FOCWizardArguments(this.txCharacteristic, this.bleHelper, this.escMotorConfigurationDefaults);
}

class Dialogs {
  static Future<void> showLoadingDialog(
      BuildContext context, GlobalKey key) async {
    return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new WillPopScope(
              onWillPop: () async => false,
              child: SimpleDialog(
                  key: key,
                  backgroundColor: Colors.black54,
                  children: <Widget>[
                    Center(
                      child: Column(children: [
                        Icon(Icons.watch_later, size: 80,),
                        SizedBox(height: 10,),
                        Text("Please Wait...."),
                        Text("Be sure the wheels are off the ground!")
                      ]),
                    )
                  ]));
        });
  }
}

class ConfigureESC extends StatefulWidget {
  @override
  ConfigureESCState createState() => ConfigureESCState();

  static const String routeName = "/focwizard";
}


class ConfigureESCState extends State<ConfigureESC> {
  int currentStepIndex = 0;
  static bool loadESCDefaults = false;

  static bool focDetectCANDevices = true;
  static int focDetectMaxLosses = 60;
  static int focDetectOpenloopErpm = 700;
  static int focDetectSensorlessErpm = 4000;
  static double focDetectMaxBatteryAmps = 0.0;
  static double focDetectMinBatteryAmps = 0.0;

  TextEditingController tecBatteryCurrentRegen = TextEditingController();
  TextEditingController tecBatteryCurrentOutput = TextEditingController();

  final GlobalKey<State> _keyLoader = new GlobalKey<State>();

  @override
  void initState() {
    super.initState();
    loadESCDefaults = false;
    tecBatteryCurrentRegen.addListener(() {
      focDetectMinBatteryAmps = double.tryParse(tecBatteryCurrentRegen.text); //Try parse so we don't throw
      if(focDetectMinBatteryAmps==null) focDetectMinBatteryAmps = 0.0; //Ensure not null
      if(focDetectMinBatteryAmps>0.0) focDetectMinBatteryAmps *= -1; //Ensure negative
    });
    tecBatteryCurrentOutput.addListener(() {
      focDetectMaxBatteryAmps = double.tryParse(tecBatteryCurrentOutput.text); //Try parse so we don't throw
      if(focDetectMaxBatteryAmps==null) focDetectMaxBatteryAmps = 0.0; //Ensure not null
    });
  }

  @override
  void dispose() {
    tecBatteryCurrentRegen.dispose();
    tecBatteryCurrentOutput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Building focWizard");

    const int numberOfSteps = 3;

    //Receive arguments building this widget
    FOCWizardArguments myArguments = ModalRoute.of(context).settings.arguments;
    //print("arguments passed to creation: $myArguments");
    if(myArguments == null){
      return Container(child:Text("No arguments. BUG BUG."));
    }

    tecBatteryCurrentRegen.text = focDetectMinBatteryAmps.toString();
    tecBatteryCurrentOutput.text = focDetectMaxBatteryAmps.toString();

    List<Step> mySteps = [
      Step(
          title: Text("Step 1: Notice"),
          content: Text("This is a partial implementation of the FOC detection wizard. Intended for medium size outrunner motors. If you've replaced your motors or switched the phase leads this is totally cool. Otherwise, please use another tool."),
          isActive: currentStepIndex == 0? true: false),

      Step(
          title: Text("Step 2: Battery limits"),
          subtitle: Text("(optional) Specify charge and discharge amps"),
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            TextField(
                controller: tecBatteryCurrentRegen,
                decoration: new InputDecoration(labelText: "Battery Input Current Limit (0.0 = Defaults)"),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  NumberTextInputFormatter() //This allows for negative doubles
                ]
            ),
            TextField(
                controller: tecBatteryCurrentOutput,
                decoration: new InputDecoration(labelText: "Battery Output Current Limit (0.0 = Defaults)"),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  WhitelistingTextInputFormatter(RegExp(r'^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)$'))
                ]
            ),
          ],),
          isActive: currentStepIndex == 1? true: false),

      Step(
          title: Text("Step 3: Run Detection"),
          subtitle: Text("Watch out, the wheels will go skrrrrrrrr"),
          content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            SizedBox(height: 80, child: ListView( children: <Widget>[
              SwitchListTile(
                title: Text("Reset ESC motor configuration before detection (not functional)"),
                value: loadESCDefaults,
                onChanged: (bool newValue) { setState(() {
                  loadESCDefaults = newValue;
                }); },
                secondary: const Icon(Icons.loop),
              ),
            ],)),
          ],),
          isActive: currentStepIndex == 2? true: false),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: <Widget>[
          Icon( Icons.donut_large,
            size: 35.0,
            color: Colors.blue,
          ),
          Text("FOC Wizard"),
        ],),
      ),
      body: Stepper(
        // Using a variable here for handling the currentStep
        currentStep: this.currentStepIndex,
        // List the steps you would like to have
        steps: mySteps,
        // Define the type of Stepper style
        // StepperType.horizontal :  Horizontal Style
        // StepperType.vertical   :  Vertical Style
        type: StepperType.vertical,
        // Know the step that is tapped
        onStepTapped: (step) {
          // On hitting step itself, change the state and jump to that step
          setState(() {
            // update the variable handling the current step value
            // jump to the tapped step
            currentStepIndex = step;
          });
          // Log function call
          print("onStepTapped : " + step.toString());
        },
        onStepCancel: () {
          // On hitting cancel button, change the state
          if( currentStepIndex == 0 ) {
            Navigator.of(context).pop();
          } else {
            setState(() {
              --currentStepIndex;
            });
          }


          // Log function call
          print("onStepCancel : " + currentStepIndex.toString());
        },
        // On hitting continue button, change the state
        onStepContinue: () {

          setState(() {
            // On the last step
            if (currentStepIndex == numberOfSteps - 1) {
              Dialogs.showLoadingDialog(context, _keyLoader);
              //TODO: implement reception and
              if(loadESCDefaults) {
                //TODO: request MCCONF DEFAULT and wait for response
                //myArguments.txCharacteristic.write([0x02,0x01,0x0f,0xf1,0xef,0x03]).then((value){
                //  print("Requested MCCONF DEFAULT");
                //});
                //TODO: set MCCONF from response data. Passing via arguments will most likely not work
                if(myArguments.escMotorConfigurationDefaults != null){
                  print("Have MCCONF DEFAULT but don't know what to do with it yet");
                  int mcconfPacketLength = myArguments.escMotorConfigurationDefaults.length;
                  var byteData = new ByteData(mcconfPacketLength + 6); //<start><len><len2><payload><crc><crc2><end>
                  byteData.setUint8(0, 0x03);
                  byteData.setUint16(1, mcconfPacketLength);
                  byteData.setUint8(3, COMM_PACKET_ID.COMM_SET_MCCONF.index);
                  //byteData.set
                  //myArguments.txCharacteristic.write([]).then((value){
                  //  print("Set MCCONF defaults");
                  //});
                  //FW5.1//BleUart::writeData(): "03 01 b6 0d dc 73 3e bd 01 00 02 00 42 70 00 00 c2 70 00 00 42 c6 00 00 c2 70 00 00 43 16 00 00 c7 c3 50 00 47 c3 50 00 3f 4c cc cd 43 96 00 00 44 bb 80 00 41 00 00 00 42 64 00 00 41 20 00 00 41 00 00 00 01 42 aa 00 00 42 c8 00 00 42 aa 00 00 42 c8 00 00 3e 19 99 9a 3b a3 d7 0a 3f 73 33 33 49 b7 1b 00 c9 b7 1b 00 3f 80 00 00 3f 80 00 00 3f 80 00 00 43 16 00 00 44 89 80 00 41 20 00 00 42 78 00 00 3f 4c cc cd 47 9c 40 00 44 16 00 00 ff 01 03 02 05 06 04 ff 44 fa 00 00 3c f5 c2 8f 42 48 00 00 46 c3 50 00 3d f5 c2 8f 00 43 34 00 00 40 e0 00 00 3f 80 00 00 3f 80 00 00 3f d3 33 33 3f d3 33 33 3f 00 00 00 00 44 fa 00 00 46 ea 60 00 36 ea e1 8b 3c 75 c2 8f 3b 20 90 2e 4c ab a9 50 3d 4c cc cd 41 20 00 00 43 48 00 00 43 c8 00 00 3d cc cc cd 3d cc cc cd 00 00 00 00 00 00 00 00 ff ff ff ff ff ff ff ff 45 1c 40 00 00 00 00 00 00 00 00 41 c8 00 00 3d cc cc cd 02 00 41 a0 00 00 40 80 00 00 41 20 00 00 44 fa 00 00 00 41 3a 83 12 6f 01 00 c8 00 00 3d cc cc cd 3c f5 c2 8f 42 48 00 00 3b 83 12 6f 3b 83 12 6f 38 d1 b7 17 3e 4c cc cd 44 61 00 00 01 3c f5 c2 8f 00 00 00 00 39 d1 b7 17 3e 4c cc cd 3f 80 00 00 3c 23 d7 0a 3d 4c cc cd 3b 96 bb 99 3d 23 d7 0a 00 00 01 f4 3c a3 d7 0a 3f 00 00 00 00 00 20 00 00 00 00 10 45 3b 80 00 47 08 b8 00 46 c3 50 00 45 53 40 00 00 00 3f 1c 28 f6 0e 40 40 00 00 3d a9 fb e7 00 03 40 c0 00 00 75 e9 03" ../vesc_tool/bleuart.cpp: 132
                }
              }
              /// FOC Detection packet
              //    vb.vbAppendInt8(COMM_DETECT_APPLY_ALL_FOC);
              //    vb.vbAppendInt8(detect_can);
              //    vb.vbAppendDouble32(max_power_loss, 1e3);
              //    vb.vbAppendDouble32(min_current_in, 1e3);
              //    vb.vbAppendDouble32(max_current_in, 1e3);
              //    vb.vbAppendDouble32(openloop_rpm, 1e3);
              //    vb.vbAppendDouble32(sl_erpm, 1e3);
              const int focDetectPacketPayloadLength = 22;
              var byteData = new ByteData(focDetectPacketPayloadLength + 5); //<start><len><payload><crc><crc2><end>
              byteData.setUint8(0, 0x02); //Start of packet
              byteData.setUint8(1, focDetectPacketPayloadLength);
              byteData.setUint8(2, COMM_PACKET_ID.COMM_DETECT_APPLY_ALL_FOC.index);
              byteData.setUint8(3, focDetectCANDevices ? 1 : 0);
              byteData.setInt32(4, focDetectMaxLosses * 1000);
              byteData.setInt32(8, (focDetectMinBatteryAmps * 1000).round());
              byteData.setInt32(12, (focDetectMaxBatteryAmps * 1000).round());
              byteData.setInt32(16, focDetectOpenloopErpm * 1000);
              byteData.setInt32(20, focDetectSensorlessErpm * 1000);
              int checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, focDetectPacketPayloadLength);
              byteData.setUint16(24, checksum);
              byteData.setUint8(26, 0x03); //End of packet

              print("FOC Detection packet: ${byteData.buffer.asUint8List()}");

              myArguments.txCharacteristic.write(byteData.buffer.asUint8List()).then((value){
                print("FOC Detection packet is off off and away...");
              });
            } else {
              // Increment the step counter
              ++currentStepIndex;
            }

          });
          // Log function call
          print("onStepContinue : " + currentStepIndex.toString());
        },
      ),
    );
  }
}

