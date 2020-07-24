import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// UI Pages
import 'package:freesk8_mobile/tabs/connectionStatus.dart';
import 'package:freesk8_mobile/tabs/realTimeData.dart';
import 'package:freesk8_mobile/tabs/esk8Configuration.dart';
import 'package:freesk8_mobile/tabs/test.dart';
import 'package:freesk8_mobile/tabs/rideLogging.dart';
import 'package:freesk8_mobile/rideLogViewer.dart';
import 'package:freesk8_mobile/fileSyncViewer.dart';
import 'package:freesk8_mobile/focWizard.dart';

// Supporting packages
import 'package:freesk8_mobile/bleHelper.dart';
import 'package:freesk8_mobile/escHelper.dart';
import 'package:freesk8_mobile/userSettings.dart';
import 'package:freesk8_mobile/file_manager.dart';
import 'package:freesk8_mobile/autoStopHandler.dart';

import 'package:flutter_blue/flutter_blue.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:background_locator/background_locator.dart';
import 'package:background_locator/location_dto.dart';
import 'package:background_locator/location_settings.dart';

import 'package:location_permissions/location_permissions.dart';

import 'package:wakelock/wakelock.dart';

import 'databaseAssistant.dart';

///
/// FreeSK8 Mobile Known issues
/// * Sync without Erase will not show last file until you switch back to logging tab
/// * Sync with Erase while Logging is active will not erase files (could be robogotchi fw, see renee)
/// * Duty Cycle gauge on Real Time tab may flicker the red highlight on and off
/// * Editing board settings may put the input cursor at the start of the entry
///
/// Robogotchi Known issues
/// * None, it's perfect
///

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
      // Title
      title: "FreeSK8",
      // Home
      home: MyHome(),
      routes: <String, WidgetBuilder>{
        RideLogViewer.routeName: (BuildContext context) => RideLogViewer(),
        ConfigureESC.routeName: (BuildContext context) => ConfigureESC(),
      },
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.pink,
        accentColor: Colors.pinkAccent,
        buttonColor: Colors.pinkAccent.shade100
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
    )
  );
}

class MyHome extends StatefulWidget {

  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();

  final Map<Guid, List<int>> readValues = new Map<Guid, List<int>>();
  final UserSettings myUserSettings = new UserSettings();

  @override
  MyHomeState createState() => MyHomeState();
}

// SingleTickerProviderStateMixin is used for animation
class MyHomeState extends State<MyHome> with SingleTickerProviderStateMixin {
  /* Get location for the user at all times */
  static const String _isolateName = "LocatorIsolate";
  ReceivePort locatorReceivePort = ReceivePort();
  //Ok it works!
  LocationDto lastLocation;
  DateTime lastTimeLocation;
  List<LocationDto> routeTakenLocations = new List<LocationDto>();
  
  /* Testing preferences, for fun, keep a counter of how many times the app was opened */
  int counter = -1;
  _incrementCounter() async {
    final prefs = await SharedPreferences.getInstance();
    counter = (prefs.getInt('counter') ?? 0) + 1;
    await prefs.setInt('counter', counter);
  }
  _readPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      counter = prefs.getInt('counter') ?? 0;
    });
  }

  /*
   *---A really nice renee should clean all this up---*
   */
  // Create a tab controller
  TabController controller;

  BLEHelper bleHelper = new BLEHelper();
  ESCHelper escHelper = new ESCHelper();

  static Uint8List escMotorConfiguration;
  static Uint8List escMotorConfigurationDefaults;
  static List<int> _validCANBusDeviceIDs = new List();

  static bool deviceIsConnected = false;
  static bool deviceHasDisconnected = false;
  static BluetoothDevice _connectedDevice;
  static bool isConnectedDeviceKnown = false;
  static List<BluetoothService> _services;
  static StreamSubscription<BluetoothDeviceState> _connectedDeviceStreamSubscription;

  @override
  void initState() {
    super.initState();

    print("main init state");

    FileManager.createLogDirectory();

    //TODO: remove database debug shit
    //TODO: figure out db versioning to perform updates on table(s) for future needs
    //print("CLEARING DATABASE CLEARING DATABASE CLEARING DATABASE CLEARING DATABASE CLEARING DATABASE CLEARING DATABASE CLEARING DATABASE CLEARING DATABASE ");
    //DatabaseAssistant.dbDEBUGDropTable();
    //DatabaseAssistant.dbDEBUGCreateTable();

    if (_connectedDevice != null){
      widget.myUserSettings.loadSettings(_connectedDevice.id.toString());
    } else {
      widget.myUserSettings.loadSettings("defaults");
    }

    _incrementCounter();
    _readPrefs();

    telemetryPacket = new ESCTelemetry();
    bleHelper = new BLEHelper();

    // Initialize the Tab Controller
    controller = TabController(length: 4, vsync: this);

    // Setup BLE event listeners
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceToList(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceToList(result.device);
      }
    });
    widget.flutterBlue.setLogLevel(LogLevel.warning);

    // Setup Location listener
    if (IsolateNameServer.lookupPortByName(_isolateName) != null) {
      IsolateNameServer.removePortNameMapping(_isolateName);
    }
    IsolateNameServer.registerPortWithName(locatorReceivePort.sendPort, _isolateName);
    // Handler for when location data is received from callback
    locatorReceivePort.listen(
          (dynamic data) async {
            await updateLocationForRoute(data);
      },
    );

    // Spin up the background location service
    initBackgroundLocator();

    FileManager.clearLogFile();

    //TODO: watching AppLifecycleState but not doing anything
    WidgetsBinding.instance.addObserver(AutoStopHandler());
  }

  Future<void> updateLocationForRoute(LocationDto data) async {

    lastLocation = data;
    lastTimeLocation = DateTime.now();

    // Filter out points that are too close to the last one
    if (routeTakenLocations.length == 0 ){
      routeTakenLocations.add(lastLocation);
    }
    else if ( (lastLocation.latitude - routeTakenLocations.last.latitude).abs() > 0.00005 ) {
      if ((lastLocation.longitude - routeTakenLocations.last.longitude).abs() > 0.00005) {

        //TODO: also filter out points with really low accuracy, how low is too low you ask? Good question

        // Add location
        routeTakenLocations.add(lastLocation);

        // Re-draw
        if (_connectedDevice == null){ // Only re-draw if we are not connected because telemetry will be updating view
          if(controller.index == 1) { //Only re-draw if we are on the real time data tab because that is where the map lives
            setState((){});
          }
        }
      } else {
        ///print("Longitude too close to add point (${(lastLocation.longitude - routeTakenLocations.last.longitude).abs()})");
      }
    } else {
      ///print("Latitude too close to add point (${(lastLocation.latitude - routeTakenLocations.last.latitude).abs()})");
    }
  }

  Future<void> initBackgroundLocator() async {
    await BackgroundLocator.initialize();
    print("background locator initialized");

    await _checkLocationPermission();
    print("background locator registered for location updates");

    // Check if background locator is started / actually started?
    bool _isRunning = await BackgroundLocator.isRegisterLocationUpdate();
    while(_isRunning == false)
    {
      await _checkLocationPermission();
      _isRunning = await BackgroundLocator.isRegisterLocationUpdate();
      print('BackgroundLocator is Registered for Location Updates? ${_isRunning.toString()}');
    }
  }
  static void locationDataCallback(LocationDto locationDto) async {
    final SendPort send = IsolateNameServer.lookupPortByName(_isolateName);
    send?.send(locationDto);
  }
  static double dp(double val, int places) {
    double mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
  }
  static String formatLogPositionEntry(LocationDto locationDto) { //lat, lon, accuracy, altitude, speed, speedAccuracy
    return "position,${dp(locationDto.latitude, 5)},${dp(locationDto.longitude, 5)},${locationDto.accuracy.toInt()},${dp(locationDto.altitude,1)},${dp(locationDto.speed,1)},${locationDto.speedAccuracy.toInt()},";
  }
  static void notificationCallback() {
    print('notificationCallback: Someone clicked on the notification');
  }
  void startLocationService(){
    print("starting location service");
    BackgroundLocator.registerLocationUpdate(
      locationDataCallback,
      //optional
      androidNotificationCallback: notificationCallback,
      settings: LocationSettings(
          distanceFilter: 0,
          wakeLockTime: 1,
          interval: 1,
          notificationTitle: "FreeSK8 Location Tracking",
      ),
    ); //This does not return
  }
  Future<void> _checkLocationPermission() async {
    final PermissionStatus access = await LocationPermissions().checkPermissionStatus();
    print("checking location permission status: received: $access");
    switch (access) {
      case PermissionStatus.unknown:
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        final permission = await LocationPermissions().requestPermissions(
          permissionLevel: LocationPermissionLevel.locationAlways,
        );
        if (permission == PermissionStatus.granted) {
          startLocationService();
        } else {
          // show error
        }
        break;
      case PermissionStatus.granted:
        startLocationService();
        break;
    }
  }


  @override
  void dispose() {
    if(telemetryTimer != null){
      print("Dispose cancelling telemetry timer");
      telemetryTimer.cancel();
      telemetryTimer = null;
    }

    // Dispose of the Tab Controller
    controller.dispose();

    BackgroundLocator.unRegisterLocationUpdate();
    IsolateNameServer.removePortNameMapping(_isolateName);

    locatorReceivePort?.close();

    super.dispose();
  }

  TabBar getTabBar() {
    return TabBar(
      tabs: <Tab>[
        Tab(
          // set icon to the tab
          icon: Icon(_connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth),
        ),
        Tab(
          icon: Icon(Icons.timeline),
        ),
        Tab(
          icon: Icon(Icons.settings),
        ),
        Tab(
          icon: Icon(Icons.format_align_left),
        ),
      ],
      // setup the controller
      controller: controller,
    );
  }

  TabBarView getTabBarView(var tabs) {
    return TabBarView(
      physics: NeverScrollableScrollPhysics(),

      // Add tabs as widgets
      children: tabs,
      // set the controller
      controller: controller,
    );
  }

  _addDeviceToList(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  bool _scanActive = false;
  void _handleBLEScanState(bool startScan) {
    if (_connectedDevice != null) {
      print("_handleBLEScanState: disconnecting");
    }
    else if (startScan == true) {
      print("_handleBLEScanState: startScan was true");
      widget.devicesList.clear();
      widget.flutterBlue.startScan(withServices: new List<Guid>.from([uartServiceUUID]) );
    } else {
      print("_handleBLEScanState: startScan was false");
      widget.flutterBlue.stopScan();
    }
    setState(() {
      _scanActive = startScan;
      _bleDisconnect();
    });
    widget.myUserSettings.loadSettings("default");
  }

  void _bleDisconnect() {
    if (_connectedDevice != null) {
      print("_bleDisconnect: disconnecting");
      setState(() {
        widget.devicesList.clear(); //TODO: clearing list on disconnect so build() does not attempt to pass images of knownDevices that have not yet been loaded
        _scanActive = false;
        deviceIsConnected = false;
      });

      // Allow the screen to sleep
      Wakelock.disable();

      // Stop the telemetry timer
      startStopTelemetryTimer(true);

      // Stop the RX data subscription
      escRXDataSubscription?.cancel();
      escRXDataSubscription = null;

      loggerRXDataSubscription?.cancel();
      loggerRXDataSubscription = null;

      // Stop listening to the connected device events
      _connectedDeviceStreamSubscription?.cancel();
      _connectedDeviceStreamSubscription = null;

      // Disconnect device
      _connectedDevice.disconnect();
      _connectedDevice = null;

      // Reset the TX characteristic
      the_tx_characteristic = null;
      theTXLoggerCharacteristic = null;

      // Reset firmware packet
      firmwarePacket = new ESCFirmware();

      //Reset telemetry packet
      telemetryPacket = new ESCTelemetry();

      // Reset deviceHasDisconnected flag
      deviceHasDisconnected = false;

      // Reset syncInProgress flag
      syncInProgress = false;
    }
  }

  //This builds a grid view of found BLE devices... works pretty ok
  GridView _buildGridViewOfDevices() {
    List<Widget> containers = new List<Widget>();

    containers.add(
      Container(
        height: 55,
        child: Column(
          children: <Widget>[
            //Expanded(
              //child:
              Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child:
                    Text("Searching for BLE devices",style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Icon(Icons.search, size: 75 ),
                ],
              ),
            //),

            FlatButton(
              color: Theme.of(context).buttonColor,
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                _handleBLEScanState(false); // Stop scan
              },
            ),
          ],
        ),
      ),
    );

    for (BluetoothDevice device in widget.devicesList) {
      //If there is no name for the device we are going to ignore it
      if (device.name == '') continue;

      //If this device is known give it a special row in the list of devices
      if (widget.myUserSettings.isDeviceKnown(device.id.toString())) {
        Container element = Container(
            padding: EdgeInsets.all(5.0),
            height: 150,
            child: GestureDetector(
              onTap: () async {
                /// Attempt connection
                try {
                  await device.connect();
                  await widget.flutterBlue.stopScan();

                  _scanActive = false;
                  _connectedDevice = device;

                  widget.myUserSettings.loadSettings(device.id.toString()).then((value){
                    print("_buildGridViewOfDevices():widget.myUserSettings.loadSettings() returned $value");
                    isConnectedDeviceKnown = value;
                  });

                  await setupConnectedDeviceStreamListener();
                } catch (e) {
                  print("trying device.connect() threw an exception $e");
                  //TODO: if we are already connected but trying to connect we might want to disconnect. Needs testing, should only happen during debug
                  //TODO: trying device.connect() threw an exception PlatformException(already_connected, connection with device already exists, null)
                  device.disconnect().catchError((e){
                    print("While catching device.connect() exception, device.disconnect() threw an exception: $e");
                  });
                  if (e.code != 'already_connected') {
                    throw e;
                  }
                }
              },
              child:

              Column(
                children: <Widget>[
                 // Text(device.id.toString()),

                  FutureBuilder<String>(
                      future: UserSettings.getBoardAlias(device.id.toString()),
                      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                        return Text(snapshot.data != null ? snapshot.data : "unnamed", textAlign: TextAlign.center,);
                      }),
                  FutureBuilder<String>(
                      future: UserSettings.getBoardAvatarPath(device.id.toString()),
                      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                        return CircleAvatar(
                            backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.jpg'),
                            radius: 60,
                            backgroundColor: Colors.white);
                      }),
                  Text(device.name),
                ],
              ),
            )
        );
        containers.insert(1, element);
        continue; //Continue to next device
      }

      // Add unknown devices to list with name, ID and a connect button
      containers.add(
        Container(
          height: 55,
          child: Column(
            children: <Widget>[
              //Expanded(
                //child:
                Column(
                  children: <Widget>[
                    Padding(padding: EdgeInsets.only(top:16.0),
                            child: Icon(Icons.device_unknown, size: 75)),
                    Text(device.name == '' ? '(unknown device)' : device.name),
                    Text(device.id.toString()),
                  ],
                ),
              //),
              FlatButton(
                color: Theme.of(context).buttonColor,
                child: Text(
                  'Connect',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  try {
                    await device.connect();
                    await widget.flutterBlue.stopScan();
                    //setState(() {
                      _scanActive = false;
                      _connectedDevice = device;
                    //});
                    widget.myUserSettings.loadSettings(device.id.toString()).then((thisDeviceIsKnown){
                      print("_buildGridViewOfDevices():widget.myUserSettings.loadSettings() returned $thisDeviceIsKnown");
                      isConnectedDeviceKnown = thisDeviceIsKnown;
                    });
                    await setupConnectedDeviceStreamListener();
                  } catch (e) {
                    if (e.code != 'already_connected') {
                      throw e;
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ); //Adding container for unknown device
    }

    int shitElementSize = 200; //TODO: can i get the size of the elements in the list? dunno. 
    int crossAxisCount = MediaQuery.of(context).size.width ~/ shitElementSize;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      padding: const EdgeInsets.all(8),
      children: containers,
    );
  }

  static DateTime dtLastLogged = DateTime.now();

  final Guid uartServiceUUID = new Guid("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid txCharacteristicUUID = new Guid("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid rxCharacteristicUUID = new Guid("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid txLoggerCharacteristicUUID = new Guid("6e400004-b5a3-f393-e0a9-e50e24dcca9e");
  final Guid rxLoggerCharacteristicUUID = new Guid("6e400005-b5a3-f393-e0a9-e50e24dcca9e");

  static BluetoothService the_service_we_want;
  static BluetoothCharacteristic the_tx_characteristic;
  static BluetoothCharacteristic the_rx_characteristic;
  static BluetoothCharacteristic theTXLoggerCharacteristic;
  static BluetoothCharacteristic theRXLoggerCharacteristic;
  static StreamSubscription<List<int>> escRXDataSubscription;
  static StreamSubscription<List<int>> loggerRXDataSubscription;

  static ESCFirmware firmwarePacket = new ESCFirmware();
  static ESCTelemetry telemetryPacket = new ESCTelemetry();
  static Timer telemetryTimer;
  static int bleTXErrorCount = 0;

  //TODO: some logger vars that need to be in their own class
  static String loggerTestBuffer = "";
  static String catCurrentFilename = "";
  static bool syncInProgress = false;
  static bool syncAdvanceProgress = false;
  static bool lsInProgress = false;
  static bool catInProgress = false;
  static int catBytesReceived = 0;
  static int catBytesTotal = 0;
  static List<FileToSync> fileList = new List<FileToSync>();
  static List<String> fileListToDelete = new List();
  static bool syncEraseOnComplete = false;
  static bool isLoggerLogging = false;
  // Handler for RideLogging's sync button
  void _handleBLESyncState(bool startSync) {
    print("_handleBLESyncState: startSync: $startSync");
    if (startSync) {
      // Start syncing all files by setting syncInProgress to true and request
      // the file list from the receiver
      syncInProgress = true;
      theTXLoggerCharacteristic.write(utf8.encode("ls~"));
    } else {
      print("Stopping Sync Process");
      setState(() {
        syncInProgress = false;
        syncAdvanceProgress = false;
        lsInProgress = false;
        catInProgress = false;
        catCurrentFilename = "";
      });
    }
  }
  void _handleEraseOnSyncButton(bool eraseOnSync) {
    print("_handleEraseOnSyncButton: eraseOnSync: $eraseOnSync");
    setState(() {
      syncEraseOnComplete = eraseOnSync;
    });
  }
  //TODO: ^^ move this stuff when you feel like it ^^

  Future<void> setupConnectedDeviceStreamListener() async {
    _connectedDeviceStreamSubscription = _connectedDevice.state.listen((state) async {
      switch (state) {
        case BluetoothDeviceState.connected:
          if ( deviceHasDisconnected ){
            print("NOTICE: We have connected to the device that we were previously disconnected from");
            // We have reconnected to a device that disconnected
            setState(() {
              escRXDataSubscription?.cancel();
              loggerRXDataSubscription?.cancel();
              prepareConnectedDevice();
            });
          } else {
            print("Device has successfully connected.");
            setState(() {
              prepareConnectedDevice();
              deviceIsConnected = true;
            });
          }

          break;
        case BluetoothDeviceState.disconnected:
          if ( deviceIsConnected  ) {
            print("WARNING: We have disconnected but FreeSK8 was expecting a connection");
            deviceHasDisconnected = true;
            startStopTelemetryTimer(true);
          }
          break;
        default:
          print("NOTICE: prepareConnectedDevice():_connectedDeviceStreamSubscription:listen: unexpected state: $state");
          break;
      }
    });
  }

  // Prepare the BLE Services and Characteristics required to interact with the ESC
  void prepareConnectedDevice() async {
    bool foundService = false;
    bool foundTX = false;
    bool foundRX = false;
    bool foundTXLogger = false;
    bool foundRXLogger = false;
    _services = await _connectedDevice.discoverServices();

    for (BluetoothService service in _services) {
      print(service.uuid);
      if (service.uuid == uartServiceUUID) {
        foundService = true;
        the_service_we_want = service;
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print(characteristic.uuid);
          if (characteristic.uuid == txCharacteristicUUID){
            the_tx_characteristic = characteristic;
            foundTX = true;
          }
          else if (characteristic.uuid == rxCharacteristicUUID){
            the_rx_characteristic = characteristic;
            foundRX = true;
          }
          else if (characteristic.uuid == txLoggerCharacteristicUUID){
            theTXLoggerCharacteristic = characteristic;
            foundTXLogger = true;
          }
          else if (characteristic.uuid == rxLoggerCharacteristicUUID){
            theRXLoggerCharacteristic = characteristic;
            foundRXLogger = true;
          }
        }
      }
    } //--finding required service and characteristics

    if ( !foundService || !foundTX || !foundRX ) {
      print("ERROR: Required service and characteristics not found on this device");

      _alertInvalidDevice();
      _bleDisconnect();

      return;
    } else if ( !foundTXLogger || !foundRXLogger ) {
      _alertLimitedFunctionality();
    }
    else {
      print("All required service and characteristics were found on this device. Good news.");
    }

    if(foundRXLogger){
      await theRXLoggerCharacteristic.setNotifyValue(true);
    }

    if(foundRXLogger) loggerRXDataSubscription = theRXLoggerCharacteristic.value.listen((value) async {
      /// Process data received from FreeSK8 logger characteristic
      String receiveStr = new String.fromCharCodes(value);
      ///LS Command
      if (lsInProgress) {
        if (receiveStr == "ls,complete") {
          print("List File Operation Complete");
          fileList.sort((a, b) => a.fileName.compareTo(b.fileName)); // Sort ascending to grab the oldest file first
          fileList.forEach((element) {
            print("File: ${element.fileName} is ${element.fileSize} bytes");
          });
          lsInProgress = false;
          loggerTestBuffer = receiveStr;
          fileList.forEach((element) {
            loggerTestBuffer += "File: ${element.fileName} is ${element.fileSize} bytes\n";
          });

          if(fileList.length == 0) {
            //Nothing to sync
            syncInProgress = false;
            loggerTestBuffer = "No logs are saved on the receiver";
          }

          if(syncInProgress){
            //NOTE: start by cat'ing the first file
            //When cat is complete we will call setState which will request the next file
            catCurrentFilename = fileList.first.fileName;
            catBytesTotal = fileList.first.fileSize;
            theTXLoggerCharacteristic.write(utf8.encode("cat ${fileList.first.fileName}~"));
          }else _alertLoggerTest();
          return;
        }

        print("**************************************** >$receiveStr<");
        // build list of files on device
        List<String> values = receiveStr.split(",");
        if (values[1] == "FILE"){
          int fileSize = int.parse(values[3]);
          // Add file to list if it's greater than 0 bytes. (0 byte file usually means it's the active log)
          if (fileSize > 0) fileList.add(new FileToSync(fileName: values[2], fileSize: fileSize));
        }
        await theTXLoggerCharacteristic.write(utf8.encode("ls,${fileList.length},ack~"));
      }
      else if(receiveStr.startsWith("ls,/FreeSK8Logs")){
        fileList.clear();
        fileListToDelete.clear();
        lsInProgress = true;
        catInProgress = false;
        await theTXLoggerCharacteristic.write(utf8.encode("ls,${fileList.length},ack~"));
      }

      ///CAT Command
      else if (catInProgress) {
        if (receiveStr == "cat,complete") {
          print("Concatenate file operation complete on $catCurrentFilename with $catBytesReceived bytes");

          //TODO: validate file transmission. We need a proper packet definition and CRC
          // Add successful transfer to list of files to delete during sync operation
          fileListToDelete.add(catCurrentFilename);

          // Save temporary log data to final filename
          // Then generate database statistics
          // Then create database entry
          // Then rebuild state and continue sync process
          FileManager.saveLogToDocuments(filename: catCurrentFilename).then((savedFilePath)
          {
            /// Analyze log to generate database statistics
            double maxCurrentBattery = 0.0;
            double maxCurrentMotor = 0.0;
            int faultCodeCount = 0;
            double minElevation;
            double maxElevation;
            DateTime firstEntryTime;
            DateTime lastEntryTime;
            FileManager.openLogFile(savedFilePath).then((value){
              List<String> thisRideLogEntries = value.split("\n");
              for(int i=0; i<thisRideLogEntries.length; ++i) {
                if(thisRideLogEntries[i] == null || thisRideLogEntries[i] == "") continue;
//print("uhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh parsing: ${thisRideLogEntries[i]}");
                final entry = thisRideLogEntries[i].split(",");

                if(entry.length > 1){ // entry[0] = Time, entry[1] = Data type
                  ///GPS position entry
                  if(entry[1] == "position" && entry.length>8) {
                    //DateTime, 'position', lat, lon, accuracy, altitude, speed, speedAccuracy
                    // Track elevation change
                    double elevation = double.tryParse(entry[5]);
                    minElevation ??= elevation; //Set if null
                    maxElevation ??= elevation; //Set if null
                    if (elevation < minElevation) minElevation = elevation;
                    if (elevation > maxElevation) maxElevation = elevation;
                    // Determine date times
                    if(firstEntryTime ==null)firstEntryTime = DateTime.tryParse(entry[0]);
                    lastEntryTime = DateTime.tryParse(entry[0]);
                  }
                  ///ESC Values
                  else if (entry[1] == "values" && entry.length > 9) {
                    //[2020-05-19T13:46:28.8, values, 12.9, -99.9, 29.0, 0.0, 0.0, 0.0, 0.0, 11884, 102]
                    double motorCurrent = double.tryParse(entry[6]); //Motor Current
                    double batteryCurrent = double.tryParse(entry[7]); //Input Current
                    if (batteryCurrent>maxCurrentBattery) maxCurrentBattery = batteryCurrent;
                    if (motorCurrent>maxCurrentMotor) maxCurrentMotor = motorCurrent;
                    //TODO: max speed
                    //TODO: average speed
                    //TODO: Distance
                    // Determine date times
                    if(firstEntryTime ==null)firstEntryTime = DateTime.tryParse(entry[0]);
                    lastEntryTime = DateTime.tryParse(entry[0]);
                  }
                  ///Fault codes
                  else if (entry[1] == "fault") {
                    ++faultCodeCount;
                  }
                }
              }

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
                  durationSeconds: lastEntryTime.difference(firstEntryTime).inSeconds,
                  faultCount: faultCodeCount,
                  rideName: "",
                  notes: ""
              )).then((value){
                //TODO: BUG: get rideLogging widget to reList the last file after sync without erase
                loggerTestBuffer = receiveStr;
                if(!syncInProgress) _alertLoggerTest();
                setState(() {
                  syncAdvanceProgress = true;
                  //Cat completed
                  //Setting state so this widget rebuilds. On build it will
                  //check if syncInProgress and start the next file
                });
              });
            });
          }); //Save file operation complete
          catInProgress = false;
          return;
        }

        // store chunk of log data
        await FileManager.writeToLogFile(receiveStr);

        print("cat received ${receiveStr.length} bytes");
        setState(() {
          catBytesReceived += receiveStr.length;
        });
        await theTXLoggerCharacteristic.write(utf8.encode("cat,$catBytesReceived,ack~"));
      }
      else if(receiveStr.startsWith("cat,/FreeSK8Logs")){
        print("Starting cat Command: $receiveStr");
        loggerTestBuffer = "";
        catInProgress = true;
        lsInProgress = false;
        catBytesReceived = 0;
        FileManager.clearLogFile();
        await theTXLoggerCharacteristic.write(utf8.encode("cat,0,ack~"));
      }

      else if(receiveStr.startsWith("rm,")){
        print("Remove File/Directory response received:");
        print(receiveStr);
        loggerTestBuffer = receiveStr;
        if(!syncInProgress) _alertLoggerTest();
        else {
          //_alertLoggerTest();
          if (fileListToDelete.length > 0) fileListToDelete.removeAt(0);
          setState(() {
            //Calling setState to remove the next file while sync is in progress
            syncAdvanceProgress = true;
          });
        }
      }
      else if(receiveStr.startsWith("status,")) {
        print("Status packet received: $receiveStr");
        List<String> values = receiveStr.split(",");
        setState(() {
          isLoggerLogging = values[2] == "1";
        });
      }
      else {
        ///Unexpected response
        print("loggerReceived and unexpected response: ${new String.fromCharCodes(value)}");
      }

    });

    // Setup the RX characteristic to notify on value change
    await the_rx_characteristic.setNotifyValue(true);
    // Setup the RX characteristic callback function
    escRXDataSubscription = the_rx_characteristic.value.listen((value) {
      // BLE data received
      if (bleHelper.processIncomingBytes(value) > 0){

        //Time to process the packet
        int packetID = bleHelper.payload[0];
        if (packetID == COMM_PACKET_ID.COMM_FW_VERSION.index) {

          ///Firmware Packet
          setState(() {
            firmwarePacket = escHelper.processFirmware(bleHelper.payload);
          });
          var major = firmwarePacket.fw_version_major;
          var minor = firmwarePacket.fw_version_minor;
          var hardName = firmwarePacket.hardware_name;
          print("Firmware packet: major $major, minor $minor, hardware $hardName");

          bleHelper.resetPacket(); //Be ready for another packet

          // Check if compatible firmware
          if(major != 5) {
            // Do something
            _alertInvalidFirmware();
            return _bleDisconnect();
          }

        }
        else if ( packetID == COMM_PACKET_ID.COMM_GET_VALUES.index ) {
          ///Telemetry packet
          final dtNow = DateTime.now();
          telemetryPacket = escHelper.processTelemetry(bleHelper.payload);


          if(controller.index == 1) { //Only re-draw if we are on the real time data tab
            setState(() { //Re-drawing with updated telemetry data
            });
          }

          // Watch here for all fault codes received. Populate an array with time and fault for display to user
          if ( telemetryPacket.fault_code != mc_fault_code.FAULT_CODE_NONE ) {
            print("WARNING! Fault code received! ${telemetryPacket.fault_code}");
            //TODO: FileManager.writeToLogFile("${dtNow.toIso8601String().substring(0,21)},fault,${telemetryPacket.fault_code}\n");
          }

          // Prepare for the next packet
          bleHelper.resetPacket();

        } else if ( packetID == COMM_PACKET_ID.COMM_PING_CAN.index ) {
          ///Ping CAN packet
          print("Ping CAN packet received! ${bleHelper.lenPayload} bytes");
          _validCANBusDeviceIDs.clear();
          //print(bleHelper.payload);
          for (int i = 1; i < bleHelper.lenPayload; ++i) {
            if (bleHelper.payload[i] != 0) {
              print("CAN Device Found at ID ${bleHelper
                  .payload[i]}. Is it an ESC? Stay tuned to find out more...");
              _validCANBusDeviceIDs.add(bleHelper.payload[i]);
            }
          }

          // Prepare for yet another packet
          bleHelper.resetPacket();
        } else if ( packetID == COMM_PACKET_ID.COMM_NRF_START_PAIRING.index ) {
          print("NRF PAIRING packet received");
          switch (bleHelper.payload[1]) {
            case 0:
              print("Pairing started");
              startStopTelemetryTimer(true); //Stop the telemetry timer

              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("nRF Quick Pair"),
                    content: SizedBox(height: 100, child: Column(children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 10,),
                      Text("Think fast! You have 10 seconds to turn on your remote.")
                    ],),
                    ),
                  );
                },
              );
              break;
            case 1:
              print("Pairing Successful");
              Navigator.of(context).pop(); //Pop Quick Pair initial dialog
              if (controller.index == 1) startStopTelemetryTimer(false); //Resume the telemetry timer

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("nRF Quick Pair"),
                    content: Text("Pairing Successful! Your remote is now live. Congratulations =)"),
                  );
                },
              );
              break;
            case 2:
              print("Pairing timeout");
              Navigator.of(context).pop(); //Pop Quick Pair initial dialog
              if (controller.index == 1) startStopTelemetryTimer(false); //Resume the telemetry timer

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("nRF Quick Pair"),
                    content: Text("Oh bummer, a timeout. We didn't find a remote this time but you are welcome to try again."),
                  );
                },
              );
              break;
            default:
              print("ERROR: Pairing unknown payload");
              Navigator.of(context).pop(); //Pop Quick Pair initial dialog
              if (controller.index == 1) startStopTelemetryTimer(false); //Resume the telemetry timer
          }
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_MCCONF.index) {
          ///ESC Motor Configuration
          escMotorConfiguration = bleHelper.payload.sublist(0,bleHelper.lenPayload);

          //TODO: handle MCCONF data
          print("Oof.. MCCONF: $escMotorConfiguration");

          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_MCCONF_DEFAULT.index) {

          setState(() { // setState so focWizard receives updated MCCONF Defaults
            escMotorConfigurationDefaults = bleHelper.payload.sublist(0,bleHelper.lenPayload);
          });
          print("Oof.. MCCONF_DEFAULT: $escMotorConfigurationDefaults");

          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_APPCONF.index) {
          print("WARNING: Whoa now. We received this horrid APPCONF data. Whatchu want to do?");
          //TODO: handle APPCONF data
          print("Oof APPCONF: ${bleHelper.payload.sublist(0,bleHelper.lenPayload)}");
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_DETECT_APPLY_ALL_FOC.index) {
          print("COMM_DETECT_APPLY_ALL_FOC packet received");
          // Handle FOC detection results
          print(bleHelper.payload.sublist(0,bleHelper.lenPayload)); //[58, 0, 1]
          // * @return
          // * >=0: Success, see conf_general_autodetect_apply_sensors_foc codes
          // * 2: Success, AS5147 detected successfully
          // * 1: Success, Hall sensors detected successfully
          // * 0: Success, No sensors detected and sensorless mode applied successfully
          // * -10: Flux linkage detection failed
          // * -1: Detection failed
          // * -50: CAN detection timed out
          // * -51: CAN detection failed
          var byteData = new ByteData.view(bleHelper.payload.buffer);
          int resultFOCDetection = byteData.getInt16(1);

          Navigator.of(context).pop(); //Pop away the FOC wizard Loading Overlay
          if (controller.index == 1) startStopTelemetryTimer(false); //Resume the telemetry timer

          if (resultFOCDetection >= 0) {
            Navigator.of(context).pop(); //Pop away the FOC wizard on success

            // Show dialog
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("FOC Detection"),
                  content: Text("Successful detection. Result: $resultFOCDetection"),
                );
              },
            );
          } else {
            switch(resultFOCDetection) {
              case -1:
                print("Detection failed");
                break;
              case -10:
                print("Flux linkage detection failed");
                break;
              case -50:
                print("CAN detection timed out");
                break;
              case -51:
                print("CAN detection failed");
                break;
              default:
                print("ERROR: result of FOC detection was unknown: $resultFOCDetection");
            }
            // Show dialog
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("FOC Detection"),
                  content: Text("Detection failed. Result: $resultFOCDetection"),
                );
              },
            );
          }
          bleHelper.resetPacket();
        } else {
          print("Unsupported packet ID: $packetID");
          print("Unsupported packet Message: ${bleHelper.messageReceived.sublist(0,bleHelper.endMessage)}");
          bleHelper.resetPacket();
        }
      }
    });

    if (foundTXLogger) {
      await theTXLoggerCharacteristic.write(utf8.encode("settime ${DateTime.now().toIso8601String().substring(0,21).replaceAll("-", ":")}~"));
    }

    //Request firmware packet once connected
    await the_tx_characteristic.write([0x02, 0x01, 0x00, 0x00, 0x00, 0x03]);

    // Scan for CAN devices
    Uint8List packetScanCAN = new Uint8List(6);
    packetScanCAN[0] = 0x02; //Start packet
    packetScanCAN[1] = 0x01; //Payload length
    packetScanCAN[2] = COMM_PACKET_ID.COMM_PING_CAN.index; //Payload data
    //3,4 are CRC computed below
    packetScanCAN[5] = 0x03; //End packet
    int checksum = bleHelper.crc16(packetScanCAN, 2, 1);
    //print("TEST Checksum ${checksum.toRadixString(16)}");
    packetScanCAN[3] = (checksum >> 8) & 0xff;
    packetScanCAN[4] = checksum & 0xff;
    //print("TEST packetScanCAN $packetScanCAN");
    await the_tx_characteristic.write(packetScanCAN);

    // Keep the device on while connected
    Wakelock.enable();

    // Start a new log file
    FileManager.clearLogFile();

    // Check if this is a known device when we connected/loaded it's settings
    if (!isConnectedDeviceKnown) {
      print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% THIS IS A NEW DEVICE<>WONT YOU LOAD THE SETUP WIDGET? %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");
      //TODO: navigate to setup widget if we create one..
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Ooo! new device, who dis?"),
            content: Text("You have connected to a new device. Take a picture, give it a name and specify your settings now for the best experience."),
          );
        },
      );
      controller.index = 2; // switch to configuration tab for now
    }
  }

  Future<void> _alertLimitedFunctionality() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Not a Robogotchi'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('The connected device does not have all the cool features of the FreeSK8 Robogotchi =(\n\n'),
                Text('This app will be limited in functionality.'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('I understand'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _alertInvalidDevice() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Oooo nuuuuuu'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Hey sorry guy.'),
                Text('The required services and characteristics'),
                Text('were not found on the selected device...'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Give it another go'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _alertInvalidFirmware() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Uh oh'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Wouldn\'t you know it..'),
                Text('This app talks with FW5 and the'),
                Text('connected device says it is incompatible'),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Give it another go'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _alertLoggerTest() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        String alertValue = loggerTestBuffer;
        loggerTestBuffer = "";
        return AlertDialog(
          title: Text('FreeSK8 Logger'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Data received:'),
                Text(alertValue),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Whoa'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// Hamburger Menu... mmmm hamburgers
  Drawer getNavDrawer(BuildContext context) {
    var headerChild = DrawerHeader(
        child: Image(image: AssetImage('assets/FreeSK8_MobileLogo.png')),
    );

    var aboutChild = AboutListTile(
      child: Text("About"),
      applicationName: "FreeSK8 Mobile",
      applicationVersion: "v0.1.0",
      applicationIcon: Icon(Icons.info, size: 40,),
      icon: Icon(Icons.info),
      aboutBoxChildren: <Widget>[
        Text("This project was brought to you by the fine people of", textAlign: TextAlign.center,),
        Image(image: AssetImage('assets/dri_about.png'),width: 300,),
        Text("Thank you for your support!",textAlign: TextAlign.center,)
      ],
    );

    ListTile getNavItem(var icon, String s, String routeName, var args, bool requireConnection) {
      return ListTile(
        leading: Icon(icon),
        title: Text(s),
        onTap: () {
          if(requireConnection && the_tx_characteristic == null) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Connection Required =("),
                  content: Text("This feature requires an active connection."),
                );
              },
            );
            return;
          }
          startStopTelemetryTimer(true); //Stop the telemetry timer
          setState(() {
            // pop closes the drawer
            Navigator.of(context).pop();
            // navigate to the route
            Navigator.of(context).pushNamed(routeName, arguments: args);
          });
        },
      );
    }

    var myNavChildren = [
      headerChild,
      //getNavItem(Icons.settings, "Testies", Test.routeName),
      //getNavItem(Icons.home, "Home", "/"),
      //getNavItem(Icons.account_box, "RT", Second.routeName),
      aboutChild,
      getNavItem(Icons.donut_large, "FOC Wizard", ConfigureESC.routeName, FOCWizardArguments(the_tx_characteristic, bleHelper, escMotorConfigurationDefaults), true),

      ListTile(
        leading: Icon(Icons.settings_remote),
        title: Text("nRF Quick Pair"),
        onTap: () {
          // Don't write if not connected
          if (the_tx_characteristic != null) {
            var byteData = new ByteData(10); //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
            byteData.setUint8(0, 0x02);
            byteData.setUint8(1, 0x05);
            byteData.setUint8(2, COMM_PACKET_ID.COMM_NRF_START_PAIRING.index);
            byteData.setUint32(3, 10000); //milliseconds
            int checksum = bleHelper.crc16(byteData.buffer.asUint8List(), 2, 5);
            byteData.setUint16(7, checksum);
            byteData.setUint8(9, 0x03); //End of packet

            //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
            the_tx_characteristic.write(byteData.buffer.asUint8List()).then((value){
              print('You have 10 seconds to power remote!');
            }).catchError((e){
              print("nRF Quick Pair: Exception: $e");
            });
          } else {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("nRF Quick Pair"),
                  content: Text("Oops. Try connecting to your board first."),
                );
              },
            );
          }
        },
      ),

      ListTile(
        leading: Icon(Icons.system_update),
        title: Text("Firmware Update"),
        onTap: () {
          // Don't write if not connected
          if (theTXLoggerCharacteristic != null) {
            theTXLoggerCharacteristic.write(utf8.encode("dfumode~")).whenComplete((){
              print('Your robogotchi is ready to receive firmware!\nUse the nRF Toolbox application to upload new firmware.\nPower cycle board to cancel update.');
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("Firmware Update Ready"),
                    content: Text('Use the nRF Toolbox application to upload new firmware.\nWait 2 minutes or power cycle board to cancel update.'),
                  );
                },
              );
              _bleDisconnect();
            }).catchError((e){
              print("Firmware Update: Exception: $e");
            });
          } else {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Firmware Update"),
                  content: Text("Oops. Try connecting to your robogotchi first."),
                );
              },
            );
          }
        },
      ),

    ];

    return Drawer(
      child: ListView(children: myNavChildren),
    );
  }

  // Called by timer on interval to request telemetry packet
  void _requestTelemetry() async {
    if ( _connectedDevice != null || !this.mounted){

      //Request telemetry packet; On error increase error counter
      await the_tx_characteristic.write(
          [0x02, 0x01, 0x04, 0x40, 0x84, 0x03], withoutResponse: true).then((value) {
      }).
      catchError((e) {
        ++bleTXErrorCount;
        print("Second::_requestTelemetry() failed ($bleTXErrorCount) times. Exception: $e");
      });
    } else {
      // We are requesting telemetry but are not connected =/
      print("Request telemetry canceled because we are not connected");
      setState(() {
        telemetryTimer.cancel();
        telemetryTimer = null;
      });
    }
  }

  // Start and stop telemetry streaming timer
  void startStopTelemetryTimer(bool disableTimer) {
    if (!disableTimer){
      print("Start timer");
      const duration = const Duration(milliseconds:100);
      telemetryTimer = new Timer.periodic(duration, (Timer t) => _requestTelemetry());
    } else {
      print("Cancel timer");
      if (telemetryTimer != null) {
        telemetryTimer.cancel();
        telemetryTimer = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if(syncInProgress && syncAdvanceProgress){
      print("Building main.dart while syncInProgress and sync wants to advance a step");
      syncAdvanceProgress = false;

      if(fileList.length>0) //TODO: logically I didn't think this needed to be conditional but helps during debugging
        fileList.removeAt(0); //Remove the first file in the list (we just finished receiving this file)

      if(fileList.length>0){
        catCurrentFilename = fileList.first.fileName;
        catBytesTotal = fileList.first.fileSize; //Set the total expected bytes for the current file
        theTXLoggerCharacteristic.write(utf8.encode("cat ${fileList.first.fileName}~")); //Request next file
      }
      else if(fileListToDelete.length>0){
        // We have sync'd all the files and we have files to erase
        // Evaluate user's option to remove files on sync
        if (syncEraseOnComplete) {
          // Remove the first file in the list of files to delete
          theTXLoggerCharacteristic.write(utf8.encode("rm ${fileListToDelete.first}~"));
        } else {
          // We are finished with the sync process because the user does not
          // want to erase files on the receiver
          print("stopping sync without remove");
          syncInProgress = false;
          //TODO: Testing setState here to reload file list after sync is finished
          setState(() {
            //TESTING
          });
        }
      }
      else {
        syncInProgress = false;
      }
    }
    else {
      print("Building main.dart");
    }

    FileSyncViewerArguments syncStatus = FileSyncViewerArguments(syncInProgress: syncInProgress, fileName: catCurrentFilename, fileBytesReceived: catBytesReceived, fileBytesTotal: catBytesTotal, fileList: fileList);
    return Scaffold(
        // Appbar
        appBar: AppBar(
            title: Text("FreeSK8 ($counter)"),
            // Set the background color of the App Bar
            backgroundColor: Theme.of(context).primaryColor,
            // Set the bottom property of the Appbar to include a Tab Bar
            //bottom: getTabBar()
        ),
        // Set the TabBar view as the body of the Scaffold
        body: getTabBarView( <Widget>[
          ConnectionStatus(active:_scanActive, bleDevicesGrid: _buildGridViewOfDevices(), currentDevice: _connectedDevice, currentFirmware: firmwarePacket, userSettings: widget.myUserSettings, onChanged: _handleBLEScanState),
          RealTimeData(routeTakenLocations: routeTakenLocations, telemetryPacket: telemetryPacket, currentSettings: widget.myUserSettings, startStopTelemetryFunc: startStopTelemetryTimer,),
          ESK8Configuration(myUserSettings: widget.myUserSettings, currentDevice: _connectedDevice),
          RideLogging(
            myUserSettings: widget.myUserSettings,
            theTXLoggerCharacteristic: theTXLoggerCharacteristic,
            syncInProgress: syncInProgress, //TODO: RideLogging receives syncInProgress in syncStatus object
            onSyncPress: _handleBLESyncState,
            syncStatus: syncStatus,
            eraseOnSync: syncEraseOnComplete,
            onSyncEraseSwitch: _handleEraseOnSyncButton,
            isLoggerLogging: isLoggerLogging
          )
        ]),
      bottomNavigationBar: Material(
        color: Theme.of(context).primaryColor,
        child: getTabBar(),
      ),
      drawer: getNavDrawer(context),
    );
  }
}
