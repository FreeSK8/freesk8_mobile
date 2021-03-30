
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

import '../globalUtilities.dart';

import 'package:multiselect_formfield/multiselect_formfield.dart';

import '../widgets/sliderThumbImage.dart';
import 'dart:ui' as ui;

class RobogotchiConfiguration {
  int logAutoStopIdleTime;
  double logAutoStopLowVoltage;
  int logAutoStartERPM;
  int logIntervalHz;
  bool logAutoEraseWhenFull;
  int multiESCMode;
  List<int> multiESCIDs;
  int gpsBaudRate;
  double alertVoltageLow;
  double alertESCTemp;
  double alertMotorTemp;
  int alertStorageAtCapacity;
  int cfgVersion;
  int timeZoneOffsetHours;
  int timeZoneOffsetMinutes;
  RobogotchiConfiguration({
    this.logAutoStopIdleTime,
    this.logAutoStopLowVoltage,
    this.logAutoStartERPM,
    this.logIntervalHz,
    this.logAutoEraseWhenFull,
    this.multiESCMode,
    this.multiESCIDs,
    this.gpsBaudRate,
    this.alertVoltageLow,
    this.alertESCTemp,
    this.alertMotorTemp,
    this.alertStorageAtCapacity,
    this.cfgVersion,
    this.timeZoneOffsetHours,
    this.timeZoneOffsetMinutes,
  });
}

class RobogotchiCfgEditorArguments {
  final BluetoothCharacteristic txLoggerCharacteristic;
  final RobogotchiConfiguration currentConfiguration;
  final List<int> discoveredCANDevices;
  RobogotchiCfgEditorArguments({this.txLoggerCharacteristic, this.currentConfiguration, this.discoveredCANDevices});
}


class RobogotchiCfgEditor extends StatefulWidget {
  @override
  RobogotchiCfgEditorState createState() => RobogotchiCfgEditorState();

  static const String routeName = "/gotchicfgedit";
}


class RobogotchiCfgEditorState extends State<RobogotchiCfgEditor> {

  List<ListItem> _dropdownItems = [
    ListItem(1290240, "4800 baud"),
    ListItem(2576384, "9600 baud"),
    ListItem(5152768, "19200 baud"),
    ListItem(10289152,"38400 baud"),
    ListItem(15400960,"57600 baud"),
    ListItem(30801920,"115200 baud"),
    ListItem(61865984,"230400 baud"),
  ];

  List<DropdownMenuItem<ListItem>> _dropdownMenuItems;
  ListItem _selectedItem;

  List _escCANIDsSelected;
  List _escCANIDs = [];

  bool _multiESCMode;
  bool _multiESCModeQuad;
  TextEditingController tecLogAutoStopIdleTime = TextEditingController();
  TextEditingController tecLogAutoStopLowVoltage = TextEditingController();
  bool  _logAutoEraseWhenFull;

  TextEditingController tecAlertVoltageLow = TextEditingController();
  TextEditingController tecAlertESCTemp = TextEditingController();
  TextEditingController tecAlertMotorTemp = TextEditingController();



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

    _dropdownMenuItems = buildDropDownMenuItems(_dropdownItems);

    super.initState();
  }

  @override
  void dispose() {
    _selectedItem = null;
    tecLogAutoStopIdleTime.dispose();
    tecLogAutoStopLowVoltage.dispose();
    tecAlertVoltageLow.dispose();
    tecAlertESCTemp.dispose();
    tecAlertMotorTemp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    globalLogger.d("Building RobogotchiCfgEditor");

    // Check for valid arguments while building this widget
    RobogotchiCfgEditorArguments myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No arguments. BUG BUG. This should not happen. Please fix?"));
    }
    if (_multiESCMode == null) {
      // Assign value received from gotchi
      _multiESCMode = myArguments.currentConfiguration.multiESCMode == 2 || myArguments.currentConfiguration.multiESCMode == 4 ? true : false;
    }
    if (_multiESCModeQuad == null) {
      _multiESCModeQuad = myArguments.currentConfiguration.multiESCMode == 4;
    }
    if (_logAutoEraseWhenFull == null) {
      _logAutoEraseWhenFull = myArguments.currentConfiguration.logAutoEraseWhenFull;
    }
    if (myArguments.discoveredCANDevices.length > 0) {
      _escCANIDs.clear();
      for (int i=0; i<myArguments.discoveredCANDevices.length; ++i) {
        _escCANIDs.add({
          "display": "ID ${myArguments.discoveredCANDevices[i]}",
          "value": myArguments.discoveredCANDevices[i],
        });
      }
    }

    // Preselect user configured CAN IDs
    if (_escCANIDsSelected == null) {
      _escCANIDsSelected = [];
      myArguments.currentConfiguration.multiESCIDs.forEach((element) {
        if (element != 0 && myArguments.discoveredCANDevices.contains(element.toInt())) {
          globalLogger.d("Adding user selected CAN ID: $element");
          _escCANIDsSelected.add(element.toInt());
        }
      });
    }
    // Select GPS Baud
    if (_selectedItem == null) {
      _dropdownItems.forEach((item) {
        if (item.value == myArguments.currentConfiguration.gpsBaudRate) {
          _selectedItem = item;
        }
      });
    }



    // Add listeners to text editing controllers for value validation
    tecLogAutoStopIdleTime.addListener(() {
      myArguments.currentConfiguration.logAutoStopIdleTime = int.tryParse(tecLogAutoStopIdleTime.text).abs();
      if (myArguments.currentConfiguration.logAutoStopIdleTime > 65534) {
        setState(() {
          myArguments.currentConfiguration.logAutoStopIdleTime = 65534;
        });
      }
    });
    tecLogAutoStopLowVoltage.addListener(() {
      myArguments.currentConfiguration.logAutoStopLowVoltage = double.tryParse(tecLogAutoStopLowVoltage.text.replaceFirst(',', '.')).abs();
      if (myArguments.currentConfiguration.logAutoStopLowVoltage > 128.0) {
        setState(() {
          myArguments.currentConfiguration.logAutoStopLowVoltage = 128.0;
        });
      }
    });
    tecAlertVoltageLow.addListener(() {
      myArguments.currentConfiguration.alertVoltageLow = doublePrecision(double.tryParse(tecAlertVoltageLow.text.replaceFirst(',', '.')).abs(), 1);
      if (myArguments.currentConfiguration.alertVoltageLow > 128.0) {
        setState(() {
          myArguments.currentConfiguration.alertVoltageLow = 128.0;
        });
      }
    });
    tecAlertESCTemp.addListener(() {
      myArguments.currentConfiguration.alertESCTemp = doublePrecision(double.tryParse(tecAlertESCTemp.text.replaceFirst(',', '.')).abs(), 1);
      if (myArguments.currentConfiguration.alertESCTemp > 85.0) {
        setState(() {
          myArguments.currentConfiguration.alertESCTemp = 85.0;
        });
      }
    });
    tecAlertMotorTemp.addListener(() {
      myArguments.currentConfiguration.alertMotorTemp = doublePrecision(double.tryParse(tecAlertMotorTemp.text.replaceFirst(',', '.')).abs(), 1);
      if (myArguments.currentConfiguration.alertMotorTemp > 120.0) {
        setState(() {
          myArguments.currentConfiguration.alertMotorTemp = 120.0;
        });
      }
    });
    // Set text editing controller values to arguments received
    tecLogAutoStopIdleTime.text = myArguments.currentConfiguration.logAutoStopIdleTime.toString();
    tecLogAutoStopLowVoltage.text = myArguments.currentConfiguration.logAutoStopLowVoltage.toString();

    tecAlertVoltageLow.text = myArguments.currentConfiguration.alertVoltageLow.toString();
    tecAlertESCTemp.text = myArguments.currentConfiguration.alertESCTemp.toString();
    tecAlertMotorTemp.text = myArguments.currentConfiguration.alertMotorTemp.toString();


    return Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon( Icons.perm_data_setting,
              size: 35.0,
              color: Theme.of(context).accentColor,
            ),
            Text("Config Editor"),
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
                      controller: tecLogAutoStopIdleTime,
                      decoration: new InputDecoration(labelText: "Log Auto Stop/Idle Board Timeout (Seconds)"),
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ]
                  ),
                  TextField(
                      controller: tecLogAutoStopLowVoltage,
                      decoration: new InputDecoration(labelText: "Log Auto Stop Low Voltage Threshold (Volts)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),


                  Divider(thickness: 3),
                  Text("Log Auto Start Sensitivity (eRPM ${myArguments.currentConfiguration.logAutoStartERPM})"),
                  SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: timeToPlay == 3 ? SliderThumbImage(sliderImage) : RoundSliderThumbShape(enabledThumbRadius: 10)
                      ),
                      child: Slider(
                        onChanged: (newValue){ setState(() {
                          myArguments.currentConfiguration.logAutoStartERPM = 6000 - newValue.toInt();
                        }); },
                        value: 6000 - myArguments.currentConfiguration.logAutoStartERPM.toDouble(),
                        min: 1000,
                        max: 4999,
                      )),


                  Divider(thickness: 3),
                  Text("Log Entries per Second (${myArguments.currentConfiguration.logIntervalHz}Hz)"),
                  _multiESCMode && !_multiESCModeQuad && myArguments.currentConfiguration.logIntervalHz == 1 ?
                    Text("⚠️ 2Hz or more is recommended with a dual ESC configuration", style: TextStyle(color: Colors.yellow)) : Container(),
                  _multiESCMode && _multiESCModeQuad && myArguments.currentConfiguration.logIntervalHz != 4 ?
                      Text("⚠️ 4Hz is recommended with a quad ESC configuration", style: TextStyle(color: Colors.yellow)) : Container(),
                  SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                          thumbShape: timeToPlay == 3 ? SliderThumbImage(sliderImage) : RoundSliderThumbShape(enabledThumbRadius: 10)
                      ),
                      child: Slider(
                        onChanged: (newValue){ setState(() {
                          myArguments.currentConfiguration.logIntervalHz = newValue.toInt();
                        }); },
                        value: myArguments.currentConfiguration.logIntervalHz.toDouble(),
                        min: 1,
                        max: 5,
                      )
                  ),

                  /* TODO: enable when implemented
                  SwitchListTile(
                    title: Text("Log Auto Erase When Full"),
                    value: _logAutoEraseWhenFull,
                    onChanged: (bool newValue) { setState((){ _logAutoEraseWhenFull = newValue;}); },
                    secondary: const Icon(Icons.delete_forever),
                  ),
                   */


                  Divider(thickness: 3),
                  Text("GPS Baud Rate"),
                  Center(child:
                  DropdownButton<ListItem>(
                    value: _selectedItem,
                    items: _dropdownMenuItems,
                    onChanged: (newValue) {
                      setState(() {
                        _selectedItem = newValue;
                        myArguments.currentConfiguration.gpsBaudRate = newValue.value;
                      });
                    },
                  )
                  ),


                  Divider(thickness: 3),
                  SwitchListTile(
                    title: Text("Multiple ESC Mode"),
                    value: _multiESCMode,
                    onChanged: (bool newValue) { setState((){ _multiESCMode = newValue;}); },
                    secondary: const Icon(Icons.all_out),
                  ),

                  _multiESCMode ? SwitchListTile(
                    title: Text(_multiESCModeQuad ? "Quad ESC Mode" : "Dual ESC Mode"),
                    value: _multiESCModeQuad,
                    onChanged: (bool newValue) { setState((){ _multiESCModeQuad = newValue;}); },
                    secondary: _multiESCModeQuad ? const Icon(Icons.looks_4) : const Icon(Icons.looks_two),
                  ) : Container(),

                  _multiESCMode ? MultiSelectFormField(
                    autovalidate: false,
                    title: _multiESCModeQuad ? Text("Select CAN IDs") : Text("Select CAN ID"),
                    validator: (value) {
                      if (value == null || value.length != (_multiESCModeQuad ? 3 : 1)) {
                        if(_multiESCModeQuad) {
                          return "Please select 3 ESC CAN IDs";
                        } else {
                          return "Please select 1 ESC CAN ID";
                        }
                      }
                      return null;
                    },
                    dataSource: _escCANIDs,
                    textField: 'display',
                    valueField: 'value',
                    okButtonLabel: 'OK',
                    cancelButtonLabel: 'CANCEL',
                    // required: true,
                    hintWidget: _multiESCModeQuad ? Text("Select 3 ESC CAN IDs") : Text("Select 1 ESC CAN ID"),
                    initialValue: _escCANIDsSelected,
                    onSaved: (value) {
                      if (value == null) return;
                      setState(() {
                        _escCANIDsSelected = value;
                      });
                    },
                  ) : Container(),


                  Divider(thickness: 3),
                  TextField(
                      controller: tecAlertVoltageLow,
                      decoration: new InputDecoration(labelText: "Alert Low Voltage (0 = no alert)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecAlertESCTemp,
                      decoration: new InputDecoration(labelText: "Alert ESC Temperature °C (0 = no alert)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),
                  TextField(
                      controller: tecAlertMotorTemp,
                      decoration: new InputDecoration(labelText: "Alert Motor Temperature °C (0 = no alert)"),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(formatPositiveDouble)
                      ]
                  ),

                  Divider(thickness: 3),
                  Text("Alert when Storage is at Capacity (${myArguments.currentConfiguration.alertStorageAtCapacity == 0 ? "0 = no alert" : "${myArguments.currentConfiguration.alertStorageAtCapacity}%"})"),
                  SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                          thumbShape: timeToPlay == 3 ? SliderThumbImage(sliderImage) : RoundSliderThumbShape(enabledThumbRadius: 10)
                      ),
                      child: Slider(
                        onChanged: (newValue){ setState(() {
                          myArguments.currentConfiguration.alertStorageAtCapacity = newValue.toInt();
                        }); },
                        value: myArguments.currentConfiguration.alertStorageAtCapacity.toDouble(),
                        min: 0.0,
                        max: 90.0,
                      )
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
                            // Validate user input
                            if (_multiESCMode && _multiESCModeQuad && _escCANIDsSelected?.length != 3) {
                              genericAlert(context, "CAN IDs required", Text("Please select 3 CAN IDs before saving"), "OK");
                              return;
                            }
                            if (_multiESCMode && !_multiESCModeQuad && _escCANIDsSelected?.length != 1) {
                              genericAlert(context, "CAN ID required", Text("Please select 1 CAN ID before saving"), "OK");
                              return;
                            }

                            // Convert settings to robogotchi command
                            int multiESCMode = 0;
                            if (_multiESCMode && _multiESCModeQuad) {
                              multiESCMode = 4;
                            } else if (_multiESCMode) {
                              multiESCMode = 2;
                            }

                            // Add GPS TimeZoneOffset
                            myArguments.currentConfiguration.timeZoneOffsetHours = DateTime.now().timeZoneOffset.inHours;
                            myArguments.currentConfiguration.timeZoneOffsetMinutes = DateTime.now().timeZoneOffset.inMinutes % 60;
                            globalLogger.d("TimeZone Computation: ${myArguments.currentConfiguration.timeZoneOffsetHours} hours ${myArguments.currentConfiguration.timeZoneOffsetMinutes} minutes");

                            //TODO: Add Device Name to configuration
                            String newConfigCMD = "setcfg,${myArguments.currentConfiguration.cfgVersion}"
                                ",${myArguments.currentConfiguration.logAutoStopIdleTime}"
                                ",${myArguments.currentConfiguration.logAutoStopLowVoltage}"
                                ",${myArguments.currentConfiguration.logAutoStartERPM}"
                                ",${myArguments.currentConfiguration.logIntervalHz}"
                                ",${_logAutoEraseWhenFull == true ? "1": "0"}"
                                ",$multiESCMode"
                                ",${_escCANIDsSelected != null && _escCANIDsSelected.length > 0 ? _escCANIDsSelected[0] : 0}"
                                ",${_escCANIDsSelected != null && _escCANIDsSelected.length > 1 ? _escCANIDsSelected[1] : 0}"
                                ",${_escCANIDsSelected != null && _escCANIDsSelected.length > 2 ? _escCANIDsSelected[2] : 0}"
                                ",0"
                                ",${myArguments.currentConfiguration.gpsBaudRate}"
                                ",${myArguments.currentConfiguration.alertVoltageLow != null ? myArguments.currentConfiguration.alertVoltageLow : 0.0}"
                                ",${myArguments.currentConfiguration.alertESCTemp != null ? myArguments.currentConfiguration.alertESCTemp : 0.0}"
                                ",${myArguments.currentConfiguration.alertMotorTemp != null ? myArguments.currentConfiguration.alertMotorTemp : 0.0}"
                                ",${myArguments.currentConfiguration.alertStorageAtCapacity}"
                                ",${myArguments.currentConfiguration.timeZoneOffsetHours}"
                                ",${myArguments.currentConfiguration.timeZoneOffsetMinutes}~";

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
