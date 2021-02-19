/// Flutter extension for logger
library logger_flutter;

import 'dart:collection';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

import 'src/ansi_parser.dart';
import 'src/shake_detector.dart';

import 'package:esys_flutter_share/esys_flutter_share.dart';

part 'src/log_console_on_shake.dart';
part 'src/log_console.dart';
