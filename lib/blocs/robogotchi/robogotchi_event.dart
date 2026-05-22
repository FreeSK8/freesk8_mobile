import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../mainViews/connectionStatus.dart';

abstract class RobogotchiEvent extends Equatable {
  const RobogotchiEvent();
  @override
  List<Object> get props => [];
}

class RobogotchiConnected extends RobogotchiEvent {
  const RobogotchiConnected({this.txLoggerChar, this.isGotchiPro = false});
  final BluetoothCharacteristic? txLoggerChar;
  final bool isGotchiPro;
  @override
  List<Object?> get props => [txLoggerChar, isGotchiPro];
}

class RobogotchiDisconnectedEvent extends RobogotchiEvent {
  const RobogotchiDisconnectedEvent();
}

class RobogotchiStatusReceived extends RobogotchiEvent {
  const RobogotchiStatusReceived(this.status);
  final RobogotchiStatus status;
  @override
  List<Object> get props => [status];
}

class RobogotchiVersionReceived extends RobogotchiEvent {
  const RobogotchiVersionReceived({this.version, this.isGotchiPro = false});
  final String? version;
  final bool isGotchiPro;
  @override
  List<Object?> get props => [version, isGotchiPro];
}

class RobogotchiInitStepCompleted extends RobogotchiEvent {
  const RobogotchiInitStepCompleted();
}

class RobogotchiInitCompleted extends RobogotchiEvent {
  const RobogotchiInitCompleted();
}

class RobogotchiStatusPaused extends RobogotchiEvent {
  const RobogotchiStatusPaused();
}

class RobogotchiStatusResumed extends RobogotchiEvent {
  const RobogotchiStatusResumed();
}
