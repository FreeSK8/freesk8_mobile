import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';

import 'package:rxdart/rxdart.dart';

class BrocatorMapData {
  BrocatorMapData(
      {
        LatLng currentPosition,
        List<Marker> mapMarkers,
        MapController mapController,
        LatLng privacyZone,
        double privacyZoneRadius,
      }) {
    this.mapMakers = mapMarkers;
    this.currentPosition = currentPosition;
    this.mapController = mapController;
    this.privacyZone = privacyZone;
    this.privacyZoneRadius = privacyZoneRadius;
  }
  LatLng currentPosition;
  List<Marker> mapMakers = [];
  MapController mapController = new MapController();
  LatLng privacyZone;
  double privacyZoneRadius;
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

    List<LayerOptions> mapLayers = [];
    mapLayers.add(new TileLayerOptions(
        urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        subdomains: ['a', 'b', 'c']
    ));

    if (widget.brocatorMapData.privacyZone != null) {
      mapLayers.add(new CircleLayerOptions(
          circles: [
            CircleMarker( //radius marker
                point: widget.brocatorMapData.privacyZone,
                color: Colors.blue.withOpacity(0.3),
                borderStrokeWidth: 3.0,
                borderColor: Colors.blue,
                useRadiusInMeter: true,
                radius: widget.brocatorMapData.privacyZoneRadius * 1000 //kilometers to meters
            )
          ]
      ));
    }

    //NOTE: If the markers aren't last in the mapLayers array their onTap events will not work
    mapLayers.add(new MarkerLayerOptions(
      markers: widget.brocatorMapData.mapMakers,
    ));

    myMap = FlutterMap(
      mapController: widget.brocatorMapData.mapController,
      options: new MapOptions(
        center: widget.brocatorMapData.currentPosition,
        zoom: 13.0,
      ),
      layers: mapLayers,
    );

    return myMap;
  }
}