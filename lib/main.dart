import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/crc16.dart';
import 'components/deviceInformation.dart';
import 'hardwareSupport/dieBieMSHelper.dart';
import 'globalUtilities.dart';

// UI Pages
import 'mainViews/connectionStatus.dart';
import 'mainViews/realTimeData.dart';
import 'mainViews/esk8Configuration.dart';
import 'mainViews/rideLogging.dart';

import 'subViews/rideLogViewer.dart';
import 'subViews/focWizard.dart';
import 'subViews/escProfileEditor.dart';
import 'subViews/robogotchiCfgEditor.dart';

import 'widgets/fileSyncViewer.dart';

// Supporting packages
import 'hardwareSupport/bleHelper.dart';
import 'hardwareSupport/escHelper/escHelper.dart';
import 'hardwareSupport/escHelper/appConf.dart';
import 'hardwareSupport/escHelper/mcConf.dart';
import 'hardwareSupport/escHelper/dataTypes.dart';
import 'components/userSettings.dart';
import 'components/fileManager.dart';
import 'components/autoStopHandler.dart';

import 'package:flutter_blue/flutter_blue.dart';
import 'subViews/robogotchiDFU.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:latlong/latlong.dart';

import 'package:geolocator/geolocator.dart';

import 'package:wakelock/wakelock.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart';

import 'package:get_ip/get_ip.dart';

import 'package:logger_flutter/logger_flutter.dart';

import 'components/databaseAssistant.dart';
import 'hardwareSupport/escHelper/serialization/buffers.dart';

const String freeSK8ApplicationVersion = "0.13.2";
const String robogotchiFirmwareExpectedVersion = "0.8.2";

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
        RobogotchiCfgEditor.routeName: (BuildContext context) => RobogotchiCfgEditor(),
        RobogotchiDFU.routeName: (BuildContext context) => RobogotchiDFU(),
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

  static ESC_FIRMWARE escFirmwareVersion = ESC_FIRMWARE.UNSUPPORTED;
  static MCCONF escMotorConfiguration;
  static APPCONF escApplicationConfiguration;
  static int ppmLastDuration;
  static Uint8List escMotorConfigurationDefaults;
  static List<int> _validCANBusDeviceIDs = new List();
  static String robogotchiVersion;

  static bool deviceIsConnected = false;
  static bool unexpectedDisconnect = false;
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

    print("main initState");

    bleHelper = new BLEHelper();
    escHelper = new ESCHelper();
    dieBieMSHelper = new DieBieMSHelper();

    FileManager.createLogDirectory();

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

    DeviceInfo.init();
  }

  void _monitorGotchiTimer() {
    if (_gotchiStatusTimer == null && theTXLoggerCharacteristic != null && initMsgSqeuencerCompleted && (controller.index == 0 || controller.index == 3) && !syncInProgress) {
      globalLogger.d("_monitorGotchiTimer: Starting gotchiStatusTimer");
      startStopGotchiTimer(false);
    } else if (syncInProgress) {
      // Monitor data reception for loss of communication
      if (DateTime.now().millisecondsSinceEpoch - syncLastACK.millisecondsSinceEpoch > 5 * 1000) {
        // It's been 5 seconds since you looked at me.
        // Cocked your head to the side and said I'm angry
        globalLogger.w("_monitorGotchiTimer: syncInProgress = true && syncLastACK > 5 seconds; lsInProgress=$lsInProgress catInProgress=$catInProgress");
        if (lsInProgress) {
          theTXLoggerCharacteristic.write(utf8.encode("ls,${fileList.length},nack~"));
        } else if (catInProgress) {
          theTXLoggerCharacteristic.write(utf8.encode("cat,$catBytesReceived,nack~"));
        }
        syncLastACK = DateTime.now();
      }
    } else {
      //logger.wtf("_monitorGotchiTimer is alive");
    }
  }

  Future<void> checkLocationPermission() async {
    await Geolocator().checkGeolocationPermissionStatus();
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
    } else {
      //NOTE: Only storing the first and current position of the mobile device
      routeTakenLocations.last = lastLocation;
    }
    /* NOT TRACKING VIA PHONE GPS
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
        ///globalLogger.d("Longitude too close to add point (${(lastLocation.longitude - routeTakenLocations.last.longitude).abs()})");
      }
    } else {
      ///globalLogger.d("Latitude too close to add point (${(lastLocation.latitude - routeTakenLocations.last.latitude).abs()})");
    }
     */
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

  void requestAPPCONF(int optionalCANID) async {
    Uint8List packet = simpleVESCRequest(COMM_PACKET_ID.COMM_GET_APPCONF.index, optionalCANID: optionalCANID);

    // Request APPCONF from the ESC
    globalLogger.i("requestAPPCONF: requesting application configuration (CAN ID? $optionalCANID)");
    if (!await sendBLEData(theTXCharacteristic, packet, false)) {
      globalLogger.e("requestAPPCONF: failed to request application configuration");
    }
  }

  void requestMCCONF() async {
    Uint8List packet = simpleVESCRequest(COMM_PACKET_ID.COMM_GET_MCCONF.index);

    // Request MCCONF from the ESC
    globalLogger.i("requestMCCONF: requesting motor configuration");
    if (!await sendBLEData(theTXCharacteristic, packet, false)) {
      globalLogger.e("requestMCCONF: failed to request motor configuration");
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
      globalLogger.d("_handleBLEScanState: disconnecting");
    }
    else if (startScan == true) {
      globalLogger.d("_handleBLEScanState: startScan was true");
      widget.devicesList.clear();
      widget.flutterBlue.startScan(withServices: new List<Guid>.from([uartServiceUUID])).catchError((onError){
        if (onError.toString().contains("Is the Adapter on?")) {
          genericAlert(context, "Bluetooth off?", Text("Unable to start scanning. Please check that bluetooth is enabled and try again"), "OK");
        }
        return;
      });
    } else {
      globalLogger.d("_handleBLEScanState: startScan was false");
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
      globalLogger.i("_bleDisconnect: disconnecting");

      setState(() {
        // Clear BLE Scan state
        widget.devicesList.clear(); //NOTE: clearing list on disconnect so build() does not attempt to pass images of knownDevices that have not yet been loaded
        _scanActive = false;

        // Reset device is connected flag
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
      theTXCharacteristic = null;
      theTXLoggerCharacteristic = null;

      // Reset firmware packet
      firmwarePacket = new ESCFirmware();

      // Reset telemetry packet
      telemetryPacket = new ESCTelemetry();
      telemetryMap = new Map();

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
      initShowESCVersion = false;
      initShowMotorConfiguration = false;

      // Clear the Robogotchi status
      gotchiStatus = new RobogotchiStatus();

      // Clear the ESC firmware version
      escFirmwareVersion = ESC_FIRMWARE.UNSUPPORTED;

      // Clear the PPM calibration is ready flag
      _isPPMCalibrationReady = false;

      // Stop the TCP socket server
      stopTCPServer();

      // Navigate back to the connection tab
      _delayedTabControllerIndexChange(0);
    }
  }

  // TCP Socket Server
  static ServerSocket serverTCPSocket;
  static Socket clientTCPSocket;
  final int tcpBridgePort = 65102;
  void disconnectTCPClient() {
    if (clientTCPSocket != null) {
      clientTCPSocket.close();
      clientTCPSocket.destroy();
      clientTCPSocket = null;
    }
  }
  void stopTCPServer() {
    disconnectTCPClient();
    serverTCPSocket?.close();
    setState(() {
      serverTCPSocket = null;
    });
  }
  void startTCPServer() async {
    serverTCPSocket = await ServerSocket.bind(InternetAddress.anyIPv4, tcpBridgePort, shared: true);
    globalLogger.i("TCP Socket Server Started: ${serverTCPSocket.address}");
    serverTCPSocket.listen(handleTCPClient);
    if (serverTCPSocket != null) {
      genericAlert(context, "TCP Bridge Active", Text("Connect to ${await GetIp.ipAddress} on port $tcpBridgePort"), "OK");
    }
    
  }
  void handleTCPClient(Socket client) {
    clientTCPSocket = client;
    globalLogger.i("handleTCPClient: A new client has connected from ${clientTCPSocket.remoteAddress.address}:${clientTCPSocket.remotePort}");

    clientTCPSocket.listen((onData) {
        //globalLogger.wtf("TCP Client to ESC: $onData");
        // Pass TCP data to BLE
        sendBLEData(theTXCharacteristic, onData, true);
      },
      onError: (e) {
        globalLogger.e("TCP Socket Server::handleTCPClient: Error: ${e.toString()}");
        disconnectTCPClient();
      },
      onDone: () {
        globalLogger.i("TCP Socket Server::handleTCPClient:Connection has terminated.");
        disconnectTCPClient();
      },
    );
  }

  void _hideAllSubviews() {
    _showDieBieMS = false;
    _showESCProfiles = false;
    _showESCConfigurator = false;
    _showESCApplicationConfigurator = false;
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
                            globalLogger.i("_attemptDeviceConnection: User canceled connection attempt");
                            // Cancel connection attempt
                            await device.disconnect().catchError((e){
                              globalLogger.e("_attemptDeviceConnection::GestureDetector: device.disconnect() threw an exception: $e");
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
          globalLogger.i("_attemptDeviceConnection::widget.myUserSettings.loadSettings(): isConnectedDeviceKnown = $value");
          isConnectedDeviceKnown = value;
        });

        await setupConnectedDeviceStreamListener();
        Navigator.of(context).pop(); // Remove attempting connection dialog

        _changeConnectedDialogMessage("Communicating with ESC");
      }
    } catch (e) {
      Navigator.of(context).pop(); // Remove attempting connection dialog
      globalLogger.e("_attemptDeviceConnection:: An exception was thrown: $e");
      //TODO: if we are already connected but trying to connect we might want to disconnect. Needs testing, should only happen during debug
      //TODO: trying device.connect() threw an exception PlatformException(already_connected, connection with device already exists, null)
      device.disconnect().catchError((e){
        globalLogger.e("_attemptDeviceConnection:: While catching exception, device.disconnect() threw an exception: $e");
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

  static BluetoothService theServiceWeWant;
  static BluetoothCharacteristic theTXCharacteristic;
  static BluetoothCharacteristic theRXCharacteristic;
  static BluetoothCharacteristic theTXLoggerCharacteristic;
  static BluetoothCharacteristic theRXLoggerCharacteristic;
  static StreamSubscription<List<int>> escRXDataSubscription;
  static StreamSubscription<List<int>> dieBieMSRXDataSubscription;
  static StreamSubscription<List<int>> loggerRXDataSubscription;

  static ESCFirmware firmwarePacket = new ESCFirmware();
  static ESCTelemetry telemetryPacket = new ESCTelemetry();
  static Map<int, ESCTelemetry> telemetryMap = new Map();
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
  static bool _isPPMCalibrationReady = false;

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
    globalLogger.i("_handleBLESyncState: startSync = $startSync");
    if (startSync) {
      // Start syncing all files by setting syncInProgress to true and request
      // the file list from the receiver
      setState(() {
        syncInProgress = true;
        // Prevent the status timer from interrupting this request
        _gotchiStatusTimer?.cancel();
        _gotchiStatusTimer = null;
      });
      // Request the files to begin the process
      if (!await sendBLEData(theTXLoggerCharacteristic, utf8.encode("ls~"), false)) {
        globalLogger.e("_handleBLESyncState: failed to request file list");
      }
    } else {
      globalLogger.i("_handleBLESyncState: Stopping Sync Process");
      setState(() {
        syncInProgress = false;
        syncAdvanceProgress = false;
        lsInProgress = false;
        catInProgress = false;
        catCurrentFilename = "";
      });
      // After stopping the sync on this end, request stop on the Robogotchi
      if (await sendBLEData(theTXLoggerCharacteristic, utf8.encode("syncstop~"), false)) {
        globalLogger.i("_handleBLESyncState: syncstop command sent");
      } else {
        globalLogger.e("_handleBLESyncState: syncstop failed to send");
      }

    }
  }
  void _handleEraseOnSyncButton(bool eraseOnSync) {
    globalLogger.i("_handleEraseOnSyncButton: eraseOnSync: $eraseOnSync");
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
            globalLogger.w("_connectedDeviceStreamSubscription: We have connected to the device that we were previously disconnected from");
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
            globalLogger.i("_connectedDeviceStreamSubscription: Device has successfully connected.");
            Future.delayed(const Duration(milliseconds: 750), () {
              setState(() {
                prepareConnectedDevice();
                deviceIsConnected = true;
                unexpectedDisconnect = false;
              });
            });
          }

          break;
        case BluetoothDeviceState.disconnected:
          if ( deviceIsConnected  ) {
            globalLogger.w("_connectedDeviceStreamSubscription: WARNING: We have disconnected but FreeSK8 was expecting a connection");
            setState(() {
              deviceHasDisconnected = true;
              unexpectedDisconnect = true;
            });
            startStopTelemetryTimer(true);
            // Alert user that the connection was lost
            //TODO: Do we need an alert? genericAlert(context, "Disconnected", Text("The Bluetooth device has disconnected"), "OK");
            //NOTE: On an Android this connection can automatically be resumed
            //NOTE: On iOS this connection will never re-connection
            // Disconnect
            _bleDisconnect();
          }
          break;
        default:
          globalLogger.e("setupConnectedDeviceStreamListener::_connectedDeviceStreamSubscription: listen: unexpected state: $state");
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
    _services = await _connectedDevice?.discoverServices();

    for (BluetoothService service in _services) {
      globalLogger.d("prepareConnectedDevice: Discovered service: ${service.uuid}");
      if (service.uuid == uartServiceUUID) {
        foundService = true;
        theServiceWeWant = service;
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          globalLogger.d("prepareConnectedDevice: Discovered characteristic: ${characteristic.uuid}");
          if (characteristic.uuid == txCharacteristicUUID){
            theTXCharacteristic = characteristic;
            foundTX = true;
          }
          else if (characteristic.uuid == rxCharacteristicUUID){
            theRXCharacteristic = characteristic;
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
      globalLogger.e("prepareConnectedDevice: ERROR: Required service and characteristics not found on this device");

      _alertInvalidDevice();
      _bleDisconnect();

      return;
    } else if ( !foundTXLogger || !foundRXLogger ) {
      _deviceIsRobogotchi = false;
      globalLogger.d("prepareConnectedDevice: Not a Robogotchi..");
    }
    else {
      _deviceIsRobogotchi = true;
      globalLogger.d("prepareConnectedDevice: All required service and characteristics were found on this device. Good news!");
    }

    if(foundRXLogger){
      await theRXLoggerCharacteristic.setNotifyValue(true);
    }

    if(foundRXLogger) loggerRXDataSubscription = theRXLoggerCharacteristic.value.listen((value) async {
      if (value.length == 0) {
        return; // Nothing to process. This happens on initial connection
      }
      /// Process data received from FreeSK8 logger characteristic
      String receiveStr = new String.fromCharCodes(value);
      ///LS Command
      if (lsInProgress) {
        if (receiveStr == "ls,complete") {
          globalLogger.d("List File Operation Complete. ${fileList.length} files reported");
          fileList.sort((a, b) => a.fileName.compareTo(b.fileName)); // Sort ascending to grab the oldest file first
          fileList.forEach((element) {
            globalLogger.d("File: ${element.fileName} is ${element.fileSize} bytes");
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
          String logFileContentsForDebugging = "";
          try {
            globalLogger.d("Concatenate file operation complete on $catCurrentFilename with $catBytesReceived bytes");

            //TODO: validate file transmission. We need a proper packet definition and CRC
            // Write raw bytes from cat operation to the filesystem
            await FileManager.writeBytesToLogFile(catBytesRaw);
            catBytesRaw.clear();

            // Save temporary log data to final filename
            // Then generate database statistics
            // Then create database entry
            // Then rebuild state and continue sync process
            String savedFilePath = await FileManager.saveLogToDocuments(filename: catCurrentFilename, userSettings: widget.myUserSettings);

            /// Analyze log to generate database statistics
            Map<int, double> wattHoursStartByESC = new Map();
            Map<int, double> wattHoursEndByESC = new Map();
            Map<int, double> wattHoursRegenStartByESC = new Map();
            Map<int, double> wattHoursRegenEndByESC = new Map();
            double maxCurrentBattery = 0.0;
            double maxCurrentMotor = 0.0;
            double maxSpeedKph = 0.0;
            //double avgSpeedKph = 0.0;
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
            logFileContentsForDebugging = logFileContents;

            /// Iterate each line of logFileContents
            List<String> thisRideLogEntries = logFileContents.split("\n");
            for(int i=0; i<thisRideLogEntries.length; ++i) {
              if(thisRideLogEntries[i] == null || thisRideLogEntries[i] == "") continue;
              //globalLogger.wtf("uhhhh parsing: ${thisRideLogEntries[i]}");
              final entry = thisRideLogEntries[i].split(",");

              if(entry.length > 1 && entry[0] != "header"){ // entry[0] = Time, entry[1] = Data type
                ///GPS position entry
                if(entry[1] == "gps" && entry.length >= 7) {
                  //dt,gps,satellites,altitude,speed,latitude,longitude
                  // Determine date times
                  DateTime thisEntryTime = DateTime.tryParse(entry[0]);
                  firstEntryTime ??= thisEntryTime;
                  if (thisEntryTime != null) lastEntryTime = thisEntryTime;

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
                  DateTime thisEntryTime = DateTime.tryParse(entry[0]);
                  firstEntryTime ??= thisEntryTime;
                  if (thisEntryTime != null) lastEntryTime = thisEntryTime;

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
            globalLogger.d("ESC ID $firstESCID traveled $distanceTotal km");

            /// Compute consumption
            double wattHours = 0;
            double wattHoursRegen = 0;
            wattHoursStartByESC.forEach((key, value) {
              globalLogger.d("ESC ID $key consumed ${wattHoursEndByESC[key] - value} watt hours");
              wattHours += wattHoursEndByESC[key] - value;
            });
            wattHoursRegenStartByESC.forEach((key, value) {
              globalLogger.d("ESC ID $key regenerated ${wattHoursRegenEndByESC[key] - value} watt hours");
              wattHoursRegen += wattHoursRegenEndByESC[key] - value;
            });

            globalLogger.d("Consumption calculation: Watt Hours Total $wattHours Regenerated Total $wattHoursRegen");

            //NOTE: failure checking...
            //int test = null;
            //int fail = test + 420;

            /// Insert record into database
            if (lastEntryTime == null && firstEntryTime == null) {
              globalLogger.e("cat,complete: Unable to create database entry for $catCurrentFilename");
            } else {
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
            }

            /// Advance the sync process after success
            fileListToDelete.add(catCurrentFilename); // Add this file to fileListToDelete
            loggerTestBuffer = receiveStr;
            if(!syncInProgress) _alertLoggerTest();
            setState(() {
              catInProgress = false;
              syncAdvanceProgress = true;
              ///Cat completed
              ///Setting state so this widget rebuilds. On build it will
              ///check if syncInProgress and start the next file
            });

            ///Save file operation complete
            return;

          } catch (e) {
            globalLogger.e("cat,complete threw an exception: ${e.toString()}");

            // Alert user something went wrong with the parsing
            genericConfirmationDialog(context, FlatButton(
              child: Text("Copy / Share"),
              onPressed: () {
                Share.text(catCurrentFilename, "${e.toString()}\n\n$logFileContentsForDebugging}", 'text/plain');
              },
            ), FlatButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ), "File processing error", Text("Something unexpected may have happened!\n\nPlease share with renee@derelictrobot.com"));

            /// Advance the sync process after failure
            {
              setState(() {
                catInProgress = false;
                syncAdvanceProgress = true;
              });
            }
          } // catch (exception)

          // Return now, we are finished here
          return;
        } //receiveStr == "cat,complete"
        else {
          /// Cat isn't complete so we are going to store data and ask for the next packet
          // store chunk of log data
          catBytesRaw.addAll(value.sublist(0,receiveStr.length));
          //NOTE: File operations on iOS can slow things down, using memory buffer ^ await FileManager.writeBytesToLogFile(value.sublist(0,receiveStr.length));

          //globalLogger.d("cat received ${receiveStr.length} bytes");
          setState(() {
            catBytesReceived += receiveStr.length;
          });

          syncLastACK = DateTime.now();
          if (!await sendBLEData(theTXLoggerCharacteristic, utf8.encode("cat,$catBytesReceived,ack~"), true)) {
            globalLogger.e("catInProgress failed to send ACK");
          }
        }
      }
      else if(receiveStr.startsWith("cat,/FreeSK8Logs")){
        globalLogger.d("Starting cat Command: $receiveStr");
        loggerTestBuffer = "";
        catInProgress = true;
        lsInProgress = false;
        catBytesReceived = 0;
        FileManager.clearLogFile();

        syncLastACK = DateTime.now();
        await theTXLoggerCharacteristic.write(utf8.encode("cat,0,ack~"));
      }

      else if(receiveStr.startsWith("rm,")){
        globalLogger.d("Remove File/Directory response received: $receiveStr");
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
        //logger.d("Status packet received: $receiveStr");
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
        globalLogger.d("Faults packet received: $receiveStr");
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
        globalLogger.d("Version packet received: $receiveStr");
        List<String> values = receiveStr.split(",");
        // Update robogotchiVersion
        robogotchiVersion = values[1];
        // Flag the reception of an init message
        initMsgGotchiVersion = true;
        // Redraw UI
        setState(() {});
      }
      else if(receiveStr.startsWith("getcfg,")) {
        globalLogger.d("Robogotchi User Configuration received: $receiveStr");
        // Parse the configuration
        List<String> values = receiveStr.split(",");
        int parseIndex = 1;
        RobogotchiConfiguration gotchConfig = new RobogotchiConfiguration(
            cfgVersion: int.tryParse(values[parseIndex++]),
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
            timeZoneOffsetHours: int.tryParse(values[parseIndex++]),
            timeZoneOffsetMinutes: int.tryParse(values[parseIndex++]),
        );

        // Validate we received the expected cfgVersion from the module or else there could be trouble
        if (gotchConfig.cfgVersion != 4) {
          genericAlert(
              context,
              "Version mismatch",
              robogotchiVersion != robogotchiFirmwareExpectedVersion ?
              Text("Robogotchi provided an incorrect configuration version.") :
              Text(""),
              "OK"
          );
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
        globalLogger.d("Robogotchi User Configuration updated: $receiveStr");
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
        globalLogger.wtf("loggerReceived and unexpected response: ${new String.fromCharCodes(value)}");
      }

    });

    // Setup the RX characteristic to notify on value change
    await theRXCharacteristic.setNotifyValue(true);
    // Setup the RX characteristic callback function
    escRXDataSubscription = theRXCharacteristic.value.listen((value) {

      // If we have the TCP Socket server running and a client connected forward the data
      if(serverTCPSocket != null && clientTCPSocket != null) {
        //globalLogger.wtf("ESC Data $value");
        clientTCPSocket.add(value);
        return;
      }

      // BLE data received
      if (bleHelper.processIncomingBytes(value) > 0){

        //Time to process the packet
        int packetID = bleHelper.getPayload()[0];
        if (packetID == COMM_PACKET_ID.COMM_FW_VERSION.index) {
          ///Firmware Packet
          firmwarePacket = escHelper.processFirmware(bleHelper.getPayload());

          // Flag the reception of an init message
          initMsgESCVersion = true;

          // Analyze
          var major = firmwarePacket.fw_version_major;
          var minor = firmwarePacket.fw_version_minor;
          var hardName = firmwarePacket.hardware_name;
          globalLogger.d("Firmware packet: major $major, minor $minor, hardware $hardName");

          setState(() {
            isESCResponding = true;
          });


          bleHelper.resetPacket(); //Be ready for another packet

          // Check if compatible firmware
          if (major == 5 && minor == 1) {
            escFirmwareVersion = ESC_FIRMWARE.FW5_1;
          } else if (major == 5 && minor == 2) {
            escFirmwareVersion = ESC_FIRMWARE.FW5_2;
          } else {
            escFirmwareVersion = ESC_FIRMWARE.UNSUPPORTED;
          }
          if(escFirmwareVersion == ESC_FIRMWARE.UNSUPPORTED) {
            // Stop the init message sequencer
            _initMsgSequencer.cancel();
            _initMsgSequencer = null;
            initMsgSqeuencerCompleted = true;

            // Remove communicating with ESC dialog
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }

            // Notify user we are in invalid firmware land
            _alertInvalidFirmware("Firmware: $major.$minor\nHardware: $hardName");

            return; //TODO: not going to force the user to disconnect? _bleDisconnect();
          }

        }
        else if ( packetID == DieBieMSHelper.COMM_GET_BMS_CELLS ) {
          setState(() {
            dieBieMSTelemetry = dieBieMSHelper.processCells(bleHelper.getPayload());
          });
          bleHelper.resetPacket(); //Prepare for next packet
        }
        else if (packetID == COMM_PACKET_ID.COMM_GET_VALUES_SETUP.index) {
          ///Telemetry packet
          telemetryPacket = escHelper.processSetupValues(bleHelper.getPayload());

          // Update map of ESC telemetry
          telemetryMap[telemetryPacket.vesc_id] = telemetryPacket;

          if(controller.index == 1) { //Only re-draw if we are on the real time data tab
            setState(() { //Re-drawing with updated telemetry data
            });
          }

          // Watch here for all fault codes received. Populate an array with time and fault for display to user
          if ( telemetryPacket.fault_code != mc_fault_code.FAULT_CODE_NONE ) {
            globalLogger.w("WARNING! Fault code received! ${telemetryPacket.fault_code}");
          }

          // Prepare for the next packet
          bleHelper.resetPacket();
        }
        else if ( packetID == COMM_PACKET_ID.COMM_GET_VALUES.index ) {
          if(_showDieBieMS) {
            // Parse DieBieMS GET_VALUES packet - A shame they share the same ID as ESC values
            dieBieMSTelemetry = dieBieMSHelper.processTelemetry(bleHelper.getPayload(), smartBMSCANID);

            if(controller.index == 1) { //Only re-draw if we are on the real time data tab
              setState(() { //Re-drawing with updated telemetry data
              });
            }
          }

          //TODO: Old Telemetry packet
          //telemetryPacket = escHelper.processTelemetry(bleHelper.getPayload());
          //print("goodValues ${telemetryPacket.vesc_id} ${telemetryPacket.tachometer} ${telemetryPacket.tachometer_abs} ${telemetryPacket.amp_hours} ${telemetryPacket.amp_hours_charged} ${telemetryPacket.watt_hours}");

          // Prepare for the next packet
          bleHelper.resetPacket();

        } else if ( packetID == COMM_PACKET_ID.COMM_PING_CAN.index ) {
          ///Ping CAN packet
          globalLogger.d("Ping CAN packet received! ${bleHelper.lenPayload} bytes");

          // Flag the reception of an init message
          initMsgESCDevicesCAN = true;

          // Populate a fresh _validCANBusDeviceIDs array
          _validCANBusDeviceIDs.clear();
          for (int i = 1; i < bleHelper.lenPayload; ++i) {
            if (bleHelper.getPayload()[i] != 0) {
              globalLogger.d("CAN Device Found at ID ${bleHelper
                  .getPayload()[i]}. Is it an ESC? Stay tuned to find out more...");
              _validCANBusDeviceIDs.add(bleHelper.getPayload()[i]);
            }
          }

          // Prepare for yet another packet
          bleHelper.resetPacket();
        } else if ( packetID == COMM_PACKET_ID.COMM_NRF_START_PAIRING.index ) {
          globalLogger.d("COMM_PACKET_ID = COMM_NRF_START_PAIRING");
          switch (bleHelper.getPayload()[1]) {
            case 0:
              globalLogger.d("Pairing started");
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
              globalLogger.d("Pairing Successful");
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
              globalLogger.d("Pairing timeout");
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
              globalLogger.e("ERROR: Pairing unknown payload");
              Navigator.of(context).pop(); //Pop Quick Pair initial dialog
              if (controller.index == 1) {
                //Resume the telemetry timer
                startStopTelemetryTimer(false);
              }
          }
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_SET_MCCONF.index ) {
          globalLogger.d("COMM_PACKET_ID = COMM_SET_MCCONF");
          //logger.d("COMM_PACKET_ID.COMM_SET_MCCONF: ${bleHelper.getPayload().sublist(0,bleHelper.lenPayload)}");
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
          globalLogger.d("COMM_PACKET_ID = COMM_SET_MCCONF_TEMP_SETUP");
          //TODO: analyze packet before assuming success?
          _alertProfileSet();
          _handleAutoloadESCSettings(true); // Reload ESC settings from applied configuration
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_MCCONF.index) {
          ///ESC Motor Configuration
          escMotorConfiguration = escHelper.processMCCONF(bleHelper.getPayload(), escFirmwareVersion); //bleHelper.payload.sublist(0,bleHelper.lenPayload);

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
          //globalLogger.wtf("Break for MCCONF: $escMotorConfiguration");

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
            globalLogger.d("MCCONF is updating application settings specific to this board");
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
          globalLogger.d("Oof.. MCCONF_DEFAULT: $escMotorConfigurationDefaults");

          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_GET_APPCONF.index) {
          globalLogger.d("COMM_PACKET_ID = COMM_GET_APPCONF");

          ///ESC Application Configuration
          escApplicationConfiguration = escHelper.processAPPCONF(bleHelper.getPayload(), escFirmwareVersion);

          if (_showESCApplicationConfigurator) {
            setState(() {
              _hideAllSubviews();
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
          globalLogger.d("COMM_DETECT_APPLY_ALL_FOC packet received");
          // Handle FOC detection results
          globalLogger.d(bleHelper.getPayload().sublist(0,bleHelper.lenPayload)); //[58, 0, 1]
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
                globalLogger.d("COMM_DETECT_APPLY_ALL_FOC: Detection failed");
                break;
              case -10:
                globalLogger.d("COMM_DETECT_APPLY_ALL_FOC: Flux linkage detection failed");
                break;
              case -50:
                globalLogger.d("COMM_DETECT_APPLY_ALL_FOC: CAN detection timed out");
                break;
              case -51:
                globalLogger.d("COMM_DETECT_APPLY_ALL_FOC: CAN detection failed");
                break;
              default:
                globalLogger.d("COMM_DETECT_APPLY_ALL_FOC: ERROR: result of FOC detection was unknown: $resultFOCDetection");
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

          //int valueNow = buffer_get_int32(bleHelper.getPayload(), 1);
          int msNow = buffer_get_int32(bleHelper.getPayload(), 5);
          //globalLogger.d("Decoded PPM packet received: value $valueNow, milliseconds $msNow");
          setState(() {
            ppmLastDuration = msNow;
          });
          bleHelper.resetPacket();
        } else if (packetID == COMM_PACKET_ID.COMM_PRINT.index) {

          int stringLength = bleHelper.getMessage()[1] - 1;
          String messageFromESC = new String.fromCharCodes(bleHelper.getMessage().sublist(3, 3 + stringLength));
          globalLogger.wtf("ESC Custom Message: $messageFromESC");
          genericAlert(context, "Excuse me", Text("The ESC responded with a custom message:\n\n$messageFromESC"), "OK");
          bleHelper.resetPacket();

        } else if (packetID == COMM_PACKET_ID.COMM_SET_APPCONF.index) {

          if (_isPPMCalibrating != null && _isPPMCalibrating) {
            globalLogger.d("PPM Calibration is Ready");
            genericAlert(context, "Calibration", Text("Calibration Instructions:\nMove input to full brake, full throttle then leave in the center\n\nPlease ensure the wheels are off the ground in case something goes wrong. Press OK when ready."), "OK");
            _isPPMCalibrating = null;
            setState(() {
              _isPPMCalibrationReady = true;
            });
          } else if (_isPPMCalibrating != null && !_isPPMCalibrating) {
            globalLogger.d("PPM Calibration has completed");
            genericAlert(context, "Calibration", Text("Calibration Completed"), "OK");
            _isPPMCalibrating = null;
            setState(() {
              _isPPMCalibrationReady = false;
            });
          } else {
            globalLogger.d("Application Configuration Saved Successfully");
            genericAlert(context, "Success", Text("Application configuration set"), "Excellent");
          }

          bleHelper.resetPacket();

        } else {
          globalLogger.e("Unsupported packet ID: $packetID");
          globalLogger.e("Unsupported packet Message: ${bleHelper.getMessage().sublist(0,bleHelper.endMessage)}");
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

  bool initShowESCVersion = false;
  bool initShowMotorConfiguration = false;
  void _requestInitMessages() {
    if (_deviceIsRobogotchi && !initMsgGotchiVersion) {
      globalLogger.d("_requestInitMessages: Requesting Robogotchi version");
      // Request the Robogotchi version
      theTXLoggerCharacteristic.write(utf8.encode("version~"));
      _changeConnectedDialogMessage("Requesting Robogotchi version");
    } else if (_deviceIsRobogotchi && !initMsgGotchiSettime) {
      globalLogger.d("_requestInitMessages: Sending current time to Robogotchi");
      // Set the Robogotchi time from DateTime.now() converted to UTC
      theTXLoggerCharacteristic.write(utf8.encode("settime ${DateTime.now().toUtc().toIso8601String().substring(0,19).replaceAll("-", ":")}~"));
      //TODO: without a response we will assume this went as planned
      initMsgGotchiSettime = true;
    } else if (!initMsgESCVersion) {
      // Request the ESC Firmware Packet
      globalLogger.d("_requestInitMessages: Requesting ESC Firmware Packet");
      theTXCharacteristic.write([0x02, 0x01, 0x00, 0x00, 0x00, 0x03]).catchError((onError){
        // No Action
      });
      if (!initShowESCVersion) {
        _changeConnectedDialogMessage("Requesting ESC version");
        initShowESCVersion = true;
      }
    } else if (!initMsgESCMotorConfig) {
      globalLogger.d("_requestInitMessages: Requesting initMsgESCMotorConfig");
      // Request MCCONF
      _handleAutoloadESCSettings(true);
      if (!initShowMotorConfiguration) {
        _changeConnectedDialogMessage("Requesting Motor Configuration");
        initShowMotorConfiguration = true;
      }
    } else if (!initMsgESCDevicesCAN) {
      if (initMsgESCDevicesCANRequested == 0) {
        globalLogger.d("_requestInitMessages: Requesting initMsgESCDevicesCAN");
        // Request CAN Devices scan
        Uint8List packetScanCAN = new Uint8List(6);
        packetScanCAN[0] = 0x02; //Start packet
        packetScanCAN[1] = 0x01; //Payload length
        packetScanCAN[2] = COMM_PACKET_ID.COMM_PING_CAN.index; //Payload data
        //3,4 are CRC computed below
        packetScanCAN[5] = 0x03; //End packet
        int checksum = CRC16.crc16(packetScanCAN, 2, 1);
        packetScanCAN[3] = (checksum >> 8) & 0xff;
        packetScanCAN[4] = checksum & 0xff;
        theTXCharacteristic.write(packetScanCAN);
        initMsgESCDevicesCANRequested = 1;

        _changeConnectedDialogMessage("Requesting CAN IDs");

        // Start the Robogotchi Status timer before the CAN responds (so slooooooooooooow)
        if (_deviceIsRobogotchi) {
          Future.delayed(const Duration(milliseconds: 200), () {
            startStopGotchiTimer(false);
          });
        }
      } else {
        if (++initMsgESCDevicesCANRequested == 25) {
          globalLogger.e("_requestInitMessages: initMsgESCDevicesCAN did not get a response. Retrying");
          initMsgESCDevicesCANRequested = 0;
          _changeConnectedDialogMessage("Requesting CAN IDs (again)");
        }
      }
    } else {
      // Init complete
      // If user forces communicating dialog to close and we finish init don't pop the main view
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(); // Remove communicating with ESC dialog
      }

      // Alert user if Robogotchi firmware update is expected
      if (_deviceIsRobogotchi && robogotchiVersion != robogotchiFirmwareExpectedVersion) {
        genericConfirmationDialog(context, FlatButton(
          child: Text("NO"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ), FlatButton(
          child: Text("YES"),
          onPressed: () async {
            // Navigate to Firmware Update view
            await theTXLoggerCharacteristic.write(utf8.encode("dfumode~")).timeout(Duration(milliseconds: 500)).whenComplete((){
              globalLogger.d('Robogotchi DFU Mode Command Executed');
              Navigator.of(context).pop();
              _bleDisconnect();
              setState(() {
                Navigator.of(context).pushNamed(RobogotchiDFU.routeName, arguments: null);
              });
            }).catchError((e){
              globalLogger.e("Firmware Update: Exception: $e");
            });
          },
        ), "Update available", Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("This app works best when Robogotchi is up to date!"),
              SizedBox(height: 15),
              Text("Installed firmware: $robogotchiVersion"),
              Text("Ready to install: $robogotchiFirmwareExpectedVersion"),
              SizedBox(height: 15),
              Text("Would you like the begin the update process now?")
            ])
        );
      }
      // Alert user if this is a new device when we connected/loaded it's settings
      else if (!isConnectedDeviceKnown) {
        globalLogger.d("_requestInitMessages: Connected device is not known. Notifying user");
        //TODO: navigate to setup widget if we create one..
        genericAlert(context, "New device!", Text("You have connected to a new device. Take a picture, give it a name and save your settings now for the best experience."), "OK");
        _delayedTabControllerIndexChange(2); // Switch to the configuration tab
      }

      globalLogger.i("_requestInitMessages: initMsgSequencer is complete! Great success!");

      _initMsgSequencer.cancel();
      _initMsgSequencer = null;

      initMsgSqeuencerCompleted = true;
    }
  }
  void _changeConnectedDialogMessage(String message) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Remove previous dialog
    }
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
                          globalLogger.d("_changeConnectedDialogMessage: Long press received. Closing dialog.");
                          Navigator.of(context).pop(); // Remove communicating with ESC dialog
                        },
                        child: Column(children: [
                          Icon(Icons.bluetooth_searching, size: 80,color: Colors.green),
                          SizedBox(height: 10,),
                          Text("Connected"),
                          Text(message),
                          Text("(long press to dismiss)", style: TextStyle(fontSize: 7))
                        ]),
                      ),
                    )
                  ]));
        });
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
                Text('FreeSK8 currently works with ESCs using firmware 5.1 and 5.2 and the connected ESC says it is incompatible:'),
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

  void _delayedTabControllerIndexChange(int index) {
    Future.delayed(Duration(milliseconds: 250), (){
      setState(() {
        controller.index = index;
      });
    });
  }

  /// Hamburger Menu... mmmm hamburgers
  Drawer getNavDrawer(BuildContext context) {
    var headerChild = DrawerHeader(
        child: GestureDetector(
            onTap: ()
            {
              setState(() {
                if (++seriousBusinessCounter > 8) seriousBusinessCounter = 0;
                globalLogger.i("Things are getting serious $seriousBusinessCounter");
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
      applicationIcon: Icon(Icons.info, size: 40),
      icon: Icon(Icons.info),
      aboutBoxChildren: <Widget>[
        Text("This project was brought to you by the fine people of", textAlign: TextAlign.center),
        Image(image: AssetImage('assets/dri_about.png'), width: 300),
        Text("Thank you for your support!", textAlign: TextAlign.center),
        SizedBox(height: 10),
        Text("A special thank you to our beta testers and patreons\n🙏🙏🏼🙏🏾🙏🏻🙏🏿🙏🏽\nYou are what makes this awesome!", textAlign: TextAlign.center)
      ],
    );

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
            globalLogger.d("Smart BMS RealTime Disabled");
            Navigator.pop(context); // Close drawer
          } else {
            setState(() {
              _showDieBieMS = true;
            });
            _delayedTabControllerIndexChange(1);
            globalLogger.d("Smart BMS RealTime Enabled");
            Navigator.pop(context); // Close drawer
          }
        },
      ),

      ListTile(
        leading: Icon(Icons.timer),
        title: Text("Speed Profiles"),
        onTap: () {
          // Don't write if not connected
          if (theTXCharacteristic != null) {
            setState(() {
              _hideAllSubviews();
              // Set the flag to show ESC profiles. Display when MCCONF is returned
              _showESCProfiles = true;
            });

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
          if (theTXCharacteristic != null) {
            setState(() {
              _hideAllSubviews();
              _showESCApplicationConfigurator = true;
            });
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
        title: Text("Show ESC Configurator"),
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
          } else {
            setState(() {
              _hideAllSubviews();
              _showESCConfigurator = true;
            });
            _delayedTabControllerIndexChange(2);
            globalLogger.d("ESC Configurator Displayed");
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
              globalLogger.e("Gotchi User Config Request: Exception: $e");
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
        title: Text("Robogotchi Updater"),
        onLongPress: (){
          if (_connectedDevice == null) {
            Navigator.of(context).pop();
            setState(() {
              // navigate to the route
              Navigator.of(context).pushNamed(RobogotchiDFU.routeName, arguments: null);
            });
            genericAlert(context, "Hey there 👋", Text("We are not connected to a Robogotchi which means I can't prepare it for update mode.\n\nI'll search for devices anyway but you'll probably want to turn back now."), "Ok 👍");
          }
        },
        onTap: () {
          // Don't write if not connected
          if (theTXLoggerCharacteristic != null) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Ready to update?'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: <Widget>[
                        Text('Selecting YES will put your Robogotchi into update mode.'),
                        SizedBox(height:10),
                        Text('This process typically takes 1-2 minutes')
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
                      child: Text('YES'),
                      onPressed: () async {
                        await theTXLoggerCharacteristic.write(utf8.encode("dfumode~")).timeout(Duration(milliseconds: 500)).whenComplete((){
                          globalLogger.d('Robogotchi DFU Mode Command Executed');

                          Navigator.of(context).pop();

                          _bleDisconnect();

                          setState(() {
                            // navigate to the route
                            Navigator.of(context).pushNamed(RobogotchiDFU.routeName, arguments: null);
                          });
                        }).catchError((e){
                          globalLogger.e("Firmware Update: Exception: $e");
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
                  content: Text("Oops. Try connecting to your Robogotchi first."),
                );
              },
            );
          }
        },
      ),

      Divider(thickness: 3),
      ListTile(
        leading: Icon(Icons.share_outlined),
        title: Text(serverTCPSocket == null ? "Enable TCP Bridge" : "Disable TCP Bridge"),
        onTap: () {
          // Don't start if not connected
          if (theTXCharacteristic == null || !isESCResponding || !deviceIsConnected) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("No Connection"),
                  content: Text("Oops. Try connecting to your board first."),
                );
              },
            );
          } else if (serverTCPSocket == null) {
            setState(() {
              startTCPServer();
            });
          } else {
            setState(() {
              stopTCPServer();
            });
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
      globalLogger.d("_requestGotchiStatus: Auto stopping gotchi timer");
      startStopGotchiTimer(true);
    } else {
      theTXLoggerCharacteristic.write(utf8.encode("status~")).catchError((error){
        globalLogger.w("_requestGotchiStatus: theTXLoggerCharacteristic was busy");
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
        int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, packetLength);
        byteData.setUint16(5, checksum);
        byteData.setUint8(7, 0x03); //End of packet
        await theTXCharacteristic.write(byteData.buffer.asUint8List(), withoutResponse: true).then((value) {
        }).
        catchError((e) {
          ++bleTXErrorCount;
          globalLogger.e("_requestTelemetry() failed ($bleTXErrorCount) times. Exception: $e");
        });

        //TODO: This should be delayed because the characteristic might not be ready to write...
        /// Request cell data from DieBieMS
        byteData.setUint8(0, 0x02); //Start of packet
        byteData.setUint8(1, packetLength);
        byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
        byteData.setUint8(3, smartBMSCANID); //CAN ID
        byteData.setUint8(4, DieBieMSHelper.COMM_GET_BMS_CELLS);
        checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, packetLength);
        byteData.setUint16(5, checksum);
        byteData.setUint8(7, 0x03); //End of packet

        await theTXCharacteristic.write(byteData.buffer.asUint8List(), withoutResponse: true).
        catchError((e) {
          globalLogger.w("TODO: You should request the next packet type upon reception of the prior");
        });
      } else {
        /// Request ESC Telemetry
        Uint8List packet = simpleVESCRequest(COMM_PACKET_ID.COMM_GET_VALUES_SETUP.index);

        // Request COMM_GET_VALUES_SETUP from the ESC instead of COMM_GET_VALUES
        if (!await sendBLEData(theTXCharacteristic, packet, true)) {
          ++bleTXErrorCount;
          globalLogger.e("_requestTelemetry() failed ($bleTXErrorCount) times!");
        }
      }
    } else {
      // We are requesting telemetry but are not connected =/
      globalLogger.d("Request telemetry canceled because we are not connected");
      setState(() {
        telemetryTimer?.cancel();
        telemetryTimer = null;
      });
    }
  }

  // Start and stop telemetry streaming timer
  void startStopTelemetryTimer(bool disableTimer) {
    if (!disableTimer){
      globalLogger.d("startStopTelemetryTimer: Starting timer");
      const duration = const Duration(milliseconds:100);
      telemetryTimer = new Timer.periodic(duration, (Timer t) => _requestTelemetry());
    } else {
      globalLogger.d("startStopTelemetryTimer: Stopping timer");
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
        globalLogger.d("startStopGotchiTimer: Starting gotchi timer");
        const duration = const Duration(milliseconds:1000);

        Future.delayed(const Duration(milliseconds: 500), () {
          _gotchiStatusTimer = new Timer.periodic(duration, (Timer t) => _requestGotchiStatus());
        });
      }
    } else {
      globalLogger.d("startStopGotchiTimer: Cancel gotchi timer");
      if (_gotchiStatusTimer != null) {
        globalLogger.d("startStopGotchiTimer: Cancel gotchi timer OK");
        _gotchiStatusTimer?.cancel();
        _gotchiStatusTimer = null;
      }
    }
  }

  void closeDieBieMSFunc(bool closeView) {
    setState(() {
      _showDieBieMS = false;
    });
    globalLogger.d("Smart BMS RealTime Disabled");
  }

  void closeESCConfiguratorFunc(bool closeView) {
    setState(() {
      _showESCConfigurator = false;
      _handleAutoloadESCSettings(true); // Reload ESC settings after user configuration
    });
    globalLogger.d("closeESCConfiguratorFunc: Closed ESC Configurator");
  }

  void closeESCAppConfFunc(bool closeView) {
    setState(() {
      _showESCApplicationConfigurator = false;
    });
    globalLogger.d("closeESCAppConfFunc: Closed ESC Application Configurator");
  }

  void changeSmartBMSIDFunc(int nextID) {
    globalLogger.d("changeSmartBMSIDFunc: Setting smart BMS CAN FWD ID to $smartBMSCANID");
    setState(() {
      smartBMSCANID = nextID;
    });
  }

  void notifyStopStartPPMCalibrate(bool starting) {
    // Set flag to change dialogs displayed when performing PPM calibration
    _isPPMCalibrating = starting;
    if (!starting) {
      _isPPMCalibrationReady = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if(syncInProgress && syncAdvanceProgress){
      globalLogger.d("Building main.dart with syncAdvanceProgress: fileList.length=${fileList.length} fileListToDelete.length=${fileListToDelete.length} syncEraseOnComplete=$syncEraseOnComplete");
      syncAdvanceProgress = false;

      if(fileList.length>0) //TODO: logically I didn't think this needed to be conditional but helps during debugging
        fileList.removeAt(0); //Remove the first file in the list (we just finished receiving this file)

      if(fileList.length>0){
        catCurrentFilename = fileList.first.fileName;
        catBytesTotal = fileList.first.fileSize; //Set the total expected bytes for the current file
        globalLogger.d("Sync requesting cat of ${fileList.first.fileName}");
        sendBLEData(theTXLoggerCharacteristic, utf8.encode("cat ${fileList.first.fileName}~"), false); //Request next file
      }
      else if(fileListToDelete.length>0){
        // We have sync'd all the files and we have files to erase
        // Evaluate user's option to remove files on sync
        if (syncEraseOnComplete) {
          globalLogger.d("Sync requesting rm of ${fileListToDelete.first}");
          // Remove the first file in the list of files to delete
          sendBLEData(theTXLoggerCharacteristic, utf8.encode("rm ${fileListToDelete.first}~"), false);
        } else {
          // We are finished with the sync process because the user does not
          // want to erase files on the receiver
          globalLogger.d("Sync complete without performing erase");
          syncInProgress = false;
          //TODO: NOTE: setState here does not reload file list after sync is finished
        }
      }
      else {
        globalLogger.d("Sync complete!");
        syncInProgress = false;
      }
    }
    else {
      //globalLogger.d("Building main.dart (smart bms? $_showDieBieMS)");
    }

    FileSyncViewerArguments syncStatus = FileSyncViewerArguments(syncInProgress: syncInProgress, fileName: catCurrentFilename, fileBytesReceived: catBytesReceived, fileBytesTotal: catBytesTotal, fileList: fileList);

    return Scaffold(
        // Appbar
        appBar: AppBar(
            title: Text("FreeSK8 (v$freeSK8ApplicationVersion)"),
            // Set the background color of the App Bar
            backgroundColor: serverTCPSocket != null ? Colors.blueAccent : Theme.of(context).primaryColor,
            // Set the bottom property of the Appbar to include a Tab Bar
            //bottom: getTabBar()
        ),
        // Set the TabBar view as the body of the Scaffold
        body: LogConsoleOnShake(
          debugOnly: false,
          dark: true,
          child: Center(
            child: getTabBarView( <Widget>[
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
                unexpectedDisconnect: unexpectedDisconnect,
                delayedTabControllerIndexChange: _delayedTabControllerIndexChange,
              ),
              RealTimeData(
                routeTakenLocations: routeTakenLocations,
                telemetryMap: telemetryMap,
                currentSettings: widget.myUserSettings,
                startStopTelemetryFunc: startStopTelemetryTimer,
                showDieBieMS: _showDieBieMS,
                dieBieMSTelemetry: dieBieMSTelemetry,
                closeDieBieMSFunc: closeDieBieMSFunc,
                changeSmartBMSID: changeSmartBMSIDFunc,
                smartBMSID: smartBMSCANID,
                deviceIsConnected: deviceIsConnected,
              ),
              ESK8Configuration(
                myUserSettings: widget.myUserSettings,
                currentDevice: _connectedDevice,
                showESCProfiles: _showESCProfiles,
                theTXCharacteristic: theTXCharacteristic,
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
                ppmCalibrateReady: _isPPMCalibrationReady,
                escFirmwareVersion: escFirmwareVersion,
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
            ])
          ),
        ),
      bottomNavigationBar: Material(
        color: Theme.of(context).primaryColor,
        child: SafeArea(child:getTabBar()),
      ),
      drawer: getNavDrawer(context),
    );
  }
}
