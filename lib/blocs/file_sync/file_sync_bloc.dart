import 'package:flutter_bloc/flutter_bloc.dart';
import '../../widgets/fileSyncViewer.dart';
import 'file_sync_event.dart';
import 'file_sync_state.dart';

class FileSyncBloc extends Bloc<FileSyncEvent, FileSyncState> {
  FileSyncBloc() : super(const FileSyncIdle()) {
    on<FileSyncStarted>(_onStarted);
    on<FileSyncAborted>(_onAborted);
    on<FileSyncListReceived>(_onListReceived);
    on<FileSyncChunkReceived>(_onChunkReceived);
    on<FileSyncFileComplete>(_onFileComplete);
    on<FileSyncAckReceived>(_onAckReceived);
    on<FileSyncEraseOnCompleteToggled>(_onEraseToggled);
  }

  bool _eraseOnComplete = false;
  List<int> _rawBytes = [];
  int _fileIndex = 0;

  void _onStarted(FileSyncStarted event, Emitter<FileSyncState> emit) {
    _eraseOnComplete = event.eraseOnComplete;
    _rawBytes = [];
    _fileIndex = 0;
    emit(const FileSyncListing());
  }

  void _onAborted(FileSyncAborted event, Emitter<FileSyncState> emit) {
    _rawBytes = [];
    emit(const FileSyncIdle());
  }

  void _onListReceived(FileSyncListReceived event, Emitter<FileSyncState> emit) {
    if (event.files.isEmpty) {
      emit(const FileSyncComplete(0));
      return;
    }
    final first = event.files.first;
    emit(FileSyncDownloading(
      filename: first.fileName ?? '',
      bytesReceived: 0,
      bytesTotal: first.fileSize ?? 0,
      fileList: event.files,
      currentFileIndex: 0,
    ));
  }

  void _onChunkReceived(FileSyncChunkReceived event, Emitter<FileSyncState> emit) {
    if (state is! FileSyncDownloading) return;
    final current = state as FileSyncDownloading;
    _rawBytes.addAll(event.bytes);
    emit(current.copyWith(bytesReceived: _rawBytes.length));
  }

  void _onFileComplete(FileSyncFileComplete event, Emitter<FileSyncState> emit) {
    if (state is! FileSyncDownloading) return;
    final current = state as FileSyncDownloading;
    emit(FileSyncUnpacking(current.filename));
    _rawBytes = [];

    final nextIndex = current.currentFileIndex + 1;
    if (nextIndex < current.fileList.length) {
      _fileIndex = nextIndex;
      final nextFile = current.fileList[nextIndex];
      emit(FileSyncDownloading(
        filename: nextFile.fileName ?? '',
        bytesReceived: 0,
        bytesTotal: nextFile.fileSize ?? 0,
        fileList: current.fileList,
        currentFileIndex: nextIndex,
      ));
    } else {
      emit(FileSyncComplete(current.fileList.length));
    }
  }

  void _onAckReceived(FileSyncAckReceived event, Emitter<FileSyncState> emit) {
    // ACK handling is mostly managed by main.dart's BLE layer;
    // this event exists so the UI can observe ACK heartbeat if needed.
  }

  void _onEraseToggled(FileSyncEraseOnCompleteToggled event, Emitter<FileSyncState> emit) {
    _eraseOnComplete = event.value;
  }

  bool get eraseOnComplete => _eraseOnComplete;
}
