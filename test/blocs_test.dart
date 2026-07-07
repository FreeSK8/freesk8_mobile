// Unit tests for the flutter_bloc state layer and core data models.
// These are pure Dart (no plugins), so they run anywhere `flutter test` does.

import 'package:flutter_test/flutter_test.dart';

import 'package:freesk8_mobile/blocs/preferences/preferences_state.dart';
import 'package:freesk8_mobile/blocs/telemetry/telemetry_bloc.dart';
import 'package:freesk8_mobile/blocs/telemetry/telemetry_state.dart';
import 'package:freesk8_mobile/blocs/location/location_bloc.dart';
import 'package:freesk8_mobile/blocs/location/location_state.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/mcConf.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/appConf.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:freesk8_mobile/components/userSettings.dart';

void main() {
  group('PreferencesState', () {
    test('defaults match historical app defaults', () {
      const state = PreferencesState();
      expect(state.showWhWithRegen, true);
      expect(state.fontSizeValues, 30.0);
      expect(state.rideLogSortClause, 'date_created DESC');
      expect(state.loaded, false);
    });

    test('showPowerState cycles volts/percentage correctly', () {
      const base = PreferencesState();
      expect(base.showPowerState, 0);
      expect(base.copyWith(showVoltsPerCell: true).showPowerState, 1);
      expect(base.copyWith(showBatteryPercentage: true).showPowerState, 2);
    });

    test('copyWith preserves unset fields', () {
      const state = PreferencesState(fontSizeValues: 42.0);
      final copy = state.copyWith(hideMap: true);
      expect(copy.fontSizeValues, 42.0);
      expect(copy.hideMap, true);
      expect(copy.showWhWithRegen, state.showWhWithRegen);
    });
  });

  group('TelemetryBloc', () {
    test('starts in TelemetryInitial', () {
      final bloc = TelemetryBloc();
      expect(bloc.state, const TelemetryInitial());
      bloc.close();
    });

    test('updateTelemetry transitions to TelemetryActive with packet', () async {
      final bloc = TelemetryBloc();
      final packet = ESCTelemetry()..v_in = 42.5;
      bloc.updateTelemetry(packet, {0: packet});
      await expectLater(
        bloc.stream,
        emits(isA<TelemetryActive>()
            .having((s) => s.packet?.v_in, 'packet.v_in', 42.5)
            .having((s) => s.telemetryMap.length, 'map size', 1)),
      );
      bloc.close();
    });

    test('resetForDisconnect returns to TelemetryInitial', () async {
      final bloc = TelemetryBloc();
      bloc.updateTelemetry(ESCTelemetry(), const {});
      bloc.resetForDisconnect();
      await expectLater(
        bloc.stream,
        emitsThrough(const TelemetryInitial()),
      );
      bloc.close();
    });
  });

  group('LocationBloc', () {
    test('starts in LocationInitial', () {
      final bloc = LocationBloc();
      expect(bloc.state, const LocationInitial());
      bloc.close();
    });
  });

  group('Data models (null-safety defaults)', () {
    test('ESCTelemetry default-initializes all fields', () {
      final t = ESCTelemetry();
      expect(t.v_in, 0);
      expect(t.fault_code, mc_fault_code.FAULT_CODE_NONE);
      expect(t.speed, 0);
      expect(t.battery_level, 0);
    });

    test('MCCONF default-initializes limits and tables', () {
      final conf = MCCONF();
      expect(conf.l_current_max, 0);
      expect(conf.hall_table.length, 8);
      expect(conf.foc_offsets_current.length, 3);
      expect(conf.bms, isNotNull);
    });

    test('APPCONF default-initializes sub-configs', () {
      final conf = APPCONF();
      expect(conf.app_ppm_conf, isNotNull);
      expect(conf.app_adc_conf, isNotNull);
      expect(conf.imu_conf.accel_offsets.length, 3);
      expect(conf.app_nrf_conf.address.length, 3);
    });

    test('UserSettingsStructure defaults match prefs fallbacks', () {
      final s = UserSettingsStructure();
      expect(s.batterySeriesCount, 12);
      expect(s.batteryCellMinVoltage, 3.2);
      expect(s.batteryCellMaxVoltage, 4.2);
      expect(s.wheelDiameterMillimeters, 110);
      expect(s.motorPoles, 14);
      expect(s.gearRatio, 4.0);
      expect(s.boardAlias, 'Unnamed');
      expect(s.boardAvatarPath, isNull);
      expect(s.showDebugLogOnShake, true);
    });

    test('ESCProfile defaults match prefs fallbacks', () {
      final p = ESCProfile();
      expect(p.profileName, 'Unnamed');
      expect(p.speedKmh, 32.0);
      expect(p.speedKmhRev, -32.0);
      expect(p.l_current_min_scale, 1.0);
      expect(p.l_current_max_scale, 1.0);
    });
  });
}
