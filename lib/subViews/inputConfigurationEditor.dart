
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_blue/flutter_blue.dart';
import 'package:freesk8_mobile/components/crc16.dart';
import 'package:freesk8_mobile/components/smartSlider.dart';

import 'package:freesk8_mobile/globalUtilities.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/appConf.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/dataTypes.dart';
import 'package:freesk8_mobile/hardwareSupport/escHelper/escHelper.dart';


import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:freesk8_mobile/widgets/throttleCurvePainter.dart';

class InputCalibration {
  bool ppmCalibrationStarting;
  bool ppmCalibrationRunning;
  int ppmValueNow;
  int ppmMillisecondsNow;

  bool adcCalibrationStarting;
  bool adcCalibrationRunning;
  double adcLevelNow;
  double adcVoltageNow;
  double adcLevel2Now;
  double adcVoltage2Now;
}

class InputConfigurationArguments {

  final Stream calibrationStream;
  final Stream dataStream;
  final BluetoothCharacteristic theTXCharacteristic;
  final APPCONF applicationConfiguration;
  final List<int> discoveredCANDevices;
  final ESC_FIRMWARE escFirmwareVersion;
  final ValueChanged<bool> notifyStopStartADCCalibrate;
  final ValueChanged<bool> notifyStopStartPPMCalibrate;
  final InputCalibration calibrationState;


  InputConfigurationArguments({
    @required this.calibrationStream,
    @required this.dataStream,
    @required this.theTXCharacteristic,
    @required this.applicationConfiguration,
    @required this.discoveredCANDevices,
    @required this.escFirmwareVersion,
    @required this.notifyStopStartADCCalibrate,
    @required this.notifyStopStartPPMCalibrate,
    @required this.calibrationState,
  });
}

class InputConfigurationEditor extends StatefulWidget {
  @override
  InputConfigurationEditorState createState() => InputConfigurationEditorState();

  static const String routeName = "/inputconfiguration";
}

class InputConfigurationEditorState extends State<InputConfigurationEditor> {
  bool changesMade = false; //TODO: remove if unused

  static InputConfigurationArguments myArguments;

  static StreamSubscription<InputCalibration> calibrationSubscription;
  static StreamSubscription<APPCONF> appconfSubscription;
  static BluetoothCharacteristic theTXCharacteristic;

  static APPCONF escInputConfiguration;
  static ESC_FIRMWARE escFirmwareVersion;

  static List<int> discoveredCANDevices;

  int _selectedCANFwdID;
  int _invalidCANID;
  bool _writeESCInProgress = false;

  //// Balance stuff
  final tecIMUHz = TextEditingController();
  final tecBalanceHz = TextEditingController();
  final tecHalfSwitchFaultDelay = TextEditingController();
  final tecFullSwitchFaultDelay = TextEditingController();
  final tecHalfStateFaultERPM = TextEditingController();
  final tecKP = TextEditingController();
  final tecKI = TextEditingController();
  final tecKD = TextEditingController();
  final tecTiltbackConstantERPM = TextEditingController();


  /// APP Conf
  List<ListItem> _appModeItems = [
    ListItem(app_use.APP_NONE.index, "None"),
    //ListItem(app_use.APP_PPM.index, "PPM"), //TODO: disables uart!?! whoa
    //ListItem(app_use.APP_ADC.index, "ADC"),
    ListItem(app_use.APP_UART.index, "UART"),
    ListItem(app_use.APP_PPM_UART.index, "PPM + UART"),
    ListItem(app_use.APP_ADC_UART.index, "ADC + UART"),
    //ListItem(app_use.APP_NUNCHUK.index, "NUNCHUK"),
    //ListItem(app_use.APP_NRF.index, "NRF"),
    //ListItem(app_use.APP_CUSTOM.index, "CUSTOM"),
    ListItem(app_use.APP_BALANCE.index, "BALANCE"),
  ];
  List<DropdownMenuItem<ListItem>> _appModeDropdownItems;
  ListItem _selectedAppMode;

  List<ListItem> _ppmCtrlTypeItems = [
    ListItem(ppm_control_type.PPM_CTRL_TYPE_NONE.index, "None"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT.index, "Current"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_NOREV.index, "Current No Reverse"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_NOREV_BRAKE.index, "Current No Reverse with Brake"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_DUTY.index, "Duty Cycle"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_DUTY_NOREV.index, "Duty Cycle No Reverse"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_PID.index, "PID Speed Control"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_PID_NOREV.index, "PID Speed Control No Reverse"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_BRAKE_REV_HYST.index, "Current Hysteresis Reverse with Brake"),
    ListItem(ppm_control_type.PPM_CTRL_TYPE_CURRENT_SMART_REV.index, "Current Smart Reverse"),
  ];
  List<DropdownMenuItem<ListItem>> _ppmCtrlTypeDropdownItems;
  ListItem _selectedPPMCtrlType;

  List<ListItem> _thrExpModeItems = [
    ListItem(thr_exp_mode.THR_EXP_EXPO.index, "Exponential"),
    ListItem(thr_exp_mode.THR_EXP_NATURAL.index, "Natural"),
    ListItem(thr_exp_mode.THR_EXP_POLY.index, "Polynomial"),
  ];
  List<DropdownMenuItem<ListItem>> _thrExpModeDropdownItems;
  ListItem _selectedThrExpMode;

  List<ListItem> _nunchukCtrlTypeItems = [
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_NONE.index, "Off"),
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_CURRENT.index, "Current"),
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_CURRENT_NOREV.index, "Current No Reverse"),
    ListItem(chuk_control_type.CHUK_CTRL_TYPE_CURRENT_BIDIRECTIONAL.index, "Current Bidirectional"),
  ];
  List<DropdownMenuItem<ListItem>> _nunchuckCtrlTypeDropdownItems;
  ListItem _selectedNunchukCtrlType;

  List<ListItem> _thrExpModeNunchukItems = [
    ListItem(thr_exp_mode.THR_EXP_EXPO.index, "Exponential"),
    ListItem(thr_exp_mode.THR_EXP_NATURAL.index, "Natural"),
    ListItem(thr_exp_mode.THR_EXP_POLY.index, "Polynomial"),
  ];
  List<DropdownMenuItem<ListItem>> _thrExpModeNunchukDropdownItems;
  ListItem _selectedThrExpModeNunchuk;

  List<ListItem> _adcCtrlTypeItems = [
    ListItem(adc_control_type.ADC_CTRL_TYPE_NONE.index, "None"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT.index, "Current"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT_REV_CENTER.index, "Current Reverse Center"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT_REV_BUTTON.index, "Current Reverse Button"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT_REV_BUTTON_BRAKE_ADC.index, "Current Reverse ADC2 Brake Button"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT_REV_BUTTON_BRAKE_CENTER.index, "Current Reverse Button Brake Center"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT_NOREV_BRAKE_CENTER.index, "Current No Reverse Brake Center"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT_NOREV_BRAKE_BUTTON.index, "Current No Reverse Brake Button"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_CURRENT_NOREV_BRAKE_ADC.index, "Current No Reverse Brake ADC2"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_DUTY.index, "Duty Cycle"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_DUTY_REV_CENTER.index, "Duty Cycle Reverse Center"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_DUTY_REV_BUTTON.index, "Duty Cycle Reverse Button"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_PID.index, "PID Speed"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_PID_REV_CENTER.index, "PID Speed Reverse Center"),
    ListItem(adc_control_type.ADC_CTRL_TYPE_PID_REV_BUTTON.index, "PID Speed Reverse Button"),
  ];
  List<DropdownMenuItem<ListItem>> _adcCtrlTypeDropdownItems;
  ListItem _selectedADCCtrlType;

  static Timer ppmCalibrateTimer;
  bool ppmCalibrate = false;
  ppm_control_type ppmCalibrateControlTypeToRestore;
  int ppmMinMS;
  int ppmMaxMS;
  
  RangeValues _rangeSliderDiscreteValues = const RangeValues(1.5, 1.6);

  bool showAdvancedOptions = false;
  bool showPPMConfiguration = false;
  bool showNunchukConfiguration = false;
  bool showBalanceConfiguration = false;

  static Timer adcCalibrateTimer;
  bool adcCalibrate = false;
  bool showADCConfiguration = false;
  adc_control_type adcCalibrateControlTypeToRestore;
  double adcMinV;
  double adcMaxV;
  double adcMinV2;
  double adcMaxV2;
  
  //Calibration
  InputCalibration calibrationState;

  @override
  void initState() {
    /// ESC Application Configuration
    _appModeDropdownItems = buildDropDownMenuItems(_appModeItems);
    _ppmCtrlTypeDropdownItems = buildDropDownMenuItems(_ppmCtrlTypeItems);
    _thrExpModeDropdownItems = buildDropDownMenuItems(_thrExpModeItems);
    _nunchuckCtrlTypeDropdownItems = buildDropDownMenuItems(_nunchukCtrlTypeItems);
    _thrExpModeNunchukDropdownItems = buildDropDownMenuItems(_thrExpModeNunchukItems);

    /// Balance Configuration
    tecIMUHz.addListener(() { escInputConfiguration.imu_conf.sample_rate_hz = int.tryParse(tecIMUHz.text); });
    tecBalanceHz.addListener(() { escInputConfiguration.app_balance_conf.hertz = int.tryParse(tecBalanceHz.text); });
    tecHalfSwitchFaultDelay.addListener(() { escInputConfiguration.app_balance_conf.fault_delay_switch_half = int.tryParse(tecHalfSwitchFaultDelay.text); });
    tecFullSwitchFaultDelay.addListener(() { escInputConfiguration.app_balance_conf.fault_delay_switch_full = int.tryParse(tecFullSwitchFaultDelay.text); });
    tecHalfStateFaultERPM.addListener(() { escInputConfiguration.app_balance_conf.fault_adc_half_erpm = int.tryParse(tecHalfStateFaultERPM.text); });
    tecKP.addListener(() {
      double newValue = double.tryParse(tecKP.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      escInputConfiguration.app_balance_conf.kp = doublePrecision(newValue, 4);
    });
    tecKI.addListener(() {
      double newValue = double.tryParse(tecKI.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      escInputConfiguration.app_balance_conf.ki = doublePrecision(newValue, 4);
    });
    tecKD.addListener(() {
      double newValue = double.tryParse(tecKD.text.replaceFirst(',', '.'));
      if(newValue==null) newValue = 0.0; //Ensure not null
      if(newValue<0.0) newValue = 0.0; //Ensure greater than 0.0
      escInputConfiguration.app_balance_conf.kd = doublePrecision(newValue, 4);
    });

    tecTiltbackConstantERPM.addListener(() { escInputConfiguration.app_balance_conf.tiltback_constant_erpm = int.tryParse(tecTiltbackConstantERPM.text); });

    /// ADC Application Configuration
    _adcCtrlTypeDropdownItems = buildDropDownMenuItems(_adcCtrlTypeItems);
    
    super.initState();
  }

  @override
  void dispose() {
    calibrationSubscription?.cancel();
    calibrationSubscription = null;

    appconfSubscription?.cancel();
    appconfSubscription = null;
    
    escInputConfiguration = null;

    tecIMUHz.dispose();
    tecBalanceHz.dispose();
    tecHalfSwitchFaultDelay.dispose();
    tecFullSwitchFaultDelay.dispose();
    tecHalfStateFaultERPM.dispose();
    tecKP.dispose();
    tecKI.dispose();
    tecKD.dispose();
    tecTiltbackConstantERPM.dispose();

    // Stop ppm calibration timer if it's somehow left behind
    if (ppmCalibrateTimer != null) {
      globalLogger.w("InputConfigurationEditor::dispose: ppmCalibrateTimer was not null!");
      ppmCalibrateTimer?.cancel();
      ppmCalibrateTimer = null;
    }
    // Stop ADC calibration timer if it's somehow left behind
    if (adcCalibrateTimer != null) {
      globalLogger.w("InputConfigurationEditor::dispose: adcCalibrateTimer was not null!");
      adcCalibrateTimer?.cancel();
      adcCalibrateTimer = null;
    }
    
    super.dispose();
  }

  void requestAPPCONF({int optionalCANID}) async {
    Uint8List packet = simpleVESCRequest(COMM_PACKET_ID.COMM_GET_APPCONF.index, optionalCANID: optionalCANID);

    // Request APPCONF from the ESC
    globalLogger.i("requestAPPCONF: requesting application configuration (CAN ID? $optionalCANID)");
    if (!await sendBLEData(theTXCharacteristic, packet, false)) {
      globalLogger.e("requestAPPCONF: failed to request application configuration");
    }
  }

  Future<void> saveAPPCONF(int optionalCANID) async {
    if (_writeESCInProgress) {
      globalLogger.w("WARNING: InputConfigurationEditor: saveAPPCONF: _writeESCInProgress is true. Save aborted.");
      return;
    }

    // Protect from interrupting a previous write attempt
    _writeESCInProgress = true;
    ESCHelper escHelper = new ESCHelper();
    ByteData serializedAppconf = escHelper.serializeAPPCONF(escInputConfiguration, escFirmwareVersion);

    // Compute sizes and track buffer position
    int packetIndex = 0;
    int packetLength = 7; //<start><length><length> <command id><command data*><crc><crc><end>
    int payloadSize = serializedAppconf.lengthInBytes + 1; //<command id>
    if (optionalCANID != null) {
      packetLength += 2; //<canfwd><canid>
      payloadSize += 2;
    }
    packetLength += serializedAppconf.lengthInBytes; // Command Data

    // Prepare BLE request
    ByteData blePacket = new ByteData(packetLength);
    blePacket.setUint8(packetIndex++, 0x03); // Start of >255 byte packet
    blePacket.setUint16(packetIndex, payloadSize); packetIndex += 2; // Length of data
    if (optionalCANID != null) {
      blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_FORWARD_CAN.index); // CAN FWD
      blePacket.setUint8(packetIndex++, optionalCANID); // CAN ID
    }
    blePacket.setUint8(packetIndex++, COMM_PACKET_ID.COMM_SET_APPCONF.index); // Command ID
    //Copy serialized motor configuration to blePacket
    for (int i=0;i<serializedAppconf.lengthInBytes;++i) {
      blePacket.setInt8(packetIndex++, serializedAppconf.getInt8(i));
    }
    int checksum = CRC16.crc16(blePacket.buffer.asUint8List(), 3, payloadSize);
    blePacket.setUint16(packetIndex, checksum); packetIndex += 2;
    blePacket.setUint8(packetIndex, 0x03); //End of packet

    sendBLEData(theTXCharacteristic, blePacket.buffer.asUint8List(), true);

    // Finish with this save attempt
    _writeESCInProgress = false;
  }


  void requestDecodedPPM(int optionalCANID) {
    // Do nothing if we are busy writing to the ESC or not yet running
    if (_writeESCInProgress || calibrationState.ppmCalibrationRunning == null || !calibrationState.ppmCalibrationRunning) {
      return;
    }

    sendBLEData(
        theTXCharacteristic,
        simpleVESCRequest(
            COMM_PACKET_ID.COMM_GET_DECODED_PPM.index,
            optionalCANID: optionalCANID
        ), false );
  }

  void requestDecodedADC(int optionalCANID) {
    // Do nothing if we are busy writing to the ESC or not yet running
    if (_writeESCInProgress || (calibrationState.adcCalibrationRunning == null || !calibrationState.adcCalibrationRunning)) {
      return;
    }

    sendBLEData(
        theTXCharacteristic,
        simpleVESCRequest(
            COMM_PACKET_ID.COMM_GET_DECODED_ADC.index,
            optionalCANID: optionalCANID
        ), false );
  }

  // Start and stop PPM streaming timer
  void startStopPPMTimer(bool disableTimer) {
    if (!disableTimer){
      globalLogger.d("Starting PPM calibration timer");
      const duration = const Duration(milliseconds:100);
      ppmCalibrateTimer = new Timer.periodic(duration, (Timer t) => requestDecodedPPM(_selectedCANFwdID));
    } else {
      globalLogger.d("Cancel PPM timer");
      if (ppmCalibrateTimer != null) {
        ppmCalibrateTimer?.cancel();
        ppmCalibrateTimer = null;
      }
    }
  }

  // Start and stop ADC streaming timer
  void startStopADCTimer(bool disableTimer) {
    if (!disableTimer){
      globalLogger.d("Starting ADC calibration timer");
      const duration = const Duration(milliseconds:250);
      adcCalibrateTimer = new Timer.periodic(duration, (Timer t) => requestDecodedADC(_selectedCANFwdID));
    } else {
      globalLogger.d("Cancel ADC timer");
      if (adcCalibrateTimer != null) {
        adcCalibrateTimer?.cancel();
        adcCalibrateTimer = null;
      }
    }
  }
  
  Future<Widget> _buildBody(BuildContext context) async {

    // Check if we are building with an invalid motor configuration (signature mismatch)
    if (escInputConfiguration == null || escInputConfiguration.imu_conf.sample_rate_hz == null) {
      // Invalid APPCONF received
      _invalidCANID = _selectedCANFwdID; // Store invalid ID
      _selectedCANFwdID = null; // Clear selected CAN device
      // Clear selections
      _selectedPPMCtrlType = null;
      _selectedThrExpMode = null;
      _selectedAppMode = null;
      // Request primary ESC application configuration
      requestAPPCONF(optionalCANID: _selectedCANFwdID);
      return Column( // This view will be replaced when ESC responds with valid configuration
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Icon(
              Icons.settings_applications_outlined,
              size: 80.0,
              color: Colors.blue,
            ),
            Text("Input\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
          ],),

          Icon(Icons.file_download),
          Text("Missing Application Configuration from the ESC"),
          Text("If this problem persists you may need to restart the application")
        ],
      );
    }


    // Select App to use
    if (_selectedAppMode == null) {
      _appModeItems.forEach((item) {
        if (item.value == escInputConfiguration.app_to_use.index) {
          _selectedAppMode = item;
        }
      });
    }
    if (_selectedAppMode == null) {
      escInputConfiguration.app_to_use = app_use.APP_NONE;
      _selectedAppMode = _appModeItems.first;
    }
    showPPMConfiguration = escInputConfiguration.app_to_use == app_use.APP_PPM_UART;
    showNunchukConfiguration = escInputConfiguration.app_to_use == app_use.APP_UART;
    showBalanceConfiguration = escInputConfiguration.app_to_use == app_use.APP_BALANCE;
    showADCConfiguration = escInputConfiguration.app_to_use == app_use.APP_ADC_UART;


    // Select PPM control type
    if (_selectedPPMCtrlType == null) {
      _ppmCtrlTypeItems.forEach((item) {
        if (item.value == escInputConfiguration.app_ppm_conf.ctrl_type.index) {
          _selectedPPMCtrlType = item;
        }
      });
    }

    // Select throttle exponent mode
    if (_selectedThrExpMode == null) {
      _thrExpModeItems.forEach((element) {
        if (element.value == escInputConfiguration.app_ppm_conf.throttle_exp_mode.index) {
          _selectedThrExpMode = element;
        }
      });
    }

    // Select nunchuk control type
    if (_selectedNunchukCtrlType == null) {
      _nunchukCtrlTypeItems.forEach((element) {
        if (element.value == escInputConfiguration.app_chuk_conf.ctrl_type.index) {
          _selectedNunchukCtrlType = element;
        }
      });
    }

    // Select nunchuk throttle exponent mode
    if (_selectedThrExpModeNunchuk == null) {
      _thrExpModeNunchukItems.forEach((element) {
        if (element.value == escInputConfiguration.app_chuk_conf.throttle_exp_mode.index) {
          _selectedThrExpModeNunchuk = element;
        }
      });
    }

    // Select ADC control type
    if (_selectedADCCtrlType == null) {
      _adcCtrlTypeItems.forEach((item) {
        if (item.value == escInputConfiguration.app_adc_conf.ctrl_type.index) {
          _selectedADCCtrlType = item;
        }
      });
    }

    // Monitor PPM min and max
    ppmMinMS ??= calibrationState.ppmMillisecondsNow;
    ppmMaxMS ??= calibrationState.ppmMillisecondsNow;
    if (calibrationState.ppmMillisecondsNow != null && calibrationState.ppmMillisecondsNow != 0.0 && calibrationState.ppmMillisecondsNow > ppmMaxMS) ppmMaxMS = calibrationState.ppmMillisecondsNow;
    if (calibrationState.ppmMillisecondsNow != null && calibrationState.ppmMillisecondsNow != 0.0 && calibrationState.ppmMillisecondsNow < ppmMinMS) ppmMinMS = calibrationState.ppmMillisecondsNow;

    if (ppmMinMS != null && ppmMaxMS != null) {
      _rangeSliderDiscreteValues = RangeValues(ppmMinMS / 1000000, ppmMaxMS / 1000000);
    }

    // Monitor ADC min and max
    if (calibrationState.adcVoltageNow != null) {
      adcMinV ??= doublePrecision(calibrationState.adcVoltageNow, 2);
      adcMaxV ??= doublePrecision(calibrationState.adcVoltageNow, 2);
      adcMinV2 ??= doublePrecision(calibrationState.adcVoltage2Now, 2);
      adcMaxV2 ??= doublePrecision(calibrationState.adcVoltage2Now, 2);
      if (calibrationState.adcVoltageNow != null && calibrationState.adcVoltageNow != 0.0 && calibrationState.adcVoltageNow < adcMinV) adcMinV = doublePrecision(calibrationState.adcVoltageNow, 2);
      if (calibrationState.adcVoltageNow != null && calibrationState.adcVoltageNow != 0.0 && calibrationState.adcVoltageNow > adcMaxV) adcMaxV = doublePrecision(calibrationState.adcVoltageNow, 2);
      if (calibrationState.adcVoltage2Now != null && calibrationState.adcVoltage2Now != 0.0 && calibrationState.adcVoltage2Now < adcMinV2) adcMinV2 = doublePrecision(calibrationState.adcVoltage2Now, 2);
      if (calibrationState.adcVoltage2Now != null && calibrationState.adcVoltage2Now != 0.0 && calibrationState.adcVoltage2Now > adcMaxV2) adcMaxV2 = doublePrecision(calibrationState.adcVoltage2Now, 2);
    }

    // Perform rounding to make doubles pretty
    escInputConfiguration.app_ppm_conf.hyst = doublePrecision(escInputConfiguration.app_ppm_conf.hyst, 2);
    escInputConfiguration.app_ppm_conf.ramp_time_pos = doublePrecision(escInputConfiguration.app_ppm_conf.ramp_time_pos, 2);
    escInputConfiguration.app_ppm_conf.ramp_time_neg = doublePrecision(escInputConfiguration.app_ppm_conf.ramp_time_neg, 2);
    escInputConfiguration.app_ppm_conf.smart_rev_max_duty = doublePrecision(escInputConfiguration.app_ppm_conf.smart_rev_max_duty, 2);
    escInputConfiguration.app_ppm_conf.smart_rev_ramp_time = doublePrecision(escInputConfiguration.app_ppm_conf.smart_rev_ramp_time, 2);
    escInputConfiguration.app_ppm_conf.throttle_exp_brake = doublePrecision(escInputConfiguration.app_ppm_conf.throttle_exp_brake, 2);
    escInputConfiguration.app_ppm_conf.throttle_exp = doublePrecision(escInputConfiguration.app_ppm_conf.throttle_exp, 2);

    escInputConfiguration.app_balance_conf.fault_adc1 = doublePrecision(escInputConfiguration.app_balance_conf.fault_adc1, 2);
    escInputConfiguration.app_balance_conf.fault_adc2 = doublePrecision(escInputConfiguration.app_balance_conf.fault_adc2, 2);
    escInputConfiguration.app_balance_conf.kp = doublePrecision(escInputConfiguration.app_balance_conf.kp, 4);
    escInputConfiguration.app_balance_conf.ki = doublePrecision(escInputConfiguration.app_balance_conf.ki, 4);
    escInputConfiguration.app_balance_conf.kd = doublePrecision(escInputConfiguration.app_balance_conf.kd, 4);
    escInputConfiguration.app_balance_conf.tiltback_constant = doublePrecision(escInputConfiguration.app_balance_conf.tiltback_constant, 1);
    escInputConfiguration.app_balance_conf.brake_current = doublePrecision(escInputConfiguration.app_balance_conf.brake_current, 2);
    escInputConfiguration.app_balance_conf.tiltback_duty = doublePrecision(escInputConfiguration.app_balance_conf.tiltback_duty, 2);

    escInputConfiguration.app_chuk_conf.hyst = doublePrecision(escInputConfiguration.app_chuk_conf.hyst, 2);
    escInputConfiguration.app_chuk_conf.ramp_time_pos = doublePrecision(escInputConfiguration.app_chuk_conf.ramp_time_pos, 2);
    escInputConfiguration.app_chuk_conf.ramp_time_neg = doublePrecision(escInputConfiguration.app_chuk_conf.ramp_time_neg, 2);
    escInputConfiguration.app_chuk_conf.smart_rev_ramp_time = doublePrecision( escInputConfiguration.app_chuk_conf.smart_rev_ramp_time, 2);
    escInputConfiguration.app_chuk_conf.throttle_exp_brake = doublePrecision(escInputConfiguration.app_chuk_conf.throttle_exp_brake, 2);
    escInputConfiguration.app_chuk_conf.throttle_exp = doublePrecision(escInputConfiguration.app_chuk_conf.throttle_exp, 2);

    escInputConfiguration.app_adc_conf.voltage_start = doublePrecision(escInputConfiguration.app_adc_conf.voltage_start, 2);
    escInputConfiguration.app_adc_conf.voltage_center = doublePrecision(escInputConfiguration.app_adc_conf.voltage_center, 2);
    escInputConfiguration.app_adc_conf.voltage_end = doublePrecision(escInputConfiguration.app_adc_conf.voltage_end, 2);
    escInputConfiguration.app_adc_conf.voltage2_start = doublePrecision(escInputConfiguration.app_adc_conf.voltage2_start, 2);
    escInputConfiguration.app_adc_conf.voltage2_end = doublePrecision(escInputConfiguration.app_adc_conf.voltage2_end, 2);
    escInputConfiguration.app_adc_conf.ramp_time_pos = doublePrecision(escInputConfiguration.app_adc_conf.ramp_time_pos, 2);
    escInputConfiguration.app_adc_conf.ramp_time_neg = doublePrecision(escInputConfiguration.app_adc_conf.ramp_time_neg, 2);

    // Prepare TECs
    tecIMUHz.text = escInputConfiguration.imu_conf.sample_rate_hz.toString();
    tecIMUHz.selection = TextSelection.fromPosition(TextPosition(offset: tecIMUHz.text.length));
    tecBalanceHz.text = escInputConfiguration.app_balance_conf.hertz.toString();
    tecBalanceHz.selection = TextSelection.fromPosition(TextPosition(offset: tecBalanceHz.text.length));

    tecHalfSwitchFaultDelay.text = escInputConfiguration.app_balance_conf.fault_delay_switch_half.toString();
    tecHalfSwitchFaultDelay.selection = TextSelection.fromPosition(TextPosition(offset: tecHalfSwitchFaultDelay.text.length));
    tecFullSwitchFaultDelay.text = escInputConfiguration.app_balance_conf.fault_delay_switch_full.toString();
    tecFullSwitchFaultDelay.selection = TextSelection.fromPosition(TextPosition(offset: tecFullSwitchFaultDelay.text.length));
    tecHalfStateFaultERPM.text = escInputConfiguration.app_balance_conf.fault_adc_half_erpm.toString();
    tecHalfStateFaultERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecHalfStateFaultERPM.text.length));

    tecKP.text = escInputConfiguration.app_balance_conf.kp.toString();
    tecKP.selection = TextSelection.fromPosition(TextPosition(offset: tecKP.text.length));
    tecKI.text = escInputConfiguration.app_balance_conf.ki.toString();
    tecKI.selection = TextSelection.fromPosition(TextPosition(offset: tecKI.text.length));
    tecKD.text = escInputConfiguration.app_balance_conf.kd.toString();
    tecKD.selection = TextSelection.fromPosition(TextPosition(offset: tecKD.text.length));

    tecTiltbackConstantERPM.text = escInputConfiguration.app_balance_conf.tiltback_constant_erpm.toString();
    tecTiltbackConstantERPM.selection = TextSelection.fromPosition(TextPosition(offset: tecTiltbackConstantERPM.text.length));

    return Center(
      child: GestureDetector(
        onTap: () {
          // Hide the keyboard
          FocusScope.of(context).requestFocus(new FocusNode());
        },
        child: Column(
          children: [
            /// Header icon and text
            Column(
              children: [
                SizedBox(height: 5,),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  Icon(
                    Icons.settings_applications_outlined,
                    size: 80.0,
                    color: Colors.blue,
                  ),
                  Text("Input\nConfiguration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),),
                ],),

                SizedBox(height:5),
              ],
            ),


            /// Discovered CAN IDs
            Center(child: Column( children: <Widget>[
              Text("Discovered Devices"),
              Container(
                  height: 50,
                  child: GridView.builder(
                    primary: false,
                    itemCount: discoveredCANDevices.length + 1, //NOTE: adding one for the direct ESC
                    gridDelegate: new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 2, crossAxisSpacing: 1, mainAxisSpacing: 1),
                    itemBuilder: (BuildContext context, int index) {
                      // Direct ESC
                      if (index == 0) {
                        return new Card(
                          shadowColor: Colors.transparent,
                          child: new GridTile(
                            // GestureDetector to switch the currently selected CAN Forward ID
                              child: new GestureDetector(
                                onTap: (){
                                  setState(() {
                                    // Clear CAN Forward
                                    _selectedCANFwdID = null;
                                    // Request primary ESC application configuration
                                    requestAPPCONF(optionalCANID: _selectedCANFwdID);
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(
                                        SnackBar(
                                          content: Text("Requesting ESC application configuration from primary ESC"),
                                          duration: Duration(seconds: 1),
                                        ));
                                  });
                                },
                                child: Stack(
                                  children: <Widget>[



                                    new Center(child: Text(_selectedCANFwdID == null ? "Direct (Active)" :"Direct", style: TextStyle(fontSize: 12)),),
                                    new ClipRRect(
                                        borderRadius: new BorderRadius.circular(10),
                                        child: new Container(
                                          decoration: new BoxDecoration(
                                            color: _selectedCANFwdID == null ? Theme.of(context).focusColor : Colors.transparent,
                                          ),
                                        )
                                    )


                                  ],
                                ),
                              )
                          ),
                        );
                      }
                      // CAN IDs
                      bool isCANIDSelected = false;
                      if (_selectedCANFwdID == discoveredCANDevices[index-1]) {
                        isCANIDSelected = true;
                      }
                      String invalidDevice = "";
                      if (_invalidCANID == discoveredCANDevices[index-1]) {
                        invalidDevice = " (Invalid)";
                      }
                      return new Card(
                        shadowColor: Colors.transparent,
                        child: new GridTile(
                          // GestureDetector to switch the currently selected CAN Forward ID
                            child: new GestureDetector(
                              onTap: (){
                                if (isCANIDSelected) {
                                  setState(() {
                                    // Clear CAN Forward
                                    _selectedCANFwdID = null;
                                    // Request primary ESC application configuration
                                    requestAPPCONF(optionalCANID: _selectedCANFwdID);
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(
                                        SnackBar(
                                          content: Text("Requesting ESC application configuration from primary ESC"),
                                          duration: Duration(seconds: 1),
                                        ));
                                  });
                                } else {
                                  if (_invalidCANID != discoveredCANDevices[index-1]) {
                                    _selectedCANFwdID = discoveredCANDevices[index-1];
                                    // Request APPCONF from CAN device
                                    requestAPPCONF(optionalCANID: _selectedCANFwdID);
                                    ScaffoldMessenger
                                        .of(context)
                                        .showSnackBar(
                                        SnackBar(
                                          content: Text("Requesting ESC application configuration from CAN ID $_selectedCANFwdID"),
                                          duration: Duration(seconds: 1),
                                        ));
                                  }
                                }
                              },
                              child: Stack(
                                children: <Widget>[



                                  new Center(child: Text("ID ${discoveredCANDevices[index-1]}${isCANIDSelected?" (Active)":""}$invalidDevice", style: TextStyle(fontSize: 12)),),
                                  new ClipRRect(
                                      borderRadius: new BorderRadius.circular(10),
                                      child: new Container(
                                        decoration: new BoxDecoration(
                                          color: isCANIDSelected ? Theme.of(context).focusColor : Colors.transparent,
                                        ),
                                      )
                                  )


                                ],
                              ),
                            )
                        ),
                      );
                    },
                  )
              )
            ],)
            ),


            /// List view content
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                children: <Widget>[

                  Divider(thickness: 3),
                  Text("Select Application Mode"),
                  Center(child:
                  DropdownButton<ListItem>(
                    value: _selectedAppMode,
                    items: _appModeDropdownItems,
                    onChanged: (newValue) {
                      setState(() {
                        _selectedAppMode = newValue;
                        escInputConfiguration.app_to_use = app_use.values[newValue.value];
                        showPPMConfiguration = escInputConfiguration.app_to_use == app_use.APP_PPM_UART;
                        showNunchukConfiguration = escInputConfiguration.app_to_use == app_use.APP_UART;
                        showBalanceConfiguration = escInputConfiguration.app_to_use == app_use.APP_BALANCE;
                      });
                    },
                  )
                  ),
                  //TODO: User control needed? Text("app can ${escInputConfiguration.can_mode}"),

                  // Show Balance Options
                  showBalanceConfiguration ? Column(
                    children: [
                      Divider(thickness: 3),
                      Text("${escInputConfiguration.imu_conf.mode}"),
                      TextField(
                          controller: tecIMUHz,
                          decoration: new InputDecoration(labelText: "IMU Hz"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ]
                      ),
                      TextField(
                          controller: tecBalanceHz,
                          decoration: new InputDecoration(labelText: "Main Loop Hz"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ]
                      ),

                      SizedBox(height:10),
                      Text("ADC1 Fault ${escInputConfiguration.app_balance_conf.fault_adc1}"),
                      Slider(
                        value: escInputConfiguration.app_balance_conf.fault_adc1,
                        min: 0.0,
                        max: 3.3,
                        label: "${escInputConfiguration.app_balance_conf.fault_adc1}",
                        onChanged: (value) {
                          setState(() {
                            escInputConfiguration.app_balance_conf.fault_adc1 = doublePrecision(value, 1);
                          });
                        },
                      ),

                      Text("ADC2 Fault ${escInputConfiguration.app_balance_conf.fault_adc2}"),
                      Slider(
                        value: escInputConfiguration.app_balance_conf.fault_adc2,
                        min: 0.0,
                        max: 3.3,
                        label: "${escInputConfiguration.app_balance_conf.fault_adc2}",
                        onChanged: (value) {
                          setState(() {
                            escInputConfiguration.app_balance_conf.fault_adc2 = doublePrecision(value, 1);
                          });
                        },
                      ),

                      // NOTE: Not in FW5.1
                      escInputConfiguration.app_balance_conf.fault_delay_switch_half != null ? TextField(
                          controller: tecHalfSwitchFaultDelay,
                          decoration: new InputDecoration(labelText: "Half Switch Fault Delay (ms)"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ]
                      ) : Container(),
                      // NOTE: Not in FW5.1
                      escInputConfiguration.app_balance_conf.fault_delay_switch_full != null ? TextField(
                          controller: tecFullSwitchFaultDelay,
                          decoration: new InputDecoration(labelText: "Full Switch Fault Delay (ms)"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ]
                      ) : Container(),
                      TextField(
                          controller: tecHalfStateFaultERPM,
                          decoration: new InputDecoration(labelText: "Half State Fault ERPM"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ]
                      ),


                      TextField(
                          controller: tecKP,
                          decoration: new InputDecoration(labelText: "PID (P gain)"),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(formatPositiveDouble)
                          ]
                      ),
                      TextField(
                          controller: tecKI,
                          decoration: new InputDecoration(labelText: "PID (I gain)"),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(formatPositiveDouble)
                          ]
                      ),
                      TextField(
                          controller: tecKD,
                          decoration: new InputDecoration(labelText: "PID (D gain)"),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(formatPositiveDouble)
                          ]
                      ),


                      SizedBox(height: 10),
                      Text("Constant Tiltback ${escInputConfiguration.app_balance_conf.tiltback_constant}°"),
                      SmartSlider(
                        value: escInputConfiguration.app_balance_conf.tiltback_constant,
                        mini: -20,
                        maxi: 20,
                        label: "${escInputConfiguration.app_balance_conf.tiltback_constant.toInt()}",
                        onChanged: (value) {
                          setState(() {
                            escInputConfiguration.app_balance_conf.tiltback_constant = value.toInt().toDouble();
                          });
                        },
                      ),

                      TextField(
                          controller: tecTiltbackConstantERPM,
                          decoration: new InputDecoration(labelText: "Constant Tiltback ERPM"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ]
                      ),

                      SizedBox(height:10),
                      Text("Duty Cycle Tiltback ${escInputConfiguration.app_balance_conf.tiltback_duty}"),
                      SmartSlider(
                        value: escInputConfiguration.app_balance_conf.tiltback_duty,
                        mini: 0.0,
                        maxi: 1.0,
                        label: "${escInputConfiguration.app_balance_conf.tiltback_duty}",
                        onChanged: (value) {
                          setState(() {
                            escInputConfiguration.app_balance_conf.tiltback_duty = doublePrecision(value, 2);
                          });
                        },
                      ),

                      SizedBox(height:10),
                      Text("Brake Current ${escInputConfiguration.app_balance_conf.brake_current} Amps"),
                      SmartSlider(
                        value: escInputConfiguration.app_balance_conf.brake_current,
                        mini: 0.0,
                        maxi: 20.0,
                        label: "${escInputConfiguration.app_balance_conf.brake_current}",
                        onChanged: (value) {
                          setState(() {
                            escInputConfiguration.app_balance_conf.brake_current = doublePrecision(value, 1);
                          });
                        },
                      ),

                      //Text("current_boost ${escInputConfiguration.app_balance_conf.current_boost}"),
                      //Text("deadzone ${escInputConfiguration.app_balance_conf.deadzone}"),
                      //Text("fault_duty ${escInputConfiguration.app_balance_conf.fault_duty}"),
                      //NOTE: Secondary tuning
                      //Text("accel_confidence_decay ${escInputConfiguration.imu_conf.accel_confidence_decay}"),
                      //Text("imu_conf.mahony_kp ${escInputConfiguration.imu_conf.mahony_kp}"),
                      //Text("imu_conf.mahony_ki ${escInputConfiguration.imu_conf.mahony_ki}"),
                      //Text("imu_conf.madgwick_beta ${escInputConfiguration.imu_conf.madgwick_beta}"),
                    ],
                  ) : Container(),

                  // Show ADC Options
                  showADCConfiguration ? Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Divider(thickness: 3),
                        Text("Calibrate ADC"),

                        ElevatedButton(onPressed: () async {
                          // If we are not currently calibrating...
                          if (!adcCalibrate) {
                            // Clear the captured values when starting calibration
                            adcMinV = null;
                            adcMaxV = null;
                            adcMinV2 = null;
                            adcMaxV2 = null;
                            // Capture the current ADC control type to restore when finished
                            adcCalibrateControlTypeToRestore = escInputConfiguration.app_adc_conf.ctrl_type;
                            // Set the control type to none or the ESC will go WILD
                            escInputConfiguration.app_adc_conf.ctrl_type = adc_control_type.ADC_CTRL_TYPE_NONE;
                            _selectedADCCtrlType = null; // Clear selection


                            myArguments.notifyStopStartADCCalibrate(true);

                            // Apply the configuration to the ESC
                            await saveAPPCONF(_selectedCANFwdID);

                            // Start calibration routine
                            setState(() {
                              adcCalibrate = true;
                            });
                            Future.delayed(Duration(milliseconds: 500), (){startStopADCTimer(false);});
                          } else {
                            // Stop calibration routine
                            setState(() {
                              myArguments.notifyStopStartADCCalibrate(false);
                              adcCalibrate = false;
                              startStopADCTimer(true);
                            });

                            // If we did not receive any ADC information we cannot save the changes
                            if (calibrationState.adcVoltageNow == null) {
                              setState(() {
                                // Restore the user's ADC control type
                                escInputConfiguration.app_adc_conf.ctrl_type = adcCalibrateControlTypeToRestore;
                                _selectedADCCtrlType = null; // Clear selection
                                Future.delayed(Duration(milliseconds: 250), (){
                                  saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                });
                              });
                              return;
                            }

                            // Ask user if they are satisfied with the calibration results
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Accept Calibration?'),
                                  content: SingleChildScrollView(
                                    child: ListBody(
                                      children: <Widget>[
                                        Text('ADC values captured:'),
                                        SizedBox(height:10),
                                        Text("ADC1 Min $adcMinV"),
                                        Text("ADC1 Center ${doublePrecision(calibrationState.adcVoltageNow, 2)}"),
                                        Text("ADC1 Max $adcMaxV"),
                                        Text("ADC2 Min $adcMinV2"),
                                        Text("ADC2 Max $adcMaxV2"),
                                        SizedBox(height:10),
                                        Text('If you are satisfied with the results select Accept to write values to the ESC')
                                      ],
                                    ),
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text('Reject'),
                                      onPressed: () {
                                        setState(() {
                                          adcMinV = null;
                                          adcMaxV = null;
                                          adcMinV2 = null;
                                          adcMaxV2 = null;
                                          // Restore the user's ADC control type
                                          escInputConfiguration.app_adc_conf.ctrl_type = adcCalibrateControlTypeToRestore;
                                          _selectedADCCtrlType = null; // Clear selection
                                          Future.delayed(Duration(milliseconds: 250), (){
                                            saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                          });
                                        });
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: Text('Accept'),
                                      onPressed: () {
                                        setState(() {
                                          // Restore the user's ADC control type
                                          escInputConfiguration.app_adc_conf.ctrl_type = adcCalibrateControlTypeToRestore;
                                          _selectedADCCtrlType = null; // Clear selection
                                          // Set values from calibration
                                          escInputConfiguration.app_adc_conf.voltage_start = adcMinV;
                                          escInputConfiguration.app_adc_conf.voltage_center = calibrationState.adcVoltageNow;
                                          escInputConfiguration.app_adc_conf.voltage_end = adcMaxV;
                                          escInputConfiguration.app_adc_conf.voltage2_start = adcMinV2;
                                          escInputConfiguration.app_adc_conf.voltage2_end = adcMaxV2;
                                          // Apply the configuration to the ESC
                                          Future.delayed(Duration(milliseconds: 250), (){
                                            saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                          });
                                        });
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          }

                        }, child: Text(adcCalibrate ? (calibrationState.adcCalibrationRunning != null && calibrationState.adcCalibrationRunning) ? "Stop Calibration": "Starting Calibration..." : "Calibrate ADC"),),

                        adcCalibrate ? Column(
                          children: [
                            Table(children: [
                              TableRow(children: [
                                Text(""),
                                Text("Calibrate ADC"),
                                Text("ESC Config")
                              ]),
                              TableRow(children: [
                                Text("ADC1 Min"),
                                Text("${adcMinV != null ? adcMinV : ""}"),
                                Text("${escInputConfiguration.app_adc_conf.voltage_start}")
                              ]),
                              TableRow(children: [
                                Text("ADC1 Center"),
                                Text("${calibrationState.adcVoltageNow != null ? doublePrecision(calibrationState.adcVoltageNow, 2) : ""}"),
                                Text("${escInputConfiguration.app_adc_conf.voltage_center}")
                              ]),
                              TableRow(children: [
                                Text("ADC1 Max"),
                                Text("${adcMaxV != null ? adcMaxV : ""}"),
                                Text("${escInputConfiguration.app_adc_conf.voltage_end}")
                              ]),

                              TableRow(children: [
                                Text("ADC2 Min"),
                                Text("${adcMinV2 != null ? adcMinV2 : ""}"),
                                Text("${escInputConfiguration.app_adc_conf.voltage2_start}")
                              ]),
                              TableRow(children: [
                                Text("ADC2 Max"),
                                Text("${adcMaxV2 != null ? adcMaxV2 : ""}"),
                                Text("${escInputConfiguration.app_adc_conf.voltage2_end}")
                              ]),
                            ],),
                          ],
                        ) : Container(),

                        ElevatedButton(onPressed: (){
                          setState(() {
                            showAdvancedOptions = !showAdvancedOptions;
                          });
                        },
                          child: Text("${showAdvancedOptions?"Hide":"Show"} Advanced Options"),),

                        showAdvancedOptions ? Padding(
                            padding: const EdgeInsets.only(left: 13, right: 13),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Divider(thickness: 3),
                                  Text("ADC1 Min Voltage ${escInputConfiguration.app_adc_conf.voltage_start}"),
                                  SmartSlider(
                                    value: escInputConfiguration.app_adc_conf.voltage_start,
                                    mini: 0,
                                    maxi: 3.3,
                                    divisions: 100,
                                    label: "${escInputConfiguration.app_adc_conf.voltage_start}",
                                    onChanged: (value) {
                                      setState(() {
                                        escInputConfiguration.app_adc_conf.voltage_start = value;
                                      });
                                    },
                                  ),
                                  Text("ADC1 Max Voltage ${escInputConfiguration.app_adc_conf.voltage_end}"),
                                  SmartSlider(
                                    value: escInputConfiguration.app_adc_conf.voltage_end,
                                    mini: 0,
                                    maxi: 3.3,
                                    divisions: 100,
                                    label: "${escInputConfiguration.app_adc_conf.voltage_end}",
                                    onChanged: (value) {
                                      setState(() {
                                        escInputConfiguration.app_adc_conf.voltage_end = value;
                                      });
                                    },
                                  ),
                                  Text("ADC1 Center Voltage ${escInputConfiguration.app_adc_conf.voltage_center}"),
                                  SmartSlider(
                                    value: escInputConfiguration.app_adc_conf.voltage_center,
                                    mini: 0,
                                    maxi: 3.3,
                                    divisions: 100,
                                    label: "${escInputConfiguration.app_adc_conf.voltage_center}",
                                    onChanged: (value) {
                                      setState(() {
                                        escInputConfiguration.app_adc_conf.voltage_center = value;
                                      });
                                    },
                                  ),

                                  SwitchListTile(
                                    title: Text("Invert ADC1 Voltage"),
                                    value: escInputConfiguration.app_adc_conf.voltage_inverted,
                                    onChanged: (bool newValue) { setState((){escInputConfiguration.app_adc_conf.voltage_inverted = newValue;}); },
                                    secondary: const Icon(Icons.sync),
                                  ),

                                  Text("ADC2 Min Voltage ${escInputConfiguration.app_adc_conf.voltage2_start}"),
                                  SmartSlider(
                                    value: escInputConfiguration.app_adc_conf.voltage2_start,
                                    mini: 0,
                                    maxi: 3.3,
                                    divisions: 100,
                                    label: "${escInputConfiguration.app_adc_conf.voltage2_start}",
                                    onChanged: (value) {
                                      setState(() {
                                        escInputConfiguration.app_adc_conf.voltage2_start = value;
                                      });
                                    },
                                  ),
                                  Text("ADC2 Max Voltage ${escInputConfiguration.app_adc_conf.voltage2_end}"),
                                  SmartSlider(
                                    value: escInputConfiguration.app_adc_conf.voltage2_end,
                                    mini: 0,
                                    maxi: 3.3,
                                    divisions: 100,
                                    label: "${escInputConfiguration.app_adc_conf.voltage2_end}",
                                    onChanged: (value) {
                                      setState(() {
                                        escInputConfiguration.app_adc_conf.voltage2_end = value;
                                      });
                                    },
                                  ),
                                  SwitchListTile(
                                    title: Text("Invert ADC2 Voltage"),
                                    value: escInputConfiguration.app_adc_conf.voltage2_inverted,
                                    onChanged: (bool newValue) { setState((){escInputConfiguration.app_adc_conf.voltage2_inverted = newValue;}); },
                                    secondary: const Icon(Icons.sync),
                                  ),

                                  SwitchListTile(
                                    title: Text("Multiple ESC over CAN (default = on)"),
                                    value: escInputConfiguration.app_adc_conf.multi_esc,
                                    onChanged: (bool newValue) { setState((){ escInputConfiguration.app_adc_conf.multi_esc = newValue;}); },
                                    secondary: const Icon(Icons.settings_ethernet),
                                  ),

                                  ElevatedButton(onPressed: (){
                                    setState(() {
                                      showAdvancedOptions = !showAdvancedOptions;
                                    });
                                  },
                                    child: Text("${showAdvancedOptions?"Hide":"Show"} Advanced Options"),),
                                ]
                            )
                        ) : Container(),
                        /// Advanced options ^^^



                        Text("Input deadband: ${(escInputConfiguration.app_adc_conf.hyst * 100.0).toInt()}% (15% = default)"),
                        SmartSlider(
                          value: escInputConfiguration.app_adc_conf.hyst,
                          mini: 0.01,
                          maxi: 0.35,
                          divisions: 100,
                          label: "${(escInputConfiguration.app_adc_conf.hyst * 100.0).toInt()}%",
                          onChanged: (value) {
                            setState(() {
                              escInputConfiguration.app_adc_conf.hyst = value;
                            });
                          },
                        ),

                        Divider(thickness: 3),
                        Text("Select ADC Control Type"),
                        Center(child:
                        DropdownButton<ListItem>(
                          value: _selectedADCCtrlType,
                          items: _adcCtrlTypeDropdownItems,
                          onChanged: (newValue) {
                            setState(() {
                              _selectedADCCtrlType = newValue;
                              escInputConfiguration.app_adc_conf.ctrl_type = adc_control_type.values[newValue.value];
                            });
                          },
                        )
                        ),

                        SwitchListTile(
                          title: Text("Use Filter (default = on)"),
                          value: escInputConfiguration.app_adc_conf.use_filter,
                          onChanged: (bool newValue) { setState((){ escInputConfiguration.app_adc_conf.use_filter = newValue;}); },
                          secondary: const Icon(Icons.filter_tilt_shift),
                        ),
                        SwitchListTile(
                          title: Text("Safe Start (default = on)"),
                          value: escInputConfiguration.app_adc_conf.safe_start.index > 0 ? true : false,
                          onChanged: (bool newValue) { setState((){ escInputConfiguration.app_adc_conf.safe_start = SAFE_START_MODE.values[newValue ? 1 : 0];}); },
                          secondary: const Icon(Icons.not_started),
                        ),

                        SwitchListTile(
                          title: Text("Invert Cruise Control Button"),
                          value: escInputConfiguration.app_adc_conf.cc_button_inverted,
                          onChanged: (bool newValue) { setState((){ escInputConfiguration.app_adc_conf.cc_button_inverted = newValue; }); },
                          secondary: const Icon(Icons.help_outline),
                        ),

                        SwitchListTile(
                          title: Text("Invert Reverse Button"),
                          value: escInputConfiguration.app_adc_conf.rev_button_inverted,
                          onChanged: (bool newValue) { setState((){ escInputConfiguration.app_adc_conf.rev_button_inverted = newValue; }); },
                          secondary: const Icon(Icons.help_outline),
                        ),

                        Text("Positive Ramping Time: ${escInputConfiguration.app_adc_conf.ramp_time_pos} seconds (0.4 = default)"),
                        SmartSlider(
                          value: escInputConfiguration.app_adc_conf.ramp_time_pos,
                          mini: 0.01,
                          maxi: 0.5,
                          divisions: 100,
                          label: "${escInputConfiguration.app_adc_conf.ramp_time_pos} seconds",
                          onChanged: (value) {
                            setState(() {
                              escInputConfiguration.app_adc_conf.ramp_time_pos = value;
                            });
                          },
                        ),
                        Text("Negative Ramping Time: ${escInputConfiguration.app_adc_conf.ramp_time_neg} seconds (0.2 = default)"),
                        SmartSlider(
                          value: escInputConfiguration.app_adc_conf.ramp_time_neg,
                          mini: 0.01,
                          maxi: 0.5,
                          divisions: 100,
                          label: "${escInputConfiguration.app_adc_conf.ramp_time_neg} seconds",
                          onChanged: (value) {
                            setState(() {
                              escInputConfiguration.app_adc_conf.ramp_time_neg = value;
                            });
                          },
                        ),

                        SwitchListTile(
                          title: Text("Enable Traction Control"),
                          value: escInputConfiguration.app_adc_conf.tc,
                          onChanged: (bool newValue) { setState((){ escInputConfiguration.app_adc_conf.tc = newValue;}); },
                          secondary: const Icon(Icons.compare_arrows),
                        ),
                        Text("Traction Control ERPM ${escInputConfiguration.app_adc_conf.tc_max_diff.toInt()} (3000 = default)"),
                        SmartSlider(
                          value: escInputConfiguration.app_adc_conf.tc_max_diff,
                          mini: 1000.0,
                          maxi: 5000.0,
                          divisions: 1000,
                          label: "${escInputConfiguration.app_adc_conf.tc_max_diff}",
                          onChanged: (value) {
                            setState(() {
                              escInputConfiguration.app_adc_conf.tc_max_diff = value.toInt().toDouble();
                            });
                          },
                        ),

                      ]) : Container(),

                  // Show PPM Options
                  showPPMConfiguration ? Column(
                    children: [
                      Divider(thickness: 3),
                      Text("Calibrate PPM"),

                      ElevatedButton(onPressed: (){
                        // If we are not currently calibrating...
                        if (!ppmCalibrate) {
                          // Clear the captured values when starting calibration
                          ppmMinMS = null;
                          ppmMaxMS = null;
                          // Capture the current PPM control type to restore when finished
                          ppmCalibrateControlTypeToRestore = escInputConfiguration.app_ppm_conf.ctrl_type;
                          // Set the control type to none or the ESC will go WILD
                          escInputConfiguration.app_ppm_conf.ctrl_type = ppm_control_type.PPM_CTRL_TYPE_NONE;
                          _selectedPPMCtrlType = null; // Clear selection
                          // Apply the configuration to the ESC
                          //TODO: if (widget.currentDevice != null) {
                            // Save application configuration; CAN FWD ID can be null
                            Future.delayed(Duration(milliseconds: 250), (){
                              saveAPPCONF(_selectedCANFwdID);
                            });
                          //}
                          // Start calibration routine
                          setState(() {
                            myArguments.notifyStopStartPPMCalibrate(true);
                            ppmCalibrate = true;
                            startStopPPMTimer(false);
                          });
                        } else {
                          // Stop calibration routine
                          setState(() {
                            myArguments.notifyStopStartPPMCalibrate(false);
                            ppmCalibrate = false;
                            startStopPPMTimer(true);
                          });

                          // If we did not receive any PPM information we cannot save the changes
                          if (calibrationState.ppmMillisecondsNow == null) {
                            setState(() {
                              // Restore the user's PPM control type
                              escInputConfiguration.app_ppm_conf.ctrl_type = ppmCalibrateControlTypeToRestore;
                              _selectedPPMCtrlType = null; // Clear selection
                              Future.delayed(Duration(milliseconds: 250), (){
                                saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                              });
                            });
                            return;
                          }

                          // Ask user if they are satisfied with the calibration results
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Accept Calibration?'),
                                content: SingleChildScrollView(
                                  child: ListBody(
                                    children: <Widget>[
                                      Text('PPM values captured'),
                                      Text("Start: ${doublePrecision(ppmMinMS / 1000000, 3)}"),
                                      Text("Center: ${doublePrecision(calibrationState.ppmMillisecondsNow / 1000000, 3)}"),
                                      Text("End: ${doublePrecision(ppmMaxMS / 1000000, 3)}"),
                                      SizedBox(height:10),
                                      Text('If you are satisfied with the results select Accept write values to the ESC')
                                    ],
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text('Reject'),
                                    onPressed: () {
                                      setState(() {
                                        ppmMinMS = null;
                                        ppmMaxMS = null;
                                        // Restore the user's PPM control type
                                        escInputConfiguration.app_ppm_conf.ctrl_type = ppmCalibrateControlTypeToRestore;
                                        _selectedPPMCtrlType = null; // Clear selection
                                        Future.delayed(Duration(milliseconds: 250), (){
                                          saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                        });
                                      });
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: Text('Accept'),
                                    onPressed: () {
                                      setState(() {
                                        // Restore the user's PPM control type
                                        escInputConfiguration.app_ppm_conf.ctrl_type = ppmCalibrateControlTypeToRestore;
                                        _selectedPPMCtrlType = null; // Clear selection
                                        // Set values from calibration
                                        escInputConfiguration.app_ppm_conf.pulse_start = ppmMinMS / 1000000;
                                        escInputConfiguration.app_ppm_conf.pulse_center = calibrationState.ppmMillisecondsNow / 1000000;
                                        escInputConfiguration.app_ppm_conf.pulse_end = ppmMaxMS / 1000000;
                                        // Apply the configuration to the ESC
                                        Future.delayed(Duration(milliseconds: 250), (){
                                          saveAPPCONF(_selectedCANFwdID); // CAN FWD ID can be null
                                        });
                                      });
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        }

                      }, child: Text(ppmCalibrate ? calibrationState.ppmCalibrationRunning ? "Stop Calibration": "Starting Calibration..." : "Calibrate PPM"),),

                      Stack(children: [
                        RangeSlider(
                          values: _rangeSliderDiscreteValues,
                          min: ppmMinMS == null ? 0.5 : ppmMinMS / 1000000,
                          max: ppmMaxMS == null ? 2.5 : ppmMaxMS / 1000000,
                          labels: RangeLabels(
                            _rangeSliderDiscreteValues.start.round().toString(),
                            _rangeSliderDiscreteValues.end.round().toString(),
                          ),
                          onChanged: (values) {},
                        ),
                        calibrationState.ppmMillisecondsNow != null && calibrationState.ppmMillisecondsNow != 0.0 ? SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbColor: Colors.redAccent,
                            ),
                            child: Slider(
                              value: calibrationState.ppmMillisecondsNow / 1000000,
                              min: ppmMinMS == null ? 0.5 : ppmMinMS / 1000000,
                              max: ppmMaxMS == null ? 2.5 : ppmMaxMS / 1000000,
                              label: (calibrationState.ppmMillisecondsNow / 1000000).toString(),
                              onChanged: (value) {},
                            )) : Container(),
                      ],),


                      Table(children: [
                        TableRow(children: [
                          Text(""),
                          Text("Calibrate PPM"),
                          Text("ESC Config")
                        ]),
                        TableRow(children: [
                          Text("Start"),
                          Text("${ppmMinMS != null ? ppmMinMS / 1000000 : ""}"),
                          Text("${doublePrecision(escInputConfiguration.app_ppm_conf.pulse_start, 3)}")
                        ]),
                        TableRow(children: [
                          Text("Center"),
                          Text("${calibrationState.ppmMillisecondsNow != null ? calibrationState.ppmMillisecondsNow / 1000000 : ""}"),
                          Text("${doublePrecision(escInputConfiguration.app_ppm_conf.pulse_center, 3)}")
                        ]),
                        TableRow(children: [
                          Text("End"),
                          Text("${ppmMaxMS != null ? ppmMaxMS / 1000000 : ""}"),
                          Text("${doublePrecision(escInputConfiguration.app_ppm_conf.pulse_end, 3)}")
                        ]),
                      ],),

                      Divider(thickness: 3),
                      Text("Select PPM Control Type"),
                      Center(child:
                      DropdownButton<ListItem>(
                        value: _selectedPPMCtrlType,
                        items: _ppmCtrlTypeDropdownItems,
                        onChanged: (newValue) {
                          setState(() {
                            _selectedPPMCtrlType = newValue;
                            escInputConfiguration.app_ppm_conf.ctrl_type = ppm_control_type.values[newValue.value];
                          });
                        },
                      )
                      ),

                      Text("Input deadband: ${(escInputConfiguration.app_ppm_conf.hyst * 100.0).toInt()}% (15% = default)"),
                      SmartSlider(
                        value: escInputConfiguration.app_ppm_conf.hyst,
                        mini: 0.01,
                        maxi: 0.35,
                        divisions: 100,
                        label: "${(escInputConfiguration.app_ppm_conf.hyst * 100.0).toInt()}%",
                        onChanged: (value) {
                          setState(() {
                            escInputConfiguration.app_ppm_conf.hyst = value;
                          });
                        },
                      ),

                      ElevatedButton(onPressed: (){
                        setState(() {
                          showAdvancedOptions = !showAdvancedOptions;
                        });
                      },
                        child: Text("${showAdvancedOptions?"Hide":"Show"} Advanced Options"),),

                      showAdvancedOptions ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: Text("Median Filter (default = on)"),
                            value: escInputConfiguration.app_ppm_conf.median_filter,
                            onChanged: (bool newValue) { setState((){ escInputConfiguration.app_ppm_conf.median_filter = newValue;}); },
                            secondary: const Icon(Icons.filter_tilt_shift),
                          ),
                          SwitchListTile(
                            title: Text("Safe Start (default = on)"),
                            value: escInputConfiguration.app_ppm_conf.safe_start.index > 0 ? true : false,
                            onChanged: (bool newValue) { setState((){ escInputConfiguration.app_ppm_conf.safe_start = SAFE_START_MODE.values[newValue ? 1 : 0];}); },
                            secondary: const Icon(Icons.not_started),
                          ),
                          Text("Positive Ramping Time: ${doublePrecision(escInputConfiguration.app_ppm_conf.ramp_time_pos,2)} seconds (0.4 = default)"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.ramp_time_pos,
                            mini: 0.01,
                            maxi: 0.5,
                            divisions: 100,
                            label: "${escInputConfiguration.app_ppm_conf.ramp_time_pos} seconds",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.ramp_time_pos = value;
                              });
                            },
                          ),
                          Text("Negative Ramping Time: ${escInputConfiguration.app_ppm_conf.ramp_time_neg} seconds (0.2 = default)"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.ramp_time_neg,
                            mini: 0.01,
                            maxi: 0.5,
                            divisions: 100,
                            label: "${escInputConfiguration.app_ppm_conf.ramp_time_neg} seconds",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.ramp_time_neg = value;
                              });
                            },
                          ),
                          Text("PID Max ERPM ${escInputConfiguration.app_ppm_conf.pid_max_erpm} (15000 = default)"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.pid_max_erpm,
                            mini: 10000.0,
                            maxi: 30000.0,
                            divisions: 100,
                            label: "${escInputConfiguration.app_ppm_conf.pid_max_erpm}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.pid_max_erpm = value.toInt().toDouble();
                              });
                            },
                          ),
                          Text("Max ERPM for direction switch ${escInputConfiguration.app_ppm_conf.max_erpm_for_dir} (4000 = default)"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.max_erpm_for_dir,
                            mini: 1000.0,
                            maxi: 8000.0,
                            divisions: 700,
                            label: "${escInputConfiguration.app_ppm_conf.max_erpm_for_dir}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.max_erpm_for_dir = value.toInt().toDouble();
                              });
                            },
                          ),
                          Text("Smart Reverse Max Duty Cycle ${doublePrecision(escInputConfiguration.app_ppm_conf.smart_rev_max_duty,2)} (0.07 = default)"),
                          Slider(
                            value: escInputConfiguration.app_ppm_conf.smart_rev_max_duty,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            label: "${escInputConfiguration.app_ppm_conf.smart_rev_max_duty}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.smart_rev_max_duty = value;
                              });
                            },
                          ),
                          Text("Smart Reverse Ramp Time ${escInputConfiguration.app_ppm_conf.smart_rev_ramp_time} seconds (3.0 = default)"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.smart_rev_ramp_time,
                            mini: 1,
                            maxi: 10,
                            divisions: 1000,
                            label: "${escInputConfiguration.app_ppm_conf.smart_rev_ramp_time}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.smart_rev_ramp_time = value;
                              });
                            },
                          ),

                          Text("Select Throttle Exponential Mode"),
                          Center(child:
                          DropdownButton<ListItem>(
                            value: _selectedThrExpMode,
                            items: _thrExpModeDropdownItems,
                            onChanged: (newValue) {
                              setState(() {
                                _selectedThrExpMode = newValue;
                                escInputConfiguration.app_ppm_conf.throttle_exp_mode = thr_exp_mode.values[newValue.value];
                              });
                            },
                          )
                          ),
                          Center(child: Container(
                            height: 100,
                            child: CustomPaint(
                              painter: CurvePainter(
                                width: 100,
                                exp: escInputConfiguration.app_ppm_conf.throttle_exp,
                                expNegative: escInputConfiguration.app_ppm_conf.throttle_exp_brake,
                                expMode: escInputConfiguration.app_ppm_conf.throttle_exp_mode,
                              ),
                            ),
                          )
                          ),
                          Text("Throttle Exponent ${escInputConfiguration.app_ppm_conf.throttle_exp}"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.throttle_exp,
                            mini: -5,
                            maxi: 5,
                            divisions: 100,
                            label: "${escInputConfiguration.app_ppm_conf.throttle_exp}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.throttle_exp = value;
                              });
                            },
                          ),

                          Text("Throttle Exponent Brake ${escInputConfiguration.app_ppm_conf.throttle_exp_brake}"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.throttle_exp_brake,
                            mini: -5,
                            maxi: 5,
                            divisions: 100,
                            label: "${escInputConfiguration.app_ppm_conf.throttle_exp_brake}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.throttle_exp_brake = value;
                              });
                            },
                          ),


                          SwitchListTile(
                            title: Text("Enable Traction Control"),
                            value: escInputConfiguration.app_ppm_conf.tc,
                            onChanged: (bool newValue) { setState((){ escInputConfiguration.app_ppm_conf.tc = newValue;}); },
                            secondary: const Icon(Icons.compare_arrows),
                          ),
                          //Text("traction control ${escInputConfiguration.app_ppm_conf.tc}"),
                          Text("Traction Control ERPM ${escInputConfiguration.app_ppm_conf.tc_max_diff} (3000 = default)"),
                          SmartSlider(
                            value: escInputConfiguration.app_ppm_conf.tc_max_diff,
                            mini: 1000.0,
                            maxi: 5000.0,
                            divisions: 1000,
                            label: "${escInputConfiguration.app_ppm_conf.tc_max_diff}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_ppm_conf.tc_max_diff = value.toInt().toDouble();
                              });
                            },
                          ),

                          SwitchListTile(
                            title: Text("Multiple ESC over CAN (default = on)"),
                            value: escInputConfiguration.app_ppm_conf.multi_esc,
                            onChanged: (bool newValue) { setState((){ escInputConfiguration.app_ppm_conf.multi_esc = newValue;}); },
                            secondary: const Icon(Icons.settings_ethernet),
                          ),

                        ],) : Container(),

                      showAdvancedOptions ? ElevatedButton(onPressed: (){
                        setState(() {
                          showAdvancedOptions = false;
                        });
                      }, child: Text("Hide Advanced Options"),) : Container(),

                    ],) : Container(),

                  showNunchukConfiguration ? Column(
                      children: [
                        Divider(thickness: 3),
                        Text("UART Config"),

                        Center(child:
                        DropdownButton<ListItem>(
                          value: _selectedNunchukCtrlType,
                          items: _nunchuckCtrlTypeDropdownItems,
                          onChanged: (newValue) {
                            setState(() {
                              _selectedNunchukCtrlType = newValue;
                              escInputConfiguration.app_chuk_conf.ctrl_type = chuk_control_type.values[newValue.value];
                            });
                          },
                        )
                        ),


                        Text("Input deadband: ${(escInputConfiguration.app_chuk_conf.hyst * 100).toInt()}% (15% = default)"),
                        SmartSlider(
                          value: escInputConfiguration.app_chuk_conf.hyst,
                          mini: 0.01,
                          maxi: 0.35,
                          divisions: 100,
                          label: "${(escInputConfiguration.app_chuk_conf.hyst * 100).toInt()}%",
                          onChanged: (value) {
                            setState(() {
                              escInputConfiguration.app_chuk_conf.hyst = value;
                            });
                          },
                        ),

                        // Smart reverse doesn't work in Current Bidirectional mode
                        escInputConfiguration.app_chuk_conf.ctrl_type != chuk_control_type.CHUK_CTRL_TYPE_CURRENT_BIDIRECTIONAL ?
                        Column(children: [
                          SwitchListTile(
                            title: Text("Smart Reverse (default = on)"),
                            value: escInputConfiguration.app_chuk_conf.use_smart_rev,
                            onChanged: (bool newValue) { setState((){ escInputConfiguration.app_chuk_conf.use_smart_rev = newValue;}); },
                            secondary: const Icon(Icons.filter_tilt_shift),
                          ),

                          Text("Smart Reverse Max Duty Cycle ${(escInputConfiguration.app_chuk_conf.smart_rev_max_duty * 100).toInt()}% (7% = default)"),
                          Slider(
                            value: escInputConfiguration.app_chuk_conf.smart_rev_max_duty,
                            min: 0,
                            max: 1,
                            divisions: 100,
                            label: "${(escInputConfiguration.app_chuk_conf.smart_rev_max_duty * 100).toInt()}%",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_chuk_conf.smart_rev_max_duty = value;
                              });
                            },
                          ),

                          Text("Smart Reverse Ramp Time ${escInputConfiguration.app_chuk_conf.smart_rev_ramp_time} seconds (3.0 = default)"),
                          SmartSlider(
                            value: escInputConfiguration.app_chuk_conf.smart_rev_ramp_time,
                            mini: 1,
                            maxi: 10,
                            divisions: 90,
                            label: "${escInputConfiguration.app_chuk_conf.smart_rev_ramp_time}",
                            onChanged: (value) {
                              setState(() {
                                escInputConfiguration.app_chuk_conf.smart_rev_ramp_time = value;
                              });
                            },
                          ),
                        ]) : Container(),


                        ElevatedButton(onPressed: (){
                          setState(() {
                            showAdvancedOptions = !showAdvancedOptions;
                          });
                        },
                          child: Text("${showAdvancedOptions?"Hide":"Show"} Advanced Options"),),

                        showAdvancedOptions ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text("Positive Ramping Time: ${doublePrecision(escInputConfiguration.app_chuk_conf.ramp_time_pos,2)} seconds (0.4 = default)"),
                            SmartSlider(
                              value: escInputConfiguration.app_chuk_conf.ramp_time_pos,
                              mini: 0.01,
                              maxi: 0.5,
                              divisions: 100,
                              label: "${escInputConfiguration.app_chuk_conf.ramp_time_pos} seconds",
                              onChanged: (value) {
                                setState(() {
                                  escInputConfiguration.app_chuk_conf.ramp_time_pos = value;
                                });
                              },
                            ),

                            Text("Negative Ramping Time: ${escInputConfiguration.app_chuk_conf.ramp_time_neg} seconds (0.2 = default)"),
                            SmartSlider(
                              value: escInputConfiguration.app_chuk_conf.ramp_time_neg,
                              mini: 0.01,
                              maxi: 0.5,
                              divisions: 100,
                              label: "${escInputConfiguration.app_chuk_conf.ramp_time_neg} seconds",
                              onChanged: (value) {
                                setState(() {
                                  escInputConfiguration.app_chuk_conf.ramp_time_neg = value;
                                });
                              },
                            ),

                            //TODO: Text("eRPM/s w/CruiseControl (3000 = default) ${escInputConfiguration.app_chuk_conf.stick_erpm_per_s_in_cc}"),

                            Text("Select Throttle Exponential Mode"),
                            Center(child:
                            DropdownButton<ListItem>(
                              value: _selectedThrExpModeNunchuk,
                              items: _thrExpModeNunchukDropdownItems,
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedThrExpModeNunchuk = newValue;
                                  escInputConfiguration.app_chuk_conf.throttle_exp_mode = thr_exp_mode.values[newValue.value];
                                });
                              },
                            )
                            ),

                            Center(child: Container(
                              height: 100,
                              child: CustomPaint(
                                painter: CurvePainter(
                                  width: 100,
                                  exp: escInputConfiguration.app_chuk_conf.throttle_exp,
                                  expNegative: escInputConfiguration.app_chuk_conf.throttle_exp_brake,
                                  expMode: escInputConfiguration.app_chuk_conf.throttle_exp_mode,
                                ),
                              ),
                            )
                            ),
                            Text("Throttle Exponent ${escInputConfiguration.app_chuk_conf.throttle_exp}"),
                            SmartSlider(
                              value: escInputConfiguration.app_chuk_conf.throttle_exp,
                              mini: -5,
                              maxi: 5,
                              divisions: 100,
                              label: "${escInputConfiguration.app_chuk_conf.throttle_exp}",
                              onChanged: (value) {
                                setState(() {
                                  escInputConfiguration.app_chuk_conf.throttle_exp = value;
                                });
                              },
                            ),

                            Text("Throttle Exponent Brake ${escInputConfiguration.app_chuk_conf.throttle_exp_brake}"),
                            SmartSlider(
                              value: escInputConfiguration.app_chuk_conf.throttle_exp_brake,
                              mini: -5,
                              maxi: 5,
                              divisions: 100,
                              label: "${escInputConfiguration.app_chuk_conf.throttle_exp_brake}",
                              onChanged: (value) {
                                setState(() {
                                  escInputConfiguration.app_chuk_conf.throttle_exp_brake = value;
                                });
                              },
                            ),


                            SwitchListTile(
                              title: Text("Enable Traction Control"),
                              value: escInputConfiguration.app_chuk_conf.tc,
                              onChanged: (bool newValue) { setState((){ escInputConfiguration.app_chuk_conf.tc = newValue;}); },
                              secondary: const Icon(Icons.compare_arrows),
                            ),

                            Text("Traction Control ERPM ${escInputConfiguration.app_chuk_conf.tc_max_diff} (3000 = default)"),
                            SmartSlider(
                              value: escInputConfiguration.app_chuk_conf.tc_max_diff,
                              mini: 1000.0,
                              maxi: 5000.0,
                              divisions: 1000,
                              label: "${escInputConfiguration.app_chuk_conf.tc_max_diff}",
                              onChanged: (value) {
                                setState(() {
                                  escInputConfiguration.app_chuk_conf.tc_max_diff = value.toInt().toDouble();
                                });
                              },
                            ),

                            SwitchListTile(
                              title: Text("Multiple ESC over CAN (default = on"),
                              value: escInputConfiguration.app_chuk_conf.multi_esc,
                              onChanged: (bool newValue) { setState((){ escInputConfiguration.app_chuk_conf.multi_esc = newValue;}); },
                              secondary: const Icon(Icons.settings_ethernet),
                            ),

                          ],) : Container(),

                        showAdvancedOptions ? ElevatedButton(onPressed: (){
                          setState(() {
                            showAdvancedOptions = false;
                          });
                        }, child: Text("Hide Advanced Options"),) : Container(),


                      ]
                  ) : Container(),

                  ElevatedButton(
                      child: Text("Save to ESC${_selectedCANFwdID != null ? "/CAN $_selectedCANFwdID" : ""}"),
                      onPressed: () {
                        //TODO: if (widget.currentDevice != null) {
                          //setState(() {
                          // Save application configuration; CAN FWD ID can be null
                          saveAPPCONF(_selectedCANFwdID);
                        //}
                      }),

                  // PPM Default All
                  showPPMConfiguration ? ElevatedButton(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_outlined),
                          Text("Set ALL to default")
                        ],),
                      onPressed: () {
                        setState(() {
                          escInputConfiguration.app_to_use = app_use.APP_PPM_UART;
                          _selectedAppMode = null;
                          escInputConfiguration.app_ppm_conf.pulse_start = 1.0;
                          escInputConfiguration.app_ppm_conf.pulse_end = 2.0;
                          escInputConfiguration.app_ppm_conf.pulse_center = 1.5;
                          escInputConfiguration.app_ppm_conf.ctrl_type = ppm_control_type.PPM_CTRL_TYPE_NONE;
                          _selectedPPMCtrlType = null;
                          escInputConfiguration.app_ppm_conf.median_filter = true;
                          escInputConfiguration.app_ppm_conf.safe_start = SAFE_START_MODE.SAFE_START_REGULAR;
                          escInputConfiguration.app_ppm_conf.ramp_time_pos = 0.4;
                          escInputConfiguration.app_ppm_conf.ramp_time_neg = 0.2;
                          escInputConfiguration.app_ppm_conf.pid_max_erpm = 15000.0;
                          escInputConfiguration.app_ppm_conf.max_erpm_for_dir = 4000.0;
                          escInputConfiguration.app_ppm_conf.smart_rev_max_duty = 0.07;
                          escInputConfiguration.app_ppm_conf.smart_rev_ramp_time = 3.0;
                          escInputConfiguration.app_ppm_conf.throttle_exp_mode = thr_exp_mode.THR_EXP_POLY;
                          _selectedThrExpMode = null;
                          escInputConfiguration.app_ppm_conf.throttle_exp = 0.0;
                          escInputConfiguration.app_ppm_conf.throttle_exp_brake = 0.0;
                          escInputConfiguration.app_ppm_conf.tc = false;
                          escInputConfiguration.app_ppm_conf.tc_max_diff = 3000.0;
                          escInputConfiguration.app_ppm_conf.hyst = 0.15;
                        });
                      }) : Container(),
                  Divider(height: 10,),
                  Center(child: Text("Additional Tools"),),
                  Row( mainAxisAlignment: MainAxisAlignment.spaceBetween ,
                      children: <Widget>[
                        ElevatedButton(
                          //TODO: quick pair for CAN FWD device?
                            child: Row(children: <Widget>[
                              Icon(Icons.settings_remote),
                              Text("nRF Quick Pair")
                            ],),
                            onPressed: () {
                              // Don't write if not connected
                              if (theTXCharacteristic != null) {
                                var byteData = new ByteData(10); //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
                                byteData.setUint8(0, 0x02);
                                byteData.setUint8(1, 0x05);
                                byteData.setUint8(2, COMM_PACKET_ID.COMM_NRF_START_PAIRING.index);
                                byteData.setUint32(3, 10000); //milliseconds
                                int checksum = CRC16.crc16(byteData.buffer.asUint8List(), 2, 5);
                                byteData.setUint16(7, checksum);
                                byteData.setUint8(9, 0x03); //End of packet

                                //<start><payloadLen><packetID><int32_milliseconds><crc1><crc2><end>
                                theTXCharacteristic.write(byteData.buffer.asUint8List()).then((value){
                                  globalLogger.d('You have 10 seconds to power on your remote!');
                                }).catchError((e){
                                  globalLogger.e("nRF Quick Pair: Exception: $e");
                                });
                              } else {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text("nRF Quick Pair"),
                                      content: Text("Oops. Try connecting to your board first."),
                                    );
                                  },
                                );
                              }
                            }),]),
                ],
              ),
            )
          ],
        ),
      ),
    );
      
  }

  @override
  Widget build(BuildContext context) {
    print("Building InputConfigurationEditor");

    //Receive arguments building this widget
    myArguments = ModalRoute.of(context).settings.arguments;
    if(myArguments == null){
      return Container(child:Text("No Arguments"));
    }

    if(appconfSubscription == null) {
      appconfSubscription = myArguments.dataStream.listen((value) {
        globalLogger.wtf("Stream Data Received");
        setState(() {
          // Clear selections
          _selectedPPMCtrlType = null;
          _selectedThrExpMode = null;
          _selectedAppMode = null;
          // Update appconf
          escInputConfiguration = value;
        });
      });
    }

    if (theTXCharacteristic == null) {
      theTXCharacteristic = myArguments.theTXCharacteristic;
    }
    
    if (calibrationSubscription == null) {
      calibrationSubscription = myArguments.calibrationStream.listen((value) {
        globalLogger.wtf("Calibration Data Received ${value.adcCalibrationRunning}");
        setState(() {
          calibrationState = value;
        });
      });
    }

    if (calibrationState == null) {
      calibrationState = myArguments.calibrationState;
    }

    if (discoveredCANDevices == null) {
      discoveredCANDevices = myArguments.discoveredCANDevices;
    }
    if (escInputConfiguration == null) {
      escInputConfiguration = myArguments.applicationConfiguration;
    }
    escFirmwareVersion = myArguments.escFirmwareVersion;

    return new WillPopScope(
      onWillPop: () async => false,
      child: new Scaffold(
        appBar: AppBar(
          title: Row(children: <Widget>[
            Icon( Icons.settings_applications_outlined,
              size: 35.0,
              color: Colors.blue,
            ),
            SizedBox(width: 3),
            Text("Input Configuration"),
          ],),
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: (){
              //TODO: check if changes were made without saving
              Navigator.of(context).pop(changesMade);
            },
          ),
        ),
        body: FutureBuilder<Widget>(
            future: _buildBody(context),
            builder: (context, AsyncSnapshot<Widget> snapshot) {
              if (snapshot.hasData) {
                return snapshot.data;
              } else {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("Loading...."),
                    SizedBox(height: 10),
                    Center(child: SpinKitRipple(color: Colors.white,)),
                    Text("Please wait 🙏"),
                  ],);
              }
            }
        ),
      ),
    );
  }
}
