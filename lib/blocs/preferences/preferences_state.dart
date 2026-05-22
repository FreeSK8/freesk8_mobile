import 'package:equatable/equatable.dart';

class PreferencesState extends Equatable {
  const PreferencesState({
    this.showWhWithRegen = true,
    this.showVoltsPerCell = false,
    this.showBatteryPercentage = false,
    this.showRangeEstimate = false,
    this.hideMap = false,
    this.allowFontResize = false,
    this.fontSizeValues = 30.0,
    this.rideLogSortClause = 'date_created DESC',
    this.loaded = false,
  });

  final bool showWhWithRegen;
  final bool showVoltsPerCell;
  final bool showBatteryPercentage;
  final bool showRangeEstimate;
  final bool hideMap;
  final bool allowFontResize;
  final double fontSizeValues;
  final String rideLogSortClause;
  final bool loaded;

  int get showPowerState =>
      showBatteryPercentage ? 2 : showVoltsPerCell ? 1 : 0;

  PreferencesState copyWith({
    bool showWhWithRegen,
    bool showVoltsPerCell,
    bool showBatteryPercentage,
    bool showRangeEstimate,
    bool hideMap,
    bool allowFontResize,
    double fontSizeValues,
    String rideLogSortClause,
    bool loaded,
  }) {
    return PreferencesState(
      showWhWithRegen: showWhWithRegen ?? this.showWhWithRegen,
      showVoltsPerCell: showVoltsPerCell ?? this.showVoltsPerCell,
      showBatteryPercentage: showBatteryPercentage ?? this.showBatteryPercentage,
      showRangeEstimate: showRangeEstimate ?? this.showRangeEstimate,
      hideMap: hideMap ?? this.hideMap,
      allowFontResize: allowFontResize ?? this.allowFontResize,
      fontSizeValues: fontSizeValues ?? this.fontSizeValues,
      rideLogSortClause: rideLogSortClause ?? this.rideLogSortClause,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  List<Object> get props => [
        showWhWithRegen,
        showVoltsPerCell,
        showBatteryPercentage,
        showRangeEstimate,
        hideMap,
        allowFontResize,
        fontSizeValues,
        rideLogSortClause,
        loaded,
      ];
}
