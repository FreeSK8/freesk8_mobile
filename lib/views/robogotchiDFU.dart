import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_nordic_dfu/flutter_nordic_dfu.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:freesk8_mobile/globalUtilities.dart';

const String updateFileName = "Robogotchi_0.7.3"; //TODO: NOTE: Must match that of /assets/firmware/<*>.zip

class RobogotchiDFU extends StatefulWidget {
  @override
  RobogotchiDFUState createState() => RobogotchiDFUState();

  static const String routeName = "/dfumode";
}

class RobogotchiDFUState extends State<RobogotchiDFU> with SingleTickerProviderStateMixin {
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult> scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  bool dfuRunning = false;

  String _deviceAddress;
  int _percent = 0;
  double _speed;
  double _avgSpeed;
  int _currentPart;
  int _partsTotal;

  AnimationController _animationController;

  @override
  void initState() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );
    super.initState();
    startScan();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    scanSubscription?.cancel();
    scanSubscription = null;

    flutterBlue.stopScan();

    super.dispose();
  }

  Future<void> doDfu(String deviceId) async {
    stopScan();
    setState(() {
      _percent = 0;
      dfuRunning = true;
    });

    // Attempt DFU process 3 times before giving up
    int failCount = 0;
    while(dfuRunning) {
      try {
        var result = await FlutterNordicDfu.startDfu(
          deviceId,
          'assets/firmware/$updateFileName.zip',
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
            if (_percent == 100) {
              showCompletedDialog();
            }
          }),
        );
        print("DFU Operation Completed. ($result)");
        dfuRunning = false;
      } catch (e) {
        //NOTE: Sometimes we are throwing PlatformException(DFU_Failed, Device address: *****, null, null)
        //TODO: Consider checking rssi, notify user of retry event
        print("DFU Operation Exception: ${e.toString()}");

        if (++failCount > 2) {
          setState(() {
            dfuRunning = false;
          });
          genericAlert(context, "Exception", Text("Wait, what does this mean? ${e.toString()}"), "OK");
        }
      }
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

  void showCompletedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Update completed'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Your Robogotchi is ready! It will automatically boot in a few seconds."),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close this dialog
                Navigator.of(context).pop(); // Close robogotchi updater
              },
            )
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final isScanning = scanSubscription != null;
    final hasDevice = scanResults.length > 0;
    final hasCompleted = _percent == 100;

    // Update icon angle every state refresh
    if (dfuRunning) {
      _animationController.forward(from: _animationController.isCompleted ? 0.0 : _animationController.value);
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('Robogotchi Updater'),
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
        body:
        Column(children: [
          SizedBox(height:10),
          Image(image: AssetImage("assets/robogotchi_render.png"),height: 150),
          Text("New Version: $updateFileName"),
          Text("Discovered devices:"),

          !hasDevice ? const Center( child: const Text('No devices found')) :Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemBuilder: _deviceItemBuilder,
                separatorBuilder: (context, index) => const SizedBox(height: 5),
                itemCount: scanResults.length,
              ),
          ),
          dfuRunning ?
          SizedBox(height: 175,
              child: Column(children: [
                hasCompleted ? Icon(
                  Icons.check_circle_outline,
                  size: 60.0,
                  color: Colors.blue,
                ) :
                RotationTransition(
                  turns: Tween(begin: 0.0, end: -1.0).animate(_animationController),
                  child: Icon(
                    Icons.sync,
                    size: 60.0,
                    color: Colors.blue,
                  ),
                ),
                _deviceAddress == null ? Text("Connecting to Robogotchi") : Text("Connected to Robogotchi"),
                _partsTotal == null ? Container() : Text("Updating Part $_currentPart / $_partsTotal"),
                Container(
                  padding: EdgeInsets.all(10),
                  child: LinearProgressIndicator(
                    value: _percent / 100,
                    minHeight: 20.0,
                  ),
                ),
              ])
          ) : Container()
        ])
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
                  Text(inDFUMode ? "Robogotchi (ready for update)" : name),
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
