import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freesk8_mobile/dieBieMSHelper.dart';
import 'package:freesk8_mobile/escProfileEditor.dart';
import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/robogotchiCfgEditor.dart';

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
import 'package:freesk8_mobile/escHelper/appConf.dart';
import 'package:freesk8_mobile/userSettings.dart';
import 'package:freesk8_mobile/file_manager.dart';
import 'package:freesk8_mobile/autoStopHandler.dart';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:latlong/latlong.dart';

import 'package:geolocator/geolocator.dart';

import 'package:wakelock/wakelock.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart';

import 'databaseAssistant.dart';

const String freeSK8ApplicationVersion = "0.10.0";
const String robogotchiFirmwareExpectedVersion = "0.7.0";

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
        ESCProfileEditor.routeName: (BuildContext context) => ESCProfileEditor(),
        RobogotchiCfgEditor.routeName: (BuildContext context) => RobogotchiCfgEditor()
      },
      theme: ThemeData(
        //TODO: Select satisfying colors for the light theme
        brightness: Brightness.light,
        primaryColor: Colors.pink,
        accentColor: Colors.pinkAccent,
        buttonColor: Colors.pinkAccent.shade100
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.dark, //TODO: Always using the dark mode regardless of system preference
    )
  );
}

class MyHome extends StatefulWidget {

  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();

  final UserSettings myUserSettings = new UserSettings();

  @override
  MyHomeState createState() => MyHomeState();
}

// SingleTickerProviderStateMixin is used for animation
class MyHomeState extends State<MyHome> with SingleTickerProviderStateMixin {

  final GlobalKey<State> _keyLoader = new GlobalKey<State>();

  /* User's current location for map */
  var geolocator = Geolocator();
  var locationOptions = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 0);

  LatLng lastLocation;
  DateTime lastTimeLocation;
  List<LatLng> routeTakenLocations = new List<LatLng>();
  
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

  BLEHelper bleHelper;
  ESCHelper escHelper;
  DieBieMSHelper dieBieMSHelper;

  static MCCONF escMotorConfiguration;
  static APPCONF escApplicationConfiguration;
  static int ppmLastDuration;
  static Uint8List escMotorConfigurationDefaults;
  static List<int> _validCANBusDeviceIDs = new List();
  static String robogotchiVersion;

  static bool deviceIsConnected = false;
  static bool deviceHasDisconnected = false;
  static BluetoothDevice _connectedDevice;
  static bool isConnectedDeviceKnown = false;
  static bool isESCResponding = false;
  static List<BluetoothService> _services;
  static StreamSubscription<BluetoothDeviceState> _connectedDeviceStreamSubscription;
  static StreamSubscription<Position> positionStream;

  MemoryImage cachedBoardAvatar;

  @override
  void initState() {
    super.initState();

    print("main init state");

    bleHelper = new BLEHelper();
    escHelper = new ESCHelper();
    dieBieMSHelper = new DieBieMSHelper();

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

    FileManager.clearLogFile();

    checkLocationPermission();
    positionStream = geolocator.getPositionStream(locationOptions).listen(
            (Position position) {
          if(position != null) {
            updateLocationForRoute(new LatLng(position.latitude, position.longitude));
          }
        });

    //TODO: watching AppLifecycleState but not doing anything
    WidgetsBinding.instance.addObserver(AutoStopHandler());

    _timerMonitor = new Timer.periodic(Duration(seconds: 1), (Timer t) => _monitorGotchiTimer());
  }

  void _monitorGotchiTimer() {
    if (_gotchiStatusTimer == null && theTXLoggerCharacteristic != null && initMsgSqeuencerCompleted && (controller.index == 0 || controller.index == 3) && !syncInProgress) {
      print("*****************************************************************_timerMonitor starting gotchiStatusTimer");
      startStopGotchiTimer(false);
    } else if (syncInProgress) {
      // Monitor data reception for loss of communication
      if (DateTime.now().millisecondsSinceEpoch - syncLastACK.millisecondsSinceEpoch > 5 * 1000) {
        // It's been 5 seconds since you looked at me.
        // Cocked your head to the side and said I'm angry
        if (lsInProgress) {
          theTXLoggerCharacteristic.write(utf8.encode("ls,${fileList.length},nack~"));
        } else if (catInProgress) {
          theTXLoggerCharacteristic.write(utf8.encode("cat,$catBytesReceived,nack~"));
        }
        syncLastACK = DateTime.now();
      }
    } else {
      print("timer monitor is alive");
    }
  }

  Future<void> checkLocationPermission() async {
    GeolocationStatus geolocationStatus  = await Geolocator().checkGeolocationPermissionStatus();

    if (await Geolocator().isLocationServiceEnabled() != true) {
      genericAlert(context, "Location service unavailable", Text('Please enable location services on your mobile device'), "OK");
    }
  }

  Future<void> updateLocationForRoute(LatLng data) async {

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

  @override
  void dispose() {
    telemetryTimer?.cancel();

    _timerMonitor?.cancel();

    _gotchiStatusTimer?.cancel();

    // Dispose of the Tab Controller
    controller.dispose();

    positionStream?.cancel();

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
          icon: Icon(Icons.multiline_chart),
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

  //TODO: method to assemble simple esc requests
  //TODO: method to request until success or disconnect
  //TODO: sooooo much duplicated code
  void requestAPPCONF(int optionalCANID) async {
    bool sendCAN = optionalCANID != null;
    var byteData = new ByteData(sendCAN ? 8:6); //<start><payloadLen><packetID><crc1><crc2><end>
    byteData.setUint8(0, 0x02);
    byteData.setUint8(1, sendCAN ? 0x03 : 0x01); // Data length
    if (sendCAN) {
      byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
      byteData.setUint8(3, optionalCANID);
    }
    byteData.setUint8(sendCAN ? 4:2, COMM_PACKET_ID.COMM_GET_APPCONF.index);
    int checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, sendCAN ? 3:1);
    byteData.setUint16(sendCAN ? 5:3, checksum);
    byteData.setUint8(sendCAN ? 7:5, 0x03); //End of packet

    // Request APPCONF from the ESC
    print("requesting app conf (CAN ID? $optionalCANID)");
    await sendBLEData(the_tx_characteristic, byteData.buffer.asUint8List(), _connectedDevice);
  }

  void requestMCCONF() async {
    var byteData = new ByteData(6); //<start><payloadLen><packetID><crc1><crc2><end>
    byteData.setUint8(0, 0x02);
    byteData.setUint8(1, 0x01);
    byteData.setUint8(2, COMM_PACKET_ID.COMM_GET_MCCONF.index);
    int checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, 1);
    byteData.setUint16(3, checksum);
    byteData.setUint8(5, 0x03); //End of packet

    // Request MCCONF from the ESC
    dynamic errorCheck = 0;
    while (errorCheck != null && _connectedDevice != null) {
      errorCheck = null;
      await the_tx_characteristic.write(byteData.buffer.asUint8List()).catchError((error){
        errorCheck = error;
        print("COMM_GET_MCCONF: Exception: $errorCheck");
      });
    }
  }

  void _handleESCProfileFinished(bool newValue) {
    setState(() {
      _showESCProfiles = newValue;
    });
  }
  void _handleAutoloadESCSettings(bool newValue) {
    if(_connectedDevice != null) {
      _autoloadESCSettings = true;
      //TODO: Testing resetPacket here to prevent `Missing Motor Configuration from the ESC` message
      bleHelper.resetPacket();
      requestMCCONF();
    }
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
    widget.myUserSettings.loadSettings("defaults");
  }

  void _bleDisconnect() {
    if (_connectedDevice != null) {
      print("_bleDisconnect: disconnecting");
      // Navigate back to the connection tab
      controller.index = 0;

      setState(() {
        widget.devicesList.clear(); //TODO: clearing list on disconnect so build() does not attempt to pass images of knownDevices that have not yet been loaded
        _scanActive = false;
        deviceIsConnected = false;
      });

      // Allow the screen to sleep
      Wakelock.disable();

      // Stop the telemetry timer
      startStopTelemetryTimer(true);

      // Stop the gotchi status timer
      _gotchiStatusTimer?.cancel();
      _gotchiStatusTimer = null;

      // Stop the RX data subscription
      escRXDataSubscription?.cancel();
      escRXDataSubscription = null;

      loggerRXDataSubscription?.cancel();
      loggerRXDataSubscription = null;

      dieBieMSRXDataSubscription?.cancel();
      dieBieMSRXDataSubscription = null;

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

      // Reset telemetry packet
      telemetryPacket = new ESCTelemetry();

      // Reset deviceHasDisconnected flag
      deviceHasDisconnected = false;

      // Reset syncInProgress flag
      syncInProgress = false;

      // Reset device is a Robogotchi flag
      _deviceIsRobogotchi = false;

      // Reset current ESC motor configuration
      escMotorConfiguration = new MCCONF();

      // Reset current ESC application configuration
      escApplicationConfiguration = new APPCONF();

      // Reset displaying ESC profiles flag
      _showESCProfiles = false;

      // Reset displaying ESC Configurator flag
      _showESCConfigurator = false;
      _showESCApplicationConfigurator = false;

      // Reset Robogotchi version
      robogotchiVersion = null;

      // Reset is ESC responding flag
      isESCResponding = false;

      // Clear cached board avatar
      cachedBoardAvatar = null;

      // Reset the init message sequencer
      initMsgGotchiSettime = false;
      initMsgGotchiVersion = false;
      initMsgESCVersion = false;
      initMsgESCMotorConfig = false;
      initMsgESCDevicesCAN = false;
      initMsgESCDevicesCANRequested = 0;
      initMsgSqeuencerCompleted = false;
      _initMsgSequencer?.cancel();
      _initMsgSequencer = null;

      // Clear the Robogotchi status
      gotchiStatus = new RobogotchiStatus();
    }
  }

  Future<void> _attemptDeviceConnection(BluetoothDevice device) async {
    // If the user aborts device.connect() prevent this Future from taking action
    bool _userAborted = false;
    /// Attempt connection
    try {
      // Display connection attempt in progress
      showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return new WillPopScope(
                onWillPop: () async => false,
                child: SimpleDialog(
                    key: _keyLoader,
                    backgroundColor: Colors.black54,
                    children: <Widget>[
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            print("Cancelling connection attempt");
                            // Cancel connection attempt
                            await device.disconnect().catchError((e){
                              print("GestureDetector device.disconnect() threw an exception: $e");
                            });
                            _userAborted = true;
                            Navigator.of(context).pop(); // Remove attempting connection dialog
                          },
                          child: Column(children: [
                            Icon(Icons.bluetooth_searching, size: 80,),
                            SizedBox(height: 10,),
                            //TODO: Update status of connection
                            //TODO: https://stackoverflow.com/questions/51962272/how-to-refresh-an-alertdialog-in-flutter
                            Text("Establishing connection..."),
                            Text("(tap to abort)", style: TextStyle(fontSize: 10))
                          ]),
                        ),
                      )
                    ]));
          });

      await device.connect();
      if (!_userAborted) {
        await widget.flutterBlue.stopScan();

        _scanActive = false;
        _connectedDevice = device;

        widget.myUserSettings.loadSettings(device.id.toString()).then((value){
          print("_buildGridViewOfDevices():widget.myUserSettings.loadSettings() returned $value");
          isConnectedDeviceKnown = value;
        });

        await setupConnectedDeviceStreamListener();
        Navigator.of(context).pop(); // Remove attempting connection dialog

        // Display communicating with ESC dialog
        showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return new WillPopScope(
                  onWillPop: () async => false,
                  child: SimpleDialog(
                      backgroundColor: Colors.black54,
                      children: <Widget>[
                        Center(
                          child: GestureDetector(
                            onLongPress: () async {
                              Navigator.of(context).pop(); // Remove communicating with ESC dialog
                            },
                            child: Column(children: [
                              Icon(Icons.bluetooth_searching, size: 80,color: Colors.green),
                              SizedBox(height: 10,),
                              Text("Connected"),
                              Text("Communicating with ESC"),
                              Text("(please wait)", style: TextStyle(fontSize: 10))
                            ]),
                          ),
                        )
                      ]));
            });
      }
    } catch (e) {
      Navigator.of(context).pop(); // Remove attempting connection dialog
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
  }
  //This builds a grid view of found BLE devices... works pretty ok
  GridView _buildGridViewOfDevices() {
    final int crossAxisCount = 2;
    List<Widget> containers = new List<Widget>();

    containers.add(
      Container(
        width: MediaQuery.of(context).size.width / crossAxisCount,
        child: Column(
          children: <Widget>[
            //Expanded(
              //child:
              Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                        "Searching for devices",
                        style: TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                    )
                  ),
                  Icon(Icons.search, size: 60),
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
            width: MediaQuery.of(context).size.width / crossAxisCount,
            child: GestureDetector(
              onTap: () async {
                await _attemptDeviceConnection(device);
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
          width: MediaQuery.of(context).size.width / crossAxisCount,
          child: GestureDetector(
            onTap: () async {
              await _attemptDeviceConnection(device);
            },
            child: Column(
              children: <Widget>[
                Padding(padding: EdgeInsets.only(top:32.0),
                    child: Icon(Icons.device_unknown, size: 75)),
                Text(device.name == '' ? '(unknown device)' : device.name),
                //NOTE: this is not MAC on iOS: Text(device.id.toString()),
              ],
            )
          ),
        ),
      ); //Adding container for unknown device
    }

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
  static StreamSubscription<List<int>> dieBieMSRXDataSubscription;
  static StreamSubscription<List<int>> loggerRXDataSubscription;

  static ESCFirmware firmwarePacket = new ESCFirmware();
  static ESCTelemetry telemetryPacket = new ESCTelemetry();
  static DieBieMSTelemetry dieBieMSTelemetry = new DieBieMSTelemetry();
  static int smartBMSCANID = 10;
  static bool _showDieBieMS = false;
  static bool _showESCConfigurator = false;
  static bool _showESCApplicationConfigurator = false;
  static bool _showESCProfiles = false;
  static bool _autoloadESCSettings = false; // Controls the population of ESC Information from MCCONF response
  static Timer telemetryTimer;
  static Timer _gotchiStatusTimer;
  static Timer _timerMonitor;
  static Timer _initMsgSequencer;
  static int bleTXErrorCount = 0;
  static bool _deviceIsRobogotchi = false;
  static bool _isPPMCalibrating;

  //TODO: some logger vars that need to be in their own class
  static String loggerTestBuffer = "";
  static String catCurrentFilename = "";
  static bool syncInProgress = false;
  static bool syncAdvanceProgress = false;
  static bool lsInProgress = false;
  static bool catInProgress = false;
  static List<int> catBytesRaw = new List();
  static int catBytesReceived = 0;
  static int catBytesTotal = 0;
  static List<FileToSync> fileList = new List<FileToSync>();
  static List<String> fileListToDelete = new List();
  static bool syncEraseOnComplete = true;
  static bool isLoggerLogging = false; //TODO: this is redundant
  static RobogotchiStatus gotchiStatus = new RobogotchiStatus();
  static DateTime syncLastACK = DateTime.now();
  static List<ESCFault> escFaults = new List();

  // Handler for RideLogging's sync button
  void _handleBLESyncState(bool startSync) async {
    print("_handleBLESyncState: startSync: $startSync");
    if (startSync) {
      // Start syncing all files by setting syncInProgress to true and request
      // the file list from the receiver
      setState(() async {
        syncInProgress = true;
        // Prevent the status timer from interrupting this request
        _gotchiStatusTimer?.cancel();
        _gotchiStatusTimer = null;
        // Request the files to begin the process
        await sendBLEData(theTXLoggerCharacteristic, utf8.encode("ls~"), _connectedDevice);
      });
    } else {
      print("Stopping Sync Process");
      setState(() {
        syncInProgress = false;
        syncAdvanceProgress = false;
        lsInProgress = false;
        catInProgress = false;
        catCurrentFilename = "";
      });
      // After stopping the sync on this end, request stop on the Robogotchi
      dynamic errorCheck = 0;
      while (errorCheck != null && _connectedDevice != null) {
        errorCheck = null;
        await theTXLoggerCharacteristic.write(utf8.encode("syncstop~")).catchError((error){
          errorCheck = error;
          print("Failed to write syncstop command: $errorCheck");
        });
      }
      print("syncstop sent successfully");
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
            escRXDataSubscription?.cancel();
            loggerRXDataSubscription?.cancel();
            dieBieMSRXDataSubscription?.cancel();
            Future.delayed(const Duration(milliseconds: 750), () {
              setState(() {
                prepareConnectedDevice();
              });
            });
          } else {
            print("Device has successfully connected.");
            Future.delayed(const Duration(milliseconds: 750), () {
              setState(() {
                prepareConnectedDevice();
                deviceIsConnected = true;
              });
            });
          }

          break;
        case BluetoothDeviceState.disconnected:
          if ( deviceIsConnected  ) {
            print("WARNING: We have disconnected but FreeSK8 was expecting a connection");
            deviceHasDisconnected = true;
            startStopTelemetryTimer(true);
            // Alert user that the connection was lost
            genericAlert(context, "Disconnected", Text("The Bluetooth device has disconnected"), "OK");
            //NOTE: On an Android this connection can automatically be resumed
            //NOTE: On iOS this connection will never re-connection
            // Disconnect
            _bleDisconnect();
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
      _deviceIsRobogotchi = false;
      print("Not a Robogotchi..");
    }
    else {
      _deviceIsRobogotchi = true;
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
            setState(() {
              syncInProgress = false;
              loggerTestBuffer = "No logs are saved on the receiver";
            });
          }

          if(syncInProgress){
            //NOTE: start by cat'ing the first file
            //When cat is complete we will call setState which will request the next file
            catCurrentFilename = fileList.first.fileName;
            catBytesTotal = fileList.first.fileSize;
            catBytesRaw.clear();
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
        syncLastACK = DateTime.now();
        await theTXLoggerCharacteristic.write(utf8.encode("ls,${fileList.length},ack~"));
      }
      else if(receiveStr.startsWith("ls,/FreeSK8Logs")){
        fileList.clear();
        fileListToDelete.clear();
        lsInProgress = true;
        catInProgress = false;
        syncLastACK = DateTime.now();
        await theTXLoggerCharacteristic.write(utf8.encode("ls,${fileList.length},ack~"));
      }

      ///CAT Command
      else if (catInProgress) {
        if (receiveStr == "cat,complete") {
          print("Concatenate file operation complete on $catCurrentFilename with $catBytesReceived bytes");

          //TODO: validate file transmission. We need a proper packet definition and CRC
          // Add successful transfer to list of files to delete during sync operation
          fileListToDelete.add(catCurrentFilename);

          await FileManager.writeBytesToLogFile(catBytesRaw);
          catBytesRaw.clear();

          // Save temporary log data to final filename
          // Then generate database statistics
          // Then create database entry
          // Then rebuild state and continue sync process
          String savedFilePath = await FileManager.saveLogToDocuments(filename: catCurrentFilename);
          {
            /// Analyze log to generate database statistics
            Map<int, double> wattHoursStartByESC = new Map();
            Map<int, double> wattHoursEndByESC = new Map();
            Map<int, double> wattHoursRegenStartByESC = new Map();
            Map<int, double> wattHoursRegenEndByESC = new Map();
            double maxCurrentBattery = 0.0;
            double maxCurrentMotor = 0.0;
            double maxSpeedKph = 0.0;
            double avgSpeedKph = 0.0;
            int firstESCID;
            double distanceStart;
            double distanceEnd;
            double distanceTotal;
            int faultCodeCount = 0;
            double minElevation;
            double maxElevation;
            DateTime firstEntryTime;
            DateTime lastEntryTime;
            String logFileContents = await FileManager.openLogFile(savedFilePath);
            {
              List<String> thisRideLogEntries = logFileContents.split("\n");
              for(int i=0; i<thisRideLogEntries.length; ++i) {
                if(thisRideLogEntries[i] == null || thisRideLogEntries[i] == "") continue;
//print("uhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhh parsing: ${thisRideLogEntries[i]}");
                final entry = thisRideLogEntries[i].split(",");

                if(entry.length > 1 && entry[0] != "header"){ // entry[0] = Time, entry[1] = Data type
                  ///GPS position entry
                  if(entry[1] == "gps" && entry.length >= 7) {
                    //dt,gps,satellites,altitude,speed,latitude,longitude
                    // Determine date times
                    firstEntryTime ??= DateTime.tryParse(entry[0]);
                    lastEntryTime = DateTime.tryParse(entry[0]);

                    // Track elevation change
                    double elevation = double.tryParse(entry[3]);
                    minElevation ??= elevation; //Set if null
                    maxElevation ??= elevation; //Set if null
                    if (elevation < minElevation) minElevation = elevation;
                    if (elevation > maxElevation) maxElevation = elevation;

                  }
                  ///ESC Values
                  else if (entry[1] == "esc" && entry.length >= 14) {
                    //dt,esc,esc_id,voltage,motor_temp,esc_temp,duty_cycle,motor_current,battery_current,watt_hours,watt_hours_regen,e_rpm,e_distance,fault
                    // Determine date times
                    firstEntryTime ??= DateTime.tryParse(entry[0]);
                    lastEntryTime = DateTime.tryParse(entry[0]);

                    // ESC ID
                    int escID = int.parse(entry[2]);
                    firstESCID ??= escID;

                    // Determine max values
                    double motorCurrent = double.tryParse(entry[7]); //Motor Current
                    double batteryCurrent = double.tryParse(entry[8]); //Input Current
                    double eRPM = double.tryParse(entry[11]); //eRPM
                    double eDistance = double.tryParse(entry[12]); //eDistance
                    if (batteryCurrent>maxCurrentBattery) maxCurrentBattery = batteryCurrent;
                    if (motorCurrent>maxCurrentMotor) maxCurrentMotor = motorCurrent;
                    // Compute max speed!
                    double speed = eRPMToKph(eRPM, widget.myUserSettings.settings.gearRatio, widget.myUserSettings.settings.wheelDiameterMillimeters, widget.myUserSettings.settings.motorPoles);
                    if (speed > maxSpeedKph) {
                      maxSpeedKph = speed;
                    }
                    //TODO: Compute average speed!
                    // Capture Distance for first ESC
                    if (escID == firstESCID) {
                      distanceStart ??= eDistanceToKm(eDistance, widget.myUserSettings.settings.gearRatio, widget.myUserSettings.settings.wheelDiameterMillimeters, widget.myUserSettings.settings.motorPoles);
                      distanceEnd = eDistanceToKm(eDistance, widget.myUserSettings.settings.gearRatio, widget.myUserSettings.settings.wheelDiameterMillimeters, widget.myUserSettings.settings.motorPoles);
                    }
                    // Capture consumption per ESC
                    double wattHours = double.parse(entry[9]);
                    double wattHoursRegen = double.parse(entry[10]);
                    wattHoursStartByESC[escID] ??= wattHours;
                    wattHoursEndByESC[escID] = wattHours;
                    wattHoursRegenStartByESC[escID] ??= wattHoursRegen;
                    wattHoursRegenEndByESC[escID] = wattHoursRegen;
                  }
                  ///Fault codes
                  else if (entry[1] == "err") {
                    ++faultCodeCount;
                  }
                }
              }

              /// Compute distance
              if (distanceEnd != null) {
                distanceTotal = doublePrecision(distanceEnd - distanceStart, 2);
              } else {
                distanceTotal = -1.0;
              }
              print("ESC ID $firstESCID traveled $distanceTotal km");

              /// Compute consumption
              double wattHours = 0;
              double wattHoursRegen = 0;
              wattHoursStartByESC.forEach((key, value) {
                print("ESC ID $key consumed ${wattHoursEndByESC[key] - value} watt hours");
                wattHours += wattHoursEndByESC[key] - value;
              });
              wattHoursRegenStartByESC.forEach((key, value) {
                print("ESC ID $key regenerated ${wattHoursRegenEndByESC[key] - value} watt hours");
                wattHoursRegen += wattHoursRegenEndByESC[key] - value;
              });
              print(wattHoursStartByESC);
              print(wattHoursEndByESC);
              print("Consumption calculation: Watt Hours Total $wattHours Regenerated Total $wattHoursRegen");

              /// Insert record into database
              if (lastEntryTime != null && firstEntryTime != null) {
                await DatabaseAssistant.dbInsertLog(LogInfoItem(
                    dateTime: firstEntryTime,
                    boardID: widget.myUserSettings.currentDeviceID,
                    boardAlias: widget.myUserSettings.settings.boardAlias,
                    logFilePath: savedFilePath,
                    avgSpeed: -1.0,
                    maxSpeed: maxSpeedKph,
                    elevationChange: maxElevation != null ? maxElevation - minElevation : -1.0,
                    maxAmpsBattery: maxCurrentBattery,
                    maxAmpsMotors: maxCurrentMotor,
                    wattHoursTotal: wattHours,
                    wattHoursRegenTotal: wattHoursRegen,
                    distance: distanceTotal,
                    durationSeconds: lastEntryTime.difference(firstEntryTime).inSeconds,
                    faultCount: faultCodeCount,
                    rideName: "",
                    notes: ""
                ));
              } else {
                genericConfirmationDialog(context, FlatButton(
                  child: Text("Copy / Share"),
                  onPressed: () {
                    Share.text(catCurrentFilename, "logFileContents:\n$logFileContents\n\ncatBytesRaw[$catBytesTotal]:\n${catBytesRaw.toList().toString()}", 'text/plain');
                  },
                ), FlatButton(
                  child: Text("Close"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ), "Oh crap", Text("Something unexpected happened. Please share with renee@derelictrobot.com"));
              }

              /// Advance the sync process
              {
                //TODO: BUG: get rideLogging widget to reList the last file after sync without erase
                loggerTestBuffer = receiveStr;
                if(!syncInProgress) _alertLoggerTest();
                setState(() {
                  syncAdvanceProgress = true;
                  ///Cat completed
                  ///Setting state so this widget rebuilds. On build it will
                  ///check if syncInProgress and start the next file
                });
              }
            }
          } //Save file operation complete
          catInProgress = false;
          return;
        }

        // store chunk of log data
        catBytesRaw.addAll(value.sublist(0,receiveStr.length));
        //await FileManager.writeBytesToLogFile(value.sublist(0,receiveStr.length));

        print("cat received ${receiveStr.length} bytes");
        setState(() {
          catBytesReceived += receiveStr.length;
        });

        syncLastACK = DateTime.now();
        await theTXLoggerCharacteristic.write(utf8.encode("cat,$catBytesReceived,ack~"));
      }
      else if(receiveStr.startsWith("cat,/FreeSK8Logs")){
        print("Starting cat Command: $receiveStr");
        loggerTestBuffer = "";
        catInProgress = true;
        lsInProgress = false;
        catBytesReceived = 0;
        FileManager.clearLogFile();

        syncLastACK = DateTime.now();
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
          isLoggerLogging = (values[2] == "1");
          gotchiStatus.isLogging = isLoggerLogging;
          gotchiStatus.faultCount = int.tryParse(values[3]);
          gotchiStatus.faultCode = int.tryParse(values[4]);
          gotchiStatus.percentFree = int.tryParse(values[5]);
          gotchiStatus.fileCount = int.tryParse(values[6]);
          gotchiStatus.gpsFix = int.tryParse(values[7]);
          gotchiStatus.gpsSatellites = int.tryParse(values[8]);
        });
      }
      else if(receiveStr.startsWith("faults,")) {
        print("Faults packet received: $receiveStr");
        List<String> values = receiveStr.split(",");
        int count = int.tryParse(values[1]);
        //TODO: Robogotchi firmware is limiting output to 6 faults
        if (count > 6) {
          count = 6;
        }
        // Capture fault data at end of buffer
        const int startPosition = 10; // "faults,xx,"
        const int sizeOfESCFault = 24; // sizeof(struct esc_fault)
        Uint8List dataBuffer = new Uint8List.fromList(value.sublist(startPosition, startPosition + sizeOfESCFault*count));
        // Extract faults
        escFaults = escHelper.processFaults(count, dataBuffer);

        String shareData = "";
        List<Widget> children = new List();
        escFaults.forEach((element) {
          children.add(Text(element.toString()));
          children.add(Text(""));
          shareData += element.toString() + "\n\n";
        });
        //genericAlert(context, "Faults observed", Column(children: children), "OK");
        genericConfirmationDialog(context, FlatButton(
          child: Text("Copy / Share"),
          onPressed: () {
            Share.text('Faults observed', shareData, 'text/plain');
          },
        ), FlatButton(
          child: Text("Close"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ), "Faults observed", Column(children: children, mainAxisSize: MainAxisSize.min,));
      }
      else if(receiveStr.startsWith("version,")) {
        print("Version packet received: $receiveStr");
        List<String> values = receiveStr.split(",");
        // Update robogotchiVersion
        robogotchiVersion = values[1];
        // Check for latest firmware
        if (robogotchiVersion != robogotchiFirmwareExpectedVersion) {
          genericAlert(
              context,
              "Update available",
              Column(children: [
                Text("This app works best when Robogotchi is up to date!"),
                SizedBox(height: 15),
                Text("Please update the Robogotchi firmware from $robogotchiVersion to $robogotchiFirmwareExpectedVersion")
              ]),
              "OK"
          );
        }
        // Flag the reception of an init message
        initMsgGotchiVersion = true;
        // Redraw UI
        setState(() {});
      }
      else if(receiveStr.startsWith("getcfg,")) {
        print("Robogotchi User Configuration received: $receiveStr");
        // Parse the configuration
        List<String> values = receiveStr.split(",");
        int parseIndex = 1;
        RobogotchiConfiguration gotchConfig = new RobogotchiConfiguration(
            logAutoStopIdleTime: int.tryParse(values[parseIndex++]),
            logAutoStopLowVoltage: double.tryParse(values[parseIndex++]),
            logAutoStartERPM: int.tryParse(values[parseIndex++]),
            logIntervalHz: int.tryParse(values[parseIndex++]),
            logAutoEraseWhenFull: int.tryParse(values[parseIndex++]) == 1 ? true : false,
            multiESCMode: int.tryParse(values[parseIndex++]),
            multiESCIDs: new List.from({int.tryParse(values[parseIndex++]), int.tryParse(values[parseIndex++]), int.tryParse(values[parseIndex++]), int.tryParse(values[parseIndex++])}),
            gpsBaudRate: int.tryParse(values[parseIndex++]),
            alertVoltageLow: double.tryParse(values[parseIndex++]),
            alertESCTemp: double.tryParse(values[parseIndex++]),
            alertMotorTemp: double.tryParse(values[parseIndex++]),
            alertStorageAtCapacity: int.tryParse(values[parseIndex++]),
            cfgVersion: int.tryParse(values[parseIndex])
        );

        // Validate we received the expected cfgVersion from the module or else there could be trouble
        if (gotchConfig.cfgVersion != 3) {
          genericAlert(context, "Version mismatch", Text("Robogotchi provided an incorrect configuration version"), "OK");
        } else {
          // Load the user configuration window
          Navigator.of(context).pushNamed(
              RobogotchiCfgEditor.routeName,
              arguments: RobogotchiCfgEditorArguments(
                  txLoggerCharacteristic: theTXLoggerCharacteristic,
                  currentConfiguration: gotchConfig,
                  discoveredCANDevices: _validCANBusDeviceIDs
              )
          );
        }
      }
      else if(receiveStr.startsWith("setcfg,")) {
        print("Robogotchi User Configuration updated: $receiveStr");
        // Parse the configuration
        List<String> values = receiveStr.split(",");
        if (values[1] == "OK") {
          // Close Robogotchi Configuration Editor
          Navigator.of(context).pop();
          genericAlert(context, "Success", Text("Robogotchi configuration updated!"), "OK");
        } else {
          // Alert user setcfg failed!
          genericAlert(context, "oof!", Text("Setting Robogotchi configuration failed:\n\n$receiveStr"), "Help!");
        }
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
        int packetID = bleHelper.getPayload()[0];
        if (packetID == COMM_PACKET_ID.COMM_FW_VERSION.index) {

          // Flag the reception of an init message
          initMsgESCVersion = true;

          ///Firmware Packet
          setState(() {
            firmwarePacket = escHelper.processFirmware(bleHelper.getPayload());
            isESCResponding = true;
          });
          var major = firmwarePacket.fw_version_major;
          var minor = firmwarePacket.fw_version_minor;
          var hardName = firmwarePacket.hardware_name;
          print("Firmware packet: major $major, minor $minor, hardware $hardName");

          bleHelper.resetPacket(); //Be ready for another packet

          // Check if compatible firmware
          if(major != 5 || minor != 1) {
            // Do something
            _alertInvalidFirmware("Firmware: $major.$minor\nHardware: $hardName");
            return _bleDisconnect();
          }

        }
        else if ( packetID == DieBieMSHelper.COMM_GET_BMS_CELLS ) {
          setState(() {
            dieBieMSTelemetry = dieBieMSHelper.processCells(bleHelper.getPayload());
          });
          bleHelper.resetPacket(); //Prepare for next packet
        }
        else if ( packetID == COMM_PACKET_ID.COMM_GET_VALUES.index ) {
          if(_showDieBieMS) {
            //TODO: Parse DieBieMS GET_VALUES packet - A shame they share the same ID as ESC values
            dieBieMSTelemetry = dieBieMSHelper.processTelemetry(bleHelper.getPayload());
            bleHelper.resetPacket(); //Prepare for next packet
            return;
          }


          ///Telemetry packet
          final dtNow = DateTime.now();
          telemetryPacket = escHelper.processTelemetry(bleHelper.getPayload());


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

          // Flag the reception of an init message
          initMsgESCDevicesCAN = true;

          // Populate a fresh _validCANBusDeviceIDs array
          _validCANBusDeviceIDs.clear();
          //print(bleHelper.payload);
          for (int i = 1; i < bleHelper.lenPayload; ++i) {
            if (bleHelper.getPayload()[i] != 0) {
              print("CAN Device Found at ID ${bleHelper
                  .getPayload()[i]}. Is it an ESC? Stay tuned to find out more...");
              _validCANBusDeviceIDs.add(bleHelper.getPayload()[i]);
            }
          }

          // Prepare for yet another packet
          bleHelper.resetPacket();
        } else if ( packetID == COMM_PACKET_ID.COMM_NRF_START_PAIRING.index ) {
          print("NRF PAIRING packet received");
          switch (bleHelper.getPayload()[1]) {
            case 0:
              print("Pairing started");
              startStopTelemetryTimer(true); //Stop the telemetry timer

              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("nRF Quick Pair"),
                    content: SizedBox(
                      height: 100, child: Column(children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 10,),
                      Text(
                          "Think fast! You have 10 seconds to turn on your remote.")
                    ],),
                    ),
                  );
                },
              );
              break;
            case 1:
              print("Pairing Successful");
              Navigator.of(context).pop(); //Pop Quick Pair initial dialog
              if (controller.index == 1) startStopTelemetryTimer(
                  false); //Resume the telemetry timer

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("nRF Quick Pair"),
                    content: Text(
                        "Pairing Successful! Your remote is now live. Congratulations =)"),
                  );
                },
              );
              break;
            case 2:
              print("Pairing timeout");
              Navigator.of(context).pop(); //Pop Quick Pair initial dialog
              if (controller.index == 1) startStopTelemetryTimer(
                  false); //Resume the telemetry timer

              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text("nRF Quick Pair"),
                    content: Text(
                        "Oh bummer, a timeout. We didn't find a remote this time but you are welcome to try again."),
                  );
                },
              );
              break;
            default:
              print("ERROR: Pairing unknown payload");
              Navigator.of(context).pop(); //Pop Quick Pair initial dialog
              if (controller.index == 1) {
                //Resume the telemetry timer
                startStopTelemetryTimer(false);
              }
          }
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_SET_MCCONF.index ) {
          print("HUZZAH!");
          print("COMM_PACKET_ID.COMM_SET_MCCONF: ${bleHelper.getPayload().sublist(0,bleHelper.lenPayload)}");
          // Show dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Success"),
                content: Text("ESC configuration saved successfully!"),
              );
            },
          );
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_SET_MCCONF_TEMP_SETUP.index ) {
          print("COMM_SET_MCCONF_TEMP_SETUP received! This is a good sign.. packetID(${COMM_PACKET_ID.COMM_SET_MCCONF_TEMP_SETUP.index})");
          //TODO: analyze packet before assuming success?
          _alertProfileSet();
          _handleAutoloadESCSettings(true); // Reload ESC settings from applied configuration
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_MCCONF.index) {
          ///ESC Motor Configuration
          escMotorConfiguration = escHelper.processMCCONF(bleHelper.getPayload()); //bleHelper.payload.sublist(0,bleHelper.lenPayload);

          if (escMotorConfiguration.si_battery_ah == null) {
            // Show dialog
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Incompatible ESC"),
                  content: Text("The selected ESC did not return a valid Motor Configuration"),
                );
              },
            );
          }
          //NOTE: for debug & testing
          //ByteData serializedMcconf = escHelper.serializeMCCONF(escMotorConfiguration);
          //MCCONF refriedMcconf = escHelper.processMCCONF(serializedMcconf.buffer.asUint8List());
          //print("Break for MCCONF: $escMotorConfiguration");

          // Flag the reception of an init message
          initMsgESCMotorConfig = true;

          // Check flag to show ESC Profiles when MCCONF data is received
          if (_showESCProfiles) {
            setState(() {
              controller.index = 2; // Navigate user to Configuration tab
            });
          }

          // Check flag to update application configuration with ESC motor configuration
          else if (_autoloadESCSettings) {
            print("MCCONF is updating application settings specific to this board");
            _autoloadESCSettings = false;
            widget.myUserSettings.settings.batterySeriesCount = escMotorConfiguration.si_battery_cells;
            switch (escMotorConfiguration.si_battery_type) {
              case BATTERY_TYPE.BATTERY_TYPE_LIIRON_2_6__3_6:
                widget.myUserSettings.settings.batteryCellMinVoltage = 2.6;
                widget.myUserSettings.settings.batteryCellMaxVoltage = 3.6;
                break;
              default:
                widget.myUserSettings.settings.batteryCellMinVoltage = 3.0;
                widget.myUserSettings.settings.batteryCellMaxVoltage = 4.2;
                break;
            }

            widget.myUserSettings.settings.wheelDiameterMillimeters = (escMotorConfiguration.si_wheel_diameter * 1000).toInt();
            widget.myUserSettings.settings.motorPoles = escMotorConfiguration.si_motor_poles;
            widget.myUserSettings.settings.maxERPM = escMotorConfiguration.l_max_erpm;
            widget.myUserSettings.settings.gearRatio = escMotorConfiguration.si_gear_ratio;

            widget.myUserSettings.saveSettings();

            setState(() {
              // Update UI for ESC Configurator
            });
          } else {
            setState(() {
              // Update UI for ESC Configurator
            });
          }

          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_MCCONF_DEFAULT.index) {

          setState(() { // setState so focWizard receives updated MCCONF Defaults
            //TODO: focWizard never uses escMotorConfigurationDefaults
            escMotorConfigurationDefaults = bleHelper.getPayload().sublist(0,bleHelper.lenPayload);
          });
          print("Oof.. MCCONF_DEFAULT: $escMotorConfigurationDefaults");

          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_APPCONF.index) {
          print("WARNING: Whoa now. We received this APPCONF data. Whatchu want to do?");
          //TODO: handle APPCONF data
          ///ESC Application Configuration
          escApplicationConfiguration = escHelper.processAPPCONF(bleHelper.getPayload());

          if (escApplicationConfiguration.imu_conf.gyro_offset_comp_clamp != null) {
            print("SUCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCESSSSS?");
          }

          if (_showESCApplicationConfigurator) {
            setState(() {
              controller.index = 2;
              _showESCApplicationConfigurator = true;
            });
          } else {
            // Update UI for configurator
            setState(() {

            });
          }

          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_DETECT_APPLY_ALL_FOC.index) {
          print("COMM_DETECT_APPLY_ALL_FOC packet received");
          // Handle FOC detection results
          print(bleHelper.getPayload().sublist(0,bleHelper.lenPayload)); //[58, 0, 1]
          // * @return
          // * >=0: Success, see conf_general_autodetect_apply_sensors_foc codes
          // * 2: Success, AS5147 detected successfully
          // * 1: Success, Hall sensors detected successfully
          // * 0: Success, No sensors detected and sensorless mode applied successfully
          // * -10: Flux linkage detection failed
          // * -1: Detection failed
          // * -50: CAN detection timed out
          // * -51: CAN detection failed
          var byteData = new ByteData.view(bleHelper.getPayload().buffer);
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
        } else if (packetID == COMM_PACKET_ID.COMM_GET_DECODED_PPM.index) {

          int valueNow = escHelper.buffer_get_int32(bleHelper.getPayload(), 1);
          int msNow = escHelper.buffer_get_int32(bleHelper.getPayload(), 5);
          print(
              "Decoded PPM packet received: value $valueNow, milliseconds $msNow");
          setState(() {
            ppmLastDuration = msNow;
          });
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_PRINT.index) {

          int stringLength = bleHelper.getMessage()[1] - 1;
          String messageFromESC = new String.fromCharCodes(bleHelper.getMessage().sublist(3, 3 + stringLength));
          genericAlert(context, "Excuse me", Text("The ESC responded with a custom message:\n\n$messageFromESC"), "OK");
          bleHelper.resetPacket();

        } else if (packetID == COMM_PACKET_ID.COMM_SET_APPCONF.index) {

          if (_isPPMCalibrating != null && _isPPMCalibrating) {
            genericAlert(context, "Calibration", Text("Begin calibration\nMove input to full brake, full throttle then leave in the center\n\nPlease ensure the wheels are off the ground in case something goes wrong. This is beta after all!"), "OK");
            _isPPMCalibrating = null;
          } else if (_isPPMCalibrating != null && !_isPPMCalibrating) {
            genericAlert(context, "Calibration", Text("Calibration Complete\n\nIf you are satisfied with the results tap 'Apply Calibration' followed by 'Save to ESC' to commit."), "OK");
            _isPPMCalibrating = null;
          } else {
            genericAlert(context, "Success", Text("Application configuration set"), "Excellent");
          }

          bleHelper.resetPacket();

        } else {
          print("Unsupported packet ID: $packetID");
          print("Unsupported packet Message: ${bleHelper.getMessage().sublist(0,bleHelper.endMessage)}");
          bleHelper.resetPacket();
        }
      }
    });

    // Begin initMessageSequencer to handle all of the desired communication on connection
    //NOTE: be sure to check if null, iOS could create a second timer
    if (_initMsgSequencer == null) {
      _initMsgSequencer = new Timer.periodic(Duration(milliseconds: 200), (Timer t) => _requestInitMessages());
    }

    // Keep the device on while connected
    Wakelock.enable();

    // Start a new log file
    FileManager.clearLogFile();

    // Check if this is a known device when we connected/loaded it's settings
    if (isConnectedDeviceKnown) {
      // Load board avatar
      _cacheAvatar(false);
    }
  }

  bool initMsgGotchiSettime = false;
  bool initMsgGotchiVersion = false;
  bool initMsgESCVersion = false;
  bool initMsgESCMotorConfig = false;
  bool initMsgESCDevicesCAN = false;
  int initMsgESCDevicesCANRequested = 0;
  bool initMsgSqeuencerCompleted = false;
  void _requestInitMessages() {
    if (_deviceIsRobogotchi && !initMsgGotchiVersion) {
      // Request the Robogotchi version
      theTXLoggerCharacteristic.write(utf8.encode("version~"));
    } else if (_deviceIsRobogotchi && !initMsgGotchiSettime) {
      // Set the Robogotchi time
      theTXLoggerCharacteristic.write(utf8.encode("settime ${DateTime.now().toIso8601String().substring(0,21).replaceAll("-", ":")}~"));
      //TODO: without a response we will assume this went as planned
      initMsgGotchiSettime = true;
    } else if (!initMsgESCVersion) {
      // Request the ESC Firmware Packet
      the_tx_characteristic.write([0x02, 0x01, 0x00, 0x00, 0x00, 0x03]);
    } else if (!initMsgESCMotorConfig) {
      // Request MCCONF
      _handleAutoloadESCSettings(true);
    } else if (!initMsgESCDevicesCAN) {
      if (initMsgESCDevicesCANRequested == 0) {
        // Request CAN Devices scan
        Uint8List packetScanCAN = new Uint8List(6);
        packetScanCAN[0] = 0x02; //Start packet
        packetScanCAN[1] = 0x01; //Payload length
        packetScanCAN[2] = COMM_PACKET_ID.COMM_PING_CAN.index; //Payload data
        //3,4 are CRC computed below
        packetScanCAN[5] = 0x03; //End packet
        int checksum = BLEHelper.crc16(packetScanCAN, 2, 1);
        packetScanCAN[3] = (checksum >> 8) & 0xff;
        packetScanCAN[4] = checksum & 0xff;
        the_tx_characteristic.write(packetScanCAN);
        initMsgESCDevicesCANRequested = 1;

        // Start the Robogotchi Status timer before the CAN responds (so slooooooooooooow)
        Future.delayed(const Duration(milliseconds: 200), () {
          startStopGotchiTimer(false);
        });
      } else {
        print("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ FYI");
        if (++initMsgESCDevicesCANRequested == 20) {
          print("initMsgESCDevicesCAN did not get a response. Retrying");
          initMsgESCDevicesCANRequested = 0;
        }
      }
    } else {
      // Init complete
      // If user forces dialog to close and ESC actually responds don't pop the main view
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Remove communicating with ESC dialog
      }

      print("##################################################################### initMsgSequencer is complete! Great success!");

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

      _initMsgSequencer.cancel();
      _initMsgSequencer = null;

      initMsgSqeuencerCompleted = true;
    }
  }

  void _cacheAvatar(bool doSetState) async {
    // Cache this so it does not flicker on setState()
    cachedBoardAvatar = widget.myUserSettings.settings.boardAvatarPath != null ? MemoryImage(File(
        "${(await getApplicationDocumentsDirectory()).path}${widget.myUserSettings.settings.boardAvatarPath}").readAsBytesSync()) : null;
    if (doSetState) {
      setState(() {

      });
    }
  }

  Future<void> _alertProfileSet() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Good news everyone'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Profile set successfully.'),
                Text('Give it a test before your session!')
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Noice'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _alertInvalidDevice() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Oooo nuuuuuu'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Hey sorry buddy.'),
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

  Future<void> _alertInvalidFirmware(String escDetails) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Uh oh'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('FreeSK8 currently works with ESCs using firmware 5.1 and the connected ESC says it is incompatible:'),
                SizedBox(height:10),
                Text(escDetails),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  static int seriousBusinessCounter = 0;
  Future<void> _alertLoggerTest() {
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
        child: GestureDetector(
            onTap: ()
            {
              setState(() {
                if (++seriousBusinessCounter > 8) seriousBusinessCounter = 0;
                print("Things are getting serious $seriousBusinessCounter");
              });
            },
            child: seriousBusinessCounter > 4 && seriousBusinessCounter < 7 ? Image(image: AssetImage('assets/dri_about_serious.gif')) :
            Image(image: AssetImage('assets/FreeSK8_MobileLogo.png'))
        ),
    );

    var aboutChild = AboutListTile(
      child: Text("About"),
      applicationName: "FreeSK8 Mobile",
      applicationVersion: "v$freeSK8ApplicationVersion",
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


      ListTile(
        leading: Icon(Icons.battery_unknown),
        title: Text(_showDieBieMS ? "Hide Flexi/DieBieMS" : "Show Flexi/DieBieMS"),
        onTap: () async {
          if(_showDieBieMS) {
            setState(() {
              _showDieBieMS = false;
            });
            print("DieBieMS RealTime Disabled");
          } else {
            setState(() {
              _showDieBieMS = true;
              controller.index = 1;
            });
            print("DieBieMS RealTime Enabled");
            Navigator.pop(context); // Close drawer
          }
        },
      ),

      ListTile(
        leading: Icon(Icons.timer),
        title: Text("Speed Profiles"),
        onTap: () {
          // Don't write if not connected
          if (the_tx_characteristic != null) {
            // Set the flag to show ESC profiles. Display when MCCONF is returned
            _showESCProfiles = true;

            requestMCCONF();
            Navigator.pop(context); // Close the drawer
          } else {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("No Connection"),
                  content: Text("Oops. Try connecting to your board first."),
                );
              },
            );
          }
        },
      ),

      Divider(height: 5, thickness: 2),
      ListTile(
        leading: Icon(Icons.settings_applications_outlined),
        title: Text("Input Configuration"),
        onTap: () {
          // Don't write if not connected
          if (the_tx_characteristic != null) {
            _showESCApplicationConfigurator = true;
            requestAPPCONF(null);
            Navigator.of(context).pop();
          } else {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("No Connection"),
                  content: Text("Oops. Try connecting to your board first."),
                );
              },
            );
          }
        },
      ),

      ListTile(
        leading: Icon(Icons.settings_applications),
        title: Text(_showESCConfigurator ? "Hide ESC Configurator" : "Show ESC Configurator"),
        onTap: () async {
          if (_connectedDevice == null) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("No connection"),
                  content: Text("This feature requires an active connection. Please try again."),
                );
              },
            );
          }
          else if (!isESCResponding) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("No data"),
                  content: Text("There is an active connection but no communication from the ESC. Please check your configuration."),
                );
              },
            );
          }
          else if(_showESCConfigurator) {
            setState(() {
              _showESCConfigurator = false;
              _handleAutoloadESCSettings(true); // Reload ESC settings after user configuration
            });
            print("ESC Configurator Hidden");
            // Close the menu
            Navigator.pop(context);
          } else {
            setState(() {
              _showESCConfigurator = true;
              controller.index = 2;
            });
            print("ESC Configurator Displayed");
            // Close the menu
            Navigator.pop(context);
          }

        },
      ),

      Divider(height: 5, thickness: 2),
      ListTile(
        leading: Icon(Icons.settings),
        title: Text("Robogotchi Config"),
        onTap: () {
          // Don't write if not connected
          if (theTXLoggerCharacteristic != null) {
            theTXLoggerCharacteristic.write(utf8.encode("getcfg~"))..catchError((e){
              print("Gotchi User Config Request: Exception: $e");
            });
          } else {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Robogotchi Config"),
                  content: Text("Oops. Try connecting to your robogotchi first."),
                );
              },
            );
          }
        },
      ),
      ListTile(
        leading: Icon(Icons.devices),
        title: Text("Robogotchi FW Update"),
        onTap: () {
          // Don't write if not connected
          if (theTXLoggerCharacteristic != null) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Robogotchi FW Update'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        Text('Caution!'),
                        Text('Do you want to perform a firmware update?'),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    FlatButton(
                      child: Text('No thank you.'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    FlatButton(
                      child: Text('Yep!'),
                      onPressed: () {
                        theTXLoggerCharacteristic.write(utf8.encode("dfumode~")).timeout(Duration(milliseconds: 500)).whenComplete((){
                          print('Your robogotchi is ready to receive firmware!\nUse the nRF Toolbox application to upload new firmware.\nPower cycle board to cancel update.');
                          Navigator.of(context).pop();
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
                      },
                    ),
                  ],
                );
              },
            );
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

  // Called by timer on interval to request Robogotchi Status packet
  void _requestGotchiStatus() {
    if ((controller.index != 0 && controller.index != 3 ) || syncInProgress || theTXLoggerCharacteristic == null) {
      print("*******************************************************************Auto stop gotchi timer");
      startStopGotchiTimer(true);
    } else {
      theTXLoggerCharacteristic.write(utf8.encode("status~")).catchError((error){
        print("_requestGotchiStatus: theTXLoggerCharacteristic was busy");
      }); //Request next file
    }
  }

  // Called by timer on interval to request telemetry packet
  static int telemetryRateLimiter = 0;
  void _requestTelemetry() async {
    if ( _connectedDevice != null || !this.mounted && isESCResponding){

      //Request telemetry packet; On error increase error counter
      if(_showDieBieMS) {
        if(++telemetryRateLimiter > 4) {
          telemetryRateLimiter = 0;
        } else {
          return;
        }
        /// Request DieBieMS Telemetry
        var byteData = new ByteData(10);
        const int packetLength = 3;
        byteData.setUint8(0, 0x02); //Start of packet
        byteData.setUint8(1, packetLength);
        byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
        byteData.setUint8(3, smartBMSCANID); //CAN ID
        byteData.setUint8(4, COMM_PACKET_ID.COMM_GET_VALUES.index);
        int checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, packetLength);
        byteData.setUint16(5, checksum);
        byteData.setUint8(7, 0x03); //End of packet
        await the_tx_characteristic.write(byteData.buffer.asUint8List(), withoutResponse: true).then((value) {
        }).
        catchError((e) {
          ++bleTXErrorCount;
          print("_requestTelemetry() failed ($bleTXErrorCount) times. Exception: $e");
        });

        //TODO: This should be delayed because the characteristic might not be ready to write...
        /// Request cell data from DieBieMS
        byteData.setUint8(0, 0x02); //Start of packet
        byteData.setUint8(1, packetLength);
        byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
        byteData.setUint8(3, smartBMSCANID); //CAN ID
        byteData.setUint8(4, DieBieMSHelper.COMM_GET_BMS_CELLS);
        checksum = BLEHelper.crc16(byteData.buffer.asUint8List(), 2, packetLength);
        byteData.setUint16(5, checksum);
        byteData.setUint8(7, 0x03); //End of packet

        await the_tx_characteristic.write(byteData.buffer.asUint8List(), withoutResponse: true).
        catchError((e) {
          print("TODO: You should request the next packet type upon reception of the prior");
        });
      } else {
        /// Request ESC Telemetry
        await the_tx_characteristic.write(
            [0x02, 0x01, 0x04, 0x40, 0x84, 0x03], withoutResponse: true).then((value) {
        }).
        catchError((e) {
          ++bleTXErrorCount;
          print("_requestTelemetry() failed ($bleTXErrorCount) times. Exception: $e");
        });
      }
    } else {
      // We are requesting telemetry but are not connected =/
      print("Request telemetry canceled because we are not connected");
      setState(() {
        telemetryTimer?.cancel();
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
        telemetryTimer?.cancel();
        telemetryTimer = null;
      }
    }
  }

  // Start and stop Robogotchi Status timer
  void startStopGotchiTimer(bool disableTimer) {
    if (!disableTimer){
      //NOTE: Be sure to check if this is null or iOS could create a second timer
      if (_gotchiStatusTimer == null) {
        print("*******************************************************************Start gotchi timer");
        const duration = const Duration(milliseconds:1000);

        Future.delayed(const Duration(milliseconds: 500), () {
          _gotchiStatusTimer = new Timer.periodic(duration, (Timer t) => _requestGotchiStatus());
        });
      }
    } else {
      print("*******************************************************************Cancel gotchi timer");
      if (_gotchiStatusTimer != null) {
        print("*******************************************************************Cancel gotchi timer OK");
        _gotchiStatusTimer?.cancel();
        _gotchiStatusTimer = null;
      }
    }
  }

  void closeDieBieMSFunc(bool closeView) {
    setState(() {
      _showDieBieMS = false;
    });
    print("DieBieMS RealTime Disabled");
  }

  void closeESCConfiguratorFunc(bool closeView) {
    setState(() {
      _showESCConfigurator = false;
      _handleAutoloadESCSettings(true); // Reload ESC settings after user configuration
    });
    print("Closed ESC Configurator");
  }

  void closeESCAppConfFunc(bool closeView) {
    setState(() {
      _showESCApplicationConfigurator = false;
    });
    print("Closed ESC Application Configurator");
  }

  void changeSmartBMSIDFunc(int nextID) {
    setState(() {
      smartBMSCANID = nextID;
    });
    print("Setting smart BMS CAN FWD ID to $smartBMSCANID");
  }

  void notifyStopStartPPMCalibrate(bool starting) {
    // Set flag to change dialogs displayed when performing PPM calibration
    _isPPMCalibrating = starting;
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
          //TODO: NOTE: setState here does not reload file list after sync is finished
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
            title: Text("FreeSK8 ($freeSK8ApplicationVersion.$counter.preview)"),
            // Set the background color of the App Bar
            backgroundColor: Theme.of(context).primaryColor,
            // Set the bottom property of the Appbar to include a Tab Bar
            //bottom: getTabBar()
        ),
        // Set the TabBar view as the body of the Scaffold
        body: getTabBarView( <Widget>[
          ConnectionStatus(
              active:_scanActive,
              bleDevicesGrid: _buildGridViewOfDevices(),
              currentDevice: _connectedDevice,
              currentFirmware: firmwarePacket,
              userSettings: widget.myUserSettings,
              onChanged: _handleBLEScanState,
              robogotchiVersion: robogotchiVersion,
              imageBoardAvatar: cachedBoardAvatar,
              gotchiStatus: gotchiStatus,
              theTXLoggerCharacteristic: theTXLoggerCharacteristic,
          ),
          RealTimeData(
            routeTakenLocations: routeTakenLocations,
            telemetryPacket: telemetryPacket,
            currentSettings: widget.myUserSettings,
            startStopTelemetryFunc: startStopTelemetryTimer,
            showDieBieMS: _showDieBieMS,
            dieBieMSTelemetry: dieBieMSTelemetry,
            closeDieBieMSFunc: closeDieBieMSFunc,
            changeSmartBMSID: changeSmartBMSIDFunc,
            smartBMSID: smartBMSCANID,
          ),
          ESK8Configuration(
            myUserSettings: widget.myUserSettings,
            currentDevice: _connectedDevice,
            showESCProfiles: _showESCProfiles,
            theTXCharacteristic: the_tx_characteristic,
            escMotorConfiguration: escMotorConfiguration,
            onExitProfiles: _handleESCProfileFinished,
            onAutoloadESCSettings: _handleAutoloadESCSettings,
            showESCConfigurator: _showESCConfigurator,
            discoveredCANDevices: _validCANBusDeviceIDs,
            closeESCConfigurator: closeESCConfiguratorFunc,
            updateCachedAvatar: _cacheAvatar,
            showESCAppConfig: _showESCApplicationConfigurator,
            escAppConfiguration: escApplicationConfiguration,
            closeESCApplicationConfigurator: closeESCAppConfFunc,
            requestESCApplicationConfiguration: requestAPPCONF,
            ppmLastDuration: ppmLastDuration,
            notifyStopStartPPMCalibrate: notifyStopStartPPMCalibrate,
          ),
          RideLogging(
              myUserSettings: widget.myUserSettings,
              theTXLoggerCharacteristic: theTXLoggerCharacteristic,
              syncInProgress: syncInProgress, //TODO: RideLogging receives syncInProgress in syncStatus object
              onSyncPress: _handleBLESyncState,
              syncStatus: syncStatus,
              eraseOnSync: syncEraseOnComplete,
              onSyncEraseSwitch: _handleEraseOnSyncButton,
              isLoggerLogging: isLoggerLogging,
              isRobogotchi : _deviceIsRobogotchi
          )
        ]),
      bottomNavigationBar: Material(
        color: Theme.of(context).primaryColor,
        child: SafeArea(child:getTabBar()),
      ),
      drawer: getNavDrawer(context),
    );
  }
}
