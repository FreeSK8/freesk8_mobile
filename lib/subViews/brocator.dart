
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/widgets/brocatorMap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:latlong/latlong.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'package:http/http.dart' as http;

class Bro {
  String alias;
  MemoryImage avatar;
  DateTime lastUpdated;
  LatLng position;

  Bro({this.alias, this.avatar, this.lastUpdated, this.position});
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
        'Longitude': position.longitude.toString()
      };

  factory Bro.fromJson(Map<String, dynamic> json) {
    return Bro(
      alias: json['Alias'],
      avatar: MemoryImage(base64Decode(json['Avatar'])),
      lastUpdated: DateTime.parse(json['LastUpdate']),
      position: LatLng(double.parse(json['Latitude']), double.parse(json['Longitude']))
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

  BrocatorArguments(this.boardAlias, this.boardAvatar);
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

  bool broadcastPosition;
  BrocatorArguments myArguments;

  TextEditingController tecServer = TextEditingController();
  String serverURL = "";
  bool serverURLValid = false;

  var geolocator = Geolocator();
  var locationOptions = LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 0);
  static StreamSubscription<Position> positionStream;

  LatLng currentLocation;
  Bro myBrocation = new Bro();
  BroList myBros;

  static Timer dataRequestTimer;

  static MapController _mapController = MapController();

  Future<void> checkLocationPermission() async {
    await Geolocator().checkGeolocationPermissionStatus();
    if (await Geolocator().isLocationServiceEnabled() != true) {
      genericAlert(context, "Location service unavailable", Text('Please enable location services on your mobile device'), "OK");
    }
  }
  Future<void> updateLocation(LatLng data) async {
    currentLocation = data;
    //globalLogger.wtf(data);
  }

  Future<void> loadSettings() async {
    globalLogger.wtf("settings loading");
    final prefs = await SharedPreferences.getInstance();

    myUUID = prefs.getString('brocatorUUID') ?? _uuid.v4().toString();
    broadcastPosition = prefs.getBool('broadcastBrocation') ?? false;
    serverURL = prefs.getString('brocatorServer') ?? "";
    serverURLValid = Uri.tryParse(serverURL).isAbsolute;
  }

  void saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('brocatorUUID', myUUID);
    await prefs.setBool('broadcastBrocation', broadcastPosition);
    await prefs.setString('brocatorServer', serverURL);
  }

  Future<BroList> fetchBrocations() async {
    globalLogger.wtf("Requesting Bros");
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
    globalLogger.wtf("Sending brocation");

    myBrocation.alias = myArguments.boardAlias;
    if (myArguments.boardAvatar != null) {
      myBrocation.avatar = MemoryImage(myArguments.boardAvatar.file.readAsBytesSync(), scale: 0.1);
    } else {
      myBrocation.avatar = MemoryImage((await rootBundle.load('assets/FreeSK8_Mobile.png'))
          .buffer
          .asUint8List(), scale: 0.1);
    }
    
    myBrocation.position = currentLocation;
    myBrocation.lastUpdated = DateTime.now().toUtc();

    final response = await http.post(Uri.parse(Uri.encodeFull("${serverURL}/brocator.php")),
      body: jsonEncode(<String, String>{
        'Avatar': base64Encode(myBrocation.avatar.bytes),
        'UUID' : myUUID,
        'Alias' : myBrocation.alias,
        'Latitude' : myBrocation.position.latitude.toString(),
        'Longitude' : myBrocation.position.longitude.toString(),
      }),
    );
    if (response.statusCode == 200) {
      // Server returned a 200 OK response
      //globalLogger.d("sendBrocation Response: ${response.body}");
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

    setState(() {
      // Update UI
    });
  }

  @override
  void initState() {
    tecServer.addListener(() {
      serverURL = tecServer.text;
      serverURLValid = Uri.tryParse(serverURL).isAbsolute;
      // Save settings when URL is valid
      if (serverURLValid) {
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
    positionStream?.cancel();
    dataRequestTimer?.cancel();

    super.dispose();
  }

  Future<Widget> _buildBody(BuildContext context) async {
    if (broadcastPosition == null) await loadSettings();

    tecServer.text = serverURL;
    tecServer.selection = TextSelection.fromPosition(TextPosition(offset: tecServer.text.length));

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
              //TODO:
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
        Container(
          height: MediaQuery.of(context).size.height * 0.50,
          child: BrocatorMap(
              brocatorMapData: BrocatorMapData(
                  currentPosition: currentLocation,
                  mapMarkers: mapMakers,
                  mapController: _mapController
              )),
        ),
        myBros != null ? Expanded(
          child: ListView.builder(
            itemCount: myBros.brocations.length,
              itemBuilder: (context, i) {
                return GestureDetector(
                  onTap: (){
                    // Center map on selected user
                    _mapController.move(myBros.brocations[i].position, _mapController.zoom);
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                          backgroundImage: myBros.brocations[i].avatar != null ? myBros.brocations[i].avatar : AssetImage('assets/FreeSK8_Mobile.png'),
                          radius: 20,
                          backgroundColor: Colors.white),
                      Spacer(),
                      Text(myBros.brocations[i].alias.toString()),
                      Spacer(),
                      Text("${(DateTime.now().subtract(DateTime.now().timeZoneOffset)).difference(myBros.brocations[i].lastUpdated).inSeconds} seconds"),
                      Spacer(),
                      currentLocation == null ? Container() : Text("${doublePrecision(calculateGPSDistance(currentLocation, myBros.brocations[i].position), 1)}km"),
                    ],
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
