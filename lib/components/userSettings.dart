import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../globalUtilities.dart';

class UserSettingsStructure {
  bool useImperial;
  bool useFahrenheit;

  //TODO: these are technically board settings below
  String boardAlias;
  String boardAvatarPath;

  int batterySeriesCount;
  double batteryCellMinVoltage;
  double batteryCellMaxVoltage;

  int wheelDiameterMillimeters;
  int motorPoles;
  double maxERPM;
  double gearRatio;

  String deviceID;

  @override
  String toString(){
    return jsonEncode(this.toJson());
  }

  Map<String, dynamic> toJson() =>
      {
        'version': 0,
        'deviceID' : deviceID,
        'boardAlias': this.boardAlias,
        'boardAvatarPath': boardAvatarPath,
        'wheelDiameterMillimeters': wheelDiameterMillimeters,
        'motorPoles': motorPoles,
        'gearRatio': gearRatio,
      };
}


class UserSettings {
  UserSettingsStructure settings;
  String currentDeviceID;
  List<String> knownDevices;

  UserSettings({this.settings, this.currentDeviceID, this.knownDevices}) {
    settings = new UserSettingsStructure();
    knownDevices = [];
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
    globalLogger.d("Loading settings for $currentDeviceID");

    await _getSettings();

    if (!isKnownDevice()) {
      globalLogger.d(
          "Device $currentDeviceID has been initialized with default values");
      return Future.value(false);
    } else {
      globalLogger.d(
          "Device $currentDeviceID was a known device. Congratulations.");
      return Future.value(true);
    }
  }

  void reloadSettings() async {
    _getSettings();
  }

  Future<void> _getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't set knownDevices to null - This will happen if there are no saved ESCs hardware IDs on the device
    knownDevices =
    prefs.getStringList('knownDevices') != null ? prefs.getStringList(
        'knownDevices') : knownDevices;

    settings.useImperial = prefs.getBool('useImperial') ?? false;
    settings.useFahrenheit = prefs.getBool('useFahrenheit') ?? false;

    settings.boardAlias =
        prefs.getString('$currentDeviceID boardAlias') ?? "Unnamed";

    settings.boardAvatarPath =
        prefs.getString('$currentDeviceID boardAvatarPath') ?? null;

    settings.batterySeriesCount =
        prefs.getInt('$currentDeviceID batterySeriesCount') ?? 12;
    settings.batteryCellMinVoltage =
        prefs.getDouble('$currentDeviceID batteryCellMinVoltage') ?? 3.2;
    settings.batteryCellMaxVoltage =
        prefs.getDouble('$currentDeviceID batteryCellMaxVoltage') ?? 4.2;

    settings.wheelDiameterMillimeters =
        prefs.getInt('$currentDeviceID wheelDiameterMillimeters') ?? 110;
    settings.motorPoles = prefs.getInt('$currentDeviceID motorPoles') ?? 14;

    settings.maxERPM = prefs.getDouble('$currentDeviceID maxERPM') ?? 100000;
    settings.gearRatio = prefs.getDouble('$currentDeviceID gearRatio') ?? 4.0;

    settings.deviceID = currentDeviceID;
  }

  Future<void> saveSettings() async {
    globalLogger.d("Saving settings for $currentDeviceID");
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('useImperial', settings.useImperial);
    await prefs.setBool('useFahrenheit', settings.useFahrenheit);

    // Do not allow the internal "defaults" profile to update the board image or alias
    if (currentDeviceID != "defaults") {
      await prefs.setString('$currentDeviceID boardAlias', settings.boardAlias);
      await prefs.setString(
          '$currentDeviceID boardAvatarPath', settings.boardAvatarPath);
    }

    await prefs.setInt(
        '$currentDeviceID batterySeriesCount', settings.batterySeriesCount);
    await prefs.setDouble('$currentDeviceID batteryCellMinVoltage',
        settings.batteryCellMinVoltage);
    await prefs.setDouble('$currentDeviceID batteryCellMaxVoltage',
        settings.batteryCellMaxVoltage);

    await prefs.setInt('$currentDeviceID wheelDiameterMillimeters',
        settings.wheelDiameterMillimeters);
    await prefs.setInt('$currentDeviceID motorPoles', settings.motorPoles);

    await prefs.setDouble('$currentDeviceID maxERPM', settings.maxERPM);
    await prefs.setDouble('$currentDeviceID gearRatio', settings.gearRatio);

    if (!isKnownDevice()) {
      knownDevices.add(currentDeviceID);
      globalLogger.d("Adding $currentDeviceID to known devices $knownDevices");
      await prefs.setStringList('knownDevices', knownDevices);
    }
  }

  ///Helper methods for FutureBuilders
  static Future<String> getBoardAvatarPath(String deviceID) async {
    final prefs = await SharedPreferences.getInstance();
    String avatarPath = prefs.getString('$deviceID boardAvatarPath');

    if (avatarPath != null) {
      avatarPath = "${(await getApplicationDocumentsDirectory()).path}$avatarPath";
    }

    return avatarPath;
  }

  static Future<String> getBoardAlias(String deviceID) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$deviceID boardAlias') ?? null;
  }
}

Future<File> exportSettings(String filePath) async {
  final prefs = await SharedPreferences.getInstance();
  File exportFile = File(filePath);
  UserSettings settings = UserSettings();

  exportFile.writeAsStringSync("[");

  List<String> knownDevices = prefs.getStringList('knownDevices');
  for (int i=0; i<knownDevices.length; ++i) {
    await settings.loadSettings(knownDevices[i]);
    globalLogger.wtf(settings.settings.toString());
    exportFile.writeAsBytesSync(utf8.encode(settings.settings.toString()), mode: FileMode.append);
    if (i!=knownDevices.length-1) {
      exportFile.writeAsStringSync(",", mode: FileMode.append);
    } else {
      exportFile.writeAsStringSync("]", mode: FileMode.append);
    }
  }

  return exportFile;
}

Future<bool> importSettings(String filePath) async {
  File importFile = File(filePath);
  print(importFile.readAsStringSync());
  List<dynamic> jsonSettings = json.decode(importFile.readAsStringSync());

  jsonSettings.forEach((value) async {
    if (value['version'] != 0) {
      globalLogger.e("importSettings: version mismatch: expected 0 received: ${value['version']}");
      return false;
    }
    globalLogger.wtf(value);
    UserSettings importSettings = UserSettings();
    await importSettings.loadSettings(value['deviceID']);
    importSettings.settings.motorPoles = value['motorPoles'];
    importSettings.settings.wheelDiameterMillimeters = value['wheelDiameterMillimeters'];
    importSettings.settings.boardAvatarPath = value['boardAvatarPath'];
    importSettings.settings.boardAlias = value['boardAlias'];
    importSettings.settings.gearRatio = value['gearRatio'];
    await importSettings.saveSettings();
  });

  return true;
}