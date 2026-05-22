import 'package:equatable/equatable.dart';
import 'package:geolocator/geolocator.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();
  @override
  List<Object> get props => [];
}

class LocationStarted extends LocationEvent {
  const LocationStarted();
}

class LocationStopped extends LocationEvent {
  const LocationStopped();
}

class LocationUpdated extends LocationEvent {
  const LocationUpdated(this.position);
  final Position position;
  @override
  List<Object> get props => [position];
}

class LocationRouteCleared extends LocationEvent {
  const LocationRouteCleared();
}

class LocationPermissionGranted extends LocationEvent {
  const LocationPermissionGranted();
}

class LocationPermissionDenied extends LocationEvent {
  const LocationPermissionDenied();
}
