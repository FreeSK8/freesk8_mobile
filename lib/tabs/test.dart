import 'package:flutter/material.dart';

//TODO: Make all the tabs with updating data stateful widgets

class Test extends StatefulWidget {
  Test({this.textInput});
  final Widget textInput;
  TestState createState() => new TestState();

  static const String routeName = "/testies";
}

class TestState extends State<Test> {
  bool checkBoxValue = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          },
        child:
        Center(
          child: Column(
          // center the children
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.lightbulb_outline,
              size: 160.0,
              color: Colors.blue,
            ),
            Text("Everything is a widget"),
            Text("Especially Sean's mom!"),
          ],
        ),
      ),
    )
    );
  }
}