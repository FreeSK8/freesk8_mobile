import 'package:equatable/equatable.dart';
import '../../mainViews/connectionStatus.dart';

abstract class RobogotchiState extends Equatable {
  const RobogotchiState();
  @override
  List<Object> get props => [];
}

class RobogotchiDisconnected extends RobogotchiState {
  const RobogotchiDisconnected();
}

class RobogotchiInitializing extends RobogotchiState {
  const RobogotchiInitializing({this.stepsComplete = 0, this.stepsTotal = 6});
  final int stepsComplete;
  final int stepsTotal;
  @override
  List<Object> get props => [stepsComplete, stepsTotal];
}

class RobogotchiReady extends RobogotchiState {
  const RobogotchiReady({
    this.status,
    this.version = '',
    this.isGotchiPro = false,
  });

  final RobogotchiStatus status;
  final String version;
  final bool isGotchiPro;

  RobogotchiReady copyWith({
    RobogotchiStatus status,
    String version,
    bool isGotchiPro,
  }) {
    return RobogotchiReady(
      status: status ?? this.status,
      version: version ?? this.version,
      isGotchiPro: isGotchiPro ?? this.isGotchiPro,
    );
  }

  @override
  List<Object> get props => [status, version, isGotchiPro];
}

class RobogotchiError extends RobogotchiState {
  const RobogotchiError(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}
