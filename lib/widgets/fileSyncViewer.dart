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

  static double bytesPerSecond;
  static int bytesReceivedLastSecond;
  static DateTime bytesReceivedLastUpdated;
  static String bytesReceivedLastFile;
  static double estimatedSecondsRemaining; //NOTE: for current file

  static double totalSecondsRemaining;
  static int totalBytesRemaining;

  FileSyncViewerArguments myArguments;
  double syncIconAngle = 0.0;

  @override
  void initState()
  {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //globalLogger.wtf("Build: fileSyncViewer");

    // Update icon angle every state refresh
    syncIconAngle -= 0.1;

    // Compute which children to show
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

    // Compute total bytes remaining
    totalBytesRemaining = 0;
    widget.syncStatus.fileList.forEach((element) {
      totalBytesRemaining += element.fileSize;
    });
    totalBytesRemaining -= widget.syncStatus.fileBytesReceived;

    // Estimate sync time remaining
    if (bytesReceivedLastFile != widget.syncStatus.fileName) {
      bytesReceivedLastFile = widget.syncStatus.fileName;
      bytesPerSecond = 0;
      bytesReceivedLastSecond = 0;
      bytesReceivedLastUpdated = DateTime.now();
      print("Starting new sync time estimate");
    }
    else if (!unPackingNow) {
      int secondsElapsed = DateTime.now().difference(bytesReceivedLastUpdated).inSeconds;
      if (secondsElapsed > 0) {
        int byesLastSecond = widget.syncStatus.fileBytesReceived - bytesReceivedLastSecond;

        bytesReceivedLastSecond = widget.syncStatus.fileBytesReceived;
        bytesReceivedLastUpdated = DateTime.now();

        if (bytesPerSecond == 0) {
          bytesPerSecond = byesLastSecond / secondsElapsed;
        }
        bytesPerSecond = bytesPerSecond * 0.7 + (byesLastSecond / secondsElapsed) * 0.3;

        estimatedSecondsRemaining = (widget.syncStatus.fileBytesTotal - widget.syncStatus.fileBytesReceived) / bytesPerSecond;
        totalSecondsRemaining = totalBytesRemaining / bytesPerSecond;
      }
      if (bytesPerSecond > 0 && widget.syncStatus.fileList.length > 1) {
        zeChildren.add(Text("Estimated time remaining: ${estimatedSecondsRemaining.toInt()} ${estimatedSecondsRemaining.toInt() == 1 ? "second" : "seconds"} / ${totalSecondsRemaining.toInt()} seconds"));
      } else if (bytesPerSecond > 0 && widget.syncStatus.fileList.length > 0) {
        zeChildren.add(Text("Estimated time remaining: ${estimatedSecondsRemaining.toInt()} ${estimatedSecondsRemaining.toInt() == 1 ? "second" : "seconds"}"));
      } else {
        zeChildren.add(Text("Estimated time remaining: Calculating..."));
      }
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