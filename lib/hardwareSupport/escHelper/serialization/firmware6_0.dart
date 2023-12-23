import 'dart:typed_data';

import '../../../globalUtilities.dart';

import 'buffers.dart';
import '../appConf.dart';
import '../mcConf.dart';

class SerializeFirmware60 { //fw6

  static const int MCCONF_SIGNATURE_FW6_0 = 776184161; //fw6
  static const int APPCONF_SIGNATURE_FW6_0 = 486554156;

  APPCONF processAPPCONF(Uint8List buffer) {
    int index = 1;
    APPCONF appconfData = new APPCONF();
    int signature = buffer_get_uint32(buffer, index); index += 4;
    if (signature != APPCONF_SIGNATURE_FW6_0) { //fw6
      globalLogger.e("Invalid APPCONF signature; received $signature expecting $APPCONF_SIGNATURE_FW6_0");
      return appconfData;
    }
    globalLogger.d("VALID APPCONF SIGNATURE winky face emoji, winky face emoji, winky face emoji");

    appconfData.controller_id = buffer[index++];
    appconfData.timeout_msec = buffer_get_uint32(buffer, index); index += 4;
    appconfData.timeout_brake_current = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.can_status_rate_1 = buffer_get_uint16(buffer, index); index += 2; //fw6
    appconfData.can_status_rate_2 = buffer_get_uint16(buffer, index); index += 2; //fw6
    appconfData.can_status_msgs_r1 = buffer[index++]; //fw6
    appconfData.can_status_msgs_r2 = buffer[index++]; //fw6
    appconfData.can_baud_rate = CAN_BAUD.values[buffer[index++]];
    appconfData.pairing_done = buffer[index++] > 0 ? true : false;
    appconfData.permanent_uart_enabled = buffer[index++] > 0 ? true : false;
    appconfData.shutdown_mode = SHUTDOWN_MODE.values[buffer[index++]];
    appconfData.can_mode = CAN_MODE.values[buffer[index++]];
    appconfData.uavcan_esc_index = buffer[index++];
    appconfData.uavcan_raw_mode = UAVCAN_RAW_MODE.values[buffer[index++]];
    appconfData.uavcan_raw_rpm_max = buffer_get_float32_auto(buffer, index); index += 4; //TODO investigate OoO errwhere
    appconfData.uavcan_status_current_mode = UAVCAN_STATUS_CURRENT_MODE.values[buffer[index++]];  //fw6
    appconfData.servo_out_enabled = buffer[index++] > 0 ? true : false;
    appconfData.kill_sw_mode = KILL_SW_MODE.values[buffer[index++]];
    appconfData.app_to_use = app_use.values[buffer[index++]];
    appconfData.app_ppm_conf.ctrl_type = ppm_control_type.values[buffer[index++]];
    appconfData.app_ppm_conf.pid_max_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.hyst = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.pulse_start = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.pulse_end = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.pulse_center = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.median_filter = buffer[index++] > 0 ? true : false;
    appconfData.app_ppm_conf.safe_start = SAFE_START_MODE.values[buffer[index++]];
    appconfData.app_ppm_conf.throttle_exp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.throttle_exp_brake = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.throttle_exp_mode = thr_exp_mode.values[buffer[index++]];
    appconfData.app_ppm_conf.ramp_time_pos = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.ramp_time_neg = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_ppm_conf.tc = buffer[index++] > 0 ? true : false;
    appconfData.app_ppm_conf.tc_max_diff = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.max_erpm_for_dir = buffer_get_float16(buffer, index, 1); index += 2;
    appconfData.app_ppm_conf.smart_rev_max_duty = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_ppm_conf.smart_rev_ramp_time = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.ctrl_type = adc_control_type.values[buffer[index++]];
    appconfData.app_adc_conf.hyst = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.voltage_start = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    appconfData.app_adc_conf.voltage_end = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    appconfData.app_adc_conf.voltage_min = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    appconfData.app_adc_conf.voltage_max = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    appconfData.app_adc_conf.voltage_center = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    appconfData.app_adc_conf.voltage2_start = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    appconfData.app_adc_conf.voltage2_end = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    appconfData.app_adc_conf.use_filter = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.safe_start = SAFE_START_MODE.values[buffer[index++]];
    appconfData.app_adc_conf.buttons = buffer[index++]; //fw6
    appconfData.app_adc_conf.voltage_inverted = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.voltage2_inverted = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.throttle_exp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.throttle_exp_brake = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.throttle_exp_mode = thr_exp_mode.values[buffer[index++]];
    appconfData.app_adc_conf.ramp_time_pos = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.ramp_time_neg = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.tc = buffer[index++] > 0 ? true : false;
    appconfData.app_adc_conf.tc_max_diff = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_adc_conf.update_rate_hz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_uart_baudrate = buffer_get_uint32(buffer, index); index += 4;
    appconfData.app_chuk_conf.ctrl_type = chuk_control_type.values[buffer[index++]];
    appconfData.app_chuk_conf.hyst = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.ramp_time_pos = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.ramp_time_neg = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.stick_erpm_per_s_in_cc = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.throttle_exp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.throttle_exp_brake = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.throttle_exp_mode = thr_exp_mode.values[buffer[index++]];
    appconfData.app_chuk_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_chuk_conf.tc = buffer[index++] > 0 ? true : false;
    appconfData.app_chuk_conf.tc_max_diff = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.use_smart_rev = buffer[index++] > 0 ? true : false;
    appconfData.app_chuk_conf.smart_rev_max_duty = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_chuk_conf.smart_rev_ramp_time = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_nrf_conf.speed = NRF_SPEED.values[buffer[index++]];
    appconfData.app_nrf_conf.power = NRF_POWER.values[buffer[index++]];
    appconfData.app_nrf_conf.crc_type = NRF_CRC .values[buffer[index++]];
    appconfData.app_nrf_conf.retry_delay = NRF_RETR_DELAY.values[buffer[index++]];
    appconfData.app_nrf_conf.retries = buffer[index++];
    appconfData.app_nrf_conf.channel = buffer[index++];
    appconfData.app_nrf_conf.address[0] = buffer[index++];
    appconfData.app_nrf_conf.address[1] = buffer[index++];
    appconfData.app_nrf_conf.address[2] = buffer[index++];
    appconfData.app_nrf_conf.send_crc_ack = buffer[index++] > 0 ? true : false;
    appconfData.app_balance_conf.pid_mode = BALANCE_PID_MODE.values[buffer[index++]]; //fw6
    appconfData.app_balance_conf.kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.ki = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.kd = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.kp2 = buffer_get_float32_auto(buffer, index); index += 4;  //fw6
    appconfData.app_balance_conf.ki2 = buffer_get_float32_auto(buffer, index); index += 4;  //fw6
    appconfData.app_balance_conf.kd2 = buffer_get_float32_auto(buffer, index); index += 4;  //fw6
    appconfData.app_balance_conf.hertz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.loop_time_filter = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_pitch = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.fault_roll = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.fault_duty = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.fault_adc1 = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.fault_adc2 = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.fault_delay_pitch = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_delay_roll = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_delay_duty = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_delay_switch_half = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_delay_switch_full = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_adc_half_erpm = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.fault_is_dual_switch = buffer[index++] > 0 ? true : false; //fw6
    appconfData.app_balance_conf.tiltback_duty_angle = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.tiltback_duty_speed = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.tiltback_duty = buffer_get_float16(buffer, index, 1000); index += 2;
    appconfData.app_balance_conf.tiltback_hv_angle = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.tiltback_hv_speed = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.tiltback_hv = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_lv_angle = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.tiltback_lv_speed = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.tiltback_lv = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_return_speed = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.tiltback_constant = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_constant_erpm = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.tiltback_variable = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.tiltback_variable_max = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.noseangling_speed = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_balance_conf.startup_pitch_tolerance = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.startup_roll_tolerance = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.startup_speed = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.deadzone = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.multi_esc = buffer[index++] > 0 ? true : false;
    appconfData.app_balance_conf.yaw_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.yaw_ki = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.yaw_kd = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.roll_steer_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.roll_steer_erpm_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.brake_current = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.brake_timeout = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.yaw_current_clamp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.ki_limit = buffer_get_float32_auto(buffer, index); index += 4; //fw6
    appconfData.app_balance_conf.kd_pt1_lowpass_frequency = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.kd_pt1_highpass_frequency = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.kd_biquad_lowpass = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.kd_biquad_highpass = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.booster_angle = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.booster_ramp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.booster_current = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.torquetilt_start_current = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.torquetilt_angle_limit = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.torquetilt_on_speed = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.torquetilt_off_speed = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.torquetilt_strength = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.torquetilt_filter = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.turntilt_strength = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.turntilt_angle_limit = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.turntilt_start_angle = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.turntilt_start_erpm = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.turntilt_speed = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.app_balance_conf.turntilt_erpm_boost = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_balance_conf.turntilt_erpm_boost_end = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_pas_conf.ctrl_type = pas_control_type.values[buffer[index++]];
    appconfData.app_pas_conf.sensor_type = pas_sensor_type.values[buffer[index++]];
    appconfData.app_pas_conf.current_scaling = buffer_get_float16(buffer, index, 1000); index += 2;
    appconfData.app_pas_conf.pedal_rpm_start = buffer_get_float16(buffer, index, 10); index += 2;
    appconfData.app_pas_conf.pedal_rpm_end = buffer_get_float16(buffer, index, 10); index += 2;
    appconfData.app_pas_conf.invert_pedal_direction = buffer[index++] > 0 ? true : false;
    appconfData.app_pas_conf.magnets = buffer_get_uint16(buffer, index); index += 2;
    appconfData.app_pas_conf.use_filter = buffer[index++] > 0 ? true : false;
    appconfData.app_pas_conf.ramp_time_pos = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_pas_conf.ramp_time_neg = buffer_get_float16(buffer, index, 100); index += 2;
    appconfData.app_pas_conf.update_rate_hz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.imu_conf.type = IMU_TYPE.values[buffer[index++]];
    appconfData.imu_conf.mode = AHRS_MODE.values[buffer[index++]];
    appconfData.imu_conf.filter = IMU_FILTER.values[buffer[index++]]; //fw6
    appconfData.imu_conf.accel_lowpass_filter_x = buffer_get_float16(buffer, index, 1); index += 2;  //fw6
    appconfData.imu_conf.accel_lowpass_filter_y = buffer_get_float16(buffer, index, 1); index += 2;  //fw6
    appconfData.imu_conf.accel_lowpass_filter_z = buffer_get_float16(buffer, index, 1); index += 2;  //fw6
    appconfData.imu_conf.gyro_lowpass_filter = buffer_get_float16(buffer, index, 1); index += 2;  //fw6
    appconfData.imu_conf.sample_rate_hz = buffer_get_uint16(buffer, index); index += 2;
    appconfData.imu_conf.use_magnetometer = buffer[index++] > 0 ? true : false; //fw6
    appconfData.imu_conf.accel_confidence_decay = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.mahony_kp = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.mahony_ki = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.madgwick_beta = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.rot_roll = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.rot_pitch = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.rot_yaw = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.accel_offsets[0] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.accel_offsets[1] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.accel_offsets[2] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offsets[0] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offsets[1] = buffer_get_float32_auto(buffer, index); index += 4;
    appconfData.imu_conf.gyro_offsets[2] = buffer_get_float32_auto(buffer, index); index += 4;

    //globalLogger.wtf("SerializeFirmware60::processAPPCONF: final index = $index");
    return appconfData;
  }

  ByteData serializeAPPCONF(APPCONF conf) {
    int index = 0;
    ByteData response = new ByteData(501); //TODO: ByteData is not dynamic, setting exact size
    response.setUint32(index, APPCONF_SIGNATURE_FW6_0); index += 4;

    response.setUint8(index++, conf.controller_id);
    response.setUint32(index, conf.timeout_msec); index += 4;
    response.setFloat32(index, conf.timeout_brake_current); index += 4;
    response.setUint16(index, conf.can_status_rate_1); index += 2;   //fw6
    response.setUint16(index, conf.can_status_rate_2); index += 2;   //fw6
    response.setUint8(index++, conf.can_status_msgs_r1);   //fw6
    response.setUint8(index++, conf.can_status_msgs_r2);   //fw6
    response.setUint8(index++, conf.can_baud_rate.index);
    response.setUint8(index++, conf.pairing_done ? 1 : 0);
    response.setUint8(index++, conf.permanent_uart_enabled ? 1 : 0);
    response.setUint8(index++, conf.shutdown_mode.index);
    response.setUint8(index++, conf.can_mode.index);
    response.setUint8(index++, conf.uavcan_esc_index);
    response.setUint8(index++, conf.uavcan_raw_mode.index);
    response.setFloat32(index, conf.uavcan_raw_rpm_max); index += 4;
    response.setUint8(index++, conf.uavcan_status_current_mode.index);
    response.setUint8(index++, conf.servo_out_enabled ? 1 : 0);
    response.setUint8(index++, conf.kill_sw_mode.index);
    response.setUint8(index++, conf.app_to_use.index);
    response.setUint8(index++, conf.app_ppm_conf.ctrl_type.index);
    response.setFloat32(index, conf.app_ppm_conf.pid_max_erpm); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.hyst); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.pulse_start); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.pulse_end); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.pulse_center); index += 4;
    response.setUint8(index++, conf.app_ppm_conf.median_filter ? 1 : 0);
    response.setUint8(index++, conf.app_ppm_conf.safe_start.index);
    response.setFloat32(index, conf.app_ppm_conf.throttle_exp); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.throttle_exp_brake); index += 4;
    response.setUint8(index++, conf.app_ppm_conf.throttle_exp_mode.index);
    response.setFloat32(index, conf.app_ppm_conf.ramp_time_pos); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.ramp_time_neg); index += 4;
    response.setUint8(index++, conf.app_ppm_conf.multi_esc ? 1 : 0);
    response.setUint8(index++, conf.app_ppm_conf.tc ? 1 : 0);
    response.setFloat32(index, conf.app_ppm_conf.tc_max_diff); index += 4;
    response.setInt16(index, conf.app_ppm_conf.max_erpm_for_dir.toInt()); index += 2;
    response.setFloat32(index, conf.app_ppm_conf.smart_rev_max_duty); index += 4;
    response.setFloat32(index, conf.app_ppm_conf.smart_rev_ramp_time); index += 4;
    response.setUint8(index++, conf.app_adc_conf.ctrl_type.index);
    response.setFloat32(index, conf.app_adc_conf.hyst); index += 4;
    response.setInt16(index, (conf.app_adc_conf.voltage_start * 1000).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.app_adc_conf.voltage_end * 1000).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.app_adc_conf.voltage_min * 1000).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.app_adc_conf.voltage_max * 1000).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.app_adc_conf.voltage_center * 1000).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.app_adc_conf.voltage2_start * 1000).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.app_adc_conf.voltage2_end * 1000).toInt()); index += 2;  //fw6
    response.setUint8(index++, conf.app_adc_conf.use_filter ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.safe_start.index);
    response.setUint8(index++, conf.app_adc_conf.buttons); //fw6
    response.setUint8(index++, conf.app_adc_conf.voltage_inverted ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.voltage2_inverted ? 1 : 0);
    response.setFloat32(index, conf.app_adc_conf.throttle_exp); index += 4;
    response.setFloat32(index, conf.app_adc_conf.throttle_exp_brake); index += 4;
    response.setUint8(index++, conf.app_adc_conf.throttle_exp_mode.index);
    response.setFloat32(index, conf.app_adc_conf.ramp_time_pos); index += 4;
    response.setFloat32(index, conf.app_adc_conf.ramp_time_neg); index += 4;
    response.setUint8(index++, conf.app_adc_conf.multi_esc ? 1 : 0);
    response.setUint8(index++, conf.app_adc_conf.tc ? 1 : 0);
    response.setFloat32(index, conf.app_adc_conf.tc_max_diff); index += 4;
    response.setUint16(index, conf.app_adc_conf.update_rate_hz); index += 2;
    response.setUint32(index, conf.app_uart_baudrate); index += 4;
    response.setUint8(index++, conf.app_chuk_conf.ctrl_type.index);
    response.setFloat32(index, conf.app_chuk_conf.hyst); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.ramp_time_pos); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.ramp_time_neg); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.stick_erpm_per_s_in_cc); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.throttle_exp); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.throttle_exp_brake); index += 4;
    response.setUint8(index++, conf.app_chuk_conf.throttle_exp_mode.index);
    response.setUint8(index++, conf.app_chuk_conf.multi_esc ? 1 : 0);
    response.setUint8(index++, conf.app_chuk_conf.tc ? 1 : 0);
    response.setFloat32(index, conf.app_chuk_conf.tc_max_diff); index += 4;
    response.setUint8(index++, conf.app_chuk_conf.use_smart_rev ? 1 : 0);
    response.setFloat32(index, conf.app_chuk_conf.smart_rev_max_duty); index += 4;
    response.setFloat32(index, conf.app_chuk_conf.smart_rev_ramp_time); index += 4;
    response.setUint8(index++, conf.app_nrf_conf.speed.index);
    response.setUint8(index++, conf.app_nrf_conf.power.index);
    response.setUint8(index++, conf.app_nrf_conf.crc_type.index);
    response.setUint8(index++, conf.app_nrf_conf.retry_delay.index);
    response.setUint8(index++, conf.app_nrf_conf.retries);
    response.setUint8(index++, conf.app_nrf_conf.channel);
    response.setUint8(index++, conf.app_nrf_conf.address[0]);
    response.setUint8(index++, conf.app_nrf_conf.address[1]);
    response.setUint8(index++, conf.app_nrf_conf.address[2]);
    response.setUint8(index++, conf.app_nrf_conf.send_crc_ack ? 1 : 0);
    response.setUint8(index++, conf.app_balance_conf.pid_mode.index);  //fw6
    response.setFloat32(index, conf.app_balance_conf.kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.ki); index += 4;
    response.setFloat32(index, conf.app_balance_conf.kd); index += 4;
    response.setFloat32(index, conf.app_balance_conf.kp2); index += 4;  //fw6
    response.setFloat32(index, conf.app_balance_conf.ki2); index += 4;  //fw6
    response.setFloat32(index, conf.app_balance_conf.kd2); index += 4;  //fw6
    response.setUint16(index, conf.app_balance_conf.hertz); index += 2;
    response.setUint16(index, conf.app_balance_conf.loop_time_filter); index += 2;
    response.setFloat32(index, conf.app_balance_conf.fault_pitch); index += 4;
    response.setFloat32(index, conf.app_balance_conf.fault_roll); index += 4;
    response.setFloat32(index, conf.app_balance_conf.fault_duty); index += 4;
    response.setFloat32(index, conf.app_balance_conf.fault_adc1); index += 4;
    response.setFloat32(index, conf.app_balance_conf.fault_adc2); index += 4;
    response.setUint16(index, conf.app_balance_conf.fault_delay_pitch); index += 2;
    response.setUint16(index, conf.app_balance_conf.fault_delay_roll); index += 2;
    response.setUint16(index, conf.app_balance_conf.fault_delay_duty); index += 2;
    response.setUint16(index, conf.app_balance_conf.fault_delay_switch_half); index += 2;
    response.setUint16(index, conf.app_balance_conf.fault_delay_switch_full); index += 2;
    response.setUint16(index, conf.app_balance_conf.fault_adc_half_erpm); index += 2;
    response.setUint8(index++, conf.app_balance_conf.fault_is_dual_switch ? 1 : 0); //fw6
    response.setInt16(index, (conf.app_balance_conf.tiltback_duty_angle * 100).toInt()); index += 2;
    response.setInt16(index, (conf.app_balance_conf.tiltback_duty_speed * 100).toInt()); index += 2;
    response.setInt16(index, (conf.app_balance_conf.tiltback_duty * 1000).toInt()); index += 2;
    response.setInt16(index, (conf.app_balance_conf.tiltback_hv_angle * 100).toInt()); index += 2;
    response.setInt16(index, (conf.app_balance_conf.tiltback_hv_speed * 100).toInt()); index += 2;
    response.setFloat32(index, conf.app_balance_conf.tiltback_hv); index += 4;
    response.setInt16(index, (conf.app_balance_conf.tiltback_lv_angle * 100).toInt()); index += 2;
    response.setInt16(index, (conf.app_balance_conf.tiltback_lv_speed * 100).toInt()); index += 2;
    response.setFloat32(index, conf.app_balance_conf.tiltback_lv); index += 4;
    response.setInt16(index, (conf.app_balance_conf.tiltback_return_speed * 100).toInt()); index += 2;
    response.setFloat32(index, conf.app_balance_conf.tiltback_constant); index += 4;
    response.setUint16(index, conf.app_balance_conf.tiltback_constant_erpm); index += 2;
    response.setFloat32(index, conf.app_balance_conf.tiltback_variable); index += 4;
    response.setFloat32(index, conf.app_balance_conf.tiltback_variable_max); index += 4;
    response.setInt16(index, (conf.app_balance_conf.noseangling_speed * 100).toInt()); index += 2;
    response.setFloat32(index, conf.app_balance_conf.startup_pitch_tolerance); index += 4;
    response.setFloat32(index, conf.app_balance_conf.startup_roll_tolerance); index += 4;
    response.setFloat32(index, conf.app_balance_conf.startup_speed); index += 4;
    response.setFloat32(index, conf.app_balance_conf.deadzone); index += 4;
    response.setUint8(index++, conf.app_balance_conf.multi_esc ? 1 : 0);
    response.setFloat32(index, conf.app_balance_conf.yaw_kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.yaw_ki); index += 4;
    response.setFloat32(index, conf.app_balance_conf.yaw_kd); index += 4;
    response.setFloat32(index, conf.app_balance_conf.roll_steer_kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.roll_steer_erpm_kp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.brake_current); index += 4;
    response.setUint16(index, conf.app_balance_conf.brake_timeout); index += 2;
    response.setFloat32(index, conf.app_balance_conf.yaw_current_clamp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.ki_limit); index += 4; //fw6
    response.setUint16(index, conf.app_balance_conf.kd_pt1_lowpass_frequency); index += 2;
    response.setUint16(index, conf.app_balance_conf.kd_pt1_highpass_frequency); index += 2;
    response.setFloat32(index, conf.app_balance_conf.kd_biquad_lowpass); index += 4;
    response.setFloat32(index, conf.app_balance_conf.kd_biquad_highpass); index += 4;
    response.setFloat32(index, conf.app_balance_conf.booster_angle); index += 4;
    response.setFloat32(index, conf.app_balance_conf.booster_ramp); index += 4;
    response.setFloat32(index, conf.app_balance_conf.booster_current); index += 4;
    response.setFloat32(index, conf.app_balance_conf.torquetilt_start_current); index += 4;
    response.setFloat32(index, conf.app_balance_conf.torquetilt_angle_limit); index += 4;
    response.setFloat32(index, conf.app_balance_conf.torquetilt_on_speed); index += 4;
    response.setFloat32(index, conf.app_balance_conf.torquetilt_off_speed); index += 4;
    response.setFloat32(index, conf.app_balance_conf.torquetilt_strength); index += 4;
    response.setFloat32(index, conf.app_balance_conf.torquetilt_filter); index += 4;
    response.setFloat32(index, conf.app_balance_conf.turntilt_strength); index += 4;
    response.setFloat32(index, conf.app_balance_conf.turntilt_angle_limit); index += 4;
    response.setFloat32(index, conf.app_balance_conf.turntilt_start_angle); index += 4;
    response.setUint16(index, conf.app_balance_conf.turntilt_start_erpm); index += 2;
    response.setFloat32(index, conf.app_balance_conf.turntilt_speed); index += 4;
    response.setUint16(index, conf.app_balance_conf.turntilt_erpm_boost); index += 2;
    response.setUint16(index, conf.app_balance_conf.turntilt_erpm_boost_end); index += 2;
    response.setUint8(index++, conf.app_pas_conf.ctrl_type.index);
    response.setUint8(index++, conf.app_pas_conf.sensor_type.index);
    response.setInt16(index, (conf.app_pas_conf.current_scaling * 1000).toInt()); index += 2;
    response.setInt16(index, (conf.app_pas_conf.pedal_rpm_start * 10).toInt()); index += 2;
    response.setInt16(index, (conf.app_pas_conf.pedal_rpm_end * 10).toInt()); index += 2;
    response.setUint8(index++, conf.app_pas_conf.invert_pedal_direction ? 1 : 0);
    response.setUint16(index, conf.app_pas_conf.magnets); index += 2;
    response.setUint8(index++, conf.app_pas_conf.use_filter ? 1 : 0);
    response.setInt16(index, (conf.app_pas_conf.ramp_time_pos * 100).toInt()); index += 2;
    response.setInt16(index, (conf.app_pas_conf.ramp_time_neg * 100).toInt()); index += 2;
    response.setUint16(index, conf.app_pas_conf.update_rate_hz); index += 2;
    response.setUint8(index++, conf.imu_conf.type.index);
    response.setUint8(index++, conf.imu_conf.mode.index);
    response.setUint8(index++, conf.imu_conf.filter.index); //fw6
    response.setInt16(index, (conf.imu_conf.accel_lowpass_filter_x * 1).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.imu_conf.accel_lowpass_filter_y * 1).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.imu_conf.accel_lowpass_filter_z * 1).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.imu_conf.gyro_lowpass_filter * 1).toInt()); index += 2; //fw6
    response.setUint16(index, conf.imu_conf.sample_rate_hz); index += 2;
    response.setUint8(index++, conf.imu_conf.use_magnetometer ? 1 : 0); //fw6
    response.setFloat32(index, conf.imu_conf.accel_confidence_decay); index += 4;
    response.setFloat32(index, conf.imu_conf.mahony_kp); index += 4;
    response.setFloat32(index, conf.imu_conf.mahony_ki); index += 4;
    response.setFloat32(index, conf.imu_conf.madgwick_beta); index += 4;
    response.setFloat32(index, conf.imu_conf.rot_roll); index += 4;
    response.setFloat32(index, conf.imu_conf.rot_pitch); index += 4;
    response.setFloat32(index, conf.imu_conf.rot_yaw); index += 4;
    response.setFloat32(index, conf.imu_conf.accel_offsets[0]); index += 4;
    response.setFloat32(index, conf.imu_conf.accel_offsets[1]); index += 4;
    response.setFloat32(index, conf.imu_conf.accel_offsets[2]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offsets[0]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offsets[1]); index += 4;
    response.setFloat32(index, conf.imu_conf.gyro_offsets[2]); index += 4;

    //globalLogger.wtf("SerializeFirmware60::serializeAPPCONF: final index is $index");
    return response;
  }

  MCCONF processMCCONF(Uint8List buffer) {
    int index = 1;
    MCCONF mcconfData = new MCCONF();
    int signature  = buffer_get_uint32(buffer, index); index += 4;
    if (signature != MCCONF_SIGNATURE_FW6_0) {
      globalLogger.e("Invalid MCCONF Signature. Received $signature but expected $MCCONF_SIGNATURE_FW6_0");
      //Return empty mcconf
      return mcconfData;
    }

    mcconfData.pwm_mode = mc_pwm_mode.values[buffer[index++]];
    mcconfData.comm_mode = mc_comm_mode.values[buffer[index++]];
    mcconfData.motor_type = mc_motor_type.values[buffer[index++]];
    mcconfData.sensor_mode = mc_sensor_mode.values[buffer[index++]];
    mcconfData.l_current_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_current_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_in_current_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_in_current_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_abs_current_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_min_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_erpm_start = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.l_max_erpm_fbrake = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_erpm_fbrake_cc = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_min_vin = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_max_vin = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_battery_cut_start = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_battery_cut_end = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_slow_abs_current = buffer[index++] > 0 ? true : false;
    mcconfData.l_temp_fet_start = buffer_get_float16(buffer, index, 10); index += 2;
    mcconfData.l_temp_fet_end = buffer_get_float16(buffer, index, 10); index += 2;
    mcconfData.l_temp_motor_start = buffer_get_float16(buffer, index, 10); index += 2;
    mcconfData.l_temp_motor_end = buffer_get_float16(buffer, index, 10); index += 2;
    mcconfData.l_temp_accel_dec = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.l_min_duty = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.l_max_duty = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.l_watt_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_watt_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.l_current_max_scale = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.l_current_min_scale = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.l_duty_start = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.sl_min_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_min_erpm_cycle_int_limit = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_max_fullbreak_current_dir_change = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_cycle_int_limit = buffer_get_float16(buffer, index, 10); index += 2;
    mcconfData.sl_phase_advance_at_br = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.sl_cycle_int_rpm_br = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sl_bemf_coupling_k = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.hall_table[0] = buffer[index++];
    mcconfData.hall_table[1] = buffer[index++];
    mcconfData.hall_table[2] = buffer[index++];
    mcconfData.hall_table[3] = buffer[index++];
    mcconfData.hall_table[4] = buffer[index++];
    mcconfData.hall_table[5] = buffer[index++];
    mcconfData.hall_table[6] = buffer[index++];
    mcconfData.hall_table[7] = buffer[index++];
    mcconfData.hall_sl_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_current_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_current_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_f_zv = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_dt_us = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_inverted = buffer[index++] > 0 ? true : false;
    mcconfData.foc_encoder_offset = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_encoder_ratio = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sensor_mode = mc_foc_sensor_mode.values[buffer[index++]];
    mcconfData.foc_pll_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_pll_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_motor_l = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_motor_ld_lq_diff = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_motor_r = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_motor_flux_linkage = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_observer_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_observer_gain_slow = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_observer_offset = buffer_get_float16(buffer, index, 1000); index += 2;
    mcconfData.foc_duty_dowmramp_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_duty_dowmramp_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_start_curr_dec = buffer_get_float16(buffer, index, 10000); index += 2; //fw6
    mcconfData.foc_start_curr_dec_rpm = buffer_get_float32_auto(buffer, index); index += 4; //fw6
    mcconfData.foc_openloop_rpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_openloop_rpm_low = buffer_get_float16(buffer, index, 1000); index += 2;
    mcconfData.foc_d_gain_scale_start = buffer_get_float16(buffer, index, 1000); index += 2;
    mcconfData.foc_d_gain_scale_max_mod = buffer_get_float16(buffer, index, 1000); index += 2;
    mcconfData.foc_sl_openloop_hyst = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.foc_sl_openloop_time_lock = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.foc_sl_openloop_time_ramp = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.foc_sl_openloop_time = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.foc_sl_openloop_boost_q = buffer_get_float16(buffer, index, 100); index += 2;  //fw6
    mcconfData.foc_sl_openloop_max_q = buffer_get_float16(buffer, index, 100); index += 2;  //fw6
    mcconfData.foc_hall_table[0] = buffer[index++];
    mcconfData.foc_hall_table[1] = buffer[index++];
    mcconfData.foc_hall_table[2] = buffer[index++];
    mcconfData.foc_hall_table[3] = buffer[index++];
    mcconfData.foc_hall_table[4] = buffer[index++];
    mcconfData.foc_hall_table[5] = buffer[index++];
    mcconfData.foc_hall_table[6] = buffer[index++];
    mcconfData.foc_hall_table[7] = buffer[index++];
    mcconfData.foc_hall_interp_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sl_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_sample_v0_v7 = buffer[index++] > 0 ? true: false;
    mcconfData.foc_sample_high_current = buffer[index++] > 0 ? true : false;
    mcconfData.foc_sat_comp_mode = SAT_COMP_MODE.values[buffer[index++]]; //fw6
    mcconfData.foc_sat_comp = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.foc_temp_comp = buffer[index++] > 0 ? true : false;
    mcconfData.foc_temp_comp_base_temp = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.foc_current_filter_const = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_cc_decoupling = mc_foc_cc_decoupling_mode.values[buffer[index++]];
    mcconfData.foc_observer_type = mc_foc_observer_type.values[buffer[index++]];
    mcconfData.foc_hfi_voltage_start = buffer_get_float16(buffer, index, 10); index += 2; //fw6
    mcconfData.foc_hfi_voltage_run = buffer_get_float16(buffer, index, 10); index += 2; //fw6
    mcconfData.foc_hfi_voltage_max = buffer_get_float16(buffer, index, 10); index += 2; //fw6
    mcconfData.foc_hfi_gain = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    mcconfData.foc_hfi_hyst = buffer_get_float16(buffer, index, 100); index += 2; //fw6
    mcconfData.foc_sl_erpm_hfi = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_hfi_start_samples = buffer_get_uint16(buffer, index); index += 2;
    mcconfData.foc_hfi_obs_ovr_sec = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_hfi_samples = mc_foc_hfi_samples.values[buffer[index++]];
    mcconfData.foc_offsets_cal_on_boot = buffer[index++] > 0 ? true : false;
    mcconfData.foc_offsets_current[0] = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_offsets_current[1] = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_offsets_current[2] = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_offsets_voltage[0] = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_offsets_voltage[1] = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_offsets_voltage[2] = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_offsets_voltage_undriven[0] = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_offsets_voltage_undriven[1] = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_offsets_voltage_undriven[2] = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_phase_filter_enable = buffer[index++] > 0 ? true : false;
    mcconfData.foc_phase_filter_disable_fault = buffer[index++] > 0 ? true : false; //fw6
    mcconfData.foc_phase_filter_max_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_mtpa_mode = MTPA_MODE.values[buffer[index++]];
    mcconfData.foc_fw_current_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.foc_fw_duty_start = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_fw_ramp_time = buffer_get_float16(buffer, index, 1000); index += 2;
    mcconfData.foc_fw_q_current_factor = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.foc_speed_source = FOC_SPEED_SRC.values[buffer[index++]]; //fw6
    mcconfData.gpd_buffer_notify_left = buffer_get_int16(buffer, index); index += 2;
    mcconfData.gpd_buffer_interpol = buffer_get_int16(buffer, index); index += 2;
    mcconfData.gpd_current_filter_const = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.gpd_current_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.gpd_current_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.sp_pid_loop_rate = PID_RATE.values[buffer[index++]];
    mcconfData.s_pid_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_kd = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_kd_filter = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.s_pid_min_erpm = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.s_pid_allow_braking = buffer[index++] > 0 ? true: false;
    mcconfData.s_pid_ramp_erpms_s = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_kp = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_ki = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_kd = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_kd_proc = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_kd_filter = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.p_pid_ang_div = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.p_pid_gain_dec_angle = buffer_get_float16(buffer, index, 10); index += 2;
    mcconfData.p_pid_offset = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.cc_startup_boost_duty = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.cc_min_current = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.cc_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.cc_ramp_step_max = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.m_fault_stop_time_ms = buffer_get_int32(buffer, index); index += 4;
    mcconfData.m_duty_ramp_step = buffer_get_float16(buffer, index, 10000); index += 2;
    mcconfData.m_current_backoff_gain = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_encoder_counts = buffer_get_uint32(buffer, index); index += 4;
    mcconfData.m_encoder_sin_amp = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    mcconfData.m_encoder_cos_amp = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    mcconfData.m_encoder_sin_offset = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    mcconfData.m_encoder_cos_offset = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    mcconfData.m_encoder_sincos_filter_constant = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    mcconfData.m_encoder_sincos_phase_correction = buffer_get_float16(buffer, index, 1000); index += 2; //fw6
    mcconfData.m_sensor_port_mode = sensor_port_mode.values[buffer[index++]];
    mcconfData.m_invert_direction = buffer[index++] > 0 ? true: false;
    mcconfData.m_drv8301_oc_mode = drv8301_oc_mode.values[buffer[index++]];
    mcconfData.m_drv8301_oc_adj = buffer[index++];
    mcconfData.m_bldc_f_sw_min = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_bldc_f_sw_max = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_dc_f_sw = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_ntc_motor_beta = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_out_aux_mode = out_aux_mode.values[buffer[index++]];
    mcconfData.m_motor_temp_sens_type = temp_sensor_type.values[buffer[index++]];
    mcconfData.m_ptc_motor_coeff = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.m_ntcx_ptcx_res = buffer_get_float16(buffer, index, 0.1); index += 2; //fw6
    mcconfData.m_ntcx_ptcx_temp_base = buffer_get_float16(buffer, index, 10); index += 2; //fw6
    mcconfData.m_hall_extra_samples = buffer[index++];
    mcconfData.m_batt_filter_const = buffer[index++];
    mcconfData.si_motor_poles = buffer[index++];
    mcconfData.si_gear_ratio = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.si_wheel_diameter = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.si_battery_type = BATTERY_TYPE.values[buffer[index++]];
    mcconfData.si_battery_cells = buffer[index++];
    mcconfData.si_battery_ah = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.si_motor_nl_current = buffer_get_float32_auto(buffer, index); index += 4;
    mcconfData.bms.type = BMS_TYPE.values[buffer[index++]];
    mcconfData.bms.t_limit_start = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.bms.t_limit_end = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.bms.soc_limit_start = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.bms.soc_limit_end = buffer_get_float16(buffer, index, 100); index += 2;
    mcconfData.bms.fwd_can_mode = BMS_FWD_CAN_MODE.values[buffer[index++]];

    //globalLogger.wtf("SerializeFirmware60::processMCCONF: final index = $index");
    return mcconfData;
  }

  ByteData serializeMCCONF(MCCONF conf) {
    int index = 0;
    ByteData response = new ByteData(477); //TODO: ByteData is not dynamic, setting exact size
    response.setUint32(index, MCCONF_SIGNATURE_FW6_0); index += 4;

    response.setUint8(index++, conf.pwm_mode.index);
    response.setUint8(index++, conf.comm_mode.index);
    response.setUint8(index++, conf.motor_type.index);
    response.setUint8(index++, conf.sensor_mode.index);
    response.setFloat32(index, conf.l_current_max); index += 4;
    response.setFloat32(index, conf.l_current_min); index += 4;
    response.setFloat32(index, conf.l_in_current_max); index += 4;
    response.setFloat32(index, conf.l_in_current_min); index += 4;
    response.setFloat32(index, conf.l_abs_current_max); index += 4;
    response.setFloat32(index, conf.l_min_erpm); index += 4;
    response.setFloat32(index, conf.l_max_erpm); index += 4;
    response.setInt16(index, (conf.l_erpm_start * 10000).toInt()); index += 2;
    response.setFloat32(index, conf.l_max_erpm_fbrake); index += 4;
    response.setFloat32(index, conf.l_max_erpm_fbrake_cc); index += 4;
    response.setFloat32(index, conf.l_min_vin); index += 4;
    response.setFloat32(index, conf.l_max_vin); index += 4;
    response.setFloat32(index, conf.l_battery_cut_start); index += 4;
    response.setFloat32(index, conf.l_battery_cut_end); index += 4;
    response.setUint8(index++, conf.l_slow_abs_current ? 1 : 0);
    response.setInt16(index, (conf.l_temp_fet_start * 10).toInt()); index += 2;
    response.setInt16(index, (conf.l_temp_fet_end * 10).toInt()); index += 2;
    response.setInt16(index, (conf.l_temp_motor_start * 10).toInt()); index += 2;
    response.setInt16(index, (conf.l_temp_motor_end * 10).toInt()); index += 2;
    response.setInt16(index, (conf.l_temp_accel_dec * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.l_min_duty * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.l_max_duty * 10000).toInt()); index += 2;
    response.setFloat32(index, conf.l_watt_max); index += 4;
    response.setFloat32(index, conf.l_watt_min); index += 4;
    response.setInt16(index, (conf.l_current_max_scale * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.l_current_min_scale * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.l_duty_start * 10000).toInt()); index += 2;
    response.setFloat32(index, conf.sl_min_erpm); index += 4;
    response.setFloat32(index, conf.sl_min_erpm_cycle_int_limit); index += 4;
    response.setFloat32(index, conf.sl_max_fullbreak_current_dir_change); index += 4;
    response.setInt16(index, (conf.sl_cycle_int_limit * 10).toInt()); index += 2;
    response.setInt16(index, (conf.sl_phase_advance_at_br * 10000).toInt()); index += 2;
    response.setFloat32(index, conf.sl_cycle_int_rpm_br); index += 4;
    response.setFloat32(index, conf.sl_bemf_coupling_k); index += 4;
    response.setUint8(index++, conf.hall_table[0]);
    response.setUint8(index++, conf.hall_table[1]);
    response.setUint8(index++, conf.hall_table[2]);
    response.setUint8(index++, conf.hall_table[3]);
    response.setUint8(index++, conf.hall_table[4]);
    response.setUint8(index++, conf.hall_table[5]);
    response.setUint8(index++, conf.hall_table[6]);
    response.setUint8(index++, conf.hall_table[7]);
    response.setFloat32(index, conf.hall_sl_erpm); index += 4;
    response.setFloat32(index, conf.foc_current_kp); index += 4;
    response.setFloat32(index, conf.foc_current_ki); index += 4;
    response.setFloat32(index, conf.foc_f_zv); index += 4;
    response.setFloat32(index, conf.foc_dt_us); index += 4;
    response.setUint8(index++, conf.foc_encoder_inverted ? 1 : 0);
    response.setFloat32(index, conf.foc_encoder_offset); index += 4;
    response.setUint8(index++, conf.foc_sensor_mode.index);
    response.setFloat32(index, conf.foc_pll_kp); index += 4;
    response.setFloat32(index, conf.foc_pll_ki); index += 4;
    response.setFloat32(index, conf.foc_motor_l); index += 4;
    response.setFloat32(index, conf.foc_motor_ld_lq_diff); index += 4;
    response.setFloat32(index, conf.foc_motor_r); index += 4;
    response.setFloat32(index, conf.foc_motor_flux_linkage); index += 4;
    response.setFloat32(index, conf.foc_observer_gain); index += 4;
    response.setFloat32(index, conf.foc_observer_gain_slow); index += 4;
    response.setInt16(index, (conf.foc_observer_offset * 1000).toInt()); index += 2;
    response.setFloat32(index, conf.foc_duty_dowmramp_kp); index += 4;
    response.setFloat32(index, conf.foc_duty_dowmramp_ki); index += 4;
    response.setInt16(index, (conf.foc_start_curr_dec * 10000).toInt()); index += 2; //fw6
    response.setFloat32(index, conf.foc_start_curr_dec_rpm); index += 4;  //fw6
    response.setFloat32(index, conf.foc_openloop_rpm); index += 4;
    response.setInt16(index, (conf.foc_openloop_rpm_low * 1000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_d_gain_scale_start * 1000).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.foc_d_gain_scale_max_mod * 1000).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.foc_sl_openloop_hyst * 100).toInt()); index += 2;
    response.setInt16(index, (conf.foc_sl_openloop_time_lock * 100).toInt()); index += 2;
    response.setInt16(index, (conf.foc_sl_openloop_time_ramp * 100).toInt()); index += 2;
    response.setInt16(index, (conf.foc_sl_openloop_time * 100).toInt()); index += 2;
    response.setInt16(index, (conf.foc_sl_openloop_boost_q * 100).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.foc_d_gain_scale_max_mod * 100).toInt()); index += 2;  //fw6
    response.setUint8(index++, conf.foc_hall_table[0]);
    response.setUint8(index++, conf.foc_hall_table[1]);
    response.setUint8(index++, conf.foc_hall_table[2]);
    response.setUint8(index++, conf.foc_hall_table[3]);
    response.setUint8(index++, conf.foc_hall_table[4]);
    response.setUint8(index++, conf.foc_hall_table[5]);
    response.setUint8(index++, conf.foc_hall_table[6]);
    response.setUint8(index++, conf.foc_hall_table[7]);
    response.setFloat32(index, conf.foc_hall_interp_erpm); index += 4;
    response.setFloat32(index, conf.foc_sl_erpm); index += 4;
    response.setUint8(index++, conf.foc_sample_v0_v7 ? 1 : 0);
    response.setUint8(index++, conf.foc_sample_high_current ? 1 : 0);
    response.setUint8(index++, conf.foc_sat_comp_mode.index);  //fw6
    response.setInt16(index, (conf.foc_sat_comp * 100).toInt()); index += 2;
    response.setUint8(index++, conf.foc_temp_comp ? 1 : 0);
    response.setInt16(index, (conf.foc_temp_comp_base_temp * 100).toInt()); index += 2;
    response.setInt16(index, (conf.foc_current_filter_const * 10000).toInt()); index += 2;
    response.setUint8(index++, conf.foc_cc_decoupling.index);
    response.setUint8(index++, conf.foc_observer_type.index);
    response.setInt16(index, (conf.foc_hfi_voltage_start * 10).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.foc_hfi_voltage_run * 10).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.foc_hfi_voltage_max * 10).toInt()); index += 2;  //fw6
    response.setInt16(index, (conf.foc_hfi_gain * 1000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_hfi_hyst * 100).toInt()); index += 2;
    response.setFloat32(index, conf.foc_sl_erpm_hfi); index += 4;
    response.setUint16(index, conf.foc_hfi_start_samples); index += 2;
    response.setFloat32(index, conf.foc_hfi_obs_ovr_sec); index += 4;
    response.setUint8(index++, conf.foc_hfi_samples.index);
    response.setUint8(index++, conf.foc_offsets_cal_on_boot ? 1 : 0);
    response.setFloat32(index, conf.foc_offsets_current[0]); index += 4;
    response.setFloat32(index, conf.foc_offsets_current[1]); index += 4;
    response.setFloat32(index, conf.foc_offsets_current[2]); index += 4;
    response.setInt16(index, (conf.foc_offsets_voltage[0] * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_offsets_voltage[1] * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_offsets_voltage[2] * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_offsets_voltage_undriven[0] * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_offsets_voltage_undriven[1] * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_offsets_voltage_undriven[2] * 10000).toInt()); index += 2;
    response.setUint8(index++, conf.foc_phase_filter_enable ? 1 : 0);
    response.setUint8(index++, conf.foc_phase_filter_disable_fault ? 1 : 0);  //fw6
    response.setFloat32(index, conf.foc_phase_filter_max_erpm); index += 4;
    response.setUint8(index++, conf.foc_mtpa_mode.index);
    response.setFloat32(index, conf.foc_fw_current_max); index += 4;
    response.setInt16(index, (conf.foc_fw_duty_start * 10000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_fw_ramp_time * 1000).toInt()); index += 2;
    response.setInt16(index, (conf.foc_fw_q_current_factor * 10000).toInt()); index += 2;
    response.setUint8(index++, conf.foc_speed_source.index); //fw6
    response.setInt16(index, conf.gpd_buffer_notify_left); index += 2;
    response.setInt16(index, conf.gpd_buffer_interpol); index += 2;
    response.setInt16(index, (conf.gpd_current_filter_const * 10000).toInt()); index += 2;
    response.setFloat32(index, conf.gpd_current_kp); index += 4;
    response.setFloat32(index, conf.gpd_current_ki); index += 4;
    response.setUint8(index++, conf.sp_pid_loop_rate.index);
    response.setFloat32(index, conf.s_pid_kp); index += 4;
    response.setFloat32(index, conf.s_pid_ki); index += 4;
    response.setFloat32(index, conf.s_pid_kd); index += 4;
    response.setInt16(index, (conf.s_pid_kd_filter * 10000).toInt()); index += 2;
    response.setFloat32(index, conf.s_pid_min_erpm); index += 4;
    response.setUint8(index++, conf.s_pid_allow_braking ? 1 : 0);
    response.setFloat32(index, conf.s_pid_ramp_erpms_s); index += 4;
    response.setFloat32(index, conf.p_pid_kp); index += 4;
    response.setFloat32(index, conf.p_pid_ki); index += 4;
    response.setFloat32(index, conf.p_pid_kd); index += 4;
    response.setFloat32(index, conf.p_pid_kd_proc); index += 4;
    response.setInt16(index, (conf.p_pid_kd_filter * 10000).toInt()); index += 2; //fw6
    response.setFloat32(index, conf.p_pid_ang_div); index += 4;
    response.setInt16(index, (conf.p_pid_gain_dec_angle * 10).toInt()); index += 2;
    response.setFloat32(index, conf.p_pid_offset); index += 4;
    response.setInt16(index, (conf.cc_startup_boost_duty * 10000).toInt()); index += 2; //fw6
    response.setFloat32(index, conf.cc_min_current); index += 4;
    response.setFloat32(index, conf.cc_gain); index += 4;
    response.setInt16(index, (conf.cc_ramp_step_max * 10000).toInt()); index += 2; //fw6
    response.setInt32(index, conf.m_fault_stop_time_ms); index += 4;
    response.setInt16(index, (conf.m_duty_ramp_step * 10000).toInt()); index += 2; //fw6
    response.setFloat32(index, conf.m_current_backoff_gain); index += 4;
    response.setUint32(index, conf.m_encoder_counts); index += 4;
    response.setInt16(index, (conf.m_encoder_sin_amp * 1000).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.m_encoder_cos_amp * 1000).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.m_encoder_sin_offset * 1000).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.m_encoder_cos_offset * 1000).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.m_encoder_sincos_filter_constant * 1000).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.m_encoder_sincos_phase_correction * 1000).toInt()); index += 2; //fw6
    response.setUint8(index++, conf.m_sensor_port_mode.index);
    response.setUint8(index++, conf.m_invert_direction ? 1 : 0);
    response.setUint8(index++, conf.m_drv8301_oc_mode.index);
    response.setUint8(index++, conf.m_drv8301_oc_adj);
    response.setFloat32(index, conf.m_bldc_f_sw_min); index += 4;
    response.setFloat32(index, conf.m_bldc_f_sw_max); index += 4;
    response.setFloat32(index, conf.m_dc_f_sw); index += 4;
    response.setFloat32(index, conf.m_ntc_motor_beta); index += 4;
    response.setUint8(index++, conf.m_out_aux_mode.index);
    response.setUint8(index++, conf.m_motor_temp_sens_type.index);
    response.setFloat32(index, conf.m_ptc_motor_coeff); index += 4;
    response.setInt16(index, (conf.m_ntcx_ptcx_res * 0.1).toInt()); index += 2; //fw6
    response.setInt16(index, (conf.m_ntcx_ptcx_temp_base * 10).toInt()); index += 2; //fw6
    response.setUint8(index++, conf.m_hall_extra_samples);
    response.setUint8(index++, conf.m_batt_filter_const);
    response.setUint8(index++, conf.si_motor_poles);
    response.setFloat32(index, conf.si_gear_ratio); index += 4;
    response.setFloat32(index, conf.si_wheel_diameter); index += 4;
    response.setUint8(index++, conf.si_battery_type.index);
    response.setUint8(index++, conf.si_battery_cells);
    response.setFloat32(index, conf.si_battery_ah); index += 4;
    response.setFloat32(index, conf.si_motor_nl_current); index += 4;
    response.setUint8(index++, conf.bms.type.index);
    response.setUint8(index++, conf.bms.limit_mode); //fw6
    response.setInt16(index, (conf.bms.t_limit_start * 100).toInt()); index += 2;
    response.setInt16(index, (conf.bms.t_limit_end * 100).toInt()); index += 2;
    response.setInt16(index, (conf.bms.soc_limit_start * 100).toInt()); index += 2;
    response.setInt16(index, (conf.bms.soc_limit_end * 100).toInt()); index += 2;
    response.setUint8(index++, conf.bms.fwd_can_mode.index);

    //globalLogger.wtf("SerializeFirmware60::serializeMCCONF: final index is $index");
    return response;
  }
}
