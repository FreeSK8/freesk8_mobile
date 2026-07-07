import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../hardwareSupport/escHelper/escHelper.dart';
import 'ble_connection_event.dart';
import 'ble_connection_state.dart';

// Service / characteristic UUIDs matching main.dart
const _uartServiceUUID        = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
const _txCharacteristicUUID   = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
const _rxCharacteristicUUID   = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
const _txLoggerCharUUID       = "6e400004-b5a3-f393-e0a9-e50e24dcca9e";
const _rxLoggerCharUUID       = "6e400005-b5a3-f393-e0a9-e50e24dcca9e";

class BLEConnectionBloc extends Bloc<BLEConnectionEvent, BLEConnectionState> {
  BLEConnectionBloc() : super(const BLEIdle()) {
    on<BLEScanStarted>(_onScanStarted);
    on<BLEScanStopped>(_onScanStopped);
    on<BLEScanResultsUpdated>(_onScanResultsUpdated);
    on<BLEConnectRequested>(_onConnectRequested);
    on<BLEDisconnectRequested>(_onDisconnectRequested);
    on<BLEConnectionStateChanged>(_onConnectionStateChanged);
    on<BLEServicesDiscovered>(_onServicesDiscovered);
    on<BLEFirmwareVersionReceived>(_onFirmwareVersionReceived);
    on<BLEDeviceVersionReceived>(_onDeviceVersionReceived);
  }

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  Future<void> _onScanStarted(BLEScanStarted event, Emitter<BLEConnectionState> emit) async {
    emit(const BLEScanning());
    await _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) => add(BLEScanResultsUpdated(results)),
    );
    try {
      await FlutterBluePlus.startScan(withServices: [Guid(_uartServiceUUID)]);
    } catch (e) {
      emit(BLEError('Scan failed: $e'));
    }
  }

  Future<void> _onScanStopped(BLEScanStopped event, Emitter<BLEConnectionState> emit) async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (state is BLEScanning) emit(const BLEIdle());
  }

  void _onScanResultsUpdated(BLEScanResultsUpdated event, Emitter<BLEConnectionState> emit) {
    if (state is BLEScanning) {
      emit(BLEScanning(results: event.results));
    }
  }

  Future<void> _onConnectRequested(BLEConnectRequested event, Emitter<BLEConnectionState> emit) async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    emit(BLEConnecting(event.device));

    await _connectionSubscription?.cancel();
    _connectionSubscription = event.device.connectionState.listen(
      (cs) => add(BLEConnectionStateChanged(cs)),
    );

    try {
      await event.device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
    } catch (e) {
      emit(BLEError('Connection failed: $e'));
    }
  }

  Future<void> _onDisconnectRequested(BLEDisconnectRequested event, Emitter<BLEConnectionState> emit) async {
    if (state is BLEConnected) {
      final connected = state as BLEConnected;
      emit(const BLEDisconnecting());
      await connected.device?.disconnect();
    }
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    emit(const BLEIdle());
  }

  void _onConnectionStateChanged(BLEConnectionStateChanged event, Emitter<BLEConnectionState> emit) {
    if (event.connectionState == BluetoothConnectionState.connected) {
      // Service discovery is triggered by main.dart after connection
      if (state is BLEConnecting) {
        final device = (state as BLEConnecting).device;
        emit(BLEConnected(device: device));
      }
    } else if (event.connectionState == BluetoothConnectionState.disconnected) {
      if (state is BLEConnected) {
        emit(BLEUnexpectedDisconnect((state as BLEConnected).device!));
      } else if (state is! BLEDisconnecting && state is! BLEIdle) {
        emit(const BLEIdle());
      }
    }
  }

  void _onServicesDiscovered(BLEServicesDiscovered event, Emitter<BLEConnectionState> emit) {
    if (state is! BLEConnected) return;

    final current = state as BLEConnected;
    BluetoothCharacteristic? txChar;
    BluetoothCharacteristic? rxChar;
    BluetoothCharacteristic? txLoggerChar;
    BluetoothCharacteristic? rxLoggerChar;

    for (final service in event.services) {
      if (service.uuid == Guid(_uartServiceUUID)) {
        for (final char in service.characteristics) {
          if (char.uuid == Guid(_txCharacteristicUUID)) txChar = char;
          else if (char.uuid == Guid(_rxCharacteristicUUID)) rxChar = char;
          else if (char.uuid == Guid(_txLoggerCharUUID)) txLoggerChar = char;
          else if (char.uuid == Guid(_rxLoggerCharUUID)) rxLoggerChar = char;
        }
      }
    }

    if (txChar == null || rxChar == null) {
      emit(const BLEError('Required BLE characteristics not found'));
      return;
    }

    final deviceType = (txLoggerChar != null && rxLoggerChar != null)
        ? BLEDeviceType.robogotchi
        : BLEDeviceType.escDirect;

    emit(current.copyWith(
      txChar: txChar,
      rxChar: rxChar,
      txLoggerChar: txLoggerChar,
      rxLoggerChar: rxLoggerChar,
      deviceType: deviceType,
    ));
  }

  void _onFirmwareVersionReceived(BLEFirmwareVersionReceived event, Emitter<BLEConnectionState> emit) {
    if (state is BLEConnected) {
      emit((state as BLEConnected).copyWith(firmwarePacket: event.firmware));
    }
  }

  void _onDeviceVersionReceived(BLEDeviceVersionReceived event, Emitter<BLEConnectionState> emit) {
    if (state is BLEConnected) {
      final current = state as BLEConnected;
      final newType = event.isGotchiPro ? BLEDeviceType.gotchiPro : current.deviceType;
      emit(current.copyWith(deviceVersion: event.version, deviceType: newType));
    }
  }

  @override
  Future<void> close() async {
    await _scanSubscription?.cancel();
    await _connectionSubscription?.cancel();
    return super.close();
  }
}
