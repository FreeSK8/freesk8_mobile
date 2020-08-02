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
    cellVoltage = new List();
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
    latestTelemetry.cellVoltage = new List();
    for( int i=0; i<latestTelemetry.noOfCells; ++i) {
      latestTelemetry.cellVoltage.add(buffer_get_float16(payload, index, 1e3));
      index += 2;
    }

    return latestTelemetry;
  }
  
  DieBieMSTelemetry processTelemetry(Uint8List payload) {
    int index = 1;

    latestTelemetry.packVoltage = buffer_get_float32(payload, index, 1e3); index += 4;
    latestTelemetry.packCurrent = buffer_get_float32(payload, index, 1e3); index += 4;
    latestTelemetry.soc = payload[index++];
    latestTelemetry.cellVoltageHigh = buffer_get_float32(payload, index, 1e3); index += 4;
    latestTelemetry.cellVoltageAverage = buffer_get_float32(payload, index, 1e3); index += 4;
    latestTelemetry.cellVoltageLow = buffer_get_float32(payload, index, 1e3); index += 4;
    latestTelemetry.cellVoltageMismatch = buffer_get_float32(payload, index, 1e3); index += 4;
    latestTelemetry.loCurrentLoadVoltage = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.loCurrentLoadCurrent = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.hiCurrentLoadVoltage = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.hiCurrentLoadCurrent = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.auxVoltage = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.auxCurrent = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.tempBatteryHigh = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.tempBatteryAverage = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.tempBMSHigh = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.tempBMSAverage = buffer_get_float16(payload, index, 1e2); index += 2;
    latestTelemetry.operationalState = payload[index++];
    latestTelemetry.chargeBalanceActive = payload[index++];
    latestTelemetry.faultState = payload[index++];
    latestTelemetry.canID = payload[index];

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

