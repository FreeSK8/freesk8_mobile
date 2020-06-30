import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_gauge/flutter_gauge.dart';

class GaugeTextPainter extends CustomPainter {
  final hourTickMarkLength = 30.0;
  final minuteTickMarkLength = 0.0;

  final hourTickMarkWidth = 1.5;
  final minuteTickMarkWidth = 1.0;

  final Paint tickPaint;
  final TextPainter textPainter;
  final TextStyle textStyle;

  int end;
  int start;
  double value;
  double widthCircle;
  String fontFamily;
  Number number;
  SecondsMarker secondsMarker;
  NumberInAndOut numberInAndOut;
  Color inactiveColor;
  Color activeColor;
  bool reverseDigits;

  GaugeTextPainter({this.inactiveColor, this.activeColor, this.numberInAndOut,this.widthCircle,this.secondsMarker,this.start, this.end, this.value,this.fontFamily,this.textStyle,this.number,this.reverseDigits})
      : tickPaint = new Paint(),
        textPainter = new TextPainter(
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        )
  {
    tickPaint.color = activeColor;
  }
  @override
  void paint(Canvas canvas, Size size)
  {
    int textLabelInterval = ((end - start) / 10).ceil();

    int textLabelCurrentPosition = 0;

    var tickMarkLength;
    final angle = ((2/3) * 2) * pi / (end - start);
//    final radius = (size.width / 2)-widthCircle;
    final radius = (size.width / 2);
    canvas.save();
    // drawing
    canvas.translate(radius, radius);
    canvas.rotate(-2.1);

    int lastlabel = -99999;

    for (var i = 0; i <= end - start; i++)
    {
      //make the length and stroke of the tick marker longer and thicker depending
      tickMarkLength = i % 5 == 0
          ? hourTickMarkLength
          : secondsMarker != SecondsMarker.seconds ?minuteTickMarkLength :hourTickMarkLength;
      tickPaint.strokeWidth = i % 5 == 0
          ?hourTickMarkWidth
          : secondsMarker != SecondsMarker.seconds ?minuteTickMarkLength :hourTickMarkWidth;

      // Set inactive color
      if(value.toInt() < start + i){
        tickPaint.color = inactiveColor;
      }

      //seconds & minutes
      if(i != 0 && i != end - start){ //(end / 1.5).toInt() > i && i != 0
        if(secondsMarker == SecondsMarker.all){
          canvas.drawLine(new Offset(0.0, -radius - 21), new Offset(0.0, -radius - 15 + tickMarkLength), tickPaint);
        }else if(secondsMarker == SecondsMarker.minutes){
          if(i % 5 == 0){
            canvas.drawLine(new Offset(0.0, -radius - 10), new Offset(0.0, -radius - 15 + tickMarkLength), tickPaint);
          }
        }else if(secondsMarker == SecondsMarker.secondsAndMinute){
          if(i % 5 == 0){
            canvas.drawLine(new Offset(0.0, -radius + 20), new Offset(0.0, -radius + 12), tickPaint);
          }else{
            canvas.drawLine(new Offset(0.0, -radius + 18), new Offset(0.0, -radius + 12), tickPaint);
          }
        }else if(secondsMarker == SecondsMarker.seconds){
          canvas.drawLine(new Offset(0.0, -radius - widthCircle/2), new Offset(0.0, -radius + widthCircle/2 ), tickPaint);
        }
      }

      //draw the text
      if (i % textLabelInterval == 0 || i == end - start)
      {
        int labelValue = start + textLabelCurrentPosition * textLabelInterval;
        int reverseValue = end - textLabelCurrentPosition * textLabelInterval;

        textLabelCurrentPosition++;
        //TODO: this hacky gauge project was further hacked

        if ( i == end - start ){ labelValue = end; }

        String label = reverseDigits ? reverseValue.toString() : labelValue.toString();

        //print("*************************************************** i $i, $valueIncreasePerInterval, $textLabelCurrentPosition, $labelValue");
        canvas.save();
        if(numberInAndOut == NumberInAndOut.inside){
          canvas.translate(0.0, -radius + (widthCircle*3));
        }else{
          canvas.translate(0.0, -radius - (0));
        }

        textPainter.text = new TextSpan(
          text: label,
          style: textStyle,

        );

        //helps make the text painted vertically
        canvas.rotate(-angle * i+2.1);

        textPainter.layout();

        if( labelValue >= lastlabel + textLabelInterval - 1 )
        {
          if(number == Number.all){
            textPainter.paint(canvas, new Offset(-(textPainter.width / 2), -(textPainter.height / 1.5)));
            lastlabel = labelValue;
          }else if(number == Number.endAndStart){
            if(i == 0 || i == end - start ){
              textPainter.paint(canvas, new Offset(-(textPainter.width / 2), -(textPainter.height / 2)));
              lastlabel = labelValue;
            }
          }else if(number == Number.endAndCenterAndStart){
            if(i == 0 || i == end - start ||  i == (end - start) ~/ 2){
              textPainter.paint(canvas, new Offset(-(textPainter.width / 2), -(textPainter.height / 1.5)));
              lastlabel = labelValue;
            }
          }
        }

        canvas.restore();
      }

      canvas.rotate(angle);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(GaugeTextPainter oldDelegate) {
    return false;
  }
}










///counter text bottom
class GaugeTextCounter extends CustomPainter {
  final hourTickMarkLength = 30.0;
  final minuteTickMarkLength = 0.0;

  final hourTickMarkWidth = 1.5;
  final minuteTickMarkWidth = 1.0;

  final Paint tickPaint;
  final TextPainter textPainter;
  final TextStyle textStyle;

  int end;
  int start;
  double value;
  String fontFamily;
  CounterAlign counterAlign;
  double width;
  bool isDecimal;

  GaugeTextCounter({this.isDecimal,this.width,this.counterAlign,this.start, this.end, this.value,this.fontFamily,this.textStyle,})
      : tickPaint = new Paint(),
        textPainter = new TextPainter(
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ){
    tickPaint.color = Colors.green;
  }
  @override
  void paint(Canvas canvas, Size size) {
    final angle = 2 * pi / 60;
    final radius = size.width / 2;
    canvas.save();
    canvas.translate(radius, radius);
    for (var i = 0; i <= 60; i++) {

      if (i == 30) {

        String label;

        if(isDecimal == true){
          label = this.value.toStringAsFixed(1);
        }else{
          label = (this.value.toInt()).toString();
        }

        canvas.save();

        if(counterAlign == CounterAlign.bottom){
          canvas.translate(0.0, -radius + (60) );
        }else if(counterAlign == CounterAlign.top){
          canvas.translate(0.0, radius - (40));
        }

        textPainter.text = new TextSpan(
            text: label,
            style: textStyle
        );
        canvas.rotate(-angle * i);

        textPainter.layout();

        textPainter.paint(canvas, new Offset(-(textPainter.width / 2), counterAlign == CounterAlign.center ?-width :0));

        canvas.restore();
      }

      canvas.rotate(angle);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(GaugeTextCounter oldDelegate) {
    return false;
  }
}

