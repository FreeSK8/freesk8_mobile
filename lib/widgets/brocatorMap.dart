import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

import 'package:rxdart/rxdart.dart';

class BrocatorMapData {
  BrocatorMapData({LatLng currentPosition, List<Marker> mapMarkers, MapController mapController}) {
    this.mapMakers = mapMarkers;
    this.currentPosition = currentPosition;
    this.mapController = mapController;
  }
  LatLng currentPosition;
  List<Marker> mapMakers = [];
  MapController mapController = new MapController();
}

class BrocatorMap extends StatefulWidget {
  BrocatorMap({this.brocatorMapData});
  final BrocatorMapData brocatorMapData;
  BrocatorMapState createState() => new BrocatorMapState();

  static const String routeName = "/brocatormap";
}

class BrocatorMapState extends State<BrocatorMap> {

  static FlutterMap myMap;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: brocatorMap");

    myMap = FlutterMap(
      mapController: widget.brocatorMapData.mapController,
      options: new MapOptions(
        center: widget.brocatorMapData.currentPosition,
        zoom: 13.0,
      ),
      layers: [
        new TileLayerOptions(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: ['a', 'b', 'c']
        ),
        new MarkerLayerOptions(
          markers: widget.brocatorMapData.mapMakers,
        ),
      ],
    );

    return myMap;
  }
}