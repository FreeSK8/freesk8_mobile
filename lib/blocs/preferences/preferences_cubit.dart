import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'preferences_state.dart';

class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit() : super(const PreferencesState());

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    emit(state.copyWith(
      showWhWithRegen: prefs.getBool('rtShowWhWithRegen'),
      showVoltsPerCell: prefs.getBool('rtShowVoltsPerCell'),
      showBatteryPercentage: prefs.getBool('rtShowBatteryPercentage'),
      showRangeEstimate: prefs.getBool('rtShowRangeEstimate'),
      hideMap: prefs.getBool('rtShowMap'),
      allowFontResize: prefs.getBool('rtAllowFontResize'),
      fontSizeValues: prefs.getDouble('rtFontSizeValues'),
      rideLogSortClause: prefs.getString('rideLogSortClause'),
      loaded: true,
    ));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rtShowWhWithRegen', state.showWhWithRegen);
    await prefs.setBool('rtShowVoltsPerCell', state.showVoltsPerCell);
    await prefs.setBool('rtShowBatteryPercentage', state.showBatteryPercentage);
    await prefs.setBool('rtShowRangeEstimate', state.showRangeEstimate);
    await prefs.setBool('rtShowMap', state.hideMap);
    await prefs.setBool('rtAllowFontResize', state.allowFontResize);
    await prefs.setDouble('rtFontSizeValues', state.fontSizeValues);
    await prefs.setString('rideLogSortClause', state.rideLogSortClause);
  }

  void toggleWhWithRegen() {
    emit(state.copyWith(showWhWithRegen: !state.showWhWithRegen));
    _persist();
  }

  void toggleRangeEstimate() {
    emit(state.copyWith(showRangeEstimate: !state.showRangeEstimate));
    _persist();
  }

  void cyclePowerDisplay() {
    bool volts = false;
    bool percentage = false;
    if (state.showVoltsPerCell) {
      percentage = true;
    } else if (!state.showBatteryPercentage) {
      volts = true;
    }
    emit(state.copyWith(showVoltsPerCell: volts, showBatteryPercentage: percentage));
    _persist();
  }

  void toggleHideMap() {
    emit(state.copyWith(hideMap: !state.hideMap));
    _persist();
  }

  void toggleAllowFontResize() {
    emit(state.copyWith(allowFontResize: !state.allowFontResize));
    _persist();
  }

  void increaseFontSize() {
    final newSize = (state.fontSizeValues + 1).clamp(10.0, 50.0);
    emit(state.copyWith(fontSizeValues: newSize));
    _persist();
  }

  void decreaseFontSize() {
    final newSize = (state.fontSizeValues - 1).clamp(10.0, 50.0);
    emit(state.copyWith(fontSizeValues: newSize));
    _persist();
  }

  void setRideLogSortClause(String clause) {
    emit(state.copyWith(rideLogSortClause: clause));
    _persist();
  }
}
