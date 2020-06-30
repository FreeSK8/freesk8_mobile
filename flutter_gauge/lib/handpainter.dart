import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_gauge/flutter_gauge.dart';

class HandPainter extends CustomPainter{
  final Paint minuteHandPaint;
  double value;
  int start;
  int end;
  Color color;
  double handSize;
  Hand hand;
  double shadowHand;
  bool reverseDial;

  HandPainter({this.reverseDial, this.shadowHand,this.hand,this.value,this.start,this.end,this.color,this.handSize}):minuteHandPaint= new Paint(){
    minuteHandPaint.color= this.color;
    minuteHandPaint.style= PaintingStyle.fill;

  }

  @override
  void paint(Canvas canvas, Size size) {
    int totalRange = this.end - this.start;

    var radius = size.width/2;
    double renderRange = 2/3; //Gauge render range

    double handRotation = (this.value - this.start) / totalRange;

    if( reverseDial ) handRotation = 1 - handRotation;


    double rotateValue = 2*pi*(handRotation*renderRange) - (2*pi/3);
    canvas.save();

    canvas.translate(radius, radius);

    canvas.rotate(rotateValue);
    //print("******************************************************************************handpainter::paint(): ${this.start} ${this.end} totalRange $totalRange renderRange $renderRange handRotation $handRotation rotate value $rotateValue");





    Path path= new Path();
    if(hand == Hand.short){
      path.moveTo(-1.0, -radius-handSize/8.0);
      path.lineTo(-5.0, -radius/1.8);
      path.lineTo(5.0, -radius/1.8);
      path.lineTo(1.0, -radius-handSize/8);
    }else{
      path.moveTo(-1.5, -radius-handSize/3.0);
      path.lineTo(-5.0, -radius/1.8);
      path.lineTo(-handSize/3, handSize/5);/// change 2 => 5
      path.lineTo(handSize/3, handSize/5);/// change 2 => 5
      path.lineTo(5.0, -radius/1.8);
      path.lineTo(1.5, -radius-handSize/3);
    }


    path.close();

    canvas.drawPath(path, minuteHandPaint);
    canvas.drawShadow(path, this.color, shadowHand, false);

    canvas.restore();
  }

  @override
  bool shouldRepaint(HandPainter oldDelegate) {
    return true;
  }
}
