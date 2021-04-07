import 'dart:typed_data';

class DieBieMSTelemetry {
  DieBieMSTelemetry() {
    packVoltage = 0;
    packCurrent = 0;
    soc = 0;
    cellVoltageHigh = 0;
    cellVoltageAverage = 0;
    cellVoltageLow = 0;
    cellVoltageMismatch = 0;
    loCurrentLoadVoltage = 0;
    loCurrentLoadCurrent = 0;
    hiCurrentLoadVoltage = 0;
    hiCurrentLoadCurrent = 0;
    auxVoltage = 0;
    auxCurrent = 0;
    tempBatteryHigh = 0;
    tempBatteryAverage = 0;
    tempBMSHigh = 0;
    tempBMSAverage = 0;
    operationalState = 0;
    chargeBalanceActive = 0;
    faultState = 0;
    canID = 0;
    noOfCells = 0;
    cellVoltage = [];
  }
  // DieBieMS COMM_GET_VALUES
  double packVoltage;
  double packCurrent;
  int soc;
  double cellVoltageHigh;
  double cellVoltageAverage;
  double cellVoltageLow;
  double cellVoltageMismatch;
  double loCurrentLoadVoltage;
  double loCurrentLoadCurrent;
  double hiCurrentLoadVoltage;
  double hiCurrentLoadCurrent;
  double auxVoltage;
  double auxCurrent;
  double tempBatteryHigh;
  double tempBatteryAverage;
  double tempBMSHigh;
  double tempBMSAverage;
  int operationalState;
  int chargeBalanceActive;
  int faultState;
  int canID;
  // DieBieMS COMM_GET_BMS_CELLS
  int noOfCells;
  List<double> cellVoltage;
}

class DieBieMSHelper {
  static const int COMM_GET_BMS_CELLS = 51;
  DieBieMSTelemetry latestTelemetry = new DieBieMSTelemetry();

  DieBieMSTelemetry processCells(Uint8List payload) {
    int index = 1;

    latestTelemetry.noOfCells = payload[index++];
    latestTelemetry.cellVoltage = [];
    for( int i=0; i<latestTelemetry.noOfCells; ++i) {
      latestTelemetry.cellVoltage.add(buffer_get_float16(payload, index, 1e3));
      index += 2;
    }

    return latestTelemetry;
  }
  
  DieBieMSTelemetry processTelemetry(Uint8List payload, int expectedCANID) {
    int index = 1;
    DieBieMSTelemetry parsedTelemetry = new DieBieMSTelemetry();
    parsedTelemetry.packVoltage = buffer_get_float32(payload, index, 1e3); index += 4;
    parsedTelemetry.packCurrent = buffer_get_float32(payload, index, 1e3); index += 4;
    parsedTelemetry.soc = payload[index++];
    parsedTelemetry.cellVoltageHigh = buffer_get_float32(payload, index, 1e3); index += 4;
    parsedTelemetry.cellVoltageAverage = buffer_get_float32(payload, index, 1e3); index += 4;
    parsedTelemetry.cellVoltageLow = buffer_get_float32(payload, index, 1e3); index += 4;
    parsedTelemetry.cellVoltageMismatch = buffer_get_float32(payload, index, 1e3); index += 4;
    parsedTelemetry.loCurrentLoadVoltage = buffer_get_float16(payload, index, 1e2); index += 2;
    parsedTelemetry.loCurrentLoadCurrent = buffer_get_float16(payload, index, 1e2); index += 2;
    parsedTelemetry.hiCurrentLoadVoltage = buffer_get_float16(payload, index, 1e2); index += 2;
    parsedTelemetry.hiCurrentLoadCurrent = buffer_get_float16(payload, index, 1e2); index += 2;
    parsedTelemetry.auxVoltage = buffer_get_float16(payload, index, 1e2); index += 2;
    parsedTelemetry.auxCurrent = buffer_get_float16(payload, index, 1e2); index += 2;
    parsedTelemetry.tempBatteryHigh = buffer_get_float16(payload, index, 1e1); index += 2;
    parsedTelemetry.tempBatteryAverage = buffer_get_float16(payload, index, 1e1); index += 2;
    parsedTelemetry.tempBMSHigh = buffer_get_float16(payload, index, 1e1); index += 2;
    parsedTelemetry.tempBMSAverage = buffer_get_float16(payload, index, 1e1); index += 2;
    parsedTelemetry.operationalState = payload[index++];
    parsedTelemetry.chargeBalanceActive = payload[index++];
    parsedTelemetry.faultState = payload[index++];
    parsedTelemetry.canID = payload[index];

    if( parsedTelemetry.canID == expectedCANID ) {
      latestTelemetry = parsedTelemetry;
    } else {
      print("TODO: this is an ESC packet");
    }

    return latestTelemetry;
  }

  int buffer_get_int16(Uint8List buffer, int index) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt16(index);
  }

  int buffer_get_int32(Uint8List buffer, int index) {
    var byteData = new ByteData.view(buffer.buffer);
    return byteData.getInt32(index);
  }

  double buffer_get_float16(Uint8List buffer, int index, double scale) {
    return buffer_get_int16(buffer, index) / scale;
  }

  double buffer_get_float32(Uint8List buffer, int index, double scale) {
    return buffer_get_int32(buffer, index) / scale;
  }
}

