import 'package:equatable/equatable.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';
import '../../hardwareSupport/escHelper/mcConf.dart';
import '../../hardwareSupport/escHelper/appConf.dart';
import '../../subViews/inputConfigurationEditor.dart';

abstract class ESCConfigState extends Equatable {
  const ESCConfigState();
  @override
  List<Object?> get props => [];
}

class ESCConfigInitial extends ESCConfigState {
  const ESCConfigInitial();
}

class ESCConfigLoading extends ESCConfigState {
  const ESCConfigLoading();
}

class ESCConfigLoaded extends ESCConfigState {
  const ESCConfigLoaded({
    this.firmware,
    this.mcconf,
    this.appconf,
    this.calibration,
    this.canDevices = const [],
    this.mcconfDefaults,
    this.isResponding = false,
  });

  final ESCFirmware? firmware;
  final MCCONF? mcconf;
  final APPCONF? appconf;
  final InputCalibration? calibration;
  final List<int> canDevices;
  final List<int>? mcconfDefaults;
  final bool isResponding;

  ESCConfigLoaded copyWith({
    ESCFirmware? firmware,
    MCCONF? mcconf,
    APPCONF? appconf,
    InputCalibration? calibration,
    List<int>? canDevices,
    List<int>? mcconfDefaults,
    bool? isResponding,
  }) {
    return ESCConfigLoaded(
      firmware: firmware ?? this.firmware,
      mcconf: mcconf ?? this.mcconf,
      appconf: appconf ?? this.appconf,
      calibration: calibration ?? this.calibration,
      canDevices: canDevices ?? this.canDevices,
      mcconfDefaults: mcconfDefaults ?? this.mcconfDefaults,
      isResponding: isResponding ?? this.isResponding,
    );
  }

  @override
  List<Object?> get props => [firmware, mcconf, appconf, calibration, canDevices, isResponding];
}

class ESCConfigError extends ESCConfigState {
  const ESCConfigError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
