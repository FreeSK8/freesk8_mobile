import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../widgets/fileSyncViewer.dart';

abstract class FileSyncEvent extends Equatable {
  const FileSyncEvent();
  @override
  List<Object?> get props => [];
}

class FileSyncStarted extends FileSyncEvent {
  const FileSyncStarted({this.txLoggerChar, this.eraseOnComplete = false});
  final BluetoothCharacteristic? txLoggerChar;
  final bool eraseOnComplete;
  @override
  List<Object?> get props => [txLoggerChar, eraseOnComplete];
}

class FileSyncAborted extends FileSyncEvent {
  const FileSyncAborted();
}

class FileSyncListReceived extends FileSyncEvent {
  const FileSyncListReceived(this.files);
  final List<FileToSync> files;
  @override
  List<Object?> get props => [files];
}

class FileSyncChunkReceived extends FileSyncEvent {
  const FileSyncChunkReceived(this.bytes);
  final List<int> bytes;
  @override
  List<Object?> get props => [bytes];
}

class FileSyncFileComplete extends FileSyncEvent {
  const FileSyncFileComplete();
}

class FileSyncAckReceived extends FileSyncEvent {
  const FileSyncAckReceived();
}

class FileSyncEraseOnCompleteToggled extends FileSyncEvent {
  const FileSyncEraseOnCompleteToggled(this.value);
  final bool value;
  @override
  List<Object?> get props => [value];
}
