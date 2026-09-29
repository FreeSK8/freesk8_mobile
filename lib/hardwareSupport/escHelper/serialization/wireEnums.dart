import '../../../globalUtilities.dart';

/// Helpers for mapping firmware wire indices to Dart enum members.
///
/// The firmware encodes enums as a single byte whose meaning depends on the
/// firmware version (members get added and, occasionally, removed). The
/// generated serializers pass a per-version table; these helpers never throw
/// on a value this build does not know, they fall back to the first member.

T enumFromWire<T>(List<T> wire, int value, String field) {
  if (value >= 0 && value < wire.length) {
    return wire[value];
  }
  globalLogger.w("enumFromWire: $field wire value $value is outside 0..${wire.length - 1}; using ${wire.first}");
  return wire.first;
}

int enumToWire<T>(List<T> wire, T value, String field) {
  final int index = wire.indexOf(value);
  if (index >= 0) {
    return index;
  }
  globalLogger.w("enumToWire: $field value $value is not available on this firmware; writing 0 (${wire.first})");
  return 0;
}

T enumFromWireMap<T>(Map<int, T> wire, int value, String field) {
  final T? found = wire[value];
  if (found != null) {
    return found;
  }
  globalLogger.w("enumFromWireMap: $field wire value $value is unknown; using ${wire.values.first}");
  return wire.values.first;
}

int enumToWireMap<T>(Map<int, T> wire, T value, String field) {
  for (final MapEntry<int, T> entry in wire.entries) {
    if (entry.value == value) {
      return entry.key;
    }
  }
  globalLogger.w("enumToWireMap: $field value $value is not available on this firmware; writing ${wire.keys.first}");
  return wire.keys.first;
}
