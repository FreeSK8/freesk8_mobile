import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:freesk8_mobile/escHelper/appConf.dart';

class CurvePainter extends CustomPainter {
  static int _paintWidth;
  static double _exponent;
  static double _exponentNegative;
  static thr_exp_mode _exponentMode;

  CurvePainter({int width, double exp, double expNegative, thr_exp_mode expMode}) {
    _paintWidth = width;
    _exponent = exp;
    _exponentNegative = expNegative;
    _exponentMode = expMode;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint();
    paint.color = Colors.green[800];
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4.0;

    var path = Path();

    List<double> x = new List();
    List<double> y = new List();
    for (double i = -1.0;i < 1.0001;i += 0.002) {
      x.add(i * _paintWidth);
      double val = throttle_curve(i, _exponent, _exponentNegative, _exponentMode);
      y.add(size.height - ((val + 1) * size.height/2));
    }

    List<Offset> points = new List();
    for (int i=0; i<x.length; ++i) {
      if (x[i].isNaN || y[i].isNaN) {
        continue;
      }
      points.add(Offset(x[i], y[i]));
    }
    path.addPolygon(points, false);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }

  double throttle_curve(double val, double curve_acc, double curve_brake, thr_exp_mode mode)
  {
    double ret = 0.0;
    double val_a = val.abs();

    if (val < -1.0) {
      val = -1.0;
    }

    if (val > 1.0) {
      val = 1.0;
    }

    double curve;
    if (val >= 0.0) {
      curve = curve_acc;
    } else {
      curve = curve_brake;
    }

    // See
    // http://math.stackexchange.com/questions/297768/how-would-i-create-a-exponential-ramp-function-from-0-0-to-1-1-with-a-single-val
    if (mode == thr_exp_mode.THR_EXP_EXPO) { // Power
      if (curve >= 0.0) {
        ret = 1.0 - pow(1.0 - val_a, 1.0 + curve);
      } else {
        ret = pow(val_a, 1.0 - curve);
      }
    } else if (mode == thr_exp_mode.THR_EXP_NATURAL) { // Exponential
      if (curve.abs() < 1e-10) {
        ret = val_a;
      } else {
        if (curve >= 0.0) {
          ret = 1.0 - ((exp(curve * (1.0 - val_a)) - 1.0) / (exp(curve) - 1.0));
        } else {
          ret = (exp(-curve * val_a) - 1.0) / (exp(-curve) - 1.0);
        }
      }
    } else if (mode == thr_exp_mode.THR_EXP_POLY) { // Polynomial
      if (curve >= 0.0) {
        ret = 1.0 - ((1.0 - val_a) / (1.0 + curve * val_a));
      } else {
        ret = val_a / (1.0 - curve * (1.0 - val_a));
      }
    } else { // Linear
      ret = val_a;
    }

    if (val < 0.0) {
      ret = -ret;
    }

    return ret;
  }
}