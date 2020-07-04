import 'package:flutter/material.dart';

class FileToSync{
  FileToSync({this.fileName, this.fileSize});
  String fileName;
  int fileSize;
}

class FileSyncViewerArguments {
  //TODO: add file sync status variable
  final bool syncInProgress;
  final String fileName;
  final int fileBytesTotal;
  final int fileBytesReceived;
  final List<FileToSync> fileList;

  FileSyncViewerArguments({this.syncInProgress,this.fileName,this.fileBytesReceived,this.fileBytesTotal,this.fileList});
}

class FileSyncViewer extends StatefulWidget {
  final FileSyncViewerArguments syncStatus;

  FileSyncViewer({this.syncStatus});

  FileSyncViewerState createState() => new FileSyncViewerState();
}

class FileSyncViewerState extends State<FileSyncViewer> {

  FileSyncViewerArguments myArguments;
  double syncIconAngle = 0.0;

  @override
  void initState()
  {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    print("Build: fileSyncViewer");

    syncIconAngle -= 0.1;

    return Container(
      child: Center(
        child: Column(
          // center the children
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Transform.rotate(
              angle: syncIconAngle,
              child: Icon(
                Icons.sync,
                size: 60.0,
                color: Colors.blue,
              )
            ),
            Text("Files remaining: ${widget.syncStatus.fileList.length}"),
            Text("Current file: ${widget.syncStatus.fileName}"),
            Text("Progress: ${widget.syncStatus.fileBytesReceived}/${widget.syncStatus.fileBytesTotal} bytes"), //TODO: dont' divide by 0
            SizedBox(width: 200, height: 20, child:
              LinearProgressIndicator( value: widget.syncStatus.fileBytesReceived / widget.syncStatus.fileBytesTotal)),

          ],
        ),
      ),
    );
  }
}