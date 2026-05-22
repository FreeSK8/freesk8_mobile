import 'package:flutter_bloc/flutter_bloc.dart';
import 'robogotchi_event.dart';
import 'robogotchi_state.dart';

class RobogotchiBloc extends Bloc<RobogotchiEvent, RobogotchiState> {
  RobogotchiBloc() : super(const RobogotchiDisconnected()) {
    on<RobogotchiConnected>(_onConnected);
    on<RobogotchiDisconnectedEvent>(_onDisconnected);
    on<RobogotchiStatusReceived>(_onStatusReceived);
    on<RobogotchiVersionReceived>(_onVersionReceived);
    on<RobogotchiInitStepCompleted>(_onInitStepCompleted);
    on<RobogotchiInitCompleted>(_onInitCompleted);
    on<RobogotchiStatusPaused>(_onStatusPaused);
    on<RobogotchiStatusResumed>(_onStatusResumed);
  }

  bool _statusPaused = false;

  void _onConnected(RobogotchiConnected event, Emitter<RobogotchiState> emit) {
    _statusPaused = false;
    emit(const RobogotchiInitializing());
  }

  void _onDisconnected(RobogotchiDisconnectedEvent event, Emitter<RobogotchiState> emit) {
    _statusPaused = false;
    emit(const RobogotchiDisconnected());
  }

  void _onStatusReceived(RobogotchiStatusReceived event, Emitter<RobogotchiState> emit) {
    if (_statusPaused) return;
    if (state is RobogotchiReady) {
      emit((state as RobogotchiReady).copyWith(status: event.status));
    } else if (state is RobogotchiInitializing) {
      // Status arrived before init complete — store it for when init finishes
    }
  }

  void _onVersionReceived(RobogotchiVersionReceived event, Emitter<RobogotchiState> emit) {
    if (state is RobogotchiReady) {
      emit((state as RobogotchiReady).copyWith(
        version: event.version,
        isGotchiPro: event.isGotchiPro,
      ));
    }
  }

  void _onInitStepCompleted(RobogotchiInitStepCompleted event, Emitter<RobogotchiState> emit) {
    if (state is RobogotchiInitializing) {
      final s = state as RobogotchiInitializing;
      emit(RobogotchiInitializing(
        stepsComplete: s.stepsComplete + 1,
        stepsTotal: s.stepsTotal,
      ));
    }
  }

  void _onInitCompleted(RobogotchiInitCompleted event, Emitter<RobogotchiState> emit) {
    emit(const RobogotchiReady());
  }

  void _onStatusPaused(RobogotchiStatusPaused event, Emitter<RobogotchiState> emit) {
    _statusPaused = true;
  }

  void _onStatusResumed(RobogotchiStatusResumed event, Emitter<RobogotchiState> emit) {
    _statusPaused = false;
  }
}
