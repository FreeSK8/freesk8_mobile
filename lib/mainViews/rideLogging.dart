import 'dart:convert';

import 'package:esys_flutter_share/esys_flutter_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

import '../components/databaseAssistant.dart';
import '../components/fileManager.dart';
import '../widgets/fileSyncViewer.dart';
import '../globalUtilities.dart';
import '../subViews/rideLogViewer.dart';
import '../components/userSettings.dart';
import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';

import 'package:table_calendar/table_calendar.dart';

import 'dart:io';

import 'package:flutter_slidable/flutter_slidable.dart';

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
  RideLogging({
    this.myUserSettings,
    this.theTXLoggerCharacteristic,
    this.syncInProgress,
    this.onSyncPress,
    this.syncStatus,
    this.eraseOnSync,
    this.onSyncEraseSwitch,
    this.isLoggerLogging,
    this.isRobogotchi
  });
  final UserSettings myUserSettings;
  final BluetoothCharacteristic theTXLoggerCharacteristic;
  final bool syncInProgress;
  final ValueChanged<bool> onSyncPress;
  final FileSyncViewerArguments syncStatus;
  final bool eraseOnSync;
  final ValueChanged<bool> onSyncEraseSwitch;
  final bool isLoggerLogging;
  final bool isRobogotchi;

  void _handleSyncPress() {
    onSyncPress(!syncInProgress);
  }

  RideLoggingState createState() => new RideLoggingState();

  static const String routeName = "/ridelogging";
}

class RideLoggingState extends State<RideLogging> with TickerProviderStateMixin {

  static bool showDevTools = false; // Flag to control shoting developer stuffs
  static bool showListView = false; // Flag to control showing list view vs calendar
  String temporaryLog = "";
  List<FileSystemEntity> rideLogs = [];
  List<FileStat> rideLogsFileStats = [];
  final GlobalKey<State> _keyLoader = new GlobalKey<State>();
  List<LogInfoItem> rideLogsFromDatabase = [];
  String orderByClause = "date_created DESC";

  final tecRideNotes = TextEditingController();

  Map<DateTime, List> _events = {};
  List _selectedEvents = [];
  CalendarController _calendarController;
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.theTXLoggerCharacteristic != null) {
      widget.theTXLoggerCharacteristic.write(utf8.encode("status~")).catchError((error){
        globalLogger.e("rideLogging::initState: Robogotchi status request failed. Are we connected?");
      });
    }

    _selectedDay = DateTime.parse(new DateFormat("yyyy-MM-dd").format(DateTime.now()));
    _listFiles(true);

    _calendarController = CalendarController();
  }

  @override
  void dispose(){
    tecRideNotes?.dispose();

    super.dispose();
  }

  void _listFiles(bool doSetState) async {
    //globalLogger.wtf("selecting logs from database");
    try {
      rideLogsFromDatabase = await DatabaseAssistant.dbSelectLogs(orderByClause: orderByClause);

      // Prepare data for Calendar View
      _events = {}; // Clear events before populating from database
      rideLogsFromDatabase.forEach((element) {
        DateTime thisDate = DateTime.parse(new DateFormat("yyyy-MM-dd").format(element.dateTime.add(DateTime.now().timeZoneOffset)));
        if (_events.containsKey(thisDate)) {
          //globalLogger.wtf("updating $thisDate");
          _events[thisDate].add('${rideLogsFromDatabase.indexOf(element)}');
        } else {
          //globalLogger.wtf("adding $thisDate");
          _events[thisDate] = ['${rideLogsFromDatabase.indexOf(element)}'];
        }
      });
      _selectedEvents = _events[_selectedDay] ?? [];

      // Set state if requested and is an appropriate time
      if (doSetState && this.mounted) setState(() {});
    } catch (e) {
      globalLogger.w("_listFiles threw an exception (rebuilding too often?): ${e.toString()}");
    }
  }


  // Simple TableCalendar configuration (using Styles)
  Widget _buildTableCalendar() {
    return TableCalendar(
      initialCalendarFormat: CalendarFormat.twoWeeks,
      calendarController: _calendarController,
      events: _events,
      //holidays: _holidays,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      calendarStyle: CalendarStyle(
        selectedColor: Colors.deepOrange[400],
        todayColor: Colors.deepOrange[200],
        markersColor: Colors.white,
        outsideDaysVisible: false,
      ),
      headerStyle: HeaderStyle(
        formatButtonShowsNext: false,
        formatButtonTextStyle: TextStyle().copyWith(
            color: Colors.white, fontSize: 15.0),
        formatButtonDecoration: BoxDecoration(
          color: Colors.deepOrange[400],
          borderRadius: BorderRadius.circular(16.0),
        ),
      ),
      onDaySelected: _onDaySelected,
      onVisibleDaysChanged: _onVisibleDaysChanged,
      onCalendarCreated: _onCalendarCreated,
    );
  }

  Widget _buildEventList() {
    return ListView(
      children: _selectedEvents
          .map((event) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).dialogBackgroundColor,
          border: Border.all(width: 0.8),
          borderRadius: BorderRadius.circular(12.0),
        ),
        margin:
        const EdgeInsets.symmetric(horizontal: 10.0, vertical: 1.0),
        child: ListTile(

          //TODO: this title's Column is essentially taken from the ListView Gesture Detector. simplify
          title: Column(
              children: <Widget>[
                Container(color: Theme.of(context).dialogBackgroundColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[

                        SizedBox(width: 50, child:
                        FutureBuilder<String>(
                            future: UserSettings.getBoardAvatarPath(rideLogsFromDatabase[int.parse(event)].boardID),
                            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                              return CircleAvatar(
                                  backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                                  radius: 25,
                                  backgroundColor: Colors.white);
                            })
                          ,),
                        SizedBox(width: 10,),

                        Expanded(
                          child: Text(rideLogsFromDatabase[int.parse(event)].dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)),
                        ),

                        SizedBox(
                          width: 32,
                          child: Icon(
                              rideLogsFromDatabase[int.parse(event)].faultCount < 1 ? Icons.check_circle_outline : Icons.error_outline,
                              color: rideLogsFromDatabase[int.parse(event)].faultCount < 1 ? Colors.green : Colors.red),
                        ),

                        /// Ride Log Note Editor
                        SizedBox(
                          width: 32,
                          child: GestureDetector(
                            onTap: (){
                              tecRideNotes.text = rideLogsFromDatabase[int.parse(event)].notes;

                              showDialog(context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Icon(Icons.chat, size:40),
                                    content: TextField(
                                      controller: tecRideNotes,
                                      decoration: new InputDecoration(labelText: "Notes:"),
                                      keyboardType: TextInputType.text,
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                          onPressed: () async {
                                            // Update notes field in database
                                            await DatabaseAssistant.dbUpdateNote(rideLogsFromDatabase[int.parse(event)].logFilePath, tecRideNotes.text);
                                            _listFiles(true);
                                            Navigator.of(context).pop(true);
                                          },
                                          child: const Text("Save")
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text("Cancel"),
                                      ),
                                    ],
                                  )
                              );
                            },
                            child: Icon( rideLogsFromDatabase[int.parse(event)].notes.length > 0 ? Icons.chat : Icons.chat_bubble_outline, size: 32),
                          ),
                        ),

                        SizedBox(width: 10),
                        //SizedBox(
                        //  width: 32,
                        //  child: Icon(Icons.timer),
                        //),
                        SizedBox(
                            //child: Text("${(File(rideLogsFromDatabase[index].logFilePath).statSync().size / 1024).round()} kb"),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${Duration(seconds: rideLogsFromDatabase[int.parse(event)].durationSeconds).toString().substring(0,Duration(seconds: rideLogsFromDatabase[int.parse(event)].durationSeconds).toString().indexOf("."))}"),
                                rideLogsFromDatabase[int.parse(event)].distance == -1.0 || widget.myUserSettings.settings.useGPSData ? Container() : Text("${widget.myUserSettings.settings.useImperial ? kmToMile(rideLogsFromDatabase[int.parse(event)].distance) : rideLogsFromDatabase[int.parse(event)].distance} ${widget.myUserSettings.settings.useImperial ? "mi" : "km"}"),
                                widget.myUserSettings.settings.useGPSData && rideLogsFromDatabase[int.parse(event)].distanceGPS != -1.0 ? Text("${widget.myUserSettings.settings.useImperial ? kmToMile(rideLogsFromDatabase[int.parse(event)].distanceGPS) : rideLogsFromDatabase[int.parse(event)].distanceGPS} ${widget.myUserSettings.settings.useImperial ? "mi" : "km"}") : Container(),
                              ],
                            )
                        ),
                      ],
                    )
                ),
                SizedBox(height: 5,)
              ]
          ),


          onTap: () async {
            await _loadLogFile(int.parse(event));
          },
          onLongPress: () {
            _buildDialog("${rideLogsFromDatabase[int.parse(event)].boardAlias}", rideLogsFromDatabase[int.parse(event)], widget.myUserSettings.settings.useImperial);
          },
        ),
      ))
          .toList(),
    );
  }

  void _onDaySelected(DateTime day, List events, List holidays) {
    //globalLogger.wtf('CALLBACK: _onDaySelected');
    setState(() {
      _selectedDay = DateTime.parse(new DateFormat("yyyy-MM-dd").format(day));
      _selectedEvents = events;
    });
  }

  void _onVisibleDaysChanged(DateTime first, DateTime last, CalendarFormat format) {
    //globalLogger.wtf('CALLBACK: _onVisibleDaysChanged');
    //TODO: capture calendar format changes and store with user preferences for determining initial viewing format
  }

  void _onCalendarCreated(
      DateTime first, DateTime last, CalendarFormat format) {
    //globalLogger.wtf('CALLBACK: _onCalendarCreated');
  }

  Future<void> _loadLogFile(int index) async {
    // Show indication of loading
    await Dialogs.showLoadingDialog(context, _keyLoader).timeout(Duration(milliseconds: 500)).catchError((error){});

    // Fetch user settings for selected board, fallback to current settings if not found
    UserSettings selectedBoardSettings = new UserSettings();
    if (await selectedBoardSettings.loadSettings(rideLogsFromDatabase[index].boardID) == false) {
      globalLogger.wtf("WARNING: Board ID ${rideLogsFromDatabase[index].boardID} has no settings on this device!");
      selectedBoardSettings = widget.myUserSettings;
    }

    // navigate to the route by replacing the loading dialog
    Navigator.of(context).pushReplacementNamed(RideLogViewer.routeName,
      arguments: RideLogViewerArguments(
          rideLogsFromDatabase[index],
          selectedBoardSettings,
          selectedBoardSettings.settings.boardAvatarPath == null ? null : FileImage(File(await UserSettings.getBoardAvatarPath(rideLogsFromDatabase[index].boardID)))
      ),
    ).then((value){
      // Once finished re-list files and remove a potential snackBar item before re-draw of setState
      if (context != null) {
        _listFiles(true);
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Build: RideLogging");

    // Access database to request file list if we are not performing Sync operation
    if (!widget.syncInProgress) {
      _listFiles(false);
    }

    return Container(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: 5,),





            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              GestureDetector(
                child: Row(children: [
                  Image(image: AssetImage("assets/dri_icon.png"),height: 60),
                  Column(children: [
                    Text("Ride Logging", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    Row(children: [
                      showListView ? Icon(Icons.calendar_today) : Icon(Icons.view_list_sharp),
                      Text(showListView ? "Show Calendar" : "Show List", style: TextStyle(fontSize: 20)),
                    ],)
                  ],)
                ],),
                onTap: (){
                  setState(() {
                    showListView = !showListView;
                  });
                },
                onLongPress: () {
                  setState(() {
                    showDevTools = !showDevTools;
                  });
                },
              ),



            ],),




            showListView ? Container() : _buildTableCalendar(),
            showListView ? Container() : SizedBox(height: 8.0),
            showListView ? Container() : Expanded(child: _buildEventList()),

            !showListView ? Container() : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
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
                IconButton(
                  icon: Icon(Icons.battery_charging_full),
                  tooltip: 'Sort by Power Used',
                  onPressed: () {
                    orderByClause = "watt_hours DESC, id DESC";
                    _listFiles(true);
                  },
                ),
              ],
            ),




            //TODO show graphic if we have no rides to list?

            /// Show rides from database entries
            !showListView ? Container() : Expanded( child:
              ListView.builder(
                itemCount: rideLogsFromDatabase.length,
                itemBuilder: (BuildContext context, int index){
                  //Each item has dismissible wrapper
                  return Slidable(
                    key: Key(rideLogsFromDatabase[index].logFilePath.substring(rideLogsFromDatabase[index].logFilePath.lastIndexOf("/") + 1)),
                    actionPane: SlidableDrawerActionPane(),
                    actionExtentRatio: 0.25,
                    child: Container(

                      child: GestureDetector(
                        onTap: () async {
                          await _loadLogFile(index);
                        },
                        onLongPress: () {
                          _buildDialog("${rideLogsFromDatabase[index].boardAlias}", rideLogsFromDatabase[index], widget.myUserSettings.settings.useImperial);
                        },
                        child: Column(
                            children: <Widget>[
                              Container(height: 50,
                                  width: MediaQuery.of(context).size.width - 20,
                                  margin: const EdgeInsets.only(left: 10.0, right: 10),
                                  color: Theme.of(context).dialogBackgroundColor,
                                  child: Row(

                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: <Widget>[
                                      SizedBox(width: 5,),
                                      SizedBox(width: 50, child:
                                      FutureBuilder<String>(
                                          future: UserSettings.getBoardAvatarPath(rideLogsFromDatabase[index].boardID),
                                          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                            if (snapshot.hasData) {
                                              return CircleAvatar(
                                                  backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                                                  radius: 25,
                                                  backgroundColor: Colors.white);
                                            }
                                            return SizedBox(width:50);
                                          })
                                        ,),
                                      SizedBox(width: 10,),

                                      Expanded(
                                        child: Text(rideLogsFromDatabase[index].dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)),
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
                                                builder: (_) =>  AlertDialog(
                                                  title: const Icon(Icons.chat, size:40),
                                                  content: TextField(
                                                    controller: tecRideNotes,
                                                    decoration: new InputDecoration(labelText: "Notes:"),
                                                    keyboardType: TextInputType.text,
                                                  ),
                                                  actions: <Widget>[
                                                    TextButton(
                                                        onPressed: () async {
                                                          // Update notes field in database
                                                          await DatabaseAssistant.dbUpdateNote(rideLogsFromDatabase[index].logFilePath, tecRideNotes.text);
                                                          _listFiles(true);
                                                          Navigator.of(context).pop(true);
                                                        },
                                                        child: const Text("Save")
                                                    ),
                                                    TextButton(
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

                                      SizedBox(width: 10),

                                      SizedBox(
                                          width: 69,
                                          //child: Text("${(File(rideLogsFromDatabase[index].logFilePath).statSync().size / 1024).round()} kb"),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("${Duration(seconds: rideLogsFromDatabase[index].durationSeconds).toString().substring(0,Duration(seconds: rideLogsFromDatabase[index].durationSeconds).toString().indexOf("."))}"),
                                              rideLogsFromDatabase[index].distance == -1.0 || widget.myUserSettings.settings.useGPSData ? Container() : Text("${widget.myUserSettings.settings.useImperial ? kmToMile(rideLogsFromDatabase[index].distance) : rideLogsFromDatabase[index].distance} ${widget.myUserSettings.settings.useImperial ? "mi" : "km"}"),
                                              widget.myUserSettings.settings.useGPSData && rideLogsFromDatabase[index].distanceGPS != -1.0 ? Text("${widget.myUserSettings.settings.useImperial ? kmToMile(rideLogsFromDatabase[index].distanceGPS) : rideLogsFromDatabase[index].distanceGPS} ${widget.myUserSettings.settings.useImperial ? "mi" : "km"}") : Container(),
                                            ],
                                          )
                                      ),
                                    ],
                                  )
                              ),
                              SizedBox(height: 5,)
                            ]
                        ),
                      ),
                    ),
                    actions: <Widget>[
                      IconSlideAction(
                        caption: 'Merge',
                        color: Colors.blue,
                        icon: Icons.archive,
                        onTap: () async {
                          if (index+1 == rideLogsFromDatabase.length) return;

                          // Confirm Merge with user
                          bool doMerge = await genericConfirmationDialog(
                              context,
                              TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Merge")
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text("Cancel"),
                              ),
                              "Merge with previous file?",
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Select merge to combine this file with the previous"),
                                  SizedBox(height: 15),
                                  Text("${rideLogsFromDatabase[index].boardAlias}"),
                                  Text("${rideLogsFromDatabase[index].dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)}"),
                                  Text("${prettyPrintDuration(Duration(seconds: rideLogsFromDatabase[index].durationSeconds))}"),

                                  SizedBox(height: 15),
                                  Text("Previous File:"),
                                  Text("${rideLogsFromDatabase[index+1].boardAlias}"),
                                  Text("${rideLogsFromDatabase[index+1].dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)}"),
                                  Text("${prettyPrintDuration(Duration(seconds: rideLogsFromDatabase[index+1].durationSeconds))}"),
                                ],
                              )
                          );
                          if (doMerge) {
                            try {
                              globalLogger.d("Log Merge Confirmed. Files: ${rideLogsFromDatabase[index].dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)}, ${rideLogsFromDatabase[index+1].dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)}");
                              final documentsDirectory = await getApplicationDocumentsDirectory();
                              // Get later file contents and statistics
                              String fileContents = File("${documentsDirectory.path}${rideLogsFromDatabase[index].logFilePath}").readAsStringSync();
                              LogInfoItem statsLater = rideLogsFromDatabase[index];
                              // Update earlier file with extra contents
                              File("${documentsDirectory.path}${rideLogsFromDatabase[index+1].logFilePath}").writeAsStringSync(fileContents,mode: FileMode.append);
                              LogInfoItem statsEarlier = rideLogsFromDatabase[index+1];
                              // Update earlier file statistics
                              double avgMovingSpeedGPS = -1.0;
                              double avgSpeedGPS = -1.0;
                              // avgMovingSpeedGPS may be -1.0 from either entry
                              if (statsEarlier.avgMovingSpeedGPS != -1.0 && statsLater.avgMovingSpeedGPS != -1.0) {
                                avgMovingSpeedGPS = doublePrecision(statsEarlier.avgMovingSpeedGPS + statsLater.avgMovingSpeedGPS / 2, 2);
                              } else if (statsEarlier.avgMovingSpeedGPS != -1.0) {
                                avgMovingSpeedGPS = statsEarlier.avgMovingSpeedGPS;
                              } else if (statsLater.avgMovingSpeedGPS != -1.0) {
                                avgMovingSpeedGPS = statsLater.avgMovingSpeedGPS;
                              }
                              // gpsAvgSpeed may be -1.0 from either entry
                              if (statsEarlier.avgSpeedGPS != -1.0 && statsLater.avgSpeedGPS != -1.0) {
                                avgSpeedGPS = doublePrecision(statsEarlier.avgSpeedGPS + statsLater.avgSpeedGPS / 2, 2);
                              } else if (statsEarlier.avgSpeedGPS != -1.0) {
                                avgSpeedGPS = statsEarlier.avgSpeedGPS;
                              } else if (statsLater.avgSpeedGPS != -1.0) {
                                avgSpeedGPS = statsLater.avgSpeedGPS;
                              }
                              LogInfoItem newStatistics = new LogInfoItem(
                                  dateTime: statsEarlier.dateTime,
                                  boardID: statsEarlier.boardID,
                                  boardAlias: statsEarlier.boardAlias,
                                  logFilePath: statsEarlier.logFilePath,
                                  avgMovingSpeed: doublePrecision(statsEarlier.avgMovingSpeed + statsLater.avgMovingSpeed / 2, 2),
                                  avgMovingSpeedGPS: avgMovingSpeedGPS,
                                  avgSpeed: doublePrecision(statsEarlier.avgSpeed + statsLater.avgSpeed / 2, 2),
                                  avgSpeedGPS: avgSpeedGPS,
                                  maxSpeed: statsEarlier.maxSpeed > statsLater.maxSpeed ? statsEarlier.maxSpeed : statsLater.maxSpeed,
                                  maxSpeedGPS: statsEarlier.maxSpeedGPS > statsLater.maxSpeedGPS ? statsEarlier.maxSpeedGPS : statsLater.maxSpeedGPS,
                                  altitudeMax: statsEarlier.altitudeMax > statsLater.altitudeMax ? statsEarlier.altitudeMax : statsLater.altitudeMax,
                                  altitudeMin: statsEarlier.altitudeMin < statsLater.altitudeMin ? statsEarlier.altitudeMin : statsLater.altitudeMin,
                                  maxAmpsBattery: statsEarlier.maxAmpsBattery > statsLater.maxAmpsBattery ? statsEarlier.maxAmpsBattery : statsLater.maxAmpsBattery,
                                  maxAmpsMotors: statsEarlier.maxAmpsBattery > statsLater.maxAmpsBattery ? statsEarlier.maxAmpsBattery : statsLater.maxAmpsBattery,
                                  wattHoursTotal: _addDoubleUnlessNegativeOne(statsEarlier.wattHoursTotal, statsLater.wattHoursTotal),
                                  wattHoursRegenTotal: _addDoubleUnlessNegativeOne(statsEarlier.wattHoursRegenTotal, statsLater.wattHoursRegenTotal),
                                  distance: _addDoubleUnlessNegativeOne(statsEarlier.distance, statsLater.distance),
                                  distanceGPS: _addDoubleUnlessNegativeOne(statsEarlier.distanceGPS, statsLater.distanceGPS),
                                  durationSeconds: statsLater.dateTime.difference(statsEarlier.dateTime).inSeconds + statsLater.durationSeconds,
                                  faultCount: statsEarlier.faultCount + statsLater.faultCount,
                                  rideName: statsEarlier.rideName,
                                  notes: statsEarlier.notes.length > statsLater.notes.length ? statsEarlier.notes : statsLater.notes
                              );
                              await DatabaseAssistant.dbUpdateLog(newStatistics); // Update database entry
                              rideLogsFromDatabase[index+1] = newStatistics; // Update in memory

                              // Remove later file from database and filesystem
                              await DatabaseAssistant.dbRemoveLog(rideLogsFromDatabase[index].logFilePath);
                              //Remove from Filesystem
                              File("${documentsDirectory.path}${rideLogsFromDatabase[index].logFilePath}").deleteSync();
                              setState(() {
                                //Remove from itemBuilder's list of entries
                                rideLogsFromDatabase.removeAt(index);
                              });
                            } catch (e, stacktrace) {
                              globalLogger.e("rideLogging:doMerge: exception: ${e.toString()}");
                              globalLogger.e(stacktrace.toString());
                            }
                          }
                        }
                      ),
                      IconSlideAction(
                        caption: 'Share',
                        color: Colors.indigo,
                        icon: Icons.share,
                        onTap: () async {
                          // Share file dialog
                          String fileSummary = 'Robogotchi gotchi!';
                          String fileContents = await FileManager.openLogFile(rideLogsFromDatabase[index].logFilePath);
                          await Share.file('FreeSK8Log', "${rideLogsFromDatabase[index].logFilePath.substring(rideLogsFromDatabase[index].logFilePath.lastIndexOf("/") + 1)}", utf8.encode(fileContents), 'text/csv', text: fileSummary);
                        },
                      ),
                    ],
                    secondaryActions: <Widget>[
                      IconSlideAction(
                        caption: 'Delete',
                        color: Colors.red,
                        icon: Icons.delete,
                        onTap: () async {
                          // Confirm Erase with user
                          bool doErase = await genericConfirmationDialog(
                              context,
                              TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Delete")
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text("Cancel"),
                              ),
                              "Delete file?",
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("Are you sure you wish to permanently erase this item?"),
                                  SizedBox(height: 15),
                                  Text("${rideLogsFromDatabase[index].boardAlias}"),
                                  Text("${rideLogsFromDatabase[index].dateTime.add(DateTime.now().timeZoneOffset).toString().substring(0,19)}"),
                                  Text("${prettyPrintDuration(Duration(seconds: rideLogsFromDatabase[index].durationSeconds))}"),
                                ],
                              )
                          );
                          if (doErase) {
                            final documentsDirectory = await getApplicationDocumentsDirectory();
                            // Remove the item from the database and rideLogs array
                            await DatabaseAssistant.dbRemoveLog(rideLogsFromDatabase[index].logFilePath);
                            //Remove from Filesystem
                            File("${documentsDirectory.path}${rideLogsFromDatabase[index].logFilePath}").deleteSync();
                            setState(() {
                              //Remove from itemBuilder's list of entries
                              rideLogsFromDatabase.removeAt(index);
                            });
                          }
                        },
                      ),
                    ],
                  );
                })),

            widget.syncStatus.syncInProgress?Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FileSyncViewer(syncStatus: widget.syncStatus,),
              ],
            ):Container(),




            Row( mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              widget.syncInProgress ? Container() : ElevatedButton(
                  child: Text(widget.isLoggerLogging? "Stop Log" : "Start Log"),
                  onPressed: () async {
                    if (!widget.isRobogotchi) {
                      return _alertLimitedFunctionality(context);
                    }
                    if (widget.isLoggerLogging) {
                      sendBLEData(widget.theTXLoggerCharacteristic, utf8.encode("logstop~"), false);
                    } else if (!widget.syncInProgress) {
                      sendBLEData(widget.theTXLoggerCharacteristic, utf8.encode("logstart~"), false);
                    }
                  }),
              SizedBox(width: 5,),
              ElevatedButton(
                  child: Text(widget.syncInProgress?"Stop Sync":"Sync Logs"),
                  onPressed: () async {
                    if (!widget.isRobogotchi) {
                      return _alertLimitedFunctionality(context);
                    }
                    if (widget.isLoggerLogging) {
                      //return genericAlert(context, "Hold up", Text("There is a log file recording. Please stop logging before sync."), "Oh, one sec!");
                      genericConfirmationDialog(
                          context,
                          TextButton(child: Text("Keep logging"),onPressed: (){
                            Navigator.of(context).pop(false); // Close dialog
                          }),
                          TextButton(child: Text("Stop N Sync"),onPressed: () async {
                            await sendBLEData(widget.theTXLoggerCharacteristic, utf8.encode("logstop~"), false); // Stop logging
                            widget._handleSyncPress(); // Start sync routine
                            Navigator.of(context).pop(true); // Close dialog
                          }),
                          "Hold up",
                          Text("There is a log file recording. Do you want to stop logging and sync now?")
                      );
                    } else {
                      widget._handleSyncPress(); //Start or stop file sync routine
                    }
                  }),



              /* Most users will not want to leave the log on the robogotchi but some developers might */
              showDevTools ? Row(
                children: [
                  SizedBox(width: 5,),
                  Column(children: <Widget>[

                    Icon(widget.eraseOnSync?Icons.delete_forever:Icons.save,
                        color: widget.eraseOnSync?Colors.orange:Colors.green
                    ),
                    Text(widget.eraseOnSync?"Take":"Leave"),
                  ],),

                  Switch(
                    value: widget.eraseOnSync,
                    onChanged: (bool newValue){
                      globalLogger.d("User Switched Erase on Sync to $newValue");
                      widget.onSyncEraseSwitch(newValue);
                    },
                  )
                ],
              ) : Container(),

            ],),


            SizedBox(height: 5,)

          ],
        ),
      ),
    );
  }

  double _addDoubleUnlessNegativeOne(double valA, double valB, {int precision=2}) {
    if (valA != -1.0 && valB != -1.0) {
      return doublePrecision(valA + valB, precision);
    } else if (valA != -1.0) {
      return valA;
    } else if (valB != -1.0) {
      return valB;
    }
    return -1.0;
  }

  Future<void> _alertLimitedFunctionality(BuildContext context) async {
    return genericAlert(context, "Not a Robogotchi", Text('This feature only works with the FreeSK8 Robogotchi\n\nPlease connect to a Robogotchi device'), "Shucks");
  }

  void _buildDialog(String title, LogInfoItem logEntry, bool useImperial) {
    List<TableRow> tableChildren = [];

    tableChildren.add(TableRow(children: [
      Icon(Icons.watch),
      Text("${prettyPrintDuration(Duration(seconds: logEntry.durationSeconds))}",
          textAlign: TextAlign.center)]));

    // Show GPS distance if requested and available
    //NOTE: Beta testers with old entries (internal database v5) will have a -1.0 distanceGPS value
    if (widget.myUserSettings.settings.useGPSData) {
      if (logEntry.distanceGPS != -1.0) tableChildren.add(TableRow(children: [
        Icon(Icons.flag),
        Text("${useImperial ? kmToMile(logEntry.distanceGPS) : logEntry.distanceGPS} ${useImperial ? "mi" : "km"}",
            textAlign: TextAlign.center)]));
    } else {
      if (logEntry.distance != -1.0) tableChildren.add(TableRow(children: [
        Icon(Icons.flag_outlined),
        Text("${useImperial ? kmToMile(logEntry.distance) : logEntry.distance} ${useImperial ? "mi" : "km"}",
            textAlign: TextAlign.center)]));
    }


    // Show GPS max speed if requested and available
    //NOTE: Beta testers with old entries (internal database v5) will have a -1.0 maxSpeedGPS value
    if (widget.myUserSettings.settings.useGPSData) {
      if (logEntry.maxSpeedGPS != -1.0) tableChildren.add(TableRow(children: [
        Transform.rotate(angle: 3.14159, child: Icon(Icons.av_timer),),
        Text("${useImperial ? kmToMile(logEntry.maxSpeedGPS) : logEntry.maxSpeedGPS} ${useImperial ? "mph" : "kph"}",
            textAlign: TextAlign.center)]));
    } else {
      tableChildren.add(TableRow(children: [
        Transform.rotate(angle: 3.14159, child: Icon(Icons.av_timer),),
        Text("${useImperial ? kmToMile(logEntry.maxSpeed) : logEntry.maxSpeed} ${useImperial ? "mph" : "kph"}",
            textAlign: TextAlign.center)]));
    }


    tableChildren.add(TableRow(children: [
      Icon(Icons.battery_charging_full),
      Text("${logEntry.maxAmpsBattery} amps (single)",
          textAlign: TextAlign.center) ]));
    tableChildren.add(TableRow(children: [
      Icon(Icons.slow_motion_video),
      Text("${logEntry.maxAmpsMotors} amps (single)",
          textAlign: TextAlign.center)]));

    tableChildren.add(TableRow(children: [
      Icon(Icons.bolt),
      Text("${logEntry.wattHoursTotal} wh (total)",
          textAlign: TextAlign.center)]));
    tableChildren.add(TableRow(children: [
      Icon(Icons.bolt),
      Text("${logEntry.wattHoursRegenTotal} wh regen",
          textAlign: TextAlign.center)]));

    if (logEntry.altitudeMax != -1.0) tableChildren.add(TableRow(children: [
      Icon(Icons.show_chart),
      Text("${doublePrecision(logEntry.altitudeMax - logEntry.altitudeMin, 2)} meters",
          textAlign: TextAlign.center)]));

    tableChildren.add(TableRow(children: [
      Icon(Icons.warning_amber_outlined),
      Text("${logEntry.faultCount} fault${logEntry.faultCount != 1 ? "s" : ""}",
          textAlign: TextAlign.center)]));

    genericAlert(context, title, Column(
      children: [
        Text("${logEntry.dateTime.toIso8601String().substring(0,19)}"),
        SizedBox(height: 10),
        Table(
            columnWidths: {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
            },
            children: tableChildren
        )
      ],
    ), "OK");
  }
}
