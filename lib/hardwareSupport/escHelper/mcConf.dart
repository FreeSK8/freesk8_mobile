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
  TEMP_SENSOR_KTY84_130, // Firmware 5.3 added
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
  SENSOR_PORT_MODE_MT6816_SPI, // Firmware 5.2 added
}

enum mc_foc_hfi_samples {
  HFI_SAMPLES_8,
  HFI_SAMPLES_16,
  HFI_SAMPLES_32
}

enum mc_foc_observer_type{
  FOC_OBSERVER_ORTEGA_ORIGINAL,
  FOC_OBSERVER_ORTEGA_ITERATIVE
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
  FOC_SENSOR_MODE_HFI_START, // Firmware 5.3 added
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
  BMS_TYPE type;
  double t_limit_start;
  double t_limit_end;
  double soc_limit_start;
  double soc_limit_end;
  BMS_FWD_CAN_MODE fwd_can_mode; // Firmware 5.3 added
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

class MCCONF {
  MCCONF() {
    hall_table = List.filled(8, 0);
    foc_hall_table = List.filled(8, 0);
    bms = new bms_config();
    foc_offsets_current = List.filled(3, 0); // Firmware 5.3 added
    foc_offsets_voltage = List.filled(3, 0); // Firmware 5.3 added
    foc_offsets_voltage_undriven = List.filled(3, 0); // Firmware 5.3 added
  }
  // Switching and drive
  mc_pwm_mode pwm_mode;
  mc_comm_mode comm_mode;
  mc_motor_type motor_type;
  mc_sensor_mode sensor_mode;
  // Limits
  double l_current_max;
  double l_current_min;
  double l_in_current_max;
  double l_in_current_min;
  double l_abs_current_max;
  double l_min_erpm;
  double l_max_erpm;
  double l_erpm_start;
  double l_max_erpm_fbrake;
  double l_max_erpm_fbrake_cc;
  double l_min_vin;
  double l_max_vin;
  double l_battery_cut_start;
  double l_battery_cut_end;
  bool l_slow_abs_current;
  double l_temp_fet_start;
  double l_temp_fet_end;
  double l_temp_motor_start;
  double l_temp_motor_end;
  double l_temp_accel_dec;
  double l_min_duty;
  double l_max_duty;
  double l_watt_max;
  double l_watt_min;
  double l_current_max_scale;
  double l_current_min_scale;
  double l_duty_start;
  // Overridden limits (Computed during runtime)
  double lo_current_max;
  double lo_current_min;
  double lo_in_current_max;
  double lo_in_current_min;
  double lo_current_motor_max_now;
  double lo_current_motor_min_now;
  // Sensorless (bldc)
  double sl_min_erpm;
  double sl_min_erpm_cycle_int_limit;
  double sl_max_fullbreak_current_dir_change;
  double sl_cycle_int_limit;
  double sl_phase_advance_at_br;
  double sl_cycle_int_rpm_br;
  double sl_bemf_coupling_k;
  // Hall sensor
  List<int> hall_table;
  double hall_sl_erpm;
  // FOC
  double foc_current_kp;
  double foc_current_ki;
  double foc_f_sw;
  double foc_dt_us;
  double foc_encoder_offset;
  bool foc_encoder_inverted;
  double foc_encoder_ratio;
  double foc_encoder_sin_offset;
  double foc_encoder_sin_gain;
  double foc_encoder_cos_offset;
  double foc_encoder_cos_gain;
  double foc_encoder_sincos_filter_constant;
  double foc_motor_l;
  double foc_motor_ld_lq_diff; // Firmware 5.2 added
  double foc_motor_r;
  double foc_motor_flux_linkage;
  double foc_observer_gain;
  double foc_observer_gain_slow;
  double foc_pll_kp;
  double foc_pll_ki;
  double foc_duty_dowmramp_kp;
  double foc_duty_dowmramp_ki;
  double foc_openloop_rpm;
  double foc_openloop_rpm_low; // Firmware 5.2 added
  double foc_d_gain_scale_start; // Fimware 5.2 added
  double foc_d_gain_scale_max_mod; // Firmware 5.2 added
  double foc_sl_openloop_hyst;
  double foc_sl_openloop_time;
  double foc_sl_openloop_time_lock; // Firmware 5.2 added; was foc_sl_d_current_duty in 5.1
  double foc_sl_openloop_time_ramp; // Firmware 5.2 added; was foc_sl_d_current_factor in 5.1
  mc_foc_sensor_mode foc_sensor_mode;
  List<int> foc_hall_table;
  double foc_hall_interp_erpm; // Firmware 5.2 added
  double foc_sl_erpm;
  bool foc_sample_v0_v7;
  bool foc_sample_high_current;
  double foc_sat_comp;
  bool foc_temp_comp;
  double foc_temp_comp_base_temp;
  double foc_current_filter_const;
  mc_foc_cc_decoupling_mode foc_cc_decoupling;
  mc_foc_observer_type foc_observer_type;
  double foc_hfi_voltage_start;
  double foc_hfi_voltage_run;
  double foc_hfi_voltage_max;
  double foc_sl_erpm_hfi;
  int foc_hfi_start_samples;
  double foc_hfi_obs_ovr_sec;
  mc_foc_hfi_samples foc_hfi_samples;
  bool foc_offsets_cal_on_boot;
  List<double> foc_offsets_current; // Firmware 5.3 added
  List<double> foc_offsets_voltage; // Firmware 5.3 added
  List<double> foc_offsets_voltage_undriven; // Firmware 5.3 added
  bool foc_phase_filter_enable; // Firmware 5.3 added
  double foc_phase_filter_max_erpm; // Firmware 5.3 added
  // Field Weakening
  double foc_fw_current_max; // Firmware 5.3 added
  double foc_fw_duty_start; // Firmware 5.3 added
  double foc_fw_ramp_time; // Firmware 5.3 added
  double foc_fw_q_current_factor; // Firmware 5.3 added
  // GPDrive
  int gpd_buffer_notify_left;
  int gpd_buffer_interpol;
  double gpd_current_filter_const;
  double gpd_current_kp;
  double gpd_current_ki;

  PID_RATE sp_pid_loop_rate; // Firmware 5.3 added

  // Speed PID
  double s_pid_kp;
  double s_pid_ki;
  double s_pid_kd;
  double s_pid_kd_filter;
  double s_pid_min_erpm;
  bool s_pid_allow_braking;
  double s_pid_ramp_erpms_s; // Firmware 5.2 added
  // Pos PID
  double p_pid_kp;
  double p_pid_ki;
  double p_pid_kd;
  double p_pid_kd_proc; // Firmware 5.3 added
  double p_pid_kd_filter;
  double p_pid_ang_div;
  double p_pid_gain_dec_angle; // Firmware 5.3 added
  double p_pid_offset; // Firmware 5.3 added
  // Current controller
  double cc_startup_boost_duty;
  double cc_min_current;
  double cc_gain;
  double cc_ramp_step_max;
  // Misc
  int m_fault_stop_time_ms;
  double m_duty_ramp_step;
  double m_current_backoff_gain;
  int m_encoder_counts;
  sensor_port_mode m_sensor_port_mode;
  bool m_invert_direction;
  drv8301_oc_mode m_drv8301_oc_mode;
  int m_drv8301_oc_adj;
  double m_bldc_f_sw_min;
  double m_bldc_f_sw_max;
  double m_dc_f_sw;
  double m_ntc_motor_beta;
  out_aux_mode m_out_aux_mode;
  temp_sensor_type m_motor_temp_sens_type;
  double m_ptc_motor_coeff;
  int m_hall_extra_samples; // Firmware 5.2 added
  // Setup info
  int si_motor_poles;
  double si_gear_ratio;
  double si_wheel_diameter;
  BATTERY_TYPE si_battery_type;
  int si_battery_cells;
  double si_battery_ah;
  bms_config bms; // Firmware 5.2 added
}