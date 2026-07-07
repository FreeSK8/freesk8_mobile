import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

abstract class LocationState extends Equatable {
  const LocationState();
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {
  const LocationInitial();
}

class LocationPermissionPending extends LocationState {
  const LocationPermissionPending();
}

class LocationPermissionDenied extends LocationState {
  const LocationPermissionDenied();
}

class LocationTracking extends LocationState {
  const LocationTracking({this.current, this.route = const []});
  final LatLng? current;
  final List<LatLng> route;

  LocationTracking copyWith({LatLng? current, List<LatLng>? route}) {
    return LocationTracking(
      current: current ?? this.current,
      route: route ?? this.route,
    );
  }

  @override
  List<Object?> get props => [current, route];
}

class LocationError extends LocationState {
  const LocationError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
