import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';

abstract class BLEConnectionEvent extends Equatable {
  const BLEConnectionEvent();
  @override
  List<Object?> get props => [];
}

class BLEScanStarted extends BLEConnectionEvent {
  const BLEScanStarted();
}

class BLEScanStopped extends BLEConnectionEvent {
  const BLEScanStopped();
}

class BLEScanResultsUpdated extends BLEConnectionEvent {
  const BLEScanResultsUpdated(this.results);
  final List<ScanResult> results;
  @override
  List<Object?> get props => [results];
}

class BLEConnectRequested extends BLEConnectionEvent {
  const BLEConnectRequested(this.device);
  final BluetoothDevice device;
  @override
  List<Object?> get props => [device];
}

class BLEDisconnectRequested extends BLEConnectionEvent {
  const BLEDisconnectRequested();
}

class BLEConnectionStateChanged extends BLEConnectionEvent {
  const BLEConnectionStateChanged(this.connectionState);
  final BluetoothConnectionState connectionState;
  @override
  List<Object?> get props => [connectionState];
}

class BLEServicesDiscovered extends BLEConnectionEvent {
  const BLEServicesDiscovered(this.services);
  final List<BluetoothService> services;
  @override
  List<Object?> get props => [services];
}

class BLEFirmwareVersionReceived extends BLEConnectionEvent {
  const BLEFirmwareVersionReceived(this.firmware);
  final ESCFirmware firmware;
  @override
  List<Object?> get props => [firmware];
}

class BLEDeviceVersionReceived extends BLEConnectionEvent {
  const BLEDeviceVersionReceived({this.version, this.isGotchiPro = false});
  final String? version;
  final bool isGotchiPro;
  @override
  List<Object?> get props => [version, isGotchiPro];
}
