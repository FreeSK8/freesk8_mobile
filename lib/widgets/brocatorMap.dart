import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  MapController mapController = MapController();
  LatLng privacyZone;
  double privacyZoneRadius;
}

class BrocatorMap extends StatefulWidget {
  BrocatorMap({this.brocatorMapData});
  final BrocatorMapData brocatorMapData;
  BrocatorMapState createState() => BrocatorMapState();

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

    List<Widget> mapChildren = [];
    mapChildren.add(TileLayer(
      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      subdomains: const ['a', 'b', 'c'],
    ));

    if (widget.brocatorMapData.privacyZone != null) {
      mapChildren.add(CircleLayer(
        circles: [
          CircleMarker(
            point: widget.brocatorMapData.privacyZone,
            color: Colors.blue.withOpacity(0.3),
            borderStrokeWidth: 3.0,
            borderColor: Colors.blue,
            useRadiusInMeter: true,
            radius: widget.brocatorMapData.privacyZoneRadius * 1000,
          ),
        ],
      ));
    }

    //NOTE: If the markers aren't last in the children array their onTap events will not work
    mapChildren.add(MarkerLayer(
      markers: widget.brocatorMapData.mapMakers,
    ));

    myMap = FlutterMap(
      mapController: widget.brocatorMapData.mapController,
      options: MapOptions(
        initialCenter: widget.brocatorMapData.currentPosition,
        initialZoom: 13.0,
      ),
      children: mapChildren,
    );

    return myMap;
  }
}
