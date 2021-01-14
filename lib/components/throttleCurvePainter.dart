import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CurvePainter extends CustomPainter {
  static int _paintWidth;
  static double _exponent;
  static double _exponentNegative;

  CurvePainter({int width, double exp, double expNegative}) {
    _paintWidth = width;
    _exponent = exp;
    _exponentNegative = expNegative;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint();
    paint.color = Colors.green[800];
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;

    var path = Path();
    path.moveTo(0, size.height);

    //TODO: draw brake curve... almost got it? take a look at https://www.dartographer.com/bezier/
    path.quadraticBezierTo((_paintWidth/4) + _paintWidth * _exponentNegative, (size.height * 0.75) + size.height * _exponentNegative, _paintWidth / 2.0, size.height / 2.0);

    //TODO: draw throttle curve...
    path.quadraticBezierTo((_paintWidth* 0.75) + _paintWidth * -_exponent, (size.height / 4) + size.height * -_exponent, _paintWidth.toDouble(), 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}