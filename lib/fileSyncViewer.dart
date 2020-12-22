import 'package:flutter/material.dart';

class FileToSync{
  FileToSync({this.fileName, this.fileSize});
  String fileName;
  int fileSize;
}

class FileSyncViewerArguments {
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

    bool unPackingNow = false;
    List<Widget> zeChildren = new List();
    if (widget.syncStatus.fileList.length > 0 && widget.syncStatus.fileBytesReceived == widget.syncStatus.fileBytesTotal) {
      zeChildren.add(Text("Files remaining: ${widget.syncStatus.fileList.length}"));
      zeChildren.add(Text("Current file: ${widget.syncStatus.fileName}"));
      zeChildren.add(Text("Unpacking contents"));
      zeChildren.add(SizedBox(width: 200, height: 20, child: LinearProgressIndicator( value: widget.syncStatus.fileBytesReceived / widget.syncStatus.fileBytesTotal)));
      unPackingNow = true;
    } else if(widget.syncStatus.fileList.length > 0) {
      zeChildren.add(Text("Files remaining: ${widget.syncStatus.fileList.length}"));
      zeChildren.add(Text("Current file: ${widget.syncStatus.fileName}"));
      zeChildren.add(Text("Progress: ${widget.syncStatus.fileBytesReceived}/${widget.syncStatus.fileBytesTotal} bytes"));
      zeChildren.add(SizedBox(width: 200, height: 20, child: LinearProgressIndicator( value: widget.syncStatus.fileBytesReceived / widget.syncStatus.fileBytesTotal)));
    } else {
      zeChildren.add(Text("Checking file list..."));
    }

    return Container(
      child: Center(
        child: Column(
          // center the children
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[

            // Display Icon
            unPackingNow ?
            Icon(
              Icons.expand,
              size: 60.0,
              color: Colors.blue,
            ) :
            Transform.rotate(
              angle: syncIconAngle,
              child: Icon(
                Icons.sync,
                size: 60.0,
                color: Colors.blue,
              )
            ),

            //Display children
            Column(
              children: zeChildren
            )

          ],
        ),
      ),
    );
  }
}