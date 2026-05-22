import 'package:flutter_bloc/flutter_bloc.dart';
import 'esc_config_event.dart';
import 'esc_config_state.dart';

class ESCConfigBloc extends Bloc<ESCConfigEvent, ESCConfigState> {
  ESCConfigBloc() : super(const ESCConfigInitial()) {
    on<ESCConfigReset>(_onReset);
    on<ESCFirmwareReceived>(_onFirmwareReceived);
    on<ESCMotorConfigReceived>(_onMotorConfigReceived);
    on<ESCAppConfigReceived>(_onAppConfigReceived);
    on<ESCCalibrationReceived>(_onCalibrationReceived);
    on<ESCCANDevicesReceived>(_onCANDevicesReceived);
    on<ESCRespondingChanged>(_onRespondingChanged);
  }

  void _onReset(ESCConfigReset event, Emitter<ESCConfigState> emit) {
    emit(const ESCConfigInitial());
  }

  void _onFirmwareReceived(ESCFirmwareReceived event, Emitter<ESCConfigState> emit) {
    final current = state is ESCConfigLoaded ? state as ESCConfigLoaded : const ESCConfigLoaded();
    emit(current.copyWith(firmware: event.firmware));
  }

  void _onMotorConfigReceived(ESCMotorConfigReceived event, Emitter<ESCConfigState> emit) {
    final current = state is ESCConfigLoaded ? state as ESCConfigLoaded : const ESCConfigLoaded();
    // isDefaults=true: raw bytes are stored separately by main.dart (escMotorConfigurationDefaults)
    if (!event.isDefaults) {
      emit(current.copyWith(mcconf: event.mcconf));
    }
  }

  void _onAppConfigReceived(ESCAppConfigReceived event, Emitter<ESCConfigState> emit) {
    final current = state is ESCConfigLoaded ? state as ESCConfigLoaded : const ESCConfigLoaded();
    emit(current.copyWith(appconf: event.appconf));
  }

  void _onCalibrationReceived(ESCCalibrationReceived event, Emitter<ESCConfigState> emit) {
    final current = state is ESCConfigLoaded ? state as ESCConfigLoaded : const ESCConfigLoaded();
    emit(current.copyWith(calibration: event.calibration));
  }

  void _onCANDevicesReceived(ESCCANDevicesReceived event, Emitter<ESCConfigState> emit) {
    final current = state is ESCConfigLoaded ? state as ESCConfigLoaded : const ESCConfigLoaded();
    emit(current.copyWith(canDevices: event.devices));
  }

  void _onRespondingChanged(ESCRespondingChanged event, Emitter<ESCConfigState> emit) {
    final current = state is ESCConfigLoaded ? state as ESCConfigLoaded : const ESCConfigLoaded();
    emit(current.copyWith(isResponding: event.isResponding));
  }
}
