// VESC based ESC defines
// From datatypes.h
enum BATTERY_TYPE {
  BATTERY_TYPE_LIION_3_0__4_2,
  BATTERY_TYPE_LIIRON_2_6__3_6,
  BATTERY_TYPE_LEAD_ACID
}

enum temp_sensor_type {
  TEMP_SENSOR_NTC_10K_25C,
  TEMP_SENSOR_PTC_1K_100C,
  TEMP_SENSOR_KTY83_122,
  TEMP_SENSOR_NTC_100K_25C, // Firmware 5.2 added
  TEMP_SENSOR_KTY84_130,
  TEMP_SENSOR_NTCX,
  TEMP_SENSOR_PTCX,
  TEMP_SENSOR_PT1000,
  TEMP_SENSOR_DISABLED
}

enum out_aux_mode {
  OUT_AUX_MODE_OFF,
  OUT_AUX_MODE_ON_AFTER_2S,
  OUT_AUX_MODE_ON_AFTER_5S,
  OUT_AUX_MODE_ON_AFTER_10S,
  OUT_AUX_MODE_UNUSED,
  OUT_AUX_MODE_ON_WHEN_RUNNING, // Firmware 5.3 added
  OUT_AUX_MODE_ON_WHEN_NOT_RUNNING, // Firmware 5.3 added
  OUT_AUX_MODE_MOTOR_50, // Firmware 5.3 added
  OUT_AUX_MODE_MOSFET_50, // Firmware 5.3 added
  OUT_AUX_MODE_MOTOR_70, // Firmware 5.3 added
  OUT_AUX_MODE_MOSFET_70, // Firmware 5.3 added
  OUT_AUX_MODE_MOTOR_MOSFET_50, // Firmware 5.3 added
  OUT_AUX_MODE_MOTOR_MOSFET_70, // Firmware 5.3 added
}

enum drv8301_oc_mode{
  DRV8301_OC_LIMIT,
  DRV8301_OC_LATCH_SHUTDOWN,
  DRV8301_OC_REPORT_ONLY,
  DRV8301_OC_DISABLED
}

enum sensor_port_mode {
  SENSOR_PORT_MODE_HALL,
  SENSOR_PORT_MODE_ABI,
  SENSOR_PORT_MODE_AS5047_SPI,
  SENSOR_PORT_MODE_AD2S1205,
  SENSOR_PORT_MODE_SINCOS,
  SENSOR_PORT_MODE_TS5700N8501,
  SENSOR_PORT_MODE_TS5700N8501_MULTITURN,
  SENSOR_PORT_MODE_MT6816_SPI_HW,
  SENSOR_PORT_MODE_AS5x47U_SPI,
  SENSOR_PORT_MODE_BISSC,
  SENSOR_PORT_MODE_TLE5012_SSC_SW,
  SENSOR_PORT_MODE_TLE5012_SSC_HW,
  SENSOR_PORT_MODE_CUSTOM_ENCODER,
}

enum mc_foc_hfi_samples {
  HFI_SAMPLES_8,
  HFI_SAMPLES_16,
  HFI_SAMPLES_32
}

enum mc_foc_observer_type{
  FOC_OBSERVER_ORTEGA_ORIGINAL,
  FOC_OBSERVER_MXLEMMING,
  FOC_OBSERVER_ORTEGA_LAMBDA_COMP,
  FOC_OBSERVER_MXLEMMING_LAMBDA_COMP
}

enum mc_foc_cc_decoupling_mode {
  FOC_CC_DECOUPLING_DISABLED,
  FOC_CC_DECOUPLING_CROSS,
  FOC_CC_DECOUPLING_BEMF,
  FOC_CC_DECOUPLING_CROSS_BEMF
}

enum mc_foc_sensor_mode {
  FOC_SENSOR_MODE_SENSORLESS,
  FOC_SENSOR_MODE_ENCODER,
  FOC_SENSOR_MODE_HALL,
  FOC_SENSOR_MODE_HFI,
  FOC_SENSOR_MODE_HFI_START,
  FOC_SENSOR_MODE_HFI_V2,
  FOC_SENSOR_MODE_HFI_V3,
  FOC_SENSOR_MODE_HFI_V4,
  FOC_SENSOR_MODE_HFI_V5
}

enum mc_foc_control_sample_mode {
  FOC_CONTROL_SAMPLE_MODE_V0,
  FOC_CONTROL_SAMPLE_MODE_V0_V7,
  FOC_CONTROL_SAMPLE_MODE_V0_V7_INTERPOL
}

enum mc_foc_current_sample_mode {
  FOC_CURRENT_SAMPLE_MODE_LONGEST_ZERO,
  FOC_CURRENT_SAMPLE_MODE_ALL_SENSORS,
  FOC_CURRENT_SAMPLE_MODE_HIGH_CURRENT
}

enum mc_sensor_mode {
  SENSOR_MODE_SENSORLESS,
  SENSOR_MODE_SENSORED,
  SENSOR_MODE_HYBRID
}

enum mc_motor_type {
  MOTOR_TYPE_BLDC,
  MOTOR_TYPE_DC,
  MOTOR_TYPE_FOC,
  MOTOR_TYPE_GPD
}

enum mc_comm_mode {
  COMM_MODE_INTEGRATE,
  COMM_MODE_DELAY
}

enum mc_pwm_mode {
  PWM_MODE_NONSYNCHRONOUS_HISW, // This mode is not recommended
  PWM_MODE_SYNCHRONOUS, // The recommended and most tested mode
  PWM_MODE_BIPOLAR // Some glitches occasionally, can kill MOSFETs
}

enum BMS_TYPE {
  BMS_TYPE_NONE,
  BMS_TYPE_VESC
}

enum BMS_FWD_CAN_MODE {
  BMS_FWD_CAN_MODE_DISABLED, // Firmware 5.3 added
  BMS_FWD_CAN_MODE_USB_ONLY, // Firmware 5.3 added
  BMS_FWD_CAN_MODE_ANY, // Firmware 5.3 added
}

class bms_config {
  BMS_TYPE type = BMS_TYPE.BMS_TYPE_NONE;
  int limit_mode = 0;
  double t_limit_start = 0;
  double t_limit_end = 0;
  double soc_limit_start = 0;
  double soc_limit_end = 0;
  BMS_FWD_CAN_MODE fwd_can_mode = BMS_FWD_CAN_MODE.BMS_FWD_CAN_MODE_DISABLED; // Firmware 5.3 added
}

enum PID_RATE {
  PID_RATE_25_HZ, // Firmware 5.3 added
  PID_RATE_50_HZ, // Firmware 5.3 added
  PID_RATE_100_HZ, // Firmware 5.3 added
  PID_RATE_250_HZ, // Firmware 5.3 added
  PID_RATE_500_HZ, // Firmware 5.3 added
  PID_RATE_1000_HZ, // Firmware 5.3 added
  PID_RATE_2500_HZ, // Firmware 5.3 added
  PID_RATE_5000_HZ, // Firmware 5.3 added
  PID_RATE_10000_HZ, // Firmware 5.3 added
}

enum MTPA_MODE{
  MTPA_MODE_OFF, // Firmware 5.3 added
  MTPA_MODE_IQ_TARGET, // Firmware 5.3 added
  MTPA_MODE_IQ_MEASURED,  // Firmware 5.3 added
}

enum FOC_SPEED_SRC {  //fw6.2
  FOC_SPEED_SRC_CORRECTED,
  FOC_SPEED_SRC_OBSERVER,
}

enum S_PID_SPEED_SRC {   //fw6.2
  S_PID_SPEED_SRC_PLL,
  S_PID_SPEED_SRC_FAST,
  S_PID_SPEED_SRC_FASTER,
}

enum SAT_COMP_MODE {
SAT_COMP_DISABLED,
SAT_COMP_FACTOR,
SAT_COMP_LAMBDA,
SAT_COMP_LAMBDA_AND_FACTOR
}


class MCCONF {
  // Limits
  double l_current_max = 0;
  double l_current_min = 0;
  double l_in_current_max = 0;
  double l_in_current_min = 0;
  double l_in_current_map_start = 0; //fw6.2
  double l_in_current_map_filter = 0;  //fw6.2
  double l_abs_current_max = 0;
  double l_min_erpm = 0;
  double l_max_erpm = 0;
  double l_erpm_start = 0;
  double l_max_erpm_fbrake = 0;
  double l_max_erpm_fbrake_cc = 0;
  double l_min_vin = 0;
  double l_max_vin = 0;
  double l_battery_cut_start = 0;
  double l_battery_cut_end = 0;
  double l_battery_regen_cut_start = 0; //fw6.2
  double l_battery_regen_cut_end = 0; //fw6.2
  bool l_slow_abs_current = false;
  double l_temp_fet_start = 0;
  double l_temp_fet_end = 0;
  double l_temp_motor_start = 0;
  double l_temp_motor_end = 0;
  double l_temp_accel_dec = 0;
  double l_min_duty = 0;
  double l_max_duty = 0;
  double l_watt_max = 0;
  double l_watt_min = 0;
  double l_current_max_scale = 0;
  double l_current_min_scale = 0;
  double l_duty_start = 0;
  // Overridden limits (Computed during runtime)
  double lo_current_max = 0;
  double lo_current_min = 0;
  double lo_in_current_max = 0;
  double lo_in_current_min = 0;
  double lo_current_motor_max_now = 0;
  double lo_current_motor_min_now = 0;

  //BLDC switching and drive
  mc_pwm_mode pwm_mode = mc_pwm_mode.PWM_MODE_NONSYNCHRONOUS_HISW;
  mc_comm_mode comm_mode = mc_comm_mode.COMM_MODE_INTEGRATE;
  mc_motor_type motor_type = mc_motor_type.MOTOR_TYPE_BLDC;
  mc_sensor_mode sensor_mode = mc_sensor_mode.SENSOR_MODE_SENSORLESS;

  // Sensorless (bldc)
  double sl_min_erpm = 0;
  double sl_min_erpm_cycle_int_limit = 0;
  double sl_max_fullbreak_current_dir_change = 0;
  double sl_cycle_int_limit = 0;
  double sl_phase_advance_at_br = 0;
  double sl_cycle_int_rpm_br = 0;
  double sl_bemf_coupling_k = 0;
  // Hall sensor
  List<int> hall_table = List.filled(8, 0);
  double hall_sl_erpm = 0;
  // FOC
  double foc_current_kp = 0;
  double foc_current_ki = 0;
  double foc_f_zv = 0; // Firmware 5.3 changed from: foc_f_sw
  double foc_dt_us = 0;
  double foc_encoder_offset = 0;
  bool foc_encoder_inverted = false;
  double foc_encoder_ratio = 0;
  double foc_encoder_sin_offset = 0;
  double foc_encoder_sin_gain = 0;
  double foc_encoder_cos_offset = 0;
  double foc_encoder_cos_gain = 0;
  double foc_encoder_sincos_filter_constant = 0;
  double foc_motor_l = 0;
  double foc_motor_ld_lq_diff = 0; // Firmware 5.2 added
  double foc_motor_r = 0;
  double foc_motor_flux_linkage = 0;
  double foc_observer_gain = 0;
  double foc_observer_gain_slow = 0;
  double foc_observer_offset = 0; // Firmware 5.3 added
  double foc_pll_kp = 0;
  double foc_pll_ki = 0;
  double foc_duty_dowmramp_kp = 0;
  double foc_duty_dowmramp_ki = 0;
  double foc_start_curr_dec = 0;  //fw6
  double foc_start_curr_dec_rpm = 0;  //fw6
  double foc_openloop_rpm = 0;
  double foc_openloop_rpm_low = 0; // Firmware 5.2 added
  double foc_d_gain_scale_start = 0; // Fimware 5.2 added
  double foc_d_gain_scale_max_mod = 0; // Firmware 5.2 added
  double foc_sl_openloop_hyst = 0;
  double foc_sl_openloop_time = 0;
  double foc_sl_openloop_time_lock = 0; // Firmware 5.2 added; was foc_sl_d_current_duty in 5.1
  double foc_sl_openloop_time_ramp = 0; // Firmware 5.2 added; was foc_sl_d_current_factor in 5.1
  double foc_sl_openloop_boost_q = 0; //fw6
  double foc_sl_openloop_max_q = 0;  //fw6
  mc_foc_sensor_mode foc_sensor_mode = mc_foc_sensor_mode.FOC_SENSOR_MODE_SENSORLESS;
  List<int> foc_hall_table = List.filled(8, 0);
  double foc_hall_interp_erpm = 0; // Firmware 5.2 added
  double foc_sl_erpm_start = 0; //fw6.2
  double foc_sl_erpm = 0;
  bool foc_sample_v0_v7 = false;
  bool foc_sample_high_current = false;
  mc_foc_control_sample_mode foc_control_sample_mode = mc_foc_control_sample_mode.FOC_CONTROL_SAMPLE_MODE_V0; //fw6.2
  mc_foc_current_sample_mode foc_current_sample_mode = mc_foc_current_sample_mode.FOC_CURRENT_SAMPLE_MODE_LONGEST_ZERO;   //fw6.2
  SAT_COMP_MODE foc_sat_comp_mode = SAT_COMP_MODE.SAT_COMP_DISABLED;  //fw6
  double foc_sat_comp = 0;
  bool foc_temp_comp = false;
  double foc_temp_comp_base_temp = 0;
  double foc_current_filter_const = 0;
  mc_foc_cc_decoupling_mode foc_cc_decoupling = mc_foc_cc_decoupling_mode.FOC_CC_DECOUPLING_DISABLED;
  mc_foc_observer_type foc_observer_type = mc_foc_observer_type.FOC_OBSERVER_ORTEGA_ORIGINAL;
  double foc_hfi_voltage_start = 0;
  double foc_hfi_voltage_run = 0;
  double foc_hfi_voltage_max = 0;
  double foc_hfi_gain = 0;  //fw6
  double foc_hfi_hyst = 0;  //fw6
  double foc_sl_erpm_hfi = 0;
  int foc_hfi_start_samples = 0;
  double foc_hfi_obs_ovr_sec = 0;
  mc_foc_hfi_samples foc_hfi_samples = mc_foc_hfi_samples.HFI_SAMPLES_8;
  bool foc_offsets_cal_on_boot = false;
  List<double> foc_offsets_current = List.filled(3, 0); // Firmware 5.3 added
  List<double> foc_offsets_voltage = List.filled(3, 0); // Firmware 5.3 added
  List<double> foc_offsets_voltage_undriven = List.filled(3, 0); // Firmware 5.3 added
  bool foc_phase_filter_enable = false; // Firmware 5.3 added
  bool foc_phase_filter_disable_fault = false;  //fw6
  double foc_phase_filter_max_erpm = 0; // Firmware 5.3 added
  MTPA_MODE foc_mtpa_mode = MTPA_MODE.MTPA_MODE_OFF; // Firmware 5.3 added
  // Field Weakening
  double foc_fw_current_max = 0; // Firmware 5.3 added
  double foc_fw_duty_start = 0; // Firmware 5.3 added
  double foc_fw_ramp_time = 0; // Firmware 5.3 added
  double foc_fw_q_current_factor = 0; // Firmware 5.3 added
  // SPEED_SRC foc_speed_source;  //fw6
  FOC_SPEED_SRC foc_speed_source = FOC_SPEED_SRC.FOC_SPEED_SRC_CORRECTED;  //fw6.2
  // GPDrive
  int gpd_buffer_notify_left = 0;
  int gpd_buffer_interpol = 0;
  double gpd_current_filter_const = 0;
  double gpd_current_kp = 0;
  double gpd_current_ki = 0;

  PID_RATE sp_pid_loop_rate = PID_RATE.PID_RATE_25_HZ; // Firmware 5.3 added

  // Speed PID
  double s_pid_kp = 0;
  double s_pid_ki = 0;
  double s_pid_kd = 0;
  double s_pid_kd_filter = 0;
  double s_pid_min_erpm = 0;
  bool s_pid_allow_braking = false;
  double s_pid_ramp_erpms_s = 0; // Firmware 5.2 added
  S_PID_SPEED_SRC s_pid_speed_source = S_PID_SPEED_SRC.S_PID_SPEED_SRC_PLL;

  // Pos PID
  double p_pid_kp = 0;
  double p_pid_ki = 0;
  double p_pid_kd = 0;
  double p_pid_kd_proc = 0; // Firmware 5.3 added
  double p_pid_kd_filter = 0;
  double p_pid_ang_div = 0;
  double p_pid_gain_dec_angle = 0; // Firmware 5.3 added
  double p_pid_offset = 0; // Firmware 5.3 added
  // Current controller
  double cc_startup_boost_duty = 0;
  double cc_min_current = 0;
  double cc_gain = 0;
  double cc_ramp_step_max = 0;
  // Misc
  int m_fault_stop_time_ms = 0;
  double m_duty_ramp_step = 0;
  double m_current_backoff_gain = 0;
  int m_encoder_counts = 0;
  double m_encoder_sin_offset = 0;  //fw6>>
  double m_encoder_sin_amp = 0;
  double m_encoder_cos_offset = 0;
  double m_encoder_cos_amp = 0;
  double m_encoder_sincos_filter_constant = 0;
  double m_encoder_sincos_phase_correction = 0; //fw6^
  sensor_port_mode m_sensor_port_mode = sensor_port_mode.SENSOR_PORT_MODE_HALL;
  bool m_invert_direction = false;
  drv8301_oc_mode m_drv8301_oc_mode = drv8301_oc_mode.DRV8301_OC_LIMIT;
  int m_drv8301_oc_adj = 0;
  double m_bldc_f_sw_min = 0;
  double m_bldc_f_sw_max = 0;
  double m_dc_f_sw = 0;
  double m_ntc_motor_beta = 0;
  out_aux_mode m_out_aux_mode = out_aux_mode.OUT_AUX_MODE_OFF;
  temp_sensor_type m_motor_temp_sens_type = temp_sensor_type.TEMP_SENSOR_NTC_10K_25C;
  double m_ptc_motor_coeff = 0;
  int m_hall_extra_samples = 0; // Firmware 5.2 added
  int m_batt_filter_const = 0;  //fw6
  double m_ntcx_ptcx_temp_base = 0; //fw6
  double m_ntcx_ptcx_res = 0; //fw6
  // Setup info
  int si_motor_poles = 0;
  double si_gear_ratio = 0;
  double si_wheel_diameter = 0;
  BATTERY_TYPE si_battery_type = BATTERY_TYPE.BATTERY_TYPE_LIION_3_0__4_2;
  int si_battery_cells = 0;
  double si_battery_ah = 0;
  double si_motor_nl_current = 0; // Firmware 5.3 added
  // BMS Configuration
  bms_config bms = new bms_config(); // Firmware 5.2 added
}
