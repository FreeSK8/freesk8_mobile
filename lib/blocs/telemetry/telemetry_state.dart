import 'package:equatable/equatable.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';
import '../../hardwareSupport/dieBieMSHelper.dart';

abstract class TelemetryState extends Equatable {
  const TelemetryState();
  @override
  List<Object?> get props => [];
}

class TelemetryInitial extends TelemetryState {
  const TelemetryInitial();
}

class TelemetryActive extends TelemetryState {
  const TelemetryActive({
    this.packet,
    this.telemetryMap = const {},
    this.escFaults = const [],
    this.dieBieMS,
    this.isLoggerLogging = false,
    this.connectedVehicleOdometer = 0.0,
    this.connectedVehicleConsumption = 0.0,
  });

  final ESCTelemetry? packet;
  final Map<int, ESCTelemetry> telemetryMap;
  final List<ESCFault> escFaults;
  final DieBieMSTelemetry? dieBieMS;
  final bool isLoggerLogging;
  final double connectedVehicleOdometer;
  final double connectedVehicleConsumption;

  TelemetryActive copyWith({
    ESCTelemetry? packet,
    Map<int, ESCTelemetry>? telemetryMap,
    List<ESCFault>? escFaults,
    DieBieMSTelemetry? dieBieMS,
    bool? clearDieBieMS,
    bool? isLoggerLogging,
    double? connectedVehicleOdometer,
    double? connectedVehicleConsumption,
  }) {
    return TelemetryActive(
      packet: packet ?? this.packet,
      telemetryMap: telemetryMap ?? this.telemetryMap,
      escFaults: escFaults ?? this.escFaults,
      dieBieMS: clearDieBieMS == true ? null : (dieBieMS ?? this.dieBieMS),
      isLoggerLogging: isLoggerLogging ?? this.isLoggerLogging,
      connectedVehicleOdometer: connectedVehicleOdometer ?? this.connectedVehicleOdometer,
      connectedVehicleConsumption: connectedVehicleConsumption ?? this.connectedVehicleConsumption,
    );
  }

  @override
  List<Object?> get props => [packet, telemetryMap, escFaults, dieBieMS, isLoggerLogging, connectedVehicleOdometer, connectedVehicleConsumption];
}

class TelemetryError extends TelemetryState {
  const TelemetryError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
