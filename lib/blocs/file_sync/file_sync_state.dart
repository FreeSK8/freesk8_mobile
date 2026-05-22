import 'package:equatable/equatable.dart';
import '../../widgets/fileSyncViewer.dart';

abstract class FileSyncState extends Equatable {
  const FileSyncState();
  @override
  List<Object> get props => [];
}

class FileSyncIdle extends FileSyncState {
  const FileSyncIdle();
}

class FileSyncListing extends FileSyncState {
  const FileSyncListing();
}

class FileSyncDownloading extends FileSyncState {
  const FileSyncDownloading({
    this.filename = '',
    this.bytesReceived = 0,
    this.bytesTotal = 0,
    this.fileList = const [],
    this.currentFileIndex = 0,
  });
  final String filename;
  final int bytesReceived;
  final int bytesTotal;
  final List<FileToSync> fileList;
  final int currentFileIndex;

  double get progress =>
      bytesTotal > 0 ? bytesReceived / bytesTotal : 0.0;

  FileSyncDownloading copyWith({
    String filename,
    int bytesReceived,
    int bytesTotal,
    List<FileToSync> fileList,
    int currentFileIndex,
  }) {
    return FileSyncDownloading(
      filename: filename ?? this.filename,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      fileList: fileList ?? this.fileList,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
    );
  }

  @override
  List<Object> get props => [filename, bytesReceived, bytesTotal, currentFileIndex];
}

class FileSyncUnpacking extends FileSyncState {
  const FileSyncUnpacking(this.filename);
  final String filename;
  @override
  List<Object> get props => [filename];
}

class FileSyncComplete extends FileSyncState {
  const FileSyncComplete(this.filesSynced);
  final int filesSynced;
  @override
  List<Object> get props => [filesSynced];
}

class FileSyncError extends FileSyncState {
  const FileSyncError(this.message);
  final String message;
  @override
  List<Object> get props => [message];
}
