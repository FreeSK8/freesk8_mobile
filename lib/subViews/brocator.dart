
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';
import 'package:freesk8_mobile/widgets/brocatorMap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:latlong/latlong.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:http/http.dart' as http;

import 'package:image/image.dart' as Im;

class Bro {
  String alias;
  MemoryImage avatar;
  DateTime lastUpdated;
  LatLng position;
  double batteryVoltage;
  int batteryPercentage;
  double distanceTraveled;

  Bro({this.alias, this.avatar, this.lastUpdated, this.position, this.batteryVoltage, this.batteryPercentage, this.distanceTraveled});
  @override
  String toString(){
    return jsonEncode(this.toJson());
  }

  Map<String, dynamic> toJson() =>
      {
        'Alias' : alias,
        'Avatar': avatar == null ? '' : base64Encode(avatar.bytes),
        'LastUpdate': lastUpdated.toIso8601String().substring(0,19),
        'Latitude': position.latitude.toString(),
        'Longitude': position.longitude.toString(),
        'BatteryVoltage' : batteryVoltage,
        'BatteryPercentage' : batteryPercentage,
        'DistanceTraveled' : distanceTraveled,
      };

  factory Bro.fromJson(Map<String, dynamic> json) {
    //globalLogger.d("${base64Decode(json['Avatar']).length} bytes for ${json['Alias']}");
    return Bro(
      alias: json['Alias'],
      avatar: MemoryImage(base64Decode(json['Avatar'])),
      lastUpdated: DateTime.parse(json['LastUpdate']),
      position: LatLng(double.parse(json['Latitude']), double.parse(json['Longitude'])),
      batteryVoltage: double.parse(json['BatteryVoltage']),
      batteryPercentage: int.parse(json['BatteryPercentage']),
      distanceTraveled: double.parse(json['DistanceTraveled']),
    );
  }
}

class BroList {
  final List<Bro> brocations;

  BroList({@required this.brocations});
  
  factory BroList.fromJson(List<dynamic> json) {
    List<Bro> bros = [];
    json.forEach((element) {
      bros.add(Bro.fromJson(element));
    });

    return BroList(brocations: bros);
  }

}

class BrocatorArguments {
  final String boardAlias;
  final FileImage boardAvatar;
  final Stream telemetryStream;
  final BluetoothCharacteristic theTXCharacteristic;

  BrocatorArguments(this.boardAlias, this.boardAvatar, this.telemetryStream, this.theTXCharacteristic);
}

class Brocator extends StatefulWidget {
  @override
  BrocatorState createState() => BrocatorState();

  static const String routeName = "/brocator";
}

class BrocatorState extends State<Brocator> {
  bool changesMade = false; //TODO: remove if unused
  String myUUID;
  Uuid _uuid = new Uuid();

  bool _showSettings = false;
  bool broadcastPosition;
  BrocatorArguments myArguments;

  TextEditingController tecServer = TextEditingController();
  String serverURL = "";
  bool serverURLValid = false;
  TextEditingController tecAlias = TextEditingController();
  String offlineAlias = "No Vehicle";

  var geolocator = Geolocator();
  var locationOptions = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 0);
  static StreamSubscription<Position> positionStream;

  LatLng currentLocation;
  Bro myBrocation = new Bro();
  BroList myBros;
  bool includeAvatar = true;

  static Timer dataRequestTimer;

  MapController _mapController = MapController();

  static StreamSubscription<ESCTelemetry> streamSubscription;
  BluetoothCharacteristic theTXCharacteristic;

  static ESCTelemetry myTelemetry = new ESCTelemetry();

  Future<void> checkLocationPermission() async {
    await Geolocator().checkGeolocationPermissionStatus();
    if (await Geolocator().isLocationServiceEnabled() != true) {
      genericAlert(context, "Location service unavailable", Text('Please enable location services on your mobile device'), "OK");
    }
  }
  Future<void> updateLocation(LatLng data) async {
    if (currentLocation == null) {
      setState(() {
        currentLocation = data;
      });
    } else {
      currentLocation = data;
    }
    //globalLogger.wtf(data);
  }

  Future<void> loadSettings() async {
    globalLogger.wtf("loading settings");
    final prefs = await SharedPreferences.getInstance();

    myUUID = prefs.getString('brocatorUUID') ?? _uuid.v4().toString();
    broadcastPosition = prefs.getBool('broadcastBrocation') ?? false;
    serverURL = prefs.getString('brocatorServer') ?? "";
    serverURLValid = Uri.tryParse(serverURL).isAbsolute;
    offlineAlias = prefs.getString('brocatorAlias') ?? offlineAlias;
  }

  void saveSettings() async {
    globalLogger.wtf("saving settings");
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('brocatorUUID', myUUID);
    await prefs.setBool('broadcastBrocation', broadcastPosition);
    await prefs.setString('brocatorServer', serverURL);
    await prefs.setString('brocatorAlias', offlineAlias);
  }

  Future<BroList> fetchBrocations() async {
    //globalLogger.wtf("Requesting Bros");
    final response = await http
        .get(Uri.parse("${serverURL}/brocator.php"));

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      return BroList.fromJson(jsonDecode(response.body));
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to fetchBrocations');
    }
  }

  Future<void> sendBrocation() async {
    //globalLogger.wtf("Sending brocation");

    myBrocation.alias = myArguments.boardAlias == null ? offlineAlias : myArguments.boardAlias;
    if (myArguments.boardAvatar != null && includeAvatar) {
      // Resize the current avatar to reduce bandwidth
      Im.Image image = Im.decodeImage(
          myArguments.boardAvatar.file.readAsBytesSync());
      Im.Image smallerImage = Im.copyResize(image,
          width: 120); // choose the size here, it will maintain aspect ratio

      myBrocation.avatar =
          MemoryImage(Im.encodeJpg(smallerImage, quality: 85));

    } else if (includeAvatar){
      // Resize the default avatar to reduce bandwidth
      Im.Image image = Im.decodeImage(
          (await rootBundle.load('assets/FreeSK8_Mobile.png'))
              .buffer
              .asUint8List());
      Im.Image smallerImage = Im.copyResize(image,
          width: 120); // choose the size here, it will maintain aspect ratio

      myBrocation.avatar =
          MemoryImage(Im.encodeJpg(smallerImage, quality: 85));
    }
    
    myBrocation.position = currentLocation;
    myBrocation.lastUpdated = DateTime.now().toUtc();

    final response = await http.post(Uri.parse(Uri.encodeFull("${serverURL}/brocator.php")),
      body: includeAvatar ? jsonEncode(<String, dynamic>{
        'Avatar': base64Encode(myBrocation.avatar.bytes),
        'UUID' : myUUID,
        'Alias' : myBrocation.alias,
        'Latitude' : myBrocation.position.latitude,
        'Longitude' : myBrocation.position.longitude,
        'BatteryVoltage' : myTelemetry.v_in,
        'BatteryPercentage' : myTelemetry.battery_level == null ? 0 : myTelemetry.battery_level * 100.toInt(),
        'DistanceTraveled' : myTelemetry.tachometer_abs / 1000.0,
      }) : jsonEncode(<String, dynamic>{
        'UUID' : myUUID,
        'Alias' : myBrocation.alias,
        'Latitude' : myBrocation.position.latitude,
        'Longitude' : myBrocation.position.longitude,
        'BatteryVoltage' : myTelemetry.v_in,
        'BatteryPercentage' : myTelemetry.battery_level == null ? 0 : myTelemetry.battery_level * 100.toInt(),
        'DistanceTraveled' : myTelemetry.tachometer_abs / 1000.0,
      }),
    );
    if (response.statusCode == 200) {
      // Server returned a 200 OK response
      includeAvatar = false; // Only send the vehicle avatar once to reduce bandwidth
     // globalLogger.d("sendBrocation Response: ${response.body}");
    } else {
      throw Exception('Failed to sendBrocation');
    }

  }

  Future<void> performWebRequests() async {
    if (!serverURLValid) {
      return;
    }

    if (broadcastPosition) {
      sendBrocation();
    }

    try {
      myBros = await fetchBrocations();
    } catch (e) {
      globalLogger.e("fetchBrocations failed: $e");
    }

    // Only update the UI if the keyboard isn't open
    if (MediaQuery.of(context).viewInsets.bottom == 0) {
      setState(() {
        // Update UI
      });
    }

    if (theTXCharacteristic != null) {
      globalLogger.wtf("Brocator Telemetry Requested");
      /// Request ESC Telemetry
      Uint8List packet = simpleVESCRequest(COMM_PACKET_ID.COMM_GET_VALUES_SETUP.index);

      // Request COMM_GET_VALUES_SETUP from the ESC
      if (!await sendBLEData(theTXCharacteristic, packet, true)) {
        globalLogger.e("_requestTelemetry() failed");
      }
    }
  }

  void showPopup(Bro element) {
    Duration lastUpdated = (DateTime.now().subtract(DateTime.now().timeZoneOffset)).difference(element.lastUpdated);
    String lastUpdatedString = "";
    if (lastUpdated.inSeconds < 120) {
      lastUpdatedString = "${lastUpdated.inSeconds} second${lastUpdated.inSeconds == 1 ? "": "s"}";
    } else if (lastUpdated.inMinutes < 60) {
      lastUpdatedString = "${lastUpdated.inMinutes} minute${lastUpdated.inMinutes == 1 ? "": "s"}";
    } else {
      lastUpdatedString = "${lastUpdated.inHours} hour${lastUpdated.inHours == 1 ? "": "s"}";
    }

    Widget alertBody = Column(

      children: [
        Text(element.alias),
        Icon(Icons.watch_outlined),
        Text("Last Updated $lastUpdatedString ago"),
        Icon(Icons.location_on_outlined),
        Text("Seen ${doublePrecision(calculateGPSDistance(currentLocation, element.position), 1)}km from your location"),
        Icon(Icons.stacked_bar_chart),
        Text("Vehicle Battery was ${element.batteryPercentage}% @ ${element.batteryVoltage}V"),
        Text("Vehicle traveled ${element.distanceTraveled}km"),
      ],
    );
    genericAlert(context, "Quick Inspection", alertBody, "OK");
  }

  @override
  void initState() {
    myTelemetry = new ESCTelemetry();

    tecServer.addListener(() {
      if (tecServer.text != serverURL) {
        serverURL = tecServer.text;
        serverURLValid = Uri.tryParse(serverURL).isAbsolute;
        // Save settings when URL is valid
        if (serverURLValid) {
          saveSettings();
          includeAvatar = true; // Include avatar on server change
        }
      }
    });

    tecAlias.addListener(() {
      if (tecAlias.text != offlineAlias) {
        offlineAlias = tecAlias.text;
        saveSettings();
      }
    });

    checkLocationPermission();
    positionStream = geolocator.getPositionStream(locationOptions).listen(
            (Position position) {
          if(position != null) {
            updateLocation(new LatLng(position.latitude, position.longitude));
          }
        });

    dataRequestTimer = new Timer.periodic(Duration(seconds: 5), (Timer t) => performWebRequests());
    super.initState();
  }

  @override
  void dispose() {
    tecServer?.dispose();
    tecAlias?.dispose();
    positionStream?.cancel();
    dataRequestTimer?.cancel();
    dataRequestTimer = null;
    streamSubscription?.cancel();
    streamSubscription = null;

    super.dispose();
  }

  Future<Widget> _buildBody(BuildContext context) async {
    if (broadcastPosition == null) await loadSettings();

    tecServer.text = serverURL;
    tecServer.selection = TextSelection.fromPosition(TextPosition(offset: tecServer.text.length));

    tecAlias.text = offlineAlias;
    tecAlias.selection = TextSelection.fromPosition(TextPosition(offset: tecAlias.text.length));

    List<Marker> mapMakers = [];
    if (myBros != null) myBros.brocations.forEach((element) {
      mapMakers.add(new Marker(
        width: 50.0,
        height: 50.0,
        point: element.position,
        builder: (ctx) =>
        new Container(
          margin: EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: GestureDetector(
            onTap: (){
              showPopup(element);
            },
            child: CircleAvatar(
                backgroundImage: element.avatar != null ? element.avatar : AssetImage('assets/FreeSK8_Mobile.png'),
                radius: 100,
                backgroundColor: Colors.white),
          ),
        ),
      ));
    });

    Widget bodyWidget = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExpansionPanelList(
            elevation: 0,
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                print(_showSettings);
                _showSettings = !_showSettings;
              });
            },
            children: [
              ExpansionPanel(
                  isExpanded: _showSettings,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  headerBuilder: (context, isOpen) {
                    return Row(children: [
                      SizedBox(width: 10),
                      Icon(Icons.settings),
                      Text("Settings")
                    ],);
                  },
                  body: Column(
                    children: [
                      SwitchListTile(
                        title: Text("Share my brocation with everyone"),
                        value: broadcastPosition,
                        onChanged: (bool newValue) {
                          setState((){
                            broadcastPosition = newValue;
                          });
                          saveSettings();
                        },
                        secondary: Icon(broadcastPosition ? Icons.public : Icons.public_off),
                      ),
                      TextField(
                          controller: tecServer,
                          decoration: new InputDecoration(labelText: "Server URL"),
                          keyboardType: TextInputType.url
                      ),
                      TextField(
                        controller: tecAlias,
                        decoration: new InputDecoration(labelText: "Username"),
                        keyboardType: TextInputType.text,
                        maxLength: 13,
                      ),
                    ],
                  )
              )
            ]
        ),

        Container(
          height: MediaQuery.of(context).size.height * 0.50,
          child: currentLocation != null ? BrocatorMap(
              brocatorMapData: BrocatorMapData(
                  currentPosition: currentLocation,
                  mapMarkers: mapMakers,
                  mapController: _mapController
              )) : Text("Awaiting location"),
        ),
        Row(
          children: [
            Container(width: 40),
            Spacer(),
            Container(
              width: MediaQuery.of(context).size.width * 0.25,
              child: Text("Name", textAlign: TextAlign.center),
            ),
            Spacer(),
            Container(
              width: MediaQuery.of(context).size.width * 0.25,
              child: Text("Last Updated", textAlign: TextAlign.center),
            ),

            Spacer(),
            Container(
              width: MediaQuery.of(context).size.width * 0.25,
              child: Text("Distance", textAlign: TextAlign.center,),
            ),

          ],
        ),
        myBros != null ? Expanded(
          child: ListView.builder(
            itemCount: myBros.brocations.length,
              itemBuilder: (context, i) {
              Color colorCellVoltage = multiColorLerp(Colors.red, Colors.yellow, Colors.green, myBros.brocations[i].batteryPercentage / 100.0);
              Duration lastUpdated = (DateTime.now().subtract(DateTime.now().timeZoneOffset)).difference(myBros.brocations[i].lastUpdated);
              String lastUpdatedString = "";
              if (lastUpdated.inSeconds < 120) {
                lastUpdatedString = "${lastUpdated.inSeconds} second${lastUpdated.inSeconds == 1 ? "": "s"}";
              } else if (lastUpdated.inMinutes < 60) {
                lastUpdatedString = "${lastUpdated.inMinutes} minute${lastUpdated.inMinutes == 1 ? "": "s"}";
              } else {
                lastUpdatedString = "${lastUpdated.inHours} hour${lastUpdated.inHours == 1 ? "": "s"}";
              }
              return Container(
                height: 50,
                padding: EdgeInsets.only(bottom: 5),
                child: GestureDetector(
                  // Center view and increase zoom
                  onTap: () {
                    // Increase map zoom level if we are already centered on this user
                    double mapZoom = _mapController.zoom;
                    if (_mapController.center == myBros.brocations[i].position && _mapController.zoom < 18) {
                      mapZoom += 2;
                      globalLogger.d("Increasing zoom $mapZoom");
                    }
                    // Center map and set zoom
                    _mapController.move(myBros.brocations[i].position, mapZoom);
                  },
                  // Center view and show telemetry popup
                  onLongPress: () {
                    _mapController.move(myBros.brocations[i].position, _mapController.zoom);
                    showPopup(myBros.brocations[i]);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: Theme.of(context).dialogBackgroundColor,
                        borderRadius: BorderRadius.circular(2),

                        gradient: myBros.brocations[i].batteryPercentage == 0 ? null :  LinearGradient(
                          tileMode: TileMode.repeated,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [0.0, 0.85, 1.0],
                          colors: [
                            colorCellVoltage,
                            Theme.of(context).dialogBackgroundColor,
                            Theme.of(context).dialogBackgroundColor,
                          ],
                        )
                    ),

                    child: Row(
                      children: [
                        CircleAvatar(
                            backgroundImage: myBros.brocations[i].avatar != null ? myBros.brocations[i].avatar : AssetImage('assets/FreeSK8_Mobile.png'),
                            radius: 20,
                            backgroundColor: Colors.white),
                        Spacer(),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.25,
                          child: Text(myBros.brocations[i].alias.toString(), textAlign: TextAlign.left,),
                        ),
                        Spacer(),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.25,
                          child: Text(lastUpdatedString),
                        ),

                        Spacer(),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.25,
                          child: currentLocation == null ? Container() : Text("${doublePrecision(calculateGPSDistance(currentLocation, myBros.brocations[i].position), 1)}km", textAlign: TextAlign.right,),
                        ),

                      ],
                    ),
                  ),
                ),
              );
            })
        ) : Text("No Data From Server"),
      ],
    );

    return bodyWidget;
  }

  @override
  Widget build(BuildContext context) {
    print("Building brocator");

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No Arguments"));
    }

    if(streamSubscription == null) {
      streamSubscription = myArguments.telemetryStream.listen((value) {
        globalLogger.wtf("Brocator Telemetry Received");
        myTelemetry = value;
      });
    }

    if (theTXCharacteristic == null) {
      theTXCharacteristic = myArguments.theTXCharacteristic;
    }

    return new WillPopScope(
      onWillPop: () async => false,
      child: new Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon( Icons.people,
              size: 35.0,
              color: Colors.blue,
            ),
            SizedBox(width: 3),
            Text("Brocator"),
          ],),
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(changesMade),
          ),
        ),
        body: FutureBuilder<Widget>(
            future: _buildBody(context),
            builder: (context, AsyncSnapshot<Widget> snapshot) {
              if (snapshot.hasData) {
                return snapshot.data;
              } else {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                  Text("Loading...."),
                  SizedBox(height: 10),
                  Center(child: SpinKitRipple(color: Colors.white,)),
                  Text("Please wait 🙏"),
                ],);
              }
            }
        ),
      ),
    );
  }
}
