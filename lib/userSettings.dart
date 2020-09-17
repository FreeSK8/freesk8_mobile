//part of 'main.dart';

import 'package:shared_preferences/shared_preferences.dart';

class UserSettingsStructure {
  bool useImperial;
  bool useFahrenheit;

  //TODO: these are technically board settings below
  String boardAlias;
  String boardAvatarPath;

  int batterySeriesCount;

  int batteryCellmAH;
  double batteryCellMinVoltage;
  double batteryCellMaxVoltage;

  int wheelDiameterMillimeters;
  int motorPoles;
  double maxERPM;
  double gearRatio;
}


class UserSettings {
  UserSettingsStructure settings;
  String currentDeviceID;
  List<String> knownDevices;

  UserSettings({this.settings, this.currentDeviceID, this.knownDevices}) {
    print("UserSettings() object created");
    settings = new UserSettingsStructure();
    knownDevices = new List();
    currentDeviceID = "defaults";
  }

  bool isKnownDevice() {
    return knownDevices.contains(currentDeviceID);
  }

  bool isDeviceKnown(String deviceID) {
    return knownDevices.contains(deviceID);
  }

  Future<bool> loadSettings(String deviceID) async {
    currentDeviceID = deviceID;
    print("Loading settings for $currentDeviceID");

    await _getSettings();

    if (!isKnownDevice()) {
      print("Device $currentDeviceID has been initialized with default values");
      return Future.value(false);
    } else {
      print("Device $currentDeviceID was a known device. Congratulations.");
      return Future.value(true);
    }
  }

  void reloadSettings() async {
    _getSettings();
  }

  Future<void> _getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't set knownDevices to null - This will happen if there are no saved ESCs hardware IDs on the device
    knownDevices = prefs.getStringList('knownDevices') != null ? prefs.getStringList('knownDevices') : knownDevices;

    settings.useImperial = prefs.getBool('useImperial') ?? false;
    settings.useFahrenheit = prefs.getBool('useFahrenheit') ?? false;

    settings.boardAlias = prefs.getString('$currentDeviceID boardAlias') ?? "Unnamed";

    settings.boardAvatarPath = prefs.getString('$currentDeviceID boardAvatarPath') ?? null;

    settings.batterySeriesCount = prefs.getInt('$currentDeviceID batterySeriesCount') ?? 12;
    settings.batteryCellmAH = prefs.getInt('$currentDeviceID batteryCellmAH') ?? 3000;
    settings.batteryCellMinVoltage = prefs.getDouble('$currentDeviceID batteryCellMinVoltage') ?? 3.2;
    settings.batteryCellMaxVoltage = prefs.getDouble('$currentDeviceID batteryCellMaxVoltage') ?? 4.2;

    settings.wheelDiameterMillimeters = prefs.getInt('$currentDeviceID wheelDiameterMillimeters') ?? 110;
    settings.motorPoles = prefs.getInt('$currentDeviceID motorPoles') ?? 14;

    settings.maxERPM = prefs.getDouble('$currentDeviceID maxERPM') ?? 8800; //TODO: what is a good default maxERPM?
    settings.gearRatio = prefs.getDouble('$currentDeviceID gearRatio') ?? 4.0;
  }

  Future<void> saveSettings() async {
    print("Saving settings for $currentDeviceID");
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('useImperial', settings.useImperial);
    await prefs.setBool('useFahrenheit', settings.useFahrenheit);

    // Do not allow the internal "defaults" profile to update the board image or alias
    if(currentDeviceID != "defaults") {
      await prefs.setString('$currentDeviceID boardAlias', settings.boardAlias);
      await prefs.setString('$currentDeviceID boardAvatarPath', settings.boardAvatarPath);
    }

    await prefs.setInt('$currentDeviceID batterySeriesCount', settings.batterySeriesCount);
    await prefs.setInt('$currentDeviceID batteryCellmAH', settings.batteryCellmAH);
    await prefs.setDouble('$currentDeviceID batteryCellMinVoltage', settings.batteryCellMinVoltage);
    await prefs.setDouble('$currentDeviceID batteryCellMaxVoltage', settings.batteryCellMaxVoltage);

    await prefs.setInt('$currentDeviceID wheelDiameterMillimeters', settings.wheelDiameterMillimeters);
    await prefs.setInt('$currentDeviceID motorPoles', settings.motorPoles);

    await prefs.setDouble('$currentDeviceID maxERPM', settings.maxERPM);
    await prefs.setDouble('$currentDeviceID gearRatio', settings.gearRatio);

    if ( !isKnownDevice() ) {
      knownDevices.add(currentDeviceID);
      print("Adding $currentDeviceID to known devices $knownDevices");
      await prefs.setStringList('knownDevices', knownDevices);
    }
  }

  ///Helper methods for FutureBuilders
  static Future<String> getBoardAvatarPath(String deviceID) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$deviceID boardAvatarPath') ?? null;
  }
  static Future<String> getBoardAlias(String deviceID) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$deviceID boardAlias') ?? null;
  }
}