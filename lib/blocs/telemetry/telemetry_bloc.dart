import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';
import '../../hardwareSupport/dieBieMSHelper.dart';
import 'telemetry_event.dart';
import 'telemetry_state.dart';

// Private internal events used by convenience methods below
class _TelemetryDirectUpdate extends TelemetryEvent {
  const _TelemetryDirectUpdate({this.packet, this.telemetryMap});
  final ESCTelemetry? packet;
  final Map<int, ESCTelemetry>? telemetryMap;
}

class _DieBieMSDirectUpdate extends TelemetryEvent {
  const _DieBieMSDirectUpdate(this.dieBieMS);
  final DieBieMSTelemetry? dieBieMS;
}

class _DieBieMSClear extends TelemetryEvent {
  const _DieBieMSClear();
}

class _ResetForDisconnect extends TelemetryEvent {
  const _ResetForDisconnect();
}

class TelemetryBloc extends Bloc<TelemetryEvent, TelemetryState> {
  TelemetryBloc() : super(const TelemetryInitial()) {
    on<TelemetryStarted>(_onStarted);
    on<TelemetryStopped>(_onStopped);
    on<TelemetryPacketReceived>(_onPacketReceived);
    on<TelemetryFaultReceived>(_onFaultReceived);
    on<TelemetryBMSPacketReceived>(_onBMSPacketReceived);
    on<TelemetryVehicleStatsUpdated>(_onVehicleStatsUpdated);
    on<TelemetryLoggerStateChanged>(_onLoggerStateChanged);
    on<_TelemetryDirectUpdate>(_onDirectUpdate);
    on<_DieBieMSDirectUpdate>(_onDieBieMSUpdate);
    on<_DieBieMSClear>(_onDieBieMSClear);
    on<_ResetForDisconnect>(_onResetForDisconnect);
  }

  void _onStarted(TelemetryStarted event, Emitter<TelemetryState> emit) {
    emit(const TelemetryActive());
  }

  void _onStopped(TelemetryStopped event, Emitter<TelemetryState> emit) {
    emit(const TelemetryInitial());
  }

  void _onPacketReceived(TelemetryPacketReceived event, Emitter<TelemetryState> emit) {
    // Raw bytes are pre-parsed by main.dart before this event fires.
    // Use updateTelemetry() after parsing to push the structured data.
  }

  void _onFaultReceived(TelemetryFaultReceived event, Emitter<TelemetryState> emit) {
    if (state is TelemetryActive) {
      final current = state as TelemetryActive;
      final updated = List<ESCFault>.from(current.escFaults)..add(event.fault);
      emit(current.copyWith(escFaults: updated));
    }
  }

  void _onBMSPacketReceived(TelemetryBMSPacketReceived event, Emitter<TelemetryState> emit) {
    // main.dart parses BMS bytes and calls updateDieBieMS().
  }

  void _onVehicleStatsUpdated(TelemetryVehicleStatsUpdated event, Emitter<TelemetryState> emit) {
    if (state is TelemetryActive) {
      final s = state as TelemetryActive;
      emit(s.copyWith(
        connectedVehicleOdometer: event.odometer ?? s.connectedVehicleOdometer,
        connectedVehicleConsumption: event.consumption ?? s.connectedVehicleConsumption,
      ));
    }
  }

  void _onLoggerStateChanged(TelemetryLoggerStateChanged event, Emitter<TelemetryState> emit) {
    if (state is TelemetryActive) {
      emit((state as TelemetryActive).copyWith(isLoggerLogging: event.isLogging));
    }
  }

  void _onDirectUpdate(_TelemetryDirectUpdate event, Emitter<TelemetryState> emit) {
    if (state is TelemetryActive) {
      emit((state as TelemetryActive).copyWith(
        packet: event.packet,
        telemetryMap: event.telemetryMap,
      ));
    } else {
      emit(TelemetryActive(packet: event.packet, telemetryMap: event.telemetryMap));
    }
  }

  void _onDieBieMSUpdate(_DieBieMSDirectUpdate event, Emitter<TelemetryState> emit) {
    if (state is TelemetryActive) {
      emit((state as TelemetryActive).copyWith(dieBieMS: event.dieBieMS));
    }
  }

  void _onDieBieMSClear(_DieBieMSClear event, Emitter<TelemetryState> emit) {
    if (state is TelemetryActive) {
      emit((state as TelemetryActive).copyWith(clearDieBieMS: true));
    }
  }

  void _onResetForDisconnect(_ResetForDisconnect event, Emitter<TelemetryState> emit) {
    emit(const TelemetryInitial());
  }

  // Convenience methods called by main.dart after BLE parsing
  void updateTelemetry(ESCTelemetry packet, Map<int, ESCTelemetry> telemetryMap) {
    add(_TelemetryDirectUpdate(packet: packet, telemetryMap: telemetryMap));
  }

  void updateDieBieMS(DieBieMSTelemetry dieBieMS) {
    add(_DieBieMSDirectUpdate(dieBieMS));
  }

  void clearDieBieMS() {
    add(const _DieBieMSClear());
  }

  void resetForDisconnect() {
    add(const _ResetForDisconnect());
  }
}
