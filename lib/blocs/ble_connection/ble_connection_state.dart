import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';

enum BLEDeviceType { unknown, robogotchi, gotchiPro, escDirect }

abstract class BLEConnectionState extends Equatable {
  const BLEConnectionState();
  @override
  List<Object> get props => [];
}

class BLEIdle extends BLEConnectionState {
  const BLEIdle();
}

class BLEScanning extends BLEConnectionState {
  const BLEScanning({this.results = const []});
  final List<ScanResult> results;
  @override
  List<Object> get props => [results];
}

class BLEConnecting extends BLEConnectionState {
  const BLEConnecting(this.device);
  final BluetoothDevice device;
  @override
  List<Object> get props => [device];
}

class BLEConnected extends BLEConnectionState {
  const BLEConnected({
    this.device,
    this.txChar,
    this.rxChar,
    this.txLoggerChar,
    this.rxLoggerChar,
    this.deviceType = BLEDeviceType.unknown,
    this.firmwarePacket,
    this.deviceVersion,
  });

  final BluetoothDevice device;
  final BluetoothCharacteristic txChar;
  final BluetoothCharacteristic rxChar;
  final BluetoothCharacteristic txLoggerChar;
  final BluetoothCharacteristic rxLoggerChar;
  final BLEDeviceType deviceType;
  final ESCFirmware firmwarePacket;
  final String deviceVersion;

  bool get isRobogotchi => deviceType == BLEDeviceType.robogotchi;
  bool get isGotchiPro => deviceType == BLEDeviceType.gotchiPro;

  BLEConnected copyWith({
    BluetoothDevice device,
    BluetoothCharacteristic txChar,
    BluetoothCharacteristic rxChar,
    BluetoothCharacteristic txLoggerChar,
    BluetoothCharacteristic rxLoggerChar,
    BLEDeviceType deviceType,
    ESCFirmware firmwarePacket,
    String deviceVersion,
  }) {
    return BLEConnected(
      device: device ?? this.device,
      txChar: txChar ?? this.txChar,
      rxChar: rxChar ?? this.rxChar,
      txLoggerChar: txLoggerChar ?? this.txLoggerChar,
      rxLoggerChar: rxLoggerChar ?? this.rxLoggerChar,
      deviceType: deviceType ?? this.deviceType,
      firmwarePacket: firmwarePacket ?? this.firmwarePacket,
      deviceVersion: deviceVersion ?? this.deviceVersion,
    );
  }

  @override
  List<Object> get props => [device, txChar, rxChar, txLoggerChar, rxLoggerChar, deviceType, firmwarePacket, deviceVersion];
}

class BLEDisconnecting extends BLEConnectionState {
  const BLEDisconnecting();
}

class BLEUnexpectedDisconnect extends BLEConnectionState {
  const BLEUnexpectedDisconnect(this.device);
  final BluetoothDevice device;
  @override
  List<Object> get props => [device];
}

class BLEError extends BLEConnectionState {
  const BLEError(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}
