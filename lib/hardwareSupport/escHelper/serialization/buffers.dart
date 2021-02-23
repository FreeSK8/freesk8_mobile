import 'dart:math';

import 'dart:typed_data';

int buffer_get_int16(Uint8List buffer, int index) {
  var byteData = new ByteData.view(buffer.buffer);
  return byteData.getInt16(index);
}

int buffer_get_uint16(Uint8List buffer, int index) {
  var byteData = new ByteData.view(buffer.buffer);
  return byteData.getUint16(index);
}

int buffer_get_int32(Uint8List buffer, int index) {
  var byteData = new ByteData.view(buffer.buffer);
  return byteData.getInt32(index);
}

int buffer_get_uint32(Uint8List buffer, int index) {
  var byteData = new ByteData.view(buffer.buffer);
  return byteData.getUint32(index);
}

int buffer_get_uint64(Uint8List buffer, int index, [Endian endian = Endian.big]) {
  var byteData = new ByteData.view(buffer.buffer);
  return byteData.getUint64(index, endian);
}

double buffer_get_float16(Uint8List buffer, int index, double scale) {
  return buffer_get_int16(buffer, index) / scale;
}

double buffer_get_float32(Uint8List buffer, int index, double scale) {
  return buffer_get_int32(buffer, index) / scale;
}

double buffer_get_float32_auto(Uint8List buffer, int index) {
  Uint32List res = new Uint32List(1);
  res[0] = buffer_get_uint32(buffer, index);

  int e = (res[0] >> 23) & 0xFF;
  Uint32List sig_i = new Uint32List(1);
  sig_i[0] = res[0] & 0x7FFFFF;
  int neg_i = res[0] & (1 << 31);
  bool neg = neg_i > 0 ? true : false;

  double sig = 0.0;
  if (e != 0 || sig_i[0] != 0) {
    sig = sig_i[0].toDouble() / (8388608.0 * 2.0) + 0.5;
    e -= 126;
  }

  if (neg) {
    sig = -sig;
  }

  return ldexpf(sig, e);
}

// Multiplies a floating point value arg by the number 2 raised to the exp power.
double ldexpf(double arg, int exp) {
  double result = arg * pow(2, exp);
  return result;
}