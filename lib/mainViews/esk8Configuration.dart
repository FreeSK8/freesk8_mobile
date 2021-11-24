import 'dart:async';
import 'dart:io';
import 'dart:typed_data';


import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freesk8_mobile/subViews/brocator.dart';

import '../components/crc16.dart';
import '../subViews/escProfileEditor.dart';
import '../subViews/vehicleManager.dart';
import '../globalUtilities.dart';

import '../components/userSettings.dart';
import '../hardwareSupport/escHelper/escHelper.dart';
import '../hardwareSupport/escHelper/mcConf.dart';
import '../hardwareSupport/escHelper/dataTypes.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart';

import 'package:flutter_blue/flutter_blue.dart';

import 'package:image_picker/image_picker.dart';

import 'package:path_provider/path_provider.dart';

import 'package:archive/archive_io.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_document_picker/flutter_document_picker.dart';

class ESK8Configuration extends StatefulWidget {
  ESK8Configuration({
    @required this.myUserSettings,
    this.currentDevice,
    this.theTXCharacteristic,
    this.updateCachedAvatar,
    this.escFirmwareVersion,
    this.updateComputedVehicleStatistics,
    @required this.applicationDocumentsDirectory,
    this.reloadUserSettings,
    this.telemetryStream,
  });
  final UserSettings myUserSettings;
  final BluetoothDevice currentDevice;
  final BluetoothCharacteristic theTXCharacteristic;
  final ValueChanged<bool> updateCachedAvatar;
  final ESC_FIRMWARE escFirmwareVersion;
  final ValueChanged<bool> updateComputedVehicleStatistics;
  final String applicationDocumentsDirectory;
  final ValueChanged<bool> reloadUserSettings;


  final Stream telemetryStream;
  ESK8ConfigurationState createState() => new ESK8ConfigurationState();
}

class ESK8ConfigurationState extends State<ESK8Configuration> {

  final GlobalKey<State> _keyLoader = new GlobalKey<State>();

  FileImage _boardAvatar;

  bool _showAdvanced = false;

  Future getImage(bool fromUserGallery) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imagePicker = ImagePicker();
    PickedFile temporaryImage = await imagePicker.getImage(source: fromUserGallery ? ImageSource.gallery : ImageSource.camera, maxWidth: 640, maxHeight: 640);

    if (temporaryImage != null) {
      // We have a new image, capture for display and update the settings in memory
      String newPath = "${documentsDirectory.path}/avatars/${widget.currentDevice.id}";
      File finalImage = await File(newPath).create(recursive: true);
      finalImage.writeAsBytesSync(await temporaryImage.readAsBytes());
      globalLogger.d("Board avatar file destination: ${finalImage.path}");

      // Let go of the old image that we are displaying here
      setState(() {
        _boardAvatar = null;
      });

      // Wait for the application
      await Future.delayed(Duration(milliseconds: 500),(){});

      // Clear the image cache and load the new image
      setState(() {
        //NOTE: A FileImage is the fastest way to load these images but because
        //      it's cached they will only update once. Unless you explicitly
        //      clear the imageCache
        // Clear the imageCache for FileImages used in rideLogging.dart
        imageCache.clear();
        imageCache.clearLiveImages();

        widget.myUserSettings.settings.boardAvatarPath = "/avatars/${widget.currentDevice.id}";
        _boardAvatar = new FileImage(new File("${widget.applicationDocumentsDirectory}${widget.myUserSettings.settings.boardAvatarPath}"));
      });
    }
  }

  final tecBoardAlias = TextEditingController();

  @override
  void initState() {
    if (widget.myUserSettings.settings.boardAvatarPath != null) {
      _boardAvatar = FileImage(File("${widget.applicationDocumentsDirectory}${widget.myUserSettings.settings.boardAvatarPath}"));
    }

    //TODO: these try parse can return null.. then the device will remove null because it's not a number
    tecBoardAlias.addListener(() { widget.myUserSettings.settings.boardAlias = tecBoardAlias.text; });

    super.initState();
  }


  @override
  void dispose() {
    tecBoardAlias.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    print("Build: ESK8Configuration");
    setLandscapeOrientation(enabled: false);

    tecBoardAlias.text = widget.myUserSettings.settings.boardAlias;
    tecBoardAlias.selection = TextSelection.fromPosition(TextPosition(offset: tecBoardAlias.text.length));


    return Container(
      //padding: EdgeInsets.all(5),
        child: Center(
          child: GestureDetector(
            onTap: () {
              // Hide the keyboard
              FocusScope.of(context).requestFocus(new FocusNode());
            },
            child: ListView(
              padding: EdgeInsets.all(10),
              children: <Widget>[

                SizedBox(height: 5,),





                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Icon(
                    Icons.settings,
                    size: 80.0,
                    color: Colors.blue,
                  ),
                  Text("FreeSK8\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                ],),


                SwitchListTile(
                  title: Text("Display imperial distances"),
                  value: widget.myUserSettings.settings.useImperial,
                  onChanged: (bool newValue) { setState((){widget.myUserSettings.settings.useImperial = newValue;}); },
                  secondary: const Icon(Icons.power_input),
                ),
                SwitchListTile(
                  title: Text("Display fahrenheit temperatures"),
                  value: widget.myUserSettings.settings.useFahrenheit,
                  onChanged: (bool newValue) { setState((){widget.myUserSettings.settings.useFahrenheit = newValue;}); },
                  secondary: const Icon(Icons.wb_sunny),
                ),
                SwitchListTile(
                  title: Text("Override speed/distance with GPS metrics"),
                  subtitle: Text("For use with eFoil, eBike"),
                  value: widget.myUserSettings.settings.useGPSData,
                  onChanged: (bool newValue) async {
                    bool valueToSet = newValue;

                    // Confirm with user if we are enabling this option
                    if (valueToSet == true) {
                      // Confirm setting with user
                      valueToSet = await genericConfirmationDialog(
                          context,
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("No Thank You"),
                          ),
                          TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Yes Please")
                          ),
                          "Quick check!",
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Oh, hey.. Usually ESC data is preferred for speed and distance. Are you sure you want to see GPS metrics?"),
                              Icon(Icons.gps_fixed),
                              SizedBox(height: 15),

                            ],
                          )
                      );
                    }

                    setState((){
                      widget.myUserSettings.settings.useGPSData = valueToSet != null ? valueToSet : false;
                    });
                  },
                  secondary: Icon(widget.myUserSettings.settings.useGPSData ? Icons.gps_fixed : Icons.gps_not_fixed),
                ),

                TextField(
                  controller: tecBoardAlias,
                  decoration: new InputDecoration(labelText: "Board Name / Alias"),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Column(children: <Widget>[
                    Text("Board Avatar"),
                    SizedBox(
                      width: 125,
                      child:  ElevatedButton(
                          child:
                          Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Take "),Icon(Icons.camera_alt),],),

                          onPressed: () {
                            getImage(false);
                          }),
                    ),
                    SizedBox(
                      width: 125,
                      child:  ElevatedButton(
                          child:
                          Row(mainAxisAlignment: MainAxisAlignment.center , children: <Widget>[Text("Select "),Icon(Icons.filter),],),

                          onPressed: () {
                            getImage(true);
                          }),
                    )
                  ],),

                  SizedBox(width: 15),
                  CircleAvatar(
                      backgroundImage: _boardAvatar != null ? _boardAvatar : AssetImage('assets/FreeSK8_Mobile.png'),
                      radius: 100,
                      backgroundColor: Colors.white)

                ]),

                SizedBox(height:10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  ElevatedButton(
                      child: Text("Revert Settings"),
                      onPressed: () {
                        setState(() {
                          widget.myUserSettings.reloadSettings();
                          ScaffoldMessenger
                              .of(context)
                              .showSnackBar(SnackBar(content: Text('Application settings loaded from last state')));
                        });
                      }),

                  SizedBox(width:15),

                  ElevatedButton(
                      child: Text("Save Settings"),
                      onPressed: () async {
                        FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                        try {
                          if (tecBoardAlias.text.length < 1) tecBoardAlias.text = "Unnamed";
                          widget.myUserSettings.settings.boardAlias = tecBoardAlias.text;
                          // NOTE: Board avatar is updated with the image picker
                          await widget.myUserSettings.saveSettings();

                          // Update cached avatar
                          widget.updateCachedAvatar(true);

                          // Recompute statistics in case we change measurement units
                          widget.updateComputedVehicleStatistics(false);

                        } catch (e) {
                          globalLogger.e("Save Settings Exception $e");
                          ScaffoldMessenger
                              .of(context)
                              .showSnackBar(SnackBar(content: Text('Sorry friend. Save settings failed =(')));
                        }
                        ScaffoldMessenger
                            .of(context)
                            .showSnackBar(SnackBar(content: Text('Application settings saved')));
                      }),


                ],),


                Divider(thickness: 2,),

                ExpansionPanelList(
                    elevation: 0,
                  expansionCallback: (int index, bool isExpanded) {
                    setState(() {
                      print(_showAdvanced);
                      _showAdvanced = !_showAdvanced;
                    });
                  },
                  children: [
                    ExpansionPanel(
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        headerBuilder: (context, isOpen) {
                          return Row(children: [
                            SizedBox(width: 10),
                            Icon(Icons.science_outlined),
                            Text("Advanced")
                          ],);
                        },
                        body: Column(children: [
                          ElevatedButton(
                              child: Text("Export Data Backup"),
                              onPressed: () async {
                                FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                                // Show dialog to prevent user input
                                await Dialogs.showPleaseWaitDialog(context, _keyLoader).timeout(Duration(milliseconds: 500)).catchError((error){});

                                try {
                                  final documentsDirectory = await getApplicationDocumentsDirectory();
                                  final supportDirectory = await getApplicationSupportDirectory();

                                  // Zip a directory to out.zip using the zipDirectory convenience method
                                  var encoder = ZipFileEncoder();

                                  // Manually create a zip of individual files
                                  encoder.create("${supportDirectory.path}/freesk8_beta_backup.zip");

                                  // Add log files
                                  encoder.addDirectory(Directory("${documentsDirectory.path}/logs"));

                                  //rideLogsFromDatabase.forEach((element)  {
                                  //TODO: no safety checking here. Opening file must be on device
                                  //  encoder.addFile(File("${documentsDirectory.path}${element.logFilePath}"));
                                  //});

                                  // Add the database
                                  String path = await getDatabasesPath();
                                  encoder.addFile(File("$path/logDatabase.db"));

                                  // Add the avatars
                                  encoder.addDirectory(Directory("${documentsDirectory.path}/avatars"));

                                  // Add the userSettings export
                                  encoder.addFile(await exportSettings('${supportDirectory.path}/freesk8_beta_userSettings.json'));

                                  // Finish out zip file
                                  encoder.close();

                                  Navigator.of(context).pop(); // Remove PleaseWait dialog
                                  await Share.file("FreeSK8 Beta Log Archive", "freesk8_beta_backup.zip", await File("${supportDirectory.path}/freesk8_beta_backup.zip").readAsBytes(), 'application/zip', text: "FreeSK8 Beta Logs");

                                } catch (e, stacktrace) {
                                  Navigator.of(context).pop(); // Remove PleaseWait dialog
                                  globalLogger.e("Export Data Exception $e");
                                  globalLogger.e(stacktrace.toString());
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(SnackBar(content: Text("Export Exception. Please send debug log")));
                                }
                              }),

                          ElevatedButton(
                              child: Text("Import Data Backup (Caution!)"),
                              onPressed: () async {
                                FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                                // Show dialog to prevent user input
                                await Dialogs.showPleaseWaitDialog(context, _keyLoader).timeout(Duration(milliseconds: 500)).catchError((error){});

                                try {
                                  final documentsDirectory = await getApplicationDocumentsDirectory();

                                  FlutterDocumentPickerParams params = FlutterDocumentPickerParams(
                                    allowedFileExtensions: ["zip"],
                                    allowedMimeTypes: ["application/zip"],
                                  );

                                  String result = await FlutterDocumentPicker.openDocument(params: params);
                                  globalLogger.d("Import Data: User imported file: $result");

                                  if (result == null) {
                                    Navigator.of(context).pop(); // Remove PleaseWait dialog
                                    return ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Import Aborted: No File Specified")));
                                  }

                                  // Read the Zip file from disk.
                                  final bytes = File(result).readAsBytesSync();

                                  // Decode the Zip file
                                  final archive = ZipDecoder().decodeBytes(bytes);

                                  // Extract the contents of the Zip archive to disk.
                                  for (final file in archive) {
                                    final filename = file.name;
                                    if (file.isFile) {
                                      final data = file.content as List<int>;
                                      File('${documentsDirectory.path}/' + filename)
                                        ..createSync(recursive: true)
                                        ..writeAsBytesSync(data);
                                      print(filename);
                                    } else {
                                      Directory('${documentsDirectory.path}/' + filename)
                                        ..create(recursive: true);
                                    }
                                  }

                                  // Make sure we've extracted the a userSettings file for importing
                                  final String importSettingsFilePath = "${documentsDirectory.path}/freesk8_beta_userSettings.json";
                                  if (!File(importSettingsFilePath).existsSync()) {
                                    Navigator.of(context).pop(); // Remove PleaseWait dialog
                                    return ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Invalid Import File Selected")));
                                  }

                                  // Import UserSettings
                                  if (await importSettings(importSettingsFilePath)) {
                                    // Import Ride Log Database
                                    String dbPath = await getDatabasesPath();
                                    File("${documentsDirectory.path}/logDatabase.db").copy("$dbPath/logDatabase.db");

                                    Navigator.of(context).pop(); // Remove PleaseWait dialog
                                    globalLogger.d("Import Data Completed Successfully");
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Import Data Completed Successfully")));

                                    // Removing import files to free space and clear import state
                                    File(importSettingsFilePath).deleteSync();
                                    File(result).deleteSync();
                                  } else {
                                    globalLogger.d("Import did not finish successfully");
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(SnackBar(content: Text("Import Aborted")));
                                  }



                                } catch (e, stacktrace) {
                                  Navigator.of(context).pop(); // Remove PleaseWait dialog
                                  globalLogger.e("Import Data Exception $e");
                                  globalLogger.e(stacktrace.toString());
                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(SnackBar(content: Text("Import Exception. Please send debug log")));

                                }
                              }),

                          ElevatedButton(
                              child: Text("Open Vehicle Manager"),
                              onPressed: () async {
                                FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                                // Wait for the navigation to return
                                final result = await Navigator.of(context).pushNamed(VehicleManager.routeName, arguments: VehicleManagerArguments(widget.currentDevice == null ? null : widget.currentDevice?.id.toString()));
                                // If changes were made the result of the Navigation will be true and we'll want to reload the user settings
                                if (result == true) {
                                  // Request the user settings to be reloaded
                                  widget.reloadUserSettings(result);
                                }
                              }),

                          ElevatedButton(
                              child: Text("Brocator"),
                              onPressed: () async {
                                FocusScope.of(context).requestFocus(new FocusNode()); //Hide keyboard
                                // Wait for the navigation to return
                                final result = await Navigator.of(context).pushNamed(Brocator.routeName, arguments: BrocatorArguments(widget.currentDevice == null ? null : widget.myUserSettings.settings.boardAlias, _boardAvatar, widget.telemetryStream, widget.theTXCharacteristic));
                                // If changes were made the result of the Navigation will be true and we'll want to reload the user settings
                                if (result == true) {
                                  globalLogger.wtf(result);
                                }
                              }),
                        ],),
                      isExpanded: _showAdvanced
                    ),
                  ],
                ),


              ],
            ),
          ),
        )
    );
  }
}
