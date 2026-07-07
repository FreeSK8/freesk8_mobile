import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:rxdart/rxdart.dart';

class FlutterMapWidget extends StatefulWidget {
  FlutterMapWidget({this.routeTakenLocations});
  final List<LatLng>? routeTakenLocations;
  FlutterMapWidgetState createState() => FlutterMapWidgetState();

  static const String routeName = "/fluttermap";
}

class FlutterMapWidgetState extends State<FlutterMapWidget> {
  var eventObservable = PublishSubject();

  @override
  void dispose() {
    super.dispose();
    eventObservable.close();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: flutterMapWidget");

    if (widget.routeTakenLocations!.length == 0)
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

    return FlutterMap(
      options: MapOptions(
        initialCenter: widget.routeTakenLocations!.last,
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: widget.routeTakenLocations!,
              strokeWidth: 3,
              color: Colors.red,
              pattern: const StrokePattern.dotted(),
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 160.0,
              height: 160.0,
              point: widget.routeTakenLocations!.first,
              child: Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 80),
                child: Image(image: AssetImage("assets/map_start.png")),
              ),
            ),
            Marker(
              width: 120.0,
              height: 120.0,
              point: widget.routeTakenLocations!.last,
              child: Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 60),
                child: Image(image: AssetImage("assets/map_position.png")),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
