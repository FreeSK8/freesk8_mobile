
import 'dart:convert';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../globalUtilities.dart';

import 'package:multiselect_formfield/multiselect_formfield.dart';

import '../widgets/sliderThumbImage.dart';
import 'dart:ui' as ui;

class gotchiProConfiguration {
  int wifi_ssid_len;
  int wifi_pass_len;
  String wifi_ssid;
  String wifi_pass;
  List<int> multiESCIDs;
  int cfgVersion;
  gotchiProConfiguration({
    this.wifi_ssid_len,
    this.wifi_pass_len,
    this.wifi_ssid,
    this.wifi_pass,
    this.multiESCIDs,
    this.cfgVersion,
  });
}

class gotchiProCfgEditorArguments {
  final BluetoothCharacteristic txLoggerCharacteristic;
  final gotchiProConfiguration currentConfiguration;
  gotchiProCfgEditorArguments({this.txLoggerCharacteristic, this.currentConfiguration});
}


class gotchiProCfgEditor extends StatefulWidget {
  @override
  gotchiProCfgEditorState createState() => gotchiProCfgEditorState();

  static const String routeName = "/gotchinetcfgedit";
}

class gotchiProCfgEditorState extends State<gotchiProCfgEditor> {


  List<DropdownMenuItem<ListItem>> _dropdownMenuItems;
  ListItem _selectedItem;

  TextEditingController ssidInput = TextEditingController();
  TextEditingController passInput = TextEditingController();


  int timeToPlay = 0;
  ui.Image sliderImage;
  Future<ui.Image> load(String asset) async {
    ByteData data = await rootBundle.load(asset);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  @override
  void initState() {
    load('assets/butt.png').then((image) {
      setState(() {
        sliderImage = image;
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _selectedItem = null;
    ssidInput.dispose();
    passInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    globalLogger.d("Building gotchiProCfgEditor");

    // Check for valid arguments while building this widget
    gotchiProCfgEditorArguments myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No arguments. BUG BUG. This should not happen. Please fix?"));
    }

    // Add listeners to text editing controllers for value validation
    ssidInput.addListener(() {
      myArguments.currentConfiguration.wifi_ssid = ssidInput.text;
    });

    // Add listeners to text editing controllers for value validation
    passInput.addListener(() {
      myArguments.currentConfiguration.wifi_pass = passInput.text;
    });

    return Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon( Icons.perm_data_setting,
              size: 35.0,
              color: Theme.of(context).accentColor,
            ),
            Text("sk8net Config"),
          ],),
        ),
        body: SafeArea(
          child: GestureDetector(
              onTap: () {
                // Hide the keyboard
                FocusScope.of(context).requestFocus(new FocusNode());
              },
              child: ListView(
                padding: EdgeInsets.all(10),
                children: <Widget>[
                  GestureDetector(
                    onTap: (){
                      setState(() {
                        if (++timeToPlay > 3) {
                          timeToPlay = 0;
                        }
                      });
                    },
                    child: Icon(
                      Icons.settings,
                      size: 60.0,
                      color: Colors.blue,
                    )
                  ),

                  TextField(
                      controller:ssidInput,
                      decoration: new InputDecoration(labelText: "WiFi SSID"),
                      keyboardType: TextInputType.text,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.singleLineFormatter
                      ]
                  ),
                  TextField(
                      controller: passInput,
                      decoration: new InputDecoration(labelText: "WiFi Password"),
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.singleLineFormatter
                      ]
                  ),
                  Divider(thickness: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ElevatedButton(child:
                      Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Icon(Icons.cancel),Text("Cancel"),],),
                          onPressed: () {
                            Navigator.of(context).pop();
                          }),

                      SizedBox(width: 10,),
                      ElevatedButton(child:
                      Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Save"),Icon(Icons.save),],),
                          onPressed: () async {

                            myArguments.currentConfiguration.wifi_ssid_len = myArguments.currentConfiguration.wifi_ssid.length;
                            myArguments.currentConfiguration.wifi_pass_len = myArguments.currentConfiguration.wifi_pass.length;

                            //TODO: Add Device Name to configuration
                            String newConfigCMD = "setnetcfg,${myArguments.currentConfiguration.cfgVersion}"
                                ",${myArguments.currentConfiguration.wifi_ssid_len}"
                                ",${myArguments.currentConfiguration.wifi_ssid}"
                                ",${myArguments.currentConfiguration.wifi_pass_len}"
                                ",${myArguments.currentConfiguration.wifi_pass}~";

                            // Save
                            globalLogger.d("Save parameters: $newConfigCMD");
                            await myArguments.txLoggerCharacteristic.write(utf8.encode(newConfigCMD)).catchError((error){
                              globalLogger.e("Save exception: ${error.toString()}");
                              // Do nothing
                              return;
                            });
                          })
                    ],)
                ],
              )
          ),
        )
    );
  }
}
