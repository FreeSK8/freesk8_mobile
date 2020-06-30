import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

import 'package:background_locator/location_dto.dart';


import 'package:rxdart/rxdart.dart';

class FlutterMapWidget extends StatefulWidget {
  FlutterMapWidget({this.routeTakenLocations});
  final List<LocationDto> routeTakenLocations;
  FlutterMapWidgetState createState() => new FlutterMapWidgetState();

  static const String routeName = "/fluttermap";
}

class FlutterMapWidgetState extends State<FlutterMapWidget> {
  var eventObservable = new PublishSubject();

  @override
  void dispose() {
    super.dispose();
    eventObservable.close();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: flutterMapWidget");

    if (widget.routeTakenLocations.length == 0)
    {
      return Column(
        children: <Widget>[
          SizedBox(height:100),
          Icon(Icons.broken_image, size: 80,),
          Text("No location available O_o"),
          Text("How embarrassing, this was not supposed to happen."),
          Text("Unless you denied me permission of course"),
        ],
      );
    }
    eventObservable.add(widget.routeTakenLocations);

    //Create polyline

    List<LatLng> routePoints = new List<LatLng>();
    for (int i=0; i<widget.routeTakenLocations.length; ++i) {
      routePoints.add(new LatLng(widget.routeTakenLocations[i].latitude, widget.routeTakenLocations[i].longitude));
    }
    Polyline routePolyLine = new Polyline(points: routePoints, strokeWidth: 3, color: Colors.red);

    Marker startPosition = Marker(
      width: 160.0,
      height: 160.0,
      point: new LatLng(widget.routeTakenLocations.first.latitude, widget.routeTakenLocations.first.longitude),
      builder: (ctx) =>
      new Container(
        margin: EdgeInsets.fromLTRB(0, 0, 0, 80),
        child: new Image(image: AssetImage("assets/home_map_marker.png")),
      ),
    );

    return FlutterMap(
      options: new MapOptions(
        center: new LatLng(widget.routeTakenLocations.last.latitude, widget.routeTakenLocations.last.longitude),
        zoom: 13.0,
      ),
      layers: [
        new TileLayerOptions(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c']
        ),
        new MarkerLayerOptions(
          markers: [
            startPosition,
            new Marker(
              width: 160.0,
              height: 160.0,
              point: new LatLng(widget.routeTakenLocations.last.latitude, widget.routeTakenLocations.last.longitude),
              builder: (ctx) =>
              new Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 80),
                child: new Image(image: AssetImage("assets/skating_pin.png")),
              ),
            ),
          ],
        ),
        new PolylineLayerOptions(
          polylines: [routePolyLine]
        )
      ],
    );
  }
}