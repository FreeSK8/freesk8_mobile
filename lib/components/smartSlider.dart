
import 'package:flutter/material.dart';

///
/// A slider that doesn't shit it's pants when you give a value outside min<>max :tada:
///
class SmartSlider extends Slider {

  const SmartSlider({
    @required this.value,
    @required this.onChanged,
    @required this.mini, //TODO: super().assert(value >= min && value <= max) will fail without renaming
    @required this.maxi, //TODO: Discover a way to use min/max without failing super()'s assert
    @required this.divisions,
    @required this.label,
  })
      : assert(value != null),
        assert(mini != null),
        assert(maxi != null),
        assert(mini <= maxi),
        assert(divisions == null || divisions > 0),
        super(
          value: value,
          onChanged: onChanged,
          min: mini < value ? mini : value,
          max: maxi > value ? maxi : value,
          divisions: divisions,
          label: label
        );

  /// The currently selected value for this slider.
  ///
  /// The slider's thumb is drawn at a position that corresponds to this value.
  final double value;

  /// Called during a drag when the user is selecting a new value for the slider
  /// by dragging.
  ///
  /// The slider passes the new value to the callback but does not actually
  /// change state until the parent widget rebuilds the slider with the new
  /// value.
  ///
  /// If null, the slider will be displayed as disabled.
  ///
  /// The callback provided to onChanged should update the state of the parent
  /// [StatefulWidget] using the [State.setState] method, so that the parent
  /// gets rebuilt; for example:
  ///
  /// {@tool snippet}
  ///
  /// ```dart
  /// Slider(
  ///   value: _duelCommandment.toDouble(),
  ///   min: 1.0,
  ///   max: 10.0,
  ///   divisions: 10,
  ///   label: '$_duelCommandment',
  ///   onChanged: (double newValue) {
  ///     setState(() {
  ///       _duelCommandment = newValue.round();
  ///     });
  ///   },
  /// )
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [onChangeStart] for a callback that is called when the user starts
  ///    changing the value.
  ///  * [onChangeEnd] for a callback that is called when the user stops
  ///    changing the value.
  final ValueChanged<double> onChanged;

  /// The minimum value the user can select.
  ///
  /// Defaults to 0.0. Must be less than or equal to [maxi].
  ///
  /// If the [maxi] is equal to the [mini], then the slider is disabled.
  final double mini;

  /// The maximum value the user can select.
  ///
  /// Defaults to 1.0. Must be greater than or equal to [mini].
  ///
  /// If the [maxi] is equal to the [mini], then the slider is disabled.
  final double maxi;

  /// The number of discrete divisions.
  ///
  /// Typically used with [label] to show the current discrete value.
  ///
  /// If null, the slider is continuous.
  final int divisions;

  /// A label to show above the slider when the slider is active.
  ///
  /// It is used to display the value of a discrete slider, and it is displayed
  /// as part of the value indicator shape.
  ///
  /// The label is rendered using the active [ThemeData]'s [TextTheme.bodyText1]
  /// text style, with the theme data's [ColorScheme.onPrimary] color. The
  /// label's text style can be overridden with
  /// [SliderThemeData.valueIndicatorTextStyle].
  ///
  /// If null, then the value indicator will not be displayed.
  ///
  /// Ignored if this slider is created with [Slider.adaptive].
  ///
  /// See also:
  ///
  ///  * [SliderComponentShape] for how to create a custom value indicator
  ///    shape.
  final String label;

}