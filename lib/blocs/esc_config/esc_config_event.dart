import 'package:equatable/equatable.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';
import '../../hardwareSupport/escHelper/mcConf.dart';
import '../../hardwareSupport/escHelper/appConf.dart';
import '../../subViews/inputConfigurationEditor.dart';

abstract class ESCConfigEvent extends Equatable {
  const ESCConfigEvent();
  @override
  List<Object> get props => [];
}

class ESCConfigReset extends ESCConfigEvent {
  const ESCConfigReset();
}

class ESCFirmwareReceived extends ESCConfigEvent {
  const ESCFirmwareReceived(this.firmware);
  final ESCFirmware firmware;
  @override
  List<Object> get props => [firmware];
}

class ESCMotorConfigReceived extends ESCConfigEvent {
  const ESCMotorConfigReceived(this.mcconf, {this.isDefaults = false});
  final MCCONF mcconf;
  final bool isDefaults;
  @override
  List<Object> get props => [mcconf, isDefaults];
}

class ESCAppConfigReceived extends ESCConfigEvent {
  const ESCAppConfigReceived(this.appconf);
  final APPCONF appconf;
  @override
  List<Object> get props => [appconf];
}

class ESCCalibrationReceived extends ESCConfigEvent {
  const ESCCalibrationReceived(this.calibration);
  final InputCalibration calibration;
  @override
  List<Object> get props => [calibration];
}

class ESCCANDevicesReceived extends ESCConfigEvent {
  const ESCCANDevicesReceived(this.devices);
  final List<int> devices;
  @override
  List<Object> get props => [devices];
}

class ESCRespondingChanged extends ESCConfigEvent {
  const ESCRespondingChanged({this.isResponding});
  final bool isResponding;
  @override
  List<Object> get props => [isResponding];
}
