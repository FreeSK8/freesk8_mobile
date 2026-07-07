import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';

abstract class TelemetryEvent extends Equatable {
  const TelemetryEvent();
  @override
  List<Object?> get props => [];
}

class TelemetryStarted extends TelemetryEvent {
  const TelemetryStarted({this.txChar, this.rxChar, this.rxDieBieMSChar});
  final BluetoothCharacteristic? txChar;
  final BluetoothCharacteristic? rxChar;
  final BluetoothCharacteristic? rxDieBieMSChar;
  @override
  List<Object?> get props => [txChar, rxChar];
}

class TelemetryStopped extends TelemetryEvent {
  const TelemetryStopped();
}

class TelemetryPacketReceived extends TelemetryEvent {
  const TelemetryPacketReceived(this.bytes);
  final List<int> bytes;
  @override
  List<Object?> get props => [bytes];
}

class TelemetryFaultReceived extends TelemetryEvent {
  const TelemetryFaultReceived(this.fault);
  final ESCFault fault;
  @override
  List<Object?> get props => [fault];
}

class TelemetryBMSPacketReceived extends TelemetryEvent {
  const TelemetryBMSPacketReceived(this.bytes);
  final List<int> bytes;
  @override
  List<Object?> get props => [bytes];
}

class TelemetryVehicleStatsUpdated extends TelemetryEvent {
  const TelemetryVehicleStatsUpdated({this.odometer, this.consumption});
  final double? odometer;
  final double? consumption;
  @override
  List<Object?> get props => [odometer, consumption];
}

class TelemetryLoggerStateChanged extends TelemetryEvent {
  const TelemetryLoggerStateChanged({this.isLogging});
  final bool? isLogging;
  @override
  List<Object?> get props => [isLogging];
}
