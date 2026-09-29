import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Calls [onPhoneShake] when the accelerometer reports [minimumShakeCount]
/// strong movements within [shakeCountResetTime].
class ShakeDetector {
  ShakeDetector({
    required this.onPhoneShake,
    this.shakeThresholdGravity = 3.5,
    this.shakeSlopTimeMS = 100,
    this.shakeCountResetTime = 750,
    this.minimumShakeCount = 3,
  });

  final void Function() onPhoneShake;

  /// Acceleration, in multiples of g, that counts as a shake.
  final double shakeThresholdGravity;

  /// Minimum time between two counted shakes.
  final int shakeSlopTimeMS;

  /// Time after which the shake count starts again from zero.
  final int shakeCountResetTime;

  /// Number of shakes needed to trigger [onPhoneShake].
  final int minimumShakeCount;

  int _shakeTimestamp = DateTime.now().millisecondsSinceEpoch;
  int _shakeCount = 0;
  StreamSubscription<AccelerometerEvent>? _subscription;

  bool get isListening => _subscription != null;

  void startListening() {
    if (_subscription != null) return;
    _subscription = accelerometerEventStream().listen(_onEvent, onError: (_) {
      // Devices without an accelerometer (or simulators) never shake.
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onEvent(AccelerometerEvent event) {
    final gX = event.x / 9.80665;
    final gY = event.y / 9.80665;
    final gZ = event.z / 9.80665;
    final gForce = sqrt(gX * gX + gY * gY + gZ * gZ);
    if (gForce <= shakeThresholdGravity) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_shakeTimestamp + shakeSlopTimeMS > now) return;
    if (_shakeTimestamp + shakeCountResetTime < now) {
      _shakeCount = 0;
    }
    _shakeTimestamp = now;
    _shakeCount++;
    if (_shakeCount >= minimumShakeCount) {
      _shakeCount = 0;
      onPhoneShake();
    }
  }
}
