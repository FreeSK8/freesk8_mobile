// Applications to use
enum app_use {
  APP_NONE,
  APP_PPM,
  APP_ADC,
  APP_UART,
  APP_PPM_UART,
  APP_ADC_UART,
  APP_NUNCHUK,
  APP_NRF,
  APP_CUSTOM,
  APP_BALANCE,
  APP_PAS, // Firmware 5.2 added
  APP_ADC_PAS, // Firmware 5.2 added
}

// Throttle curve mode
enum thr_exp_mode {
  THR_EXP_EXPO,
  THR_EXP_NATURAL,
  THR_EXP_POLY
}

// PPM control types
enum ppm_control_type {
  PPM_CTRL_TYPE_NONE,
  PPM_CTRL_TYPE_CURRENT,
  PPM_CTRL_TYPE_CURRENT_NOREV,
  PPM_CTRL_TYPE_CURRENT_NOREV_BRAKE,
  PPM_CTRL_TYPE_DUTY,
  PPM_CTRL_TYPE_DUTY_NOREV,
  PPM_CTRL_TYPE_PID,
  PPM_CTRL_TYPE_PID_NOREV,
  PPM_CTRL_TYPE_CURRENT_BRAKE_REV_HYST,
  PPM_CTRL_TYPE_CURRENT_SMART_REV
}

class ppm_config {
  ppm_control_type ctrl_type;
  double pid_max_erpm;
  double hyst;
  double pulse_start;
  double pulse_end;
  double pulse_center;
  bool median_filter;
  bool safe_start;
  double throttle_exp;
  double throttle_exp_brake;
  thr_exp_mode throttle_exp_mode;
  double ramp_time_pos;
  double ramp_time_neg;
  bool multi_esc;
  bool tc;
  double tc_max_diff;
  double max_erpm_for_dir;
  double smart_rev_max_duty;
  double smart_rev_ramp_time;
}

// ADC control types
enum adc_control_type {
  ADC_CTRL_TYPE_NONE,
  ADC_CTRL_TYPE_CURRENT,
  ADC_CTRL_TYPE_CURRENT_REV_CENTER,
  ADC_CTRL_TYPE_CURRENT_REV_BUTTON,
  ADC_CTRL_TYPE_CURRENT_REV_BUTTON_BRAKE_ADC,
  ADC_CTRL_TYPE_CURRENT_REV_BUTTON_BRAKE_CENTER,
  ADC_CTRL_TYPE_CURRENT_NOREV_BRAKE_CENTER,
  ADC_CTRL_TYPE_CURRENT_NOREV_BRAKE_BUTTON,
  ADC_CTRL_TYPE_CURRENT_NOREV_BRAKE_ADC,
  ADC_CTRL_TYPE_DUTY,
  ADC_CTRL_TYPE_DUTY_REV_CENTER,
  ADC_CTRL_TYPE_DUTY_REV_BUTTON,
  ADC_CTRL_TYPE_PID,
  ADC_CTRL_TYPE_PID_REV_CENTER,
  ADC_CTRL_TYPE_PID_REV_BUTTON
}

// PAS control types
enum pas_control_type { // Firmware 5.2 added
  PAS_CTRL_TYPE_NONE,
  PAS_CTRL_TYPE_CADENCE,
}

// PAS sensor types
enum pas_sensor_type { // Firmware 5.2 added
  PAS_SENSOR_TYPE_QUADRATURE,
}

class adc_config {
  adc_control_type ctrl_type;
  double hyst;
  double voltage_start;
  double voltage_end;
  double voltage_center;
  double voltage2_start;
  double voltage2_end;
  bool use_filter;
  bool safe_start;
  bool cc_button_inverted;
  bool rev_button_inverted;
  bool voltage_inverted;
  bool voltage2_inverted;
  double throttle_exp;
  double throttle_exp_brake;
  thr_exp_mode throttle_exp_mode;
  double ramp_time_pos;
  double ramp_time_neg;
  bool multi_esc;
  bool tc;
  double tc_max_diff;
  int update_rate_hz;
}

// Nunchuk control types
enum chuk_control_type {
  CHUK_CTRL_TYPE_NONE,
  CHUK_CTRL_TYPE_CURRENT,
  CHUK_CTRL_TYPE_CURRENT_NOREV,
  CHUK_CTRL_TYPE_CURRENT_BIDIRECTIONAL, // Firmware 5.2 added
}

class chuk_config {
  chuk_control_type ctrl_type;
  double hyst;
  double ramp_time_pos;
  double ramp_time_neg;
  double stick_erpm_per_s_in_cc;
  double throttle_exp;
  double throttle_exp_brake;
  thr_exp_mode throttle_exp_mode;
  bool multi_esc;
  bool tc;
  double tc_max_diff;
  bool use_smart_rev;
  double smart_rev_max_duty;
  double smart_rev_ramp_time;
}

class pas_config { // Firmware 5.2 added
  pas_control_type ctrl_type;
  pas_sensor_type sensor_type;
  double current_scaling;
  double pedal_rpm_start;
  double pedal_rpm_end;
  bool invert_pedal_direction;
  int magnets;
  bool use_filter;
  double ramp_time_pos;
  double ramp_time_neg;
  int update_rate_hz;
}

// NRF Datatypes
enum NRF_SPEED {
  NRF_SPEED_250K,
  NRF_SPEED_1M,
  NRF_SPEED_2M
}

enum NRF_POWER {
  NRF_POWER_M18DBM,
  NRF_POWER_M12DBM,
  NRF_POWER_M6DBM,
  NRF_POWER_0DBM,
  NRF_POWER_OFF
}

enum NRF_AW {
  NRF_AW_3,
  NRF_AW_4,
  NRF_AW_5
}

enum NRF_CRC {
  NRF_CRC_DISABLED,
  NRF_CRC_1B,
  NRF_CRC_2B
}

enum NRF_RETR_DELAY {
  NRF_RETR_DELAY_250US,
  NRF_RETR_DELAY_500US,
  NRF_RETR_DELAY_750US,
  NRF_RETR_DELAY_1000US,
  NRF_RETR_DELAY_1250US,
  NRF_RETR_DELAY_1500US,
  NRF_RETR_DELAY_1750US,
  NRF_RETR_DELAY_2000US,
  NRF_RETR_DELAY_2250US,
  NRF_RETR_DELAY_2500US,
  NRF_RETR_DELAY_2750US,
  NRF_RETR_DELAY_3000US,
  NRF_RETR_DELAY_3250US,
  NRF_RETR_DELAY_3500US,
  NRF_RETR_DELAY_3750US,
  NRF_RETR_DELAY_4000US
}

class nrf_config {
  nrf_config() {
    address = List.filled(3, 0);
  }
  NRF_SPEED speed;
  NRF_POWER power;
  NRF_CRC crc_type;
  NRF_RETR_DELAY retry_delay;
  int retries;
  int channel;
  List<int> address;
  bool send_crc_ack;
}

class balance_config {
  double kp;
  double ki;
  double kd;
  int hertz;
  double fault_pitch;
  double fault_roll;
  double fault_duty; // Firmware 5.2 added
  double fault_adc1;
  double fault_adc2;
  int fault_delay_pitch; // Firmware 5.2 added
  int fault_delay_roll; // Firmware 5.2 added
  int fault_delay_duty; // Firmware 5.2 added
  int fault_delay_switch_half; // Firmware 5.2 added
  int fault_delay_switch_full; // Firmware 5.2 added
  int fault_adc_half_erpm;
  double overspeed_duty; // Firmware 5.1 only
  double tiltback_duty;
  double tiltback_angle;
  double tiltback_speed;
  double tiltback_high_voltage;
  double tiltback_low_voltage;
  double tiltback_constant;
  int tiltback_constant_erpm; // Firmware 5.2 added
  double startup_pitch_tolerance;
  double startup_roll_tolerance;
  double startup_speed;
  double deadzone;
  double current_boost;
  bool multi_esc;
  double yaw_kp;
  double yaw_ki;
  double yaw_kd;
  double roll_steer_kp;
  double roll_steer_erpm_kp;
  double brake_current;
  int overspeed_delay; // Firmware 5.1 only
  int fault_delay; // Firmware 5.1 only
  double yaw_current_clamp;
  double setpoint_pitch_filter;
  double setpoint_target_filter;
  double setpoint_filter_clamp;
  int kd_pt1_frequency; // Firmware 5.2 added
}

// CAN status modes
enum CAN_STATUS_MODE {
  CAN_STATUS_DISABLED,
  CAN_STATUS_1,
  CAN_STATUS_1_2,
  CAN_STATUS_1_2_3,
  CAN_STATUS_1_2_3_4,
  CAN_STATUS_1_2_3_4_5
}

enum SHUTDOWN_MODE {
  SHUTDOWN_MODE_ALWAYS_OFF,
  SHUTDOWN_MODE_ALWAYS_ON,
  SHUTDOWN_MODE_TOGGLE_BUTTON_ONLY,
  SHUTDOWN_MODE_OFF_AFTER_10S,
  SHUTDOWN_MODE_OFF_AFTER_1M,
  SHUTDOWN_MODE_OFF_AFTER_5M,
  SHUTDOWN_MODE_OFF_AFTER_10M,
  SHUTDOWN_MODE_OFF_AFTER_30M,
  SHUTDOWN_MODE_OFF_AFTER_1H,
  SHUTDOWN_MODE_OFF_AFTER_5H,
}

enum IMU_TYPE {
  IMU_TYPE_OFF,
  IMU_TYPE_INTERNAL,
  IMU_TYPE_EXTERNAL_MPU9X50,
  IMU_TYPE_EXTERNAL_ICM20948,
  IMU_TYPE_EXTERNAL_BMI160,
  IMU_TYPE_EXTERNAL_LSM6DS3, // Firmware 5.2 added
}

enum AHRS_MODE {
  AHRS_MODE_MADGWICK,
  AHRS_MODE_MAHONY
}

class imu_config {
  imu_config() {
    accel_offsets = List.filled(3, 0);
    gyro_offsets = List.filled(3, 0);
    gyro_offset_comp_fact = List.filled(3, 0);
  }
  IMU_TYPE type;
  AHRS_MODE mode;
  int sample_rate_hz;
  double accel_confidence_decay;
  double mahony_kp;
  double mahony_ki;
  double madgwick_beta;
  double rot_roll;
  double rot_pitch;
  double rot_yaw;
  List<double> accel_offsets;
  List<double> gyro_offsets;
  List<double> gyro_offset_comp_fact;
  double gyro_offset_comp_clamp;
}

enum CAN_MODE {
  CAN_MODE_VESC,
  CAN_MODE_UAVCAN,
  CAN_MODE_COMM_BRIDGE
}

enum UAVCAN_RAW_MODE { // Firmware 5.2 added
  UAVCAN_RAW_MODE_CURRENT,
  UAVCAN_RAW_MODE_CURRENT_NO_REV_BRAKE,
  UAVCAN_RAW_MODE_DUTY,
}

enum CAN_BAUD {
  CAN_BAUD_125K,
  CAN_BAUD_250K,
  CAN_BAUD_500K,
  CAN_BAUD_1M,
  CAN_BAUD_10K,
  CAN_BAUD_20K,
  CAN_BAUD_50K,
  CAN_BAUD_75K,
  CAN_BAUD_100K, // Firmware 5.2 added
}

class APPCONF {
  APPCONF() {
    app_ppm_conf = new ppm_config();
    app_adc_conf = new adc_config();
    app_chuk_conf = new chuk_config();
    app_nrf_conf = new nrf_config();
    app_balance_conf = new balance_config();
    imu_conf = new imu_config();
    app_pas_conf = new pas_config();
  }
  // Settings
  int controller_id;
  int timeout_msec;
  double timeout_brake_current;
  CAN_STATUS_MODE send_can_status;
  int send_can_status_rate_hz;
  CAN_BAUD can_baud_rate;
  bool pairing_done;
  bool permanent_uart_enabled;
  SHUTDOWN_MODE shutdown_mode;

  // CAN modes
  CAN_MODE can_mode;
  int uavcan_esc_index;
  UAVCAN_RAW_MODE uavcan_raw_mode; // Firmware 5.2 added

  // Application to use
  app_use app_to_use;

  // PPM application settings
  ppm_config app_ppm_conf;

  // ADC application settings
  adc_config app_adc_conf;

  // UART application settings
  int app_uart_baudrate;

  // Nunchuk application settings
  chuk_config app_chuk_conf;

  // NRF application settings
  nrf_config app_nrf_conf;

  // Balance application settings
  balance_config app_balance_conf;

  // Pedal Assist application settings
  pas_config app_pas_conf;  // Firmware 5.2 added

  // IMU Settings
  imu_config imu_conf;
}