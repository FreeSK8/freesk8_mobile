import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_nordic_dfu/flutter_nordic_dfu.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:freesk8_mobile/globalUtilities.dart';

class RobogotchiDFU extends StatefulWidget {
  @override
  RobogotchiDFUState createState() => RobogotchiDFUState();

  static const String routeName = "/dfumode";
}

class RobogotchiDFUState extends State<RobogotchiDFU> {
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult> scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  bool dfuRunning = false;

  String _deviceAddress;
  int _percent;
  double _speed;
  double _avgSpeed;
  int _currentPart;
  int _partsTotal;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    scanSubscription = null;

    flutterBlue.stopScan();

    super.dispose();
  }

  Future<void> doDfu(String deviceId) async {
    stopScan();
    dfuRunning = true;
    try {
      var s = await FlutterNordicDfu.startDfu(
        deviceId,
        'assets/firmware/Robogotchi_0.7.2beta.zip',
        fileInAsset: true,
        progressListener:
        DefaultDfuProgressListenerAdapter(onProgressChangedHandle: (
            deviceAddress,
            percent,
            speed,
            avgSpeed,
            currentPart,
            partsTotal,
            ) {
          print('deviceAddress: $deviceAddress, percent: $percent');
          setState(() {
            _deviceAddress = deviceAddress;
            _percent = percent;
            _speed = doublePrecision(speed, 1);
            _avgSpeed = doublePrecision(avgSpeed, 1);
            _currentPart = currentPart;
            _partsTotal = partsTotal;
          });
        }),
      );
      print(s);
      dfuRunning = false;
    } catch (e) {
      dfuRunning = false;
      print(e.toString());
    }
  }

  void startScan() {
    scanSubscription?.cancel();
    flutterBlue.stopScan();
    setState(() {
      scanResults.clear();
      scanSubscription = flutterBlue.scan().listen(
            (scanResult) {
          if (scanResults.firstWhere(
                  (ele) => ele.device.id == scanResult.device.id,
              orElse: () => null) !=
              null) {
            return;
          }
          if (scanResult.device.name.startsWith("FreeSK8")) {
            setState(() {
              /// add result to results if not added
              scanResults.add(scanResult);
            });
          }
        },
      );
    });
  }

  void stopScan() {
    scanSubscription?.cancel();
    scanSubscription = null;
    setState(() => scanSubscription = null);
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = scanSubscription != null;
    final hasDevice = scanResults.length > 0;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Robogotchi Update'),
          actions: <Widget>[
            isScanning
                ? IconButton(
              icon: Icon(Icons.search_off),
              onPressed: dfuRunning ? null : stopScan,
            )
                : IconButton(
              icon: Icon(Icons.search),
              onPressed: dfuRunning ? null : startScan,
            )
          ],
        ),
        body: !hasDevice ? const Center( child: const Text('No device')) :
        Column(children: [
          SizedBox(height:10),
          Image(image: AssetImage("assets/robogotchi_render.png"),height: 150),

          Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemBuilder: _deviceItemBuilder,
                separatorBuilder: (context, index) => const SizedBox(height: 5),
                itemCount: scanResults.length,
              ),
          ),
          SizedBox(height: 100,child: Column(children: [
            Text("Connected to $_deviceAddress"),
            Text("Part $_currentPart / $_partsTotal Speed $_avgSpeed Percent $_percent")
          ],))

        ]
        )
      );
  }

  Widget _deviceItemBuilder(BuildContext context, int index) {
    var result = scanResults[index];

    return DeviceItem(
      scanResult: result,
      onPress: dfuRunning
          ? null
          : () async {
        await this.doDfu(result.device.id.id);
      },
    );
  }
}


class DeviceItem extends StatelessWidget {
  final ScanResult scanResult;

  final VoidCallback onPress;

  DeviceItem({this.scanResult, this.onPress});

  @override
  Widget build(BuildContext context) {
    var name = "Unknown";
    if (scanResult.device.name != null && scanResult.device.name.length > 0) {
      name = scanResult.device.name;
    }
    var inDFUMode = scanResult.device.name == "FreeSK8-DFU";
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: <Widget>[
            Icon(Icons.bluetooth),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name),
                  Text(scanResult.device.id.id),
                  Text("RSSI: ${scanResult.rssi}"),
                ],
              ),
            ),
            FlatButton(onPressed: inDFUMode ? onPress : null, child: Text(inDFUMode ? "Start Update" : "Not Ready"))
          ],
        ),
      ),
    );
  }
}
