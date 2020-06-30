import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import 'package:freesk8_mobile/databaseAssistant.dart';
import 'package:freesk8_mobile/file_manager.dart';
import 'package:freesk8_mobile/rideLogViewer.dart';
import 'package:freesk8_mobile/userSettings.dart';

import 'package:path_provider/path_provider.dart';

import 'dart:io';

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
                        Text("Please Wait....")
                      ]),
                    )
                  ]));
        });
  }
}

class RideLogging extends StatefulWidget {
  RideLogging({this.myUserSettings, this.theTXLoggerCharacteristic, this.syncInProgress, this.onSyncPress});
  final UserSettings myUserSettings;
  final BluetoothCharacteristic theTXLoggerCharacteristic;
  final bool syncInProgress;
  final ValueChanged<bool> onSyncPress;

  void _handleSyncPress() {
    onSyncPress(!syncInProgress);
  }

  RideLoggingState createState() => new RideLoggingState();

  static const String routeName = "/ridelogging";
}

class RideLoggingState extends State<RideLogging> {

  String temporaryLog = "";
  List<FileSystemEntity> rideLogs = new List();
  List<FileStat> rideLogsFileStats = new List();
  final GlobalKey<State> _keyLoader = new GlobalKey<State>();
  List<LogInfoItem> rideLogsFromDatabase = new List();
  String orderByClause = "date_created DESC";

  final tecRideNotes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listFiles(true);
  }

  @override
  void dispose(){
    tecRideNotes?.dispose();

    super.dispose();
  }

  void _listFiles(bool doSetState) async {
    rideLogsFromDatabase = await DatabaseAssistant.dbSelectLogs(orderByClause: orderByClause);

    String directory = (await getApplicationDocumentsDirectory()).path;


    rideLogs = Directory("$directory/logs/").listSync();
    rideLogs.sort((b, a) => a.path.compareTo(b.path)); // Sort descending
    if (doSetState && this.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    print("Build: RideLogging");

    if(widget.syncInProgress) {
      _listFiles(false);
    }

    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: 5,),





            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              //Text("Ride", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
              Image(image: AssetImage("assets/dri_icon.png"),height: 80),
              Text("Ride\r\nLogging", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
            ],),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[

              //TODO: Allow for ASCending sort order
              SizedBox(width:50, child: Text("Sort by"),),

              IconButton(
                icon: Icon(Icons.account_circle),
                tooltip: 'Sort by Board',
                onPressed: () {
                  orderByClause = "board_id DESC";
                  _listFiles(true);
                },
              ),
              IconButton(
                icon: Icon(Icons.calendar_today),
                tooltip: 'Sort by Date',
                onPressed: () {
                  orderByClause = "date_created DESC";
                  _listFiles(true);
                },
              ),






              IconButton(
                icon: Icon(Icons.check_circle_outline),
                tooltip: 'Sort by Faults',
                onPressed: () {
                  orderByClause = "fault_count DESC";
                  _listFiles(true);
                },
              ),
              IconButton(
                icon: Icon(Icons.chat_bubble),
                tooltip: 'Sort by Notes',
                onPressed: () {
                  orderByClause = "length(notes) DESC";
                  _listFiles(true);
                },
              ),
              IconButton(
                icon: Icon(Icons.timer),
                tooltip: 'Sort by Duration',
                onPressed: () {
                  orderByClause = "duration_seconds DESC";
                  _listFiles(true);
                },
              ),
            ],),




            //TODO show graphic if we have no rides to list?

            /// Show rides from database entries
            Expanded( child:
              ListView.builder(
                itemCount: rideLogsFromDatabase.length,
                itemBuilder: (BuildContext context, int index){
                  //TODO: consider https://pub.dev/packages/flutter_slidable for extended functionality
                  //Each item has dismissible wrapper
                  return Dismissible(
                    background: Container(
                        color: Colors.red,
                        margin: const EdgeInsets.only(bottom: 5.0),
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
                          child: Icon(Icons.delete, color: Colors.white,
                          ),
                        )
                    ),
                    // Each Dismissible must contain a Key. Keys allow Flutter to uniquely identify widgets.
                    // Use filename as key
                    key: Key(rideLogsFromDatabase[index].logFilePath.substring(rideLogsFromDatabase[index].logFilePath.lastIndexOf("/") + 1, rideLogsFromDatabase[index].logFilePath.lastIndexOf("/") + 20)),
                    onDismissed: (direction) {
                      // Remove the item from the data source.
                      setState(() {
                        //Remove from Database
                        DatabaseAssistant.dbRemoveLog(rideLogsFromDatabase[index].logFilePath);
                        //Remove from Filesystem
                        File(rideLogsFromDatabase[index].logFilePath).delete();
                        //Remove from itemBuilder's list of entries
                        rideLogsFromDatabase.removeAt(index);
                      });
                    },
                    confirmDismiss: (DismissDirection direction) async {
                      print("rideLogging::Dismissible: ${direction.toString()}");

                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Delete file?"),
                            content: const Text("Are you sure you wish to permanently erase this item?"),
                            actions: <Widget>[
                              FlatButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Delete")
                              ),
                              FlatButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text("Cancel"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: GestureDetector(
                      onTap: () async {
                        // Show indication of loading
                        await Dialogs.showLoadingDialog(context, _keyLoader).timeout(Duration(milliseconds: 500)).catchError((error){});

                        // navigate to the route by replacing the loading dialog
                        Navigator.of(context).pushReplacementNamed(RideLogViewer.routeName,
                          //TODO: I'm passing current user settings and not those of the board selected -- Only using imperial global preferences anyway
                          arguments: RideLogViewerArguments(rideLogsFromDatabase[index].logFilePath, widget.myUserSettings),
                        ).then((value){
                          // Once finished re-list files and remove a potential snackBar item before re-draw of setState
                          _listFiles(true);
                          Scaffold.of(context).removeCurrentSnackBar();
                        } );
                      },
                      child: Column(
                          children: <Widget>[
                            Container(height: 50,
                                width: MediaQuery.of(context).size.width - 20,
                                margin: const EdgeInsets.only(left: 10.0),
                                color: Theme.of(context).dialogBackgroundColor,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: <Widget>[
                                    /*
                                        SizedBox(width: 5,),
                                        SizedBox(
                                          width: 80,
                                          child: Text(rideLogsFromDatabase[index].boardAlias, textAlign: TextAlign.center,),
                                        ),s
                                         */
                                    SizedBox(width: 5,),
                                    SizedBox(width: 50, child:
                                    FutureBuilder<String>(
                                        future: UserSettings.getBoardAvatarPath(rideLogsFromDatabase[index].boardID),
                                        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                          return CircleAvatar(
                                              backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                                              radius: 25,
                                              backgroundColor: Colors.white);
                                        })
                                      ,),
                                    SizedBox(width: 10,),

                                    Expanded(
                                      child: Text(rideLogsFromDatabase[index].logFilePath.substring(rideLogsFromDatabase[index].logFilePath.lastIndexOf("/") + 1, rideLogsFromDatabase[index].logFilePath.lastIndexOf("/") + 20).split("T").join("\r\n")),
                                    ),

                                    SizedBox(
                                      width: 32,
                                      child: Icon(
                                          rideLogsFromDatabase[index].faultCount < 1 ? Icons.check_circle_outline : Icons.error_outline,
                                          color: rideLogsFromDatabase[index].faultCount < 1 ? Colors.green : Colors.red),
                                    ),

                                    /// Ride Log Note Editor
                                    SizedBox(
                                      width: 32,
                                      child: GestureDetector(
                                        onTap: (){
                                          tecRideNotes.text = rideLogsFromDatabase[index].notes;

                                          showDialog(context: context,
                                              child: AlertDialog(
                                                title: const Icon(Icons.chat, size:40),
                                                content: TextField(
                                                  controller: tecRideNotes,
                                                  decoration: new InputDecoration(labelText: "Notes:"),
                                                  keyboardType: TextInputType.text,
                                                ),
                                                actions: <Widget>[
                                                  FlatButton(
                                                      onPressed: () async {
                                                        // Update notes field in database
                                                        await DatabaseAssistant.dbUpdateNote(rideLogsFromDatabase[index].logFilePath, tecRideNotes.text);
                                                        _listFiles(true);
                                                        Navigator.of(context).pop(true);
                                                      },
                                                      child: const Text("Save")
                                                  ),
                                                  FlatButton(
                                                    onPressed: () => Navigator.of(context).pop(false),
                                                    child: const Text("Cancel"),
                                                  ),
                                                ],
                                              )
                                          );
                                        },
                                        child: Icon( rideLogsFromDatabase[index].notes.length > 0 ? Icons.chat : Icons.chat_bubble_outline, size: 32),
                                      ),
                                    ),

                                    SizedBox(
                                      width: 32,
                                      child: Icon(Icons.timer),
                                    ),
                                    SizedBox(
                                        width: 60,
                                        //child: Text("${(File(rideLogsFromDatabase[index].logFilePath).statSync().size / 1024).round()} kb"),
                                        child: Text("${Duration(seconds: rideLogsFromDatabase[index].durationSeconds).toString().substring(0,Duration(seconds: rideLogsFromDatabase[index].durationSeconds).toString().indexOf("."))}")
                                    ),
                                  ],
                                )
                            ),
                            SizedBox(height: 5,)
                          ]
                      ),
                    ),
                  );
                })),

            /*
              ///Display ride logs based on Files in log directory
              Expanded(//height:300,
                child: ListView.builder(
                    itemCount: rideLogs.length,
                    itemBuilder: (BuildContext context, int index) {
                      //Each item has dismissible wrapper
                      return Dismissible(
                        background: Container(
                            color: Colors.red,
                            margin: const EdgeInsets.only(bottom: 5.0),
                            alignment: AlignmentDirectional.centerEnd,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(0.0, 0.0, 10.0, 0.0),
                              child: Icon(Icons.delete, color: Colors.white,
                              ),
                            )
                        ),
                        // Each Dismissible must contain a Key. Keys allow Flutter to uniquely identify widgets.
                        // Use filename as key
                        key: Key(rideLogs[index].path.substring(rideLogs[index].path.lastIndexOf("/") + 1, rideLogs[index].path.lastIndexOf("/") + 19)),
                        onDismissed: (direction) {
                          // Remove the item from the data source.
                          setState(() {
                            File(rideLogs[index].path).delete();
                            rideLogs.removeAt(index);
                          });
                        },
                        confirmDismiss: (DismissDirection direction) async {
                          return await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("Delete file?"),
                                content: const Text("Are you sure you wish to permanently erase this item?"),
                                actions: <Widget>[
                                  FlatButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text("Delete")
                                  ),
                                  FlatButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text("Cancel"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: GestureDetector(
                          onTap: () async {
                            // Show indication of loading
                            await Dialogs.showLoadingDialog(context, _keyLoader).timeout(Duration(milliseconds: 500)).catchError((error){});

                            // navigate to the route by replacing the loading dialog
                            Navigator.of(context).pushReplacementNamed(RideLogViewer.routeName,
                                arguments: RideLogViewerArguments(rideLogs[index].path, widget.myUserSettings),
                            ).then((value){
                              // Once finished re-list files and remove a potential snackBar item before re-draw of setState
                              _listFiles();
                              Scaffold.of(context).removeCurrentSnackBar();
                            } );
                          },
                          child: Column(
                              children: <Widget>[
                                Container(height: 50,
                                    width: MediaQuery.of(context).size.width - 20,
                                    margin: const EdgeInsets.only(left: 10.0),
                                    color: Theme.of(context).dialogBackgroundColor,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: <Widget>[
                                        SizedBox(width: 20,),
                                        Expanded(
                                          child: Text(rideLogs[index].path.substring(rideLogs[index].path.lastIndexOf("/") + 1, rideLogs[index].path.lastIndexOf("/") + 19)),
                                        ),
                                        SizedBox(
                                          width: 32,
                                          child: Icon(Icons.open_in_new),
                                        ),
                                        SizedBox(
                                          width: 80,
                                          child: Text("${(rideLogs[index].statSync().size / 1024).round()} kb"),
                                        ),
                                      ],
                                  )
                                ),
                                SizedBox(height: 5,)
                              ]
                          ),
                        ),
                      );
                    }),
              ),
               */
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
/*
                RaisedButton(
                    child: Text("Start Ride"),
                    onPressed: () async {
                      await FileManager.clearLogFile().whenComplete(() {
                        Scaffold
                            .of(context)
                            .showSnackBar(SnackBar(content: Text('Recording new ride')));
                        setState(() {
                          temporaryLog = "";
                        });
                      });
                    }),

                SizedBox(width: 5,),



                  RaisedButton(
                      child: Text("Debug Data"),
                      onPressed: () async {
                        FileManager.readLogFile().then((value){
                          setState(() {
                            temporaryLog = value;
                          });
                        });
                      }),
                  SizedBox(width: 5,),
                   */

                /*
                  RaisedButton(
                      child: Text("Save Ride"),
                      onPressed: () async {

                        ///Save temporary data to user documents, later iterate documents and show list of logs to load
                        await FileManager.saveLogToDocuments().then((savedFilePath) async {

                        /// Analyze log to generate database statistics
                        double maxCurrentBattery = 0.0;
                        double maxCurrentMotor = 0.0;
                        int faultCodeCount = 0;
                        double minElevation;
                        double maxElevation;
                        await FileManager.openLogFile(savedFilePath).then((value){
                          List<String> thisRideLogEntries = value.split("\n");
                          for(int i=0; i<thisRideLogEntries.length; ++i) {
                            final entry = thisRideLogEntries[i].split(",");

                            if(entry.length > 1){ // entry[0] = Time, entry[1] = Data type
                              ///GPS position entry
                              if(entry[1] == "position") {
                                //DateTime, 'position', lat, lon, accuracy, altitude, speed, speedAccuracy
                                // Track elevation change
                                double elevation = double.parse(entry[5]);
                                minElevation ??= elevation; //Set if null
                                maxElevation ??= elevation; //Set if null
                                if (elevation < minElevation) minElevation = elevation;
                                if (elevation > maxElevation) maxElevation = elevation;
                              }
                              ///ESC Values
                              else if (entry[1] == "values" && entry.length > 9) {
                                //[2020-05-19T13:46:28.8, values, 12.9, -99.9, 29.0, 0.0, 0.0, 0.0, 0.0, 11884, 102]
                                double motorCurrent = double.parse(entry[6]); //Motor Current
                                double batteryCurrent = double.parse(entry[7]); //Input Current
                                if (batteryCurrent>maxCurrentBattery) maxCurrentBattery = batteryCurrent;
                                if (motorCurrent>maxCurrentMotor) maxCurrentMotor = motorCurrent;
                                //TODO: max speed
                                //TODO: average speed
                                //TODO: Distance
                              }
                              ///Fault codes
                              else if (entry[1] == "fault") {
                                ++faultCodeCount;
                              }
                            }
                          }
                        });

                        /// Insert record into database
                        DatabaseAssistant.dbInsertLog(LogInfoItem(
                            boardID: widget.myUserSettings.currentDeviceID,
                            boardAlias: widget.myUserSettings.settings.boardAlias,
                            logFilePath: savedFilePath,
                            avgSpeed: -1.0,
                            maxSpeed: -1.0,
                            elevationChange: maxElevation != null ? maxElevation - minElevation : -1.0,
                            maxAmpsBattery: maxCurrentBattery,
                            maxAmpsMotors: maxCurrentMotor,
                            distance: -1.0,
                            durationSeconds: DateTime.now().difference(FileManager.logFileStartTime).inSeconds,
                            faultCount: faultCodeCount,
                            rideName: "",
                            notes: ""
                        ));

                        /// Finish up //TODO: _listFiles() and below call setState(): Optimize please
                        _listFiles();
                        Scaffold
                            .of(context)
                            .showSnackBar(SnackBar(content: Text('Ride Log Saved')));
                        await FileManager.clearLogFile();
                        setState(() {
                          temporaryLog = "";
                        });
                      });
                    }),

                   */


                SizedBox(width: 5,),
                RaisedButton(
                    child: Text("ls"),
                    onPressed: () async {
                      //TODO: Request files from receiver
                      widget.theTXLoggerCharacteristic.write(utf8.encode("ls~"));
                    }),

                SizedBox(width: 5,),
                RaisedButton(
                    child: Text("cat"),
                    onPressed: () async {
                      //TODO: too much to list
                      widget.theTXLoggerCharacteristic.write(utf8.encode("cat 2020-06-20T20:26:40~"));
                    }),

                SizedBox(width: 5,),
                RaisedButton(
                    child: Text("rm"),
                    onPressed: () async {
                      //TODO: too much to list
                      widget.theTXLoggerCharacteristic.write(utf8.encode("rm 1970-01-01T00:00:06~"));
                    }),

                SizedBox(width: 5,),
                RaisedButton(
                    child: Text("sync"),
                    onPressed: () async {
                      //TODO: too much to list
                      widget._handleSyncPress();
                    }),
              ],
            ),


            Row( mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              SizedBox(width: 5,),
              RaisedButton(
                  child: Text("start"),
                  onPressed: () async {
                    widget.theTXLoggerCharacteristic.write(utf8.encode("logstart~"));
                  }),

              SizedBox(width: 5,),
              RaisedButton(
                  child: Text("stop"),
                  onPressed: () async {
                    widget.theTXLoggerCharacteristic.write(utf8.encode("logstop~"));
                  }),

              SizedBox(width: 5,),
              RaisedButton(
                  child: Text("set time"),
                  onPressed: () async {
                    widget.theTXLoggerCharacteristic.write(utf8.encode("settime ${DateTime.now().toIso8601String().substring(0,21).replaceAll("-", ":")}~"));
                  }),

            ],),

            SizedBox(height: 5,)
            /*
              Expanded(child:
                SingleChildScrollView(
                  child: Text(temporaryLog, style: TextStyle(fontSize: 8),),
                )
              ),
               */


          ],
        ),
      ),
    );
  }
}
