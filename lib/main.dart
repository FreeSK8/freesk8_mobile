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
import 'subViews/vehicleManager.dart';

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

import 'package:url_launcher/url_launcher.dart';

import 'package:signal_strength_indicator/signal_strength_indicator.dart';

import 'components/databaseAssistant.dart';
import 'hardwareSupport/escHelper/serialization/buffers.dart';

const String freeSK8ApplicationVersion = "0.18.2";
const String robogotchiFirmwareExpectedVersion = "0.10.1";

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
        VehicleManager.routeName: (BuildContext context) => VehicleManager(),
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
  final List<ScanResult> bleScanResults = [];

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
  List<LatLng> routeTakenLocations = [];
  
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
  static List<int> _validCANBusDeviceIDs = [];
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
  String applicationDocumentsDirectory;

  @override
  void initState() {
    super.initState();

    print("main initState");

    getApplicationDocumentsDirectory().then((value){
      applicationDocumentsDirectory = value.path;
    });

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
    controller.addListener(() {
      if (syncInProgress && controller.index != controllerViewLogging) {
        globalLogger.wtf("no tab change please");
        controller.index = controller.previousIndex;
      }
    });

    // Setup BLE scan results event listener
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) async {
      setState(() {
        widget.bleScanResults.clear();
        widget.bleScanResults.addAll(results);
      });
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

    // Watching AppLifecycleState for when the application is put in the background/resumed
    WidgetsBinding.instance.addObserver(AutoStopHandler());

    _timerMonitor = new Timer.periodic(Duration(seconds: 1), (Timer t) => _monitorGotchiTimer());

    DeviceInfo.init();
  }

  Future<bool> _isBLEOn(bool alertUser) async {
    if (await widget.flutterBlue.isOn) {
      return Future.value(true);
    } else {
      globalLogger.i("Bluetooth is not turned ON");
      if (alertUser) {
        genericAlert(context, "Bluetooth is OFF", Text("Please enable Bluetooth on your device"), "OK");
      }
      return Future.value(false);
    }
  }

  void _monitorGotchiTimer() {
    if (_gotchiStatusTimer == null && theTXLoggerCharacteristic != null && initMsgSqeuencerCompleted && (controller.index == controllerViewConnection || controller.index == controllerViewLogging) && !syncInProgress) {
      globalLogger.d("_monitorGotchiTimer: Starting gotchiStatusTimer");
      startStopGotchiTimer(false);
    } else if (syncInProgress && !catUnpackingFile) {
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
      //TODO: Testing fix for backgrounded iOS app disconnecting but not showing disconnected state
      //NOTE: Sept 7, 2021: Android platform may experience same issue: https://forum.freesk8.org/t/freesk8-mobile-app-android-ios/327/111
      if (unexpectedDisconnect) {
        setState(() {
          // Just refresh bc on some devices we might display a stale state after being backgrounded for extended period of time
        });
      }
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
          icon: Icon(Icons.format_align_left),
        ),
        Tab(
          icon: Icon(Icons.settings),
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

  bool _scanActive = false;
  Future<void> _handleBLEScanState(bool startScan) async {
    if (_connectedDevice != null) {
      globalLogger.d("_handleBLEScanState: disconnecting");
    }
    else if (startScan == true) {
      globalLogger.d("_handleBLEScanState: startScan was true");
      unexpectedDisconnect = false; // If we start scanning again we are no longer unexpectedly disconnected
      widget.bleScanResults.clear(); // Clear potential previous results
      // Check if BLE is on before scanning
      if (await _isBLEOn(true)) {
        widget.flutterBlue.startScan(withServices: new List<Guid>.from([uartServiceUUID])).catchError((onError){
          // Catch errors from starting scan
          genericAlert(context, "BLE Scan Error", Text("Unable to start scanning: ${onError.toString()}"), "OK");
          globalLogger.e("flutter_blue.startScan threw: ${onError.toString()}");
          return;
        });
      } else {
        startScan = false;
      }
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
        widget.bleScanResults.clear(); //NOTE: clearing list on disconnect so build() does not attempt to pass images of knownDevices that have not yet been loaded
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

      // Reset syncInProgress flags
      syncInProgress = false;
      syncAdvanceProgress = false;
      lsInProgress = false;
      catInProgress = false;
      catUnpackingFile = false;
      catCurrentFilename = "";
      fileList = [];
      fileListToDelete = [];

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
      _delayedTabControllerIndexChange(controllerViewConnection);
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

        initDialogDismissed = false;

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
    List<Widget> containers = [];

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

            ElevatedButton(
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

    for (ScanResult result in widget.bleScanResults) {
      //If there is no name for the device we are going to ignore it
      if (result.device.name == '') continue;

      //If this device is known give it a special row in the list of devices
      if (widget.myUserSettings.isDeviceKnown(result.device.id.toString())) {
        Container element = Container(
            padding: EdgeInsets.all(5.0),
            width: MediaQuery.of(context).size.width / crossAxisCount,
            child: GestureDetector(
              onTap: () async {
                globalLogger.d("Attempting connection to ${result.device.name} (${result.device.id}) with ${result.rssi}dB");
                await _attemptDeviceConnection(result.device);
              },
              child:

              Column(
                children: <Widget>[
                 // Text(device.id.toString()),

                  FutureBuilder<String>(
                      future: UserSettings.getBoardAlias(result.device.id.toString()),
                      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                        return Text(snapshot.data != null ? snapshot.data : "unnamed", textAlign: TextAlign.center,);
                      }),
                  Stack(children: [
                    FutureBuilder<String>(
                        future: UserSettings.getBoardAvatarPath(result.device.id.toString()),
                        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                          return CircleAvatar(
                              backgroundImage: snapshot.data != null ? FileImage(File(snapshot.data)) : AssetImage('assets/FreeSK8_Mobile.png'),
                              radius: 60,
                              backgroundColor: Colors.white);
                        }),
                    Positioned(right: 0, bottom: 0, child: SignalStrengthIndicator.bars(value: result.rssi, minValue: -90, maxValue: -45, barCount: 5, radius: Radius.circular(1.5)),),
                  ],),

                  Text(result.device.name),
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
              globalLogger.d("Attempting connection to ${result.device} with ${result.rssi}dB");
              await _attemptDeviceConnection(result.device);
            },
            child: Column(
              children: <Widget>[
                Stack(children: [
                  Padding(padding: EdgeInsets.only(top:32.0, bottom: 10.0),
                    child: Icon(Icons.device_unknown, size: 75),
                  ),
                  Positioned(right: 0, bottom: 0, child: SignalStrengthIndicator.bars(value: result.rssi, minValue: -90, maxValue: -45, barCount: 5, radius: Radius.circular(1.5),),),
                ]),
                Text(result.device.name == '' ? '(unknown device)' : result.device.name),
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
  static bool catUnpackingFile = false;
  static List<int> catBytesRaw = [];
  static int catBytesReceived = 0;
  static int catBytesTotal = 0;
  static List<FileToSync> fileList = [];
  static List<String> fileListToDelete = [];
  static bool syncEraseOnComplete = true;
  static bool isLoggerLogging = false; //TODO: this is redundant
  static RobogotchiStatus gotchiStatus = new RobogotchiStatus();
  static double connectedVehicleOdometer = 0;
  static double connectedVehicleConsumption = 0;
  static DateTime syncLastACK = DateTime.now();
  static List<ESCFault> escFaults = [];

  // Handler for RideLogging's sync button
  void _handleBLESyncState(bool startSync) async {
    globalLogger.i("_handleBLESyncState: startSync = $startSync");
    if (startSync && !syncInProgress) {
      // Start syncing all files by setting syncInProgress to true and request
      // the file list from the receiver
      setState(() {
        syncLastACK = DateTime.now();
        syncInProgress = true;
        // Prevent the status timer from interrupting this request
        _gotchiStatusTimer?.cancel();
        _gotchiStatusTimer = null;
      });
      // Send syncstart message to the Robogotchi
      if (await sendBLEData(theTXLoggerCharacteristic, utf8.encode("syncstart~"), false)) {
        globalLogger.i("_handleBLESyncState: syncstart command sent");

        // Request the files to begin the process
        if (!await sendBLEData(theTXLoggerCharacteristic, utf8.encode("ls~"), false)) {
          globalLogger.e("_handleBLESyncState: failed to request file list");
        }
      } else {
        globalLogger.e("_handleBLESyncState: syncstart failed to send");
      }
    } else {
      globalLogger.i("_handleBLESyncState: Stopping Sync Process");
      //TODO: Consider setting fileList to [] and advance the sync process so the files get deleted
      setState(() {
        syncInProgress = false;
        syncAdvanceProgress = false;
        lsInProgress = false;
        catInProgress = false;
        catUnpackingFile = false;
        catCurrentFilename = "";
        fileList = [];
        fileListToDelete = [];
      });
      // After stopping the sync on this end, request stop on the Robogotchi
      await sendSyncStop();
    }
  }
  void _handleEraseOnSyncButton(bool eraseOnSync) {
    globalLogger.i("_handleEraseOnSyncButton: eraseOnSync: $eraseOnSync");
    setState(() {
      syncEraseOnComplete = eraseOnSync;
    });
  }
  Future<bool> sendSyncStop() async {
    // Inform the Robogotchi we've completed the sync process
    if (await sendBLEData(theTXLoggerCharacteristic, utf8.encode("syncstop~"), false)) {
      globalLogger.i("_handleBLESyncState: syncstop command sent");
      return Future.value(true);
    } else {
      globalLogger.e("_handleBLESyncState: syncstop failed to send");
      return Future.value(false);
    }
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

  // Compute logged distance and consumption
  void updateComputedVehicleStatistics(bool doSetState) async {
    connectedVehicleOdometer = await DatabaseAssistant.dbGetOdometer(widget.myUserSettings.currentDeviceID, widget.myUserSettings.settings.useGPSData);
    connectedVehicleConsumption = await DatabaseAssistant.dbGetConsumption(widget.myUserSettings.currentDeviceID, widget.myUserSettings.settings.useImperial, widget.myUserSettings.settings.useGPSData);
    if (doSetState) {
      setState(() {});
    }
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
            await sendSyncStop();
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
            //TODO: validate file transmission. We need a proper packet definition and CRC
            // Verify the correct number of bytes were received, retry file if necessary
            if (catBytesReceived != catBytesTotal) {
              globalLogger.e("Concatenate file operation complete but received $catBytesReceived of $catBytesTotal bytes. Retrying $catCurrentFilename");
              // Take the current file and add it to the front of the fileList to be re-attempted
              fileList.insert(0,fileList.first);
              // Advance the sync process after failure
              setState(() {
                catInProgress = false;
                syncAdvanceProgress = true;
              });
              return;
            }

            globalLogger.d("Concatenate file operation complete on $catCurrentFilename with $catBytesReceived bytes");

            // Make sure we aren't processing cat,complete in another async task
            if (catUnpackingFile) {
              globalLogger.e("catUnpackingFile was true before attempting to unpack a file >:[");
              throw Exception("cat,complete called while catUnpackingFile was true");
            }

            // Write raw bytes from cat operation to the filesystem
            await FileManager.writeBytesToLogFile(catBytesRaw);
            catBytesRaw.clear();

            // Save temporary log data to final filename
            // Then generate database statistics
            // Then create database entry
            // Then rebuild state and continue sync process
            catUnpackingFile = true; // Pause the gotchiTimer from NACKing while this expensive task completes
            String savedFilePath = await FileManager.saveLogToDocuments(filename: catCurrentFilename, userSettings: widget.myUserSettings);

            /// Analyze log to generate database statistics
            Map<int, double> wattHoursStartByESC = new Map();
            Map<int, double> wattHoursEndByESC = new Map();
            Map<int, double> wattHoursRegenStartByESC = new Map();
            Map<int, double> wattHoursRegenEndByESC = new Map();
            int escRecordCount = 0;
            int gpsRecordCount = 0;
            double maxCurrentBattery = 0.0;
            double maxCurrentMotor = 0.0;
            double maxSpeedKph = 0.0;
            double maxSpeedGPS;
            double avgMovingSpeed;
            int avgMovingSpeedEntries = 0;
            double avgMovingSpeedGPS;
            int avgMovingSpeedGPSEntries = 0;
            double avgSpeed;
            int avgSpeedEntries = 0;
            double avgSpeedGPS;
            int avgSpeedGPSEntries = 0;
            int firstESCID;
            double distanceStart;
            double distanceEnd;
            double distanceTotal;
            double distanceTotalGPS;
            LatLng gpsPositionPrevious;
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


                  // Track avg speed
                  double speedNow = double.tryParse(entry[4]);
                  avgSpeedGPS ??= 0;
                  avgSpeedGPS += speedNow;
                  ++avgSpeedGPSEntries;

                  // Track avg moving speed (;idle boards won't bring you down;)
                  if (speedNow > 0.0) {
                    avgMovingSpeedGPS ??= 0;
                    avgMovingSpeedGPS += speedNow;
                    ++avgMovingSpeedGPSEntries;
                  }

                  // Track max speed
                  maxSpeedGPS ??= speedNow;
                  if (speedNow > maxSpeedGPS) {
                    maxSpeedGPS = speedNow;
                  }

                  // Compute distance traveled
                  LatLng gpsPositionNow = new LatLng(double.parse(entry[5]), double.parse(entry[6]));
                  gpsPositionPrevious ??= gpsPositionNow;
                  distanceTotalGPS ??= 0;
                  distanceTotalGPS += calculateGPSDistance(gpsPositionNow, gpsPositionPrevious);
                  gpsPositionPrevious = gpsPositionNow;
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
                  // Prepare average speed!
                  avgSpeed ??= 0;
                  avgSpeed += speed;
                  ++avgSpeedEntries;
                  // Prepare average moving speed
                  if (speed > 0.0) {
                    avgMovingSpeed ??= 0;
                    avgMovingSpeed += speed;
                    ++avgMovingSpeedEntries;
                  }
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

                  ++escRecordCount;
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
              globalLogger.e("distanceEnd was null. Distance total could not be computed");
              if (distanceTotalGPS != null) {
                distanceTotal = distanceTotalGPS;
                globalLogger.w("Using GPS distance of $distanceTotalGPS");
              } else {
                distanceTotal = -1.0;
                globalLogger.w("distanceTotal not available from ESC or GPS. Setting to -1.0");
              }
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

            /// Compute average speeds
            if (avgSpeedGPSEntries > 0) {
              avgSpeedGPS /= avgSpeedGPSEntries;
            }
            if (avgMovingSpeedGPSEntries > 0) {
              avgMovingSpeedGPS /= avgMovingSpeedGPSEntries;
            }
            if (avgSpeedEntries > 0) {
              avgSpeed /= avgSpeedEntries;
            }
            if (avgMovingSpeedEntries > 0) {
              avgMovingSpeed /= avgMovingSpeedEntries;
            }
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
                  avgMovingSpeed: avgMovingSpeed != null ? doublePrecision(avgMovingSpeed, 2) : -1.0,
                  avgMovingSpeedGPS: avgMovingSpeedGPS != null ? doublePrecision(avgMovingSpeedGPS, 2) : -1.0,
                  avgSpeed: avgSpeed != null ? doublePrecision(avgSpeed, 2) : -1.0,
                  avgSpeedGPS: avgSpeedGPS != null ? doublePrecision(avgSpeedGPS, 2) : -1.0,
                  maxSpeed: maxSpeedKph,
                  maxSpeedGPS: maxSpeedGPS != null ? doublePrecision(maxSpeedGPS, 2) : -1.0,
                  altitudeMax: maxElevation != null ? maxElevation : -1.0,
                  altitudeMin: minElevation != null ? minElevation : -1.0,
                  maxAmpsBattery: maxCurrentBattery,
                  maxAmpsMotors: maxCurrentMotor,
                  wattHoursTotal: doublePrecision(wattHours, 2),
                  wattHoursRegenTotal: doublePrecision(wattHoursRegen, 2),
                  distance: distanceTotal,
                  distanceGPS: distanceTotalGPS != null ? doublePrecision(distanceTotalGPS, 2) : -1.0,
                  durationSeconds: lastEntryTime.difference(firstEntryTime).inSeconds,
                  faultCount: faultCodeCount,
                  rideName: "",
                  notes: ""
              ));
            }

            /// Advance the sync process after success
            // Resume the gotchiTimer
            syncLastACK = DateTime.now(); // Lie about the last ACK time before unpausing the gotchiTimer
            catUnpackingFile = false; // Un-pause gotchiTimer
            // Once finished add this file to fileListToDelete
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

            updateComputedVehicleStatistics(false);

            ///Save file operation complete
            return;

          } catch (e, stacktrace) {
            globalLogger.e("cat,complete threw an exception: ${e.toString()}");
            globalLogger.e("Stacktrace: ${stacktrace.toString()}");

            // Alert user something went wrong with the parsing
            genericConfirmationDialog(context, TextButton(
              child: Text("Copy / Share"),
              onPressed: () {
                Share.text(catCurrentFilename, "${e.toString()}\n\n$logFileContentsForDebugging}", 'text/plain');
              },
            ), TextButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ), "File processing error", Text("Something unexpected may have happened!\n\nPlease share on Telegram and check the debug log for more information."));

            /// Advance the sync process after failure
            {
              // Resume the gotchiTimer
              syncLastACK = DateTime.now(); // Lie about the last ACK time before unpausing the gotchiTimer
              catUnpackingFile = false; // Un-pause gotchiTimer

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
        globalLogger.d("Starting cat, InProgress($catInProgress), Command: $receiveStr");
        loggerTestBuffer = "";
        catInProgress = true;
        lsInProgress = false;
        catBytesReceived = 0;
        catBytesRaw.clear();
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
          try {
            isLoggerLogging = (values[2] == "1");
            gotchiStatus.isLogging = isLoggerLogging;
            gotchiStatus.faultCount = int.tryParse(values[3]);
            gotchiStatus.faultCode = int.tryParse(values[4]);
            gotchiStatus.percentFree = int.tryParse(values[5]);
            gotchiStatus.fileCount = int.tryParse(values[6]);
            gotchiStatus.gpsFix = int.tryParse(values[7]);
            gotchiStatus.gpsSatellites = int.tryParse(values[8]);
            gotchiStatus.lastPriorityAlertReason = RobogotchiAlertReasons.values[int.tryParse(values[9])];
            gotchiStatus.melodySnoozeSeconds = int.tryParse(values[10]);
          } catch (e) {
            print("Robogotchi status parsing caught an exception: $e");
          }
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
        List<Widget> children = [];
        escFaults.forEach((element) {
          children.add(Text(element.toString()));
          children.add(Text(""));
          shareData += element.toString() + "\n\n";
        });
        //genericAlert(context, "Faults observed", Column(children: children), "OK");
        genericConfirmationDialog(context, TextButton(
          child: Text("Copy / Share"),
          onPressed: () {
            Share.text('Faults observed', shareData, 'text/plain');
          },
        ), TextButton(
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
          if (controller.index == controllerViewRealTime) { //Only re-draw if we are on the real time data tab
            setState(() {
              dieBieMSTelemetry = dieBieMSHelper.processCells(bleHelper.getPayload());
            });
          }
          bleHelper.resetPacket(); //Prepare for next packet
        }
        else if (packetID == COMM_PACKET_ID.COMM_GET_VALUES_SETUP.index) {
          ///Telemetry packet
          telemetryPacket = escHelper.processSetupValues(bleHelper.getPayload());

          // Update map of ESC telemetry
          telemetryMap[telemetryPacket.vesc_id] = telemetryPacket;

          if(controller.index == controllerViewRealTime) { //Only re-draw if we are on the real time data tab
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
            DieBieMSTelemetry parsedTelemetry = dieBieMSHelper.processTelemetry(bleHelper.getPayload(), smartBMSCANID);

            if (parsedTelemetry != null) {
              dieBieMSTelemetry = parsedTelemetry;

              /// Automatically request cell data from DieBieMS
              var byteData = new ByteData(10);
              byteData.setUint8(0, 0x02); // Start of packet
              byteData.setUint8(1, 3); // Packet length
              byteData.setUint8(2, COMM_PACKET_ID.COMM_FORWARD_CAN.index);
              byteData.setUint8(3, smartBMSCANID); //CAN ID
              byteData.setUint8(4, DieBieMSHelper.COMM_GET_BMS_CELLS);
              int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, 3);
              byteData.setUint16(5, checksum);
              byteData.setUint8(7, 0x03); // End of packet

              sendBLEData(theTXCharacteristic, byteData.buffer.asUint8List(), true).then((sendResult){
                if (!sendResult) {
                  globalLogger.w("Smart BMS cell data request failed");
                }
              });
            }
          }

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
              if (controller.index == controllerViewRealTime) startStopTelemetryTimer(
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
              if (controller.index == controllerViewRealTime) startStopTelemetryTimer(
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
              if (controller.index == controllerViewRealTime) {
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
              controller.index = controllerViewConfiguration; // Navigate user to Configuration tab
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

            widget.myUserSettings.settings.wheelDiameterMillimeters = (doublePrecision(escMotorConfiguration.si_wheel_diameter, 3) * 1000).toInt();
            //TODO: Take note of this importance: globalLogger.wtf("wheel diameter mm maths ${(doublePrecision(escMotorConfiguration.si_wheel_diameter, 3) * 1000).toInt()} vs ${(escMotorConfiguration.si_wheel_diameter * 1000).toInt()}");

            widget.myUserSettings.settings.motorPoles = escMotorConfiguration.si_motor_poles;
            widget.myUserSettings.settings.maxERPM = escMotorConfiguration.l_max_erpm;
            widget.myUserSettings.settings.gearRatio = doublePrecision(escMotorConfiguration.si_gear_ratio, 2);

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
              controller.index = controllerViewConfiguration;
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
          if (controller.index == controllerViewRealTime) startStopTelemetryTimer(false); //Resume the telemetry timer

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
          globalLogger.i("ESC::COMM_PRINT: $messageFromESC");
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
      _initMsgSequencer = new Timer.periodic(Duration(milliseconds: 300), (Timer t) => _requestInitMessages());
    }

    // Compute logged distance and consumption
    updateComputedVehicleStatistics(false);

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

  bool initDialogDismissed = false;
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
        theTXCharacteristic.write(simpleVESCRequest(COMM_PACKET_ID.COMM_PING_CAN.index));
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
          // Re-request CAN Devices scan
          theTXCharacteristic.write(simpleVESCRequest(COMM_PACKET_ID.COMM_PING_CAN.index));
          initMsgESCDevicesCANRequested = 1;
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
        genericConfirmationDialog(context, TextButton(
          child: Text("NO"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ), TextButton(
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
        _delayedTabControllerIndexChange(controllerViewConfiguration); // Switch to the configuration tab
      }

      globalLogger.i("_requestInitMessages: initMsgSequencer is complete! Great success!");

      _initMsgSequencer.cancel();
      _initMsgSequencer = null;

      initMsgSqeuencerCompleted = true;
    }
  }
  void _changeConnectedDialogMessage(String message) {
    if (initDialogDismissed) return; // Do nothing if the user has dismissed dialog

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
                          initDialogDismissed = true;
                          Navigator.of(context).pop(); // Remove connection dialog
                        },
                        child: Column(children: [
                          Icon(Icons.bluetooth_searching, size: 80,color: Colors.green),
                          SizedBox(height: 10,),
                          Text("Connected"),
                          Text(message),
                        ]),
                      ),
                    )
                  ],
                  shape: RoundedRectangleBorder (
                      borderRadius: BorderRadius.all(Radius.circular(10))
                  ),
              )
          );
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
            TextButton(
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
            TextButton(
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
            TextButton(
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
            TextButton(
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

    bool menuOptionIsReady({bool isRobogotchiOption}) {
      // Check if we are connected
      if (!isRobogotchiOption && _connectedDevice == null) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("No Connection"),
              content: Text("Oops. Try connecting to your board first."),
            );
          },
        );
        return false;
      } else if (!isRobogotchiOption && !isESCResponding) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("No data"),
              content: Text("There is an active connection but no communication from the ESC. Please check your configuration."),
            );
          },
        );
        return false;
      // Check if we are connected to a Robogotchi
      } else if (isRobogotchiOption && (!_deviceIsRobogotchi || theTXLoggerCharacteristic == null)) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Robogotchi Feature"),
              content: Text("This selection requires an active Robogotchi connection"),
            );
          },
        );
        return false;
      // Check if we are syncing
      } else if (syncInProgress) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Sync in progress"),
              content: Text("This feature is restricted until the sync operation is completed"),
            );
          },
        );
        return false;
      }

      // It's safe to proceed with this menu option
      return true;
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
            globalLogger.d("Smart BMS RealTime Disabled");
            Navigator.pop(context); // Close drawer
          } else if (menuOptionIsReady(isRobogotchiOption: false)) {
            setState(() {
              _showDieBieMS = true;
            });
            _delayedTabControllerIndexChange(controllerViewRealTime);
            globalLogger.d("Smart BMS RealTime Enabled");
            Navigator.pop(context); // Close drawer
          }
        },
      ),

      ListTile(
        leading: Icon(Icons.timer),
        title: Text("Speed Profiles"),
        onTap: () {
          if (menuOptionIsReady(isRobogotchiOption: false)) {
            setState(() {
              _hideAllSubviews();
              // Set the flag to show ESC profiles. Display when MCCONF is returned
              _showESCProfiles = true;
            });

            requestMCCONF();
            Navigator.pop(context); // Close the drawer
          }
        },
      ),

      Divider(height: 5, thickness: 2),
      ListTile(
        leading: Icon(Icons.settings_applications_outlined),
        title: Text("Input Configuration"),
        onTap: () {
          if (menuOptionIsReady(isRobogotchiOption: false)) {
            setState(() {
              _hideAllSubviews();
              _showESCApplicationConfigurator = true;
            });
            requestAPPCONF(null);
            Navigator.of(context).pop();
          }
        },
      ),

      ListTile(
        leading: Icon(Icons.settings_applications),
        title: Text("Motor Configuration"),
        onTap: () async {
          if (menuOptionIsReady(isRobogotchiOption: false)) {
            setState(() {
              _hideAllSubviews();
              _showESCConfigurator = true;
            });
            _delayedTabControllerIndexChange(controllerViewConfiguration);
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
          if (menuOptionIsReady(isRobogotchiOption: true)) {
            sendBLEData(theTXLoggerCharacteristic, utf8.encode("getcfg~"), false);
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
          if (menuOptionIsReady(isRobogotchiOption: true)) {
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
                    TextButton(
                      child: Text('No thank you.'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
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
          }
        },
      ),

      Divider(thickness: 3),
      ListTile(
        leading: Icon(Icons.share_outlined),
        title: Text(serverTCPSocket == null ? "Enable TCP Bridge" : "Disable TCP Bridge"),
        onTap: () {
          // Don't start if not connected
          if (menuOptionIsReady(isRobogotchiOption: false) && serverTCPSocket == null) {
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

      ListTile(
        leading: Icon(Icons.contact_support_outlined),
        title: Text("Help & Support"),
        onTap: () {
          String url = "https://codex.freesk8.org";
          String url2 = "https://forum.freesk8.org";
          String url3 = "https://t.me/FreeSK8Beta";
          String url4 = "https://derelictrobot.com";
          genericAlert(
              context,
              "🆘 Need some assistance?",
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("FreeSK8 Documentation:"),
                  SizedBox(height: 5),
                  GestureDetector(
                    child: Text(url, style: TextStyle(color: Colors.blue),),
                    onTap: () async {
                      if (await canLaunch(url)) {
                        await launch(
                          url,
                          forceSafariVC: false,
                          forceWebView: false,
                        );
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  Text("FreeSK8 Forum:"),
                  SizedBox(height: 5),
                  GestureDetector(
                    child: Text(url2, style: TextStyle(color: Colors.blue)),
                    onTap: () async {
                      if (await canLaunch(url2)) {
                        await launch(
                          url2,
                          forceSafariVC: false,
                          forceWebView: false,
                        );
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  Text("Telegram Support Channel:"),
                  SizedBox(height: 5),
                  GestureDetector(
                    child: Text(url3, style: TextStyle(color: Colors.blue)),
                    onTap: () async {
                      if (await canLaunch(url3)) {
                        await launch(
                          url3,
                          forceSafariVC: false,
                          forceWebView: false,
                        );
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  Text("DRI Shop:"),
                  SizedBox(height: 5),
                  GestureDetector(
                    child: Text(url4, style: TextStyle(color: Colors.blue)),
                    onTap: () async {
                      if (await canLaunch(url4)) {
                        await launch(
                          url4,
                          forceSafariVC: false,
                          forceWebView: false,
                        );
                      }
                    },
                  )
                ],
              ),
              "OK"
          );
        },
      ),
    ];

    return Drawer(
      child: ListView(children: myNavChildren),
    );
  }

  // Called by timer on interval to request Robogotchi Status packet
  void _requestGotchiStatus() {
    if ((controller.index != controllerViewConnection && controller.index != controllerViewLogging ) || syncInProgress || theTXLoggerCharacteristic == null) {
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
    if ((_connectedDevice != null || !this.mounted) && isESCResponding){

      // Do not request telemetry while performing sync
      if (syncInProgress) {
        return;
      }

      //Request telemetry packet; On error increase error counter
      if(_showDieBieMS) {
        /// Request DieBieMS Telemetry
        if(++telemetryRateLimiter > 7) {
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
      if (isESCResponding) {
        globalLogger.d("startStopTelemetryTimer: Starting timer");
        const duration = const Duration(milliseconds:100);
        telemetryTimer?.cancel();
        telemetryTimer = new Timer.periodic(duration, (Timer t) => _requestTelemetry());
      }
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
    globalLogger.d("changeSmartBMSIDFunc: Setting smart BMS CAN FWD ID to $nextID from $smartBMSCANID");
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

  void reloadUserSettings(bool navigateHome) async {
    globalLogger.wtf("reloadUserSettings");
    if (_connectedDevice != null) {
      await widget.myUserSettings.loadSettings(_connectedDevice.id.toString()).then((value){
        globalLogger.i("reloadUserSettings::widget.myUserSettings.loadSettings(): isConnectedDeviceKnown = $value");
        isConnectedDeviceKnown = value;
      });
      if (isConnectedDeviceKnown) {
        cachedBoardAvatar = widget.myUserSettings.settings.boardAvatarPath != null ? MemoryImage(File(
            "${(await getApplicationDocumentsDirectory()).path}${widget.myUserSettings.settings.boardAvatarPath}").readAsBytesSync()) : null;
      } else {
        cachedBoardAvatar = null;
      }
      setState(() {

      });
    }
    //TODO: I don't want to navigate back to home but I can't get the configuration page to show an updated avatar after adoption in vehicle manager
    if (navigateHome) {
      _delayedTabControllerIndexChange(controllerViewConnection);
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
        globalLogger.d("Sync requesting cat of $catCurrentFilename with $catBytesTotal bytes");
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
          sendSyncStop();
          syncInProgress = false;
        }
      }
      else {
        globalLogger.d("Sync complete!");
        sendSyncStop();
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
            title: Row(children: [
              Text("FreeSK8 (v$freeSK8ApplicationVersion)"),
              syncInProgress ? Icon(Icons.sync) : Container()
            ],),
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
                connectedVehicleOdometer: connectedVehicleOdometer,
                connectedVehicleConsumption: connectedVehicleConsumption,
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
                updateComputedVehicleStatistics: updateComputedVehicleStatistics,
                applicationDocumentsDirectory: applicationDocumentsDirectory,
                reloadUserSettings: reloadUserSettings,
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
