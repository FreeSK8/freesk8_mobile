import 'package:flutter/material.dart';

class FileSyncViewerArguments {
  //TODO: add list of files to sync
  //TODO: add file sync status variable
  final bool syncInProgress;
  final String fileName;
  final int fileBytesTotal;
  final int fileBytesReceived;

  FileSyncViewerArguments({this.syncInProgress,this.fileName,this.fileBytesReceived,this.fileBytesTotal});
}

class FileSyncViewer extends StatefulWidget {
  final FileSyncViewerArguments syncStatus;

  FileSyncViewer({this.syncStatus});

  FileSyncViewerState createState() => new FileSyncViewerState();
}

class FileSyncViewerState extends State<FileSyncViewer> {

  FileSyncViewerArguments myArguments;

  @override
  Widget build(BuildContext context) {
    print("Build: fileSyncViewer");

    return Container(
      child: Center(
        child: Column(
          // center the children
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.sync,
              size: 60.0,
              color: Colors.blue,
            ),
            Text("Current file: ${widget.syncStatus.fileName}"),
            Text("Progress: ${widget.syncStatus.fileBytesReceived}/${widget.syncStatus.fileBytesTotal} bytes"),

          ],
        ),
      ),
    );
  }
}