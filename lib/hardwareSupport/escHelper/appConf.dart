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
  APP_BALANCE,  //removed in fw6.2?
  APP_PAS, // Firmware 5.2 added
  APP_ADC_PAS, // Firmware 5.2 added
}

// Throttle curve mode
enum thr_exp_mode {
  THR_EXP_EXPO,
  THR_EXP_NATURAL,
  THR_EXP_POLY
}

enum SAFE_START_MODE {
  SAFE_START_DISABLED, // Was boolean value prior to Firmware 5.3
  SAFE_START_REGULAR, // Was boolean value prior to Firmware 5.3
  SAFE_START_NO_FAULT, // Firmware 5.3 added
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
  PPM_CTRL_TYPE_CURRENT_SMART_REV,
  PPM_CTRL_TYPE_PID_POSITION_180, //fw6
  PPM_CTRL_TYPE_PID_POSITION_360,
}

class ppm_config {
  ppm_control_type ctrl_type = ppm_control_type.PPM_CTRL_TYPE_NONE;
  double pid_max_erpm = 0;
  double hyst = 0;
  double pulse_start = 0;
  double pulse_end = 0;
  double pulse_center = 0;
  bool median_filter = false;
  SAFE_START_MODE safe_start = SAFE_START_MODE.SAFE_START_DISABLED;
  double throttle_exp = 0;
  double throttle_exp_brake = 0;
  thr_exp_mode throttle_exp_mode = thr_exp_mode.THR_EXP_EXPO;
  double ramp_time_pos = 0;
  double ramp_time_neg = 0;
  bool multi_esc = false;
  bool tc = false;
  double tc_max_diff = 0;
  double max_erpm_for_dir = 0;
  double smart_rev_max_duty = 0;
  double smart_rev_ramp_time = 0;
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
  adc_control_type ctrl_type = adc_control_type.ADC_CTRL_TYPE_NONE;
  double hyst = 0;
  double voltage_start = 0;
  double voltage_end = 0;
  double voltage_min = 0;     //fw6
  double voltage_max = 0;     //fw6
  double voltage_center = 0;
  double voltage2_start = 0;
  double voltage2_end = 0;
  bool use_filter = false;
  SAFE_START_MODE safe_start = SAFE_START_MODE.SAFE_START_DISABLED;
  bool cc_button_inverted = false;
  bool rev_button_inverted = false;
  int buttons = 0;        //fw6
  bool voltage_inverted = false;
  bool voltage2_inverted = false;
  double throttle_exp = 0;
  double throttle_exp_brake = 0;
  thr_exp_mode throttle_exp_mode = thr_exp_mode.THR_EXP_EXPO;
  double ramp_time_pos = 0;
  double ramp_time_neg = 0;
  bool multi_esc = false;
  bool tc = false;
  double tc_max_diff = 0;
  int update_rate_hz = 0;
}

// Nunchuk control types
enum chuk_control_type {
  CHUK_CTRL_TYPE_NONE,
  CHUK_CTRL_TYPE_CURRENT,
  CHUK_CTRL_TYPE_CURRENT_NOREV,
  CHUK_CTRL_TYPE_CURRENT_BIDIRECTIONAL, // Firmware 5.2 added
}

class chuk_config {
  chuk_control_type ctrl_type = chuk_control_type.CHUK_CTRL_TYPE_NONE;
  double hyst = 0;
  double ramp_time_pos = 0;
  double ramp_time_neg = 0;
  double stick_erpm_per_s_in_cc = 0;
  double throttle_exp = 0;
  double throttle_exp_brake = 0;
  thr_exp_mode throttle_exp_mode = thr_exp_mode.THR_EXP_EXPO;
  bool multi_esc = false;
  bool tc = false;
  double tc_max_diff = 0;
  bool use_smart_rev = false;
  double smart_rev_max_duty = 0;
  double smart_rev_ramp_time = 0;
}

class pas_config { // Firmware 5.2 added
  pas_control_type ctrl_type = pas_control_type.PAS_CTRL_TYPE_NONE;
  pas_sensor_type sensor_type = pas_sensor_type.PAS_SENSOR_TYPE_QUADRATURE;
  double current_scaling = 0;
  double pedal_rpm_start = 0;
  double pedal_rpm_end = 0;
  bool invert_pedal_direction = false;
  int magnets = 0;
  bool use_filter = false;
  double ramp_time_pos = 0;
  double ramp_time_neg = 0;
  int update_rate_hz = 0;
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
  NRF_SPEED speed = NRF_SPEED.NRF_SPEED_250K;
  NRF_POWER power = NRF_POWER.NRF_POWER_M18DBM;
  NRF_CRC crc_type = NRF_CRC.NRF_CRC_DISABLED;
  NRF_RETR_DELAY retry_delay = NRF_RETR_DELAY.NRF_RETR_DELAY_250US;
  int retries = 0;
  int channel = 0;
  List<int> address = List.filled(3, 0);
  bool send_crc_ack = false;
}

enum BALANCE_PID_MODE {           //fw6
  BALANCE_PID_MODE_ANGLE,
  BALANCE_PID_MODE_ANGLE_RATE_CASCADE
}

class balance_config {
  BALANCE_PID_MODE pid_mode = BALANCE_PID_MODE.BALANCE_PID_MODE_ANGLE; //fw6
  double kp = 0;
  double ki = 0;
  double kd = 0;
  double kp2 = 0; //fw6
  double ki2 = 0; //fw6
  double kd2 = 0; //fw6
  int hertz = 0;
  int loop_time_filter = 0; // Firmware 5.3 added
  double fault_pitch = 0;
  double fault_roll = 0;
  double fault_duty = 0; // Firmware 5.2 added
  double fault_adc1 = 0;
  double fault_adc2 = 0;
  int fault_delay_pitch = 0; // Firmware 5.2 added
  int fault_delay_roll = 0; // Firmware 5.2 added
  int fault_delay_duty = 0; // Firmware 5.2 added
  int fault_delay_switch_half = 0; // Firmware 5.2 added
  int fault_delay_switch_full = 0; // Firmware 5.2 added
  int fault_adc_half_erpm = 0;
  bool fault_is_dual_switch = false; //fw6
  double overspeed_duty = 0; // Firmware 5.1 only
  double tiltback_duty_angle = 0;
  double tiltback_duty_speed = 0;
  double tiltback_duty = 0;
  double tiltback_hv_angle = 0; // Firmware 5.3 added
  double tiltback_hv_speed = 0; // Firmware 5.3 added
  double tiltback_hv = 0;
  double tiltback_lv_angle = 0; // Firmware 5.3 added
  double tiltback_lv_speed = 0; // Firmware 5.3 added
  double tiltback_lv = 0;
  double tiltback_return_speed = 0; // Firmware 5.3 added
  double tiltback_constant = 0;
  int tiltback_constant_erpm = 0; // Firmware 5.2 added
  double tiltback_variable = 0; // Firmware 5.3 added
  double tiltback_variable_max = 0; // Firmware 5.3 added
  double noseangling_speed = 0; // Firmware 5.3 added
  double startup_pitch_tolerance = 0;
  double startup_roll_tolerance = 0;
  double startup_speed = 0;
  double deadzone = 0;
  double current_boost = 0; // Firmware 5.1 and 5.2 only
  bool multi_esc = false;
  double yaw_kp = 0;
  double yaw_ki = 0;
  double yaw_kd = 0;
  double roll_steer_kp = 0;
  double roll_steer_erpm_kp = 0;
  double brake_current = 0;
  int brake_timeout = 0; // Firmware 5.3 added
  int overspeed_delay = 0; // Firmware 5.1 only
  int fault_delay = 0; // Firmware 5.1 only
  double yaw_current_clamp = 0;
  double ki_limit = 0;  //fw6
  double setpoint_pitch_filter = 0; // Firmware 5.1 and 5.2 only
  double setpoint_target_filter = 0; // Firmware 5.1 and 5.2 only
  double setpoint_filter_clamp = 0; // Firmware 5.1 and 5.2 only
  int kd_pt1_lowpass_frequency = 0; // Firmware 5.2 added
  int kd_pt1_highpass_frequency = 0; // Firmware 5.3 added
  double kd_biquad_lowpass = 0; // Firmware 5.3 added
  double kd_biquad_highpass = 0; // Firmware 5.3 added
  double booster_angle = 0; // Firmware 5.3 added
  double booster_ramp = 0; // Firmware 5.3 added
  double booster_current = 0; // Firmware 5.3 added
  double torquetilt_start_current = 0; // Firmware 5.3 added
  double torquetilt_angle_limit = 0; // Firmware 5.3 added
  double torquetilt_on_speed = 0; // Firmware 5.3 added
  double torquetilt_off_speed = 0; // Firmware 5.3 added
  double torquetilt_strength = 0; // Firmware 5.3 added
  double torquetilt_filter = 0; //Firmware 5.3 added
  double turntilt_strength = 0; // Firmware 5.3 added
  double turntilt_angle_limit = 0; // Firmware 5.3 added
  double turntilt_start_angle = 0; // Firmware 5.3 added
  int turntilt_start_erpm = 0; // Firmware 5.3 added
  double turntilt_speed = 0; // Firmware 5.3 added
  int turntilt_erpm_boost = 0; // Firmware 5.3 added
  int turntilt_erpm_boost_end = 0; // Firmware 5.3 added
}

// CAN status modes fw5
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
  AHRS_MODE_MAHONY,
  AHRS_MODE_MADGWICK_FUSION, // Firmware 5.3 added
}

enum IMU_FILTER { //fw6
  IMU_FILTER_LOW,
  IMU_FILTER_MEDIUM,
  IMU_FILTER_HIGH
}

class imu_config {
  IMU_TYPE type = IMU_TYPE.IMU_TYPE_OFF;
  AHRS_MODE mode = AHRS_MODE.AHRS_MODE_MADGWICK;
  IMU_FILTER filter = IMU_FILTER.IMU_FILTER_LOW;
  double accel_lowpass_filter_x = 0;
  double accel_lowpass_filter_y = 0;
  double accel_lowpass_filter_z = 0;
  double gyro_lowpass_filter = 0;
  int sample_rate_hz = 0;
  bool use_magnetometer = false;
  double accel_confidence_decay = 0;
  double mahony_kp = 0;
  double mahony_ki = 0;
  double madgwick_beta = 0;
  double rot_roll = 0;
  double rot_pitch = 0;
  double rot_yaw = 0;
  List<double> accel_offsets = List.filled(3, 0);
  List<double> gyro_offsets = List.filled(3, 0);
  List<double> gyro_offset_comp_fact = List.filled(3, 0); // Firmware 5.1 and 5.2 only
  double gyro_offset_comp_clamp = 0; // Firmware 5.1 and 5.2 only
}

class AS504x_diag { // Firmware 5.3 added
  int is_connected = 0;
  int AGC_value = 0;
  int magnitude = 0;
  int is_OCF = 0;
  int is_COF = 0;
  int is_Comp_low = 0;
  int is_Comp_high = 0;
  int serial_diag_flgs = 0;
  int serial_magnitude = 0;
  int serial_error_flags = 0;
}

enum CAN_MODE {
  CAN_MODE_VESC,
  CAN_MODE_UAVCAN,
  CAN_MODE_COMM_BRIDGE,
  CAN_MODE_UNUSED, //fw6
}

enum UAVCAN_RAW_MODE { // Firmware 5.2 added
  UAVCAN_RAW_MODE_CURRENT,
  UAVCAN_RAW_MODE_CURRENT_NO_REV_BRAKE,
  UAVCAN_RAW_MODE_DUTY,
}

enum UAVCAN_STATUS_CURRENT_MODE {
  UAVCAN_STATUS_CURRENT_MODE_MOTOR,
  UAVCAN_STATUS_CURRENT_MODE_INPUT
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

enum KILL_SW_MODE { // Firmware 5.3 added
  KILL_SW_MODE_DISABLED,
  KILL_SW_MODE_PPM_LOW,
  KILL_SW_MODE_PPM_HIGH,
  KILL_SW_MODE_ADC2_LOW,
  KILL_SW_MODE_ADC2_HIGH,
}

class APPCONF {
  // Settings
  int controller_id = 0;
  int timeout_msec = 0;
  double timeout_brake_current = 0;
  CAN_STATUS_MODE send_can_status = CAN_STATUS_MODE.CAN_STATUS_DISABLED;
  int can_status_rate_1 = 0; //fw6
  int can_status_msgs_r1 = 0; //fw6
  int can_status_rate_2 = 0; //fw6
  int can_status_msgs_r2 = 0; //fw6
  int send_can_status_rate_hz = 0;
  CAN_BAUD can_baud_rate = CAN_BAUD.CAN_BAUD_125K;
  bool pairing_done = false;
  bool permanent_uart_enabled = false;
  SHUTDOWN_MODE shutdown_mode = SHUTDOWN_MODE.SHUTDOWN_MODE_ALWAYS_OFF;
  bool servo_out_enabled = false; // Firmware 5.3 added
  KILL_SW_MODE kill_sw_mode = KILL_SW_MODE.KILL_SW_MODE_DISABLED; // Firmware 5.3 added

  // CAN modes
  CAN_MODE can_mode = CAN_MODE.CAN_MODE_VESC;
  int uavcan_esc_index = 0;
  UAVCAN_RAW_MODE uavcan_raw_mode = UAVCAN_RAW_MODE.UAVCAN_RAW_MODE_CURRENT; // Firmware 5.2 added
  double uavcan_raw_rpm_max = 0; // Firmware 5.3 added
  UAVCAN_STATUS_CURRENT_MODE uavcan_status_current_mode = UAVCAN_STATUS_CURRENT_MODE.UAVCAN_STATUS_CURRENT_MODE_MOTOR;  //fw6
  // Application to use
  app_use app_to_use = app_use.APP_NONE;

  // PPM application settings
  ppm_config app_ppm_conf = new ppm_config();

  // ADC application settings
  adc_config app_adc_conf = new adc_config();

  // UART application settings
  int app_uart_baudrate = 0;

  // Nunchuk application settings
  chuk_config app_chuk_conf = new chuk_config();

  // NRF application settings
  nrf_config app_nrf_conf = new nrf_config();

  // Balance application settings
  balance_config app_balance_conf = new balance_config();

  // Pedal Assist application settings
  pas_config app_pas_conf = new pas_config();  // Firmware 5.2 added

  // IMU Settings
  imu_config imu_conf = new imu_config();
}
