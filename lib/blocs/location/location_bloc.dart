import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  LocationBloc() : super(const LocationInitial()) {
    on<LocationStarted>(_onStarted);
    on<LocationStopped>(_onStopped);
    on<LocationUpdated>(_onUpdated);
    on<LocationRouteCleared>(_onRouteCleared);
    on<LocationPermissionGranted>(_onPermissionGranted);
    on<LocationPermissionDenied>(_onPermissionDenied);
  }

  StreamSubscription<Position> _positionSubscription;

  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
  );

  Future<void> _onStarted(LocationStarted event, Emitter<LocationState> emit) async {
    if (!await GeolocatorPlatform.instance.isLocationServiceEnabled()) {
      emit(const LocationError('Location services disabled'));
      return;
    }

    LocationPermission permission = await GeolocatorPlatform.instance.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await GeolocatorPlatform.instance.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      emit(const LocationPermissionDenied());
      return;
    }

    emit(const LocationTracking());
    await _positionSubscription?.cancel();
    _positionSubscription = GeolocatorPlatform.instance
        .getPositionStream(locationSettings: _locationSettings)
        .listen((position) => add(LocationUpdated(position)));
  }

  void _onStopped(LocationStopped event, Emitter<LocationState> emit) {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    emit(const LocationInitial());
  }

  void _onUpdated(LocationUpdated event, Emitter<LocationState> emit) {
    final pos = event.position;
    final newLocation = LatLng(pos.latitude, pos.longitude);

    if (state is! LocationTracking) {
      emit(LocationTracking(current: newLocation, route: [newLocation]));
      return;
    }

    final current = state as LocationTracking;
    final route = List<LatLng>.from(current.route);

    if (route.isEmpty) {
      route.add(newLocation);
    } else {
      route[route.length - 1] = newLocation;
      final last = route.length > 1 ? route[route.length - 2] : route.last;
      final latDiff = (newLocation.latitude - last.latitude).abs();
      final lngDiff = (newLocation.longitude - last.longitude).abs();
      if (latDiff > 0.00005 && lngDiff > 0.00005) {
        route.add(newLocation);
      }
    }

    emit(current.copyWith(current: newLocation, route: route));
  }

  void _onRouteCleared(LocationRouteCleared event, Emitter<LocationState> emit) {
    if (state is LocationTracking) {
      final current = state as LocationTracking;
      emit(current.copyWith(route: current.current != null ? [current.current] : []));
    }
  }

  void _onPermissionGranted(LocationPermissionGranted event, Emitter<LocationState> emit) {
    add(const LocationStarted());
  }

  void _onPermissionDenied(LocationPermissionDenied event, Emitter<LocationState> emit) {
    emit(const LocationPermissionDenied());
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }
}
