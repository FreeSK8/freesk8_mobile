import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../globalUtilities.dart';

//const String updateFileName = "gotchiPro"; //TODO: NOTE: Must match that of /assets/firmware/<*>.zip

class gotchiProOTA extends StatefulWidget {
  @override
  gotchiProOTAState createState() => gotchiProOTAState();

  static const String routeName = "/otamode";
}

class gotchiProOTAState extends State<gotchiProOTA> with SingleTickerProviderStateMixin {
  final FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
  StreamSubscription<ScanResult> scanSubscription;
  List<ScanResult> scanResults = <ScanResult>[];
  bool otaRunning = false;

  String _deviceAddress;
  int _percent = 0;

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

  Future<void> doOTA(String deviceId) async {
    stopScan();
    setState(() {
      _percent = 0;
      otaRunning = true;
    });

    globalLogger.i("OTA Operation starting for $deviceId");

    // Attempt OTA process 3 times before giving up
    int failCount = 0;
    while(otaRunning) {
      try {
/*        var result = await FlutterNordicDfu.startDfu(
          deviceId,
          'assets/firmware/$updateFileName.zip',
          fileInAsset: true,
          progressListener:
          DefaultOTAProgressListenerAdapter(onProgressChangedHandle: (
              deviceAddress,
              percent,
              speed,
              avgSpeed,
              currentPart,
              partsTotal,
              ) {
            //globalLogger.wtf('deviceAddress: $deviceAddress, percent: $percent');
            setState(() {
              _deviceAddress = deviceAddress;
              _percent = percent;
              _currentPart = currentPart;
              _partsTotal = partsTotal;
            });
            if (_percent == 100) {
              showCompletedDialog();
            }
          }),
        );*/
        //globalLogger.i("OTA Operation Completed. ($result)");
        otaRunning = false;
      } catch (e, stacktrace) {
        //NOTE: Sometimes we are throwing PlatformException(DFU_Failed, Device address: *****, null, null)
        //TODO: Consider checking rssi, notify user of retry event
        globalLogger.e("OTA Operation Exception: ${e.toString()}");
        globalLogger.e(stacktrace.toString());

        if (++failCount > 2) {
          setState(() {
            otaRunning = false;
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
            TextButton(
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
    if (otaRunning) {
      _animationController.forward(from: _animationController.isCompleted ? 0.0 : _animationController.value);
    }

    return Scaffold(
        appBar: AppBar(
          title: const Text('gotchiPro Updater'),
          actions: <Widget>[
            isScanning
                ? IconButton(
              icon: Icon(Icons.search_off),
              onPressed: otaRunning ? null : stopScan,
            )
                : IconButton(
              icon: Icon(Icons.search),
              onPressed: otaRunning ? null : startScan,
            )
          ],
        ),
        body:
        Column(children: [
          SizedBox(height:10),
          Image(image: AssetImage("assets/robogotchi_render.png"),height: 150),
          //Text("New Version: $updateFileName"),
          Text("Discovered devices:"),

          !hasDevice ? const Center( child: const Text('No devices found')) :Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemBuilder: _deviceItemBuilder,
                separatorBuilder: (context, index) => const SizedBox(height: 5),
                itemCount: scanResults.length,
              ),
          ),
          otaRunning ?
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
      onPress: otaRunning
          ? null
          : () async {
        await this.doOTA(result.device.id.id);
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
    var inOTAMode = scanResult.device.name == "FreeSK8-OTA";
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
                  Text(inOTAMode ? "gotchiPro (ready for update)" : name),
                  Text(scanResult.device.id.id),
                  Text("RSSI: ${scanResult.rssi}"),
                ],
              ),
            ),
            TextButton(onPressed: inOTAMode ? onPress : null, child: Text(inOTAMode ? "Start Update" : "Not Ready"))
          ],
        ),
      ),
    );
  }
}
