import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_gauge/handpainter.dart';
import 'package:flutter_gauge/linepainter.dart';
import 'package:rxdart/rxdart.dart';

import 'flutter_gauge.dart';
import 'gaugetextpainter.dart';

class FlutterGaugeMain extends StatefulWidget {

  final int start;
  final int end;
  final double highlightStart;
  final double highlightEnd;
//  ThemeData themeData;
  final String fontFamily;
  final double widthCircle;
  final PublishSubject<double> eventObservable;
  final Number number;
  final CounterAlign counterAlign;
  final Hand hand;
  final bool isCircle;
  final Map isMark;
  final double handSize;
  final SecondsMarker secondsMarker;
  final double shadowHand;
  final Color circleColor;
  final Color handColor;
  final Color backgroundColor;
  final Color indicatorColor;
  final double paddingHand;
  final double width;
  final NumberInAndOut numberInAndOut;
  final TextStyle counterStyle;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final Color inactiveColor;
  final Color activeColor;
  final bool isDecimal;
  final bool reverseDigits;
  final bool reverseDial;



  FlutterGaugeMain({this.reverseDial=false,this.reverseDigits=false,this.isDecimal,this.inactiveColor, this.activeColor, this.textStyle,this.counterStyle,this.numberInAndOut,this.width,this.paddingHand=30.0,this.circleColor,this.handColor = Colors.black,this.backgroundColor = Colors.cyan,this.indicatorColor = Colors.black,this.shadowHand=4.0,this.counterAlign=CounterAlign.bottom,this.number=Number.all,this.isCircle=true,this.hand= Hand.long,this.secondsMarker=SecondsMarker.all,this.isMark,this.handSize=30,this.start,this.end,this.highlightStart,this.highlightEnd, this.eventObservable,@required this.fontFamily,@required this.widthCircle,}):padding = EdgeInsets.all(widthCircle);

  @override
  _FlutterGaugeMainState createState() => new _FlutterGaugeMainState(this.start,this.end,this.highlightStart,this.highlightEnd,this.eventObservable);
}

class _FlutterGaugeMainState extends State<FlutterGaugeMain>  with TickerProviderStateMixin{
  int start;
  int end;
  double highlightStart;
  double highlightEnd;
  PublishSubject<double> eventObservable;
  double val = 0.0;
  double newVal;
  AnimationController percentageAnimationController;
  StreamSubscription<double> subscription;

  @override
  void dispose() {
    percentageAnimationController.dispose();
    subscription.cancel();
    super.dispose();
  }

  _FlutterGaugeMainState(int start, int end, double highlightStart, double highlightEnd, PublishSubject<double> eventObservable) {
    this.start = start;
    this.end = end;
    this.highlightStart = highlightStart;
    this.highlightEnd = highlightEnd;
    this.eventObservable = eventObservable;

    percentageAnimationController = new AnimationController(
        vsync: this,
        duration: new Duration(milliseconds: 20)
    )
      ..addListener((){
        setState(() {
          val = lerpDouble(val,newVal,percentageAnimationController.value);
        });
      });
    subscription = this.eventObservable.listen((value) {
      (value >= this.end) ? reloadData(this.end.toDouble()) : reloadData(value);
    });//(value) => reloadData(value));
  }

  reloadData(double value){
    //Only update animation controller if the new value is actually new
    if (value != newVal){
      newVal = value;
      percentageAnimationController.forward(from: 0.0);
    } else {
      //print("fluttergauge.dart::reloadData() value and newVal were equal, leave animation controller alone");
    }

  }

  @override
  Widget build(BuildContext context) {

    return new Center(

      child: new LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {

            return new Container(
              height: widget.width == null ? constraints.maxWidth : widget.width,
              width: widget.width == null ? constraints.maxWidth : widget.width,
              alignment: Alignment.center,
              child: new Stack(
                  fit: StackFit.expand,

                  children: <Widget>[

                    widget.isCircle == true
                    ?new Container(
                      height: constraints.maxWidth,
                      width: constraints.maxWidth,
                      padding: widget.padding,
                      child: new CustomPaint(
                          foregroundPainter: new LinePainter(
                              lineColor: this.widget.backgroundColor,
                              completeColor: this.widget.circleColor == null ? Theme.of(context).primaryColor : this.widget.circleColor ,
                              startValue: this.start,
                              endValue: this.end,
                              startPercent: this.widget.highlightStart,
                              endPercent: this.widget.highlightEnd,
                              width: this.widget.widthCircle,
                              value: this.val
                          )
                      ),
                    )
                    :SizedBox(),



                    widget.hand == Hand.none || widget.hand == Hand.short
                    ?SizedBox()
                    :new Center(
                      child: new Container(
                        width: widget.handSize,
                        height: widget.handSize,
                        decoration: new BoxDecoration(
                          shape: BoxShape.circle,
                          color: this.widget.indicatorColor,
                        ),
                      ),
                    ),

                    Container(
                      height: constraints.maxWidth ,
                      width: constraints.maxWidth ,
//                      alignment: Alignment.center,
                      padding: EdgeInsets.only(top: widget.hand == Hand.short ?widget.widthCircle :widget.widthCircle,bottom: widget.widthCircle,right: widget.widthCircle,left: widget.widthCircle,),
                      child: new CustomPaint(
                          painter: new GaugeTextPainter(
                              reverseDigits: widget.reverseDigits,
                              numberInAndOut: widget.numberInAndOut,
                              secondsMarker: widget.secondsMarker,
                              number: widget.number,
                              inactiveColor : widget.inactiveColor,
                              activeColor : widget.activeColor,
                              start: this.start,
                              end: this.end,
                              value: this.val,
                              fontFamily: widget.fontFamily,
//                              color: this.widget.colorHourHand,
                              widthCircle: widget.widthCircle,
                              textStyle:widget.textStyle == null
                              ?TextStyle(
                                  color: Theme.of(context).textTheme.bodyText1.color,
                                  fontSize: 15.0,
                                  fontFamily: widget.fontFamily
                              )
                              :widget.textStyle
                          )),
                    ),

                    widget.hand != Hand.none
                        ?new Center(
                        child: new Container(
                          height: constraints.maxWidth,
                          width: constraints.maxWidth,
                          padding: EdgeInsets.all(widget.hand == Hand.short ?widget.widthCircle/1.5 :widget.paddingHand),
                          child: new CustomPaint(
                            painter: new HandPainter(
                              reverseDial: widget.reverseDial,
                                shadowHand: widget.shadowHand,
                                hand: widget.hand,
                                value: val,
                                start: this.start,
                                end: this.end,
                                color: this.widget.handColor,
                                handSize: widget.handSize
                            ),
                          ),
                        )
                    )
                        :SizedBox(),

                    Container(
                      child: widget.counterAlign != CounterAlign.none
                      ?new CustomPaint(
                          painter: new GaugeTextCounter(
                              isDecimal: widget.isDecimal,
                              start: this.start,
                              width: widget.widthCircle,
                              counterAlign: widget.counterAlign,
                              end: this.end,
                              value: this.val,
                              fontFamily: widget.fontFamily,
                              textStyle:widget.counterStyle == null
                              ?TextStyle(
                                  color: Colors.black,
                                  fontSize: 17.0,
                                  fontFamily: widget.fontFamily
                              )
                              :widget.counterStyle
                          )
                      )
                      :SizedBox(),
                    )




                  ]
              ),
            );



          }),



    );
  }
}