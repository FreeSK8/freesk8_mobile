import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:freesk8_mobile/escHelper.dart';

import 'package:freesk8_mobile/globalUtilities.dart';

class ESCProfileEditorArguments {
  final BluetoothCharacteristic txCharacteristic;
  final ESCProfile profile;
  final int profileIndex;
  ESCProfileEditorArguments(this.txCharacteristic, this.profile, this.profileIndex);
}

class ESCProfileEditor extends StatefulWidget {
  @override
  ESCProfileEditorState createState() => ESCProfileEditorState();

  static const String routeName = "/escprofileedit";
}


class ESCProfileEditorState extends State<ESCProfileEditor> {

  TextEditingController tecProfileName = TextEditingController();
  TextEditingController tecSpeedLimitFwd = TextEditingController();
  TextEditingController tecSpeedLimitRev = TextEditingController();
  TextEditingController tecCurrentMax = TextEditingController();
  TextEditingController tecCurrentMin = TextEditingController();
  bool enablePowerLimit;
  TextEditingController tecWattsMax = TextEditingController();
  TextEditingController tecWattsMin = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    tecProfileName.dispose();
    tecSpeedLimitFwd.dispose();
    tecSpeedLimitRev.dispose();
    tecCurrentMax.dispose();
    tecCurrentMin.dispose();
    tecWattsMax.dispose();
    tecWattsMin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Building ESCProfileEditor");

    // Check for valid arguments while building this widget
    ESCProfileEditorArguments myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No arguments. BUG BUG."));
    }

    // Add listeners to text editing controllers
    tecProfileName.addListener(() {
      myArguments.profile.profileName = tecProfileName.text;
      if (tecProfileName.text.length > 12) {
        setState(() {
          myArguments.profile.profileName = tecProfileName.text.substring(0,12);
          tecProfileName.selection = TextSelection.fromPosition(TextPosition(offset: myArguments.profile.profileName.length));
        });
      }
    });
    tecSpeedLimitFwd.addListener(() {
      myArguments.profile.speedKmh = double.tryParse(tecSpeedLimitFwd.text);
      if (myArguments.profile.speedKmh > 128) {
        setState(() {
          myArguments.profile.speedKmh = 128;
        });
      }
    });
    tecSpeedLimitRev.addListener(() {
      myArguments.profile.speedKmhRev = double.tryParse(tecSpeedLimitRev.text);
      if (myArguments.profile.speedKmhRev > 0.0) {
        setState(() {
          myArguments.profile.speedKmhRev = -myArguments.profile.speedKmhRev;
        });
      }
    });
    tecCurrentMax.addListener(() {
      double userInput = double.tryParse(tecCurrentMax.text) / 100; //TODO: null / 0
      myArguments.profile.l_current_max_scale =  userInput;
      if(userInput < 0.0 || userInput > 1.0) {
        setState(() {
          myArguments.profile.l_current_max_scale = 1.0;
        });
      }
    });
    tecCurrentMin.addListener(() {
      double userInput = double.tryParse(tecCurrentMin.text) / 100; //TODO: null / 0
      myArguments.profile.l_current_min_scale =  userInput;
      if(userInput < 0.0 || userInput > 1.0) {
        setState(() {
          myArguments.profile.l_current_min_scale = 1.0;
        });
      }
    });
    tecWattsMax.addListener(() { myArguments.profile.l_watt_max = double.tryParse(tecWattsMax.text); });
    tecWattsMin.addListener(() { myArguments.profile.l_watt_min = double.tryParse(tecWattsMin.text); });

    // Set text editing controller values to arguments received
    tecProfileName.text = myArguments.profile.profileName;
    tecSpeedLimitFwd.text = myArguments.profile.speedKmh.toString();
    tecSpeedLimitRev.text = myArguments.profile.speedKmhRev.toString();
    tecCurrentMax.text = (myArguments.profile.l_current_max_scale * 100).toString();
    tecCurrentMin.text = (myArguments.profile.l_current_min_scale * 100).toString();
    tecWattsMax.text = myArguments.profile.l_watt_max.toString();
    tecWattsMin.text = myArguments.profile.l_watt_min.toString();

    return Scaffold(
      appBar: AppBar(
        title: Row(children: <Widget>[
          Icon( Icons.edit,
            size: 35.0,
            color: Theme.of(context).accentColor,
          ),
          Text("ESC Profile Editor"),
        ],),
      ),
      body: GestureDetector(
          onTap: () {
            // Hide the keyboard
            FocusScope.of(context).requestFocus(new FocusNode());
          },
          child: ListView(
            padding: EdgeInsets.all(10),
            children: <Widget>[
              Icon(
                Icons.timer,
                size: 60.0,
                color: Colors.blue,
              ),

              TextField(
                controller: tecProfileName,
                decoration: new InputDecoration(labelText: "Profile Name"),
                keyboardType: TextInputType.text,

              ),

              TextField(
                  controller: tecSpeedLimitFwd,
                  decoration: new InputDecoration(labelText: "Speed Limit Forward (km/h)"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    NumberTextInputFormatter() //This allows for negative doubles
                  ]
              ),
              TextField(
                  controller: tecSpeedLimitRev,
                  decoration: new InputDecoration(labelText: "Speed Limit Reverse (km/h)"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    NumberTextInputFormatter() //This allows for negative doubles
                  ]
              ),

              Divider(thickness: 3),

              TextField(
                  controller: tecCurrentMax,
                  decoration: new InputDecoration(labelText: "Motor Current Acceleration Scale (%)"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    NumberTextInputFormatter() //This allows for negative doubles
                  ]
              ),
              TextField(
                  controller: tecCurrentMin,
                  decoration: new InputDecoration(labelText: "Motor Current Brake Scale (%)"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    NumberTextInputFormatter() //This allows for negative doubles
                  ]
              ),

              Divider(thickness: 3),

              TextField(
                  controller: tecWattsMax,
                  decoration: new InputDecoration(labelText: "Power Limit Maximum (0.0 = No Change)"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    NumberTextInputFormatter() //This allows for negative doubles
                  ]
              ),
              TextField(
                  controller: tecWattsMin,
                  decoration: new InputDecoration(labelText: "Power Limit Regen (0.0 = No Change)"),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    NumberTextInputFormatter() //This allows for negative doubles
                  ]
              ),


              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RaisedButton(child:
                  Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Cancel"),Icon(Icons.cancel),],),
                      onPressed: () {
                        Navigator.of(context).pop();
                      }),

                  SizedBox(width: 10,),
                  RaisedButton(child:
                  Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Save"),Icon(Icons.save),],),
                      onPressed: () async {
                        await ESCHelper.setESCProfile(myArguments.profileIndex, myArguments.profile);
                        Navigator.of(context).pop();
                      })
                ],)
            ],
          )
      )
    );
  }
}
