/* WS63 mask-ROM radio data ABI.
 *
 * The mask ROM addresses these objects at fixed DTCM addresses. Keep this
 * order in sync with the vendor-generated rom_data.lds; ordinary archive
 * order is not an ABI. This fragment is included inside .wifi_rom_data so the
 * existing startup relocation copies the complete radio data window.
 */

/* Wi-Fi ROM data starts at 0x1800d8. */
KEEP(*(.data.g_ltf_and_gi))
. += 2;
KEEP(*(.data.g_11b_per_cnt))
KEEP(*(.data.g_dmac_algorithm_main))
KEEP(*(.data.g_temp_protect_aggr_max_mpdu))
KEEP(*(.data.g_btcoex_aggr_max_mpdu))
KEEP(*(.data.g_smooth_phase))
KEEP(*(.data.g_rf_switch_cfg))
KEEP(*(.data.g_mac_pa_switch))
. += 3;
KEEP(*(.data.g_hal_cfg_custom))
KEEP(*(.data.g_mac_res))
KEEP(*(.data.g_buf_size))
. += 2;
KEEP(*(.data.g_mem_start_addr_cfg))
KEEP(*(.data.g_skb_size))

/* The mask ROM references the complete BTC data ABI by address. Archive
 * reachability cannot discover those reads, so every initialized object from
 * btc_rom_data.c.obj must be placed even when no relocatable object names it.
 * Gaps deliberately remain part of the load image so stale DTCM cannot
 * masquerade as initialized data. */
. = ORIGIN(DTCM) + 0x140;
KEEP(*(.data.g_pmu_state_handler_tab))
. = ORIGIN(DTCM) + 0x188;
KEEP(*(.data.g_min_deep_sleep_slot_time))
. = ORIGIN(DTCM) + 0x18c;
KEEP(*(.data.g_min_light_sleep_slot_time))
. = ORIGIN(DTCM) + 0x190;
KEEP(*(.data.g_sleep_boundary_limit))
. = ORIGIN(DTCM) + 0x192;
KEEP(*(.data.g_ble_con_evt_num_before_instant))
. = ORIGIN(DTCM) + 0x194;
KEEP(*(.data.g_ble_isr_process_tbl))
. = ORIGIN(DTCM) + 0x1f8;
KEEP(*(.data.g_current_hw_timer))
. = ORIGIN(DTCM) + 0x1fc;
KEEP(*(.data.g_last_update_time))
. = ORIGIN(DTCM) + 0x200;
KEEP(*(.data.g_clock_gt_mode_to))
. = ORIGIN(DTCM) + 0x204;
KEEP(*(.data.g_company_identifier))
. = ORIGIN(DTCM) + 0x208;
KEEP(*(.data.g_local_bdaddr))
. = ORIGIN(DTCM) + 0x20e;
KEEP(*(.data.g_sw_subversion))
. = ORIGIN(DTCM) + 0x210;
KEEP(*(.data.g_sw_version))
. = ORIGIN(DTCM) + 0x214;
KEEP(*(.data.g_btc_crypto_task_stack_depth))
. = ORIGIN(DTCM) + 0x218;
KEEP(*(.data.g_btc_crypto_task_stack_priority))
. = ORIGIN(DTCM) + 0x21c;
KEEP(*(.data.g_dts_hci_config))
. = ORIGIN(DTCM) + 0x24c;
KEEP(*(.data.g_macro_cfg_flags))
. = ORIGIN(DTCM) + 0x250;
KEEP(*(.data.g_btc_sem_evt))
. = ORIGIN(DTCM) + 0x252;
KEEP(*(.data.g_em_ble_enc_cipher_offset))
. = ORIGIN(DTCM) + 0x254;
KEEP(*(.data.g_em_ble_enc_plain_offset))
. = ORIGIN(DTCM) + 0x256;
KEEP(*(.data.g_em_ble_fal_end))
. = ORIGIN(DTCM) + 0x258;
KEEP(*(.data.g_em_ble_fal_offset))
. = ORIGIN(DTCM) + 0x25a;
KEEP(*(.data.g_em_ble_int_queue_cnt))
. = ORIGIN(DTCM) + 0x25c;
KEEP(*(.data.g_em_ble_int_queue_end))
. = ORIGIN(DTCM) + 0x25e;
KEEP(*(.data.g_em_ble_int_queue_offset))
. = ORIGIN(DTCM) + 0x260;
KEEP(*(.data.g_em_ble_ral_end))
. = ORIGIN(DTCM) + 0x262;
KEEP(*(.data.g_em_ble_ral_offset))
. = ORIGIN(DTCM) + 0x264;
KEEP(*(.data.g_em_ble_rx_desc_count))
. = ORIGIN(DTCM) + 0x266;
KEEP(*(.data.g_em_ble_rx_desc_offset))
. = ORIGIN(DTCM) + 0x268;
KEEP(*(.data.g_em_ble_tx_buff_cntl_cnt))
. = ORIGIN(DTCM) + 0x26a;
KEEP(*(.data.g_em_ble_tx_buff_cntl_offset))
. = ORIGIN(DTCM) + 0x26c;
KEEP(*(.data.g_em_ble_tx_buff_cntl_size))
. = ORIGIN(DTCM) + 0x26d;
KEEP(*(.data.g_em_ble_tx_buff_data_count))
. = ORIGIN(DTCM) + 0x26e;
KEEP(*(.data.g_em_ble_tx_buff_data_offset))
. = ORIGIN(DTCM) + 0x270;
KEEP(*(.data.g_em_ble_tx_buff_data_size))
. = ORIGIN(DTCM) + 0x272;
KEEP(*(.data.g_em_ble_txcntl_desc_cnt))
. = ORIGIN(DTCM) + 0x274;
KEEP(*(.data.g_em_chnl_scan_offset))
. = ORIGIN(DTCM) + 0x276;
KEEP(*(.data.g_em_comm_rx_buff_count))
. = ORIGIN(DTCM) + 0x278;
KEEP(*(.data.g_em_comm_rx_buff_offset))
. = ORIGIN(DTCM) + 0x27a;
KEEP(*(.data.g_em_comm_rx_buff_size))
. = ORIGIN(DTCM) + 0x27c;
KEEP(*(.data.g_em_comm_sed_count_extra))
. = ORIGIN(DTCM) + 0x27e;
KEEP(*(.data.g_em_comm_sed_offset))
. = ORIGIN(DTCM) + 0x280;
KEEP(*(.data.g_em_comm_tx_buff_data_s_count))
. = ORIGIN(DTCM) + 0x282;
KEEP(*(.data.g_em_comm_tx_buff_data_s_offset))
. = ORIGIN(DTCM) + 0x284;
KEEP(*(.data.g_em_comm_tx_buff_data_s_size))
. = ORIGIN(DTCM) + 0x286;
KEEP(*(.data.g_em_comm_txpd_desc_count_extra))
. = ORIGIN(DTCM) + 0x288;
KEEP(*(.data.g_em_comm_txpd_desc_offset))
. = ORIGIN(DTCM) + 0x28a;
KEEP(*(.data.g_em_eeq_normal_cnt))
. = ORIGIN(DTCM) + 0x28b;
KEEP(*(.data.g_em_eeq_urgent_cnt))
. = ORIGIN(DTCM) + 0x28c;
KEEP(*(.data.g_em_eeq_urgent_offset))
. = ORIGIN(DTCM) + 0x28e;
KEEP(*(.data.g_em_freq_tbl_offset))
. = ORIGIN(DTCM) + 0x290;
KEEP(*(.data.g_em_gle_int_queue_cnt))
. = ORIGIN(DTCM) + 0x292;
KEEP(*(.data.g_em_gle_int_queue_end))
. = ORIGIN(DTCM) + 0x294;
KEEP(*(.data.g_em_gle_int_queue_offset))
. = ORIGIN(DTCM) + 0x296;
KEEP(*(.data.g_em_gle_rx_desc_count))
. = ORIGIN(DTCM) + 0x298;
KEEP(*(.data.g_em_gle_rx_desc_offset))
. = ORIGIN(DTCM) + 0x29a;
KEEP(*(.data.g_em_gle_tx_buff_data_count))
. = ORIGIN(DTCM) + 0x29c;
KEEP(*(.data.g_em_gle_tx_buff_data_offset))
. = ORIGIN(DTCM) + 0x29e;
KEEP(*(.data.g_em_gle_tx_buff_data_size))
. = ORIGIN(DTCM) + 0x2a0;
KEEP(*(.data.g_em_hadm_buff_size))
. = ORIGIN(DTCM) + 0x2a2;
KEEP(*(.data.g_em_hadm_buffer_offset))
. = ORIGIN(DTCM) + 0x2a4;
KEEP(*(.data.g_em_hadm_rf_block_size))
. = ORIGIN(DTCM) + 0x2a6;
KEEP(*(.data.g_em_mdm_buff_count))
. = ORIGIN(DTCM) + 0x2a8;
KEEP(*(.data.g_em_mdm_buffer_offset))
. = ORIGIN(DTCM) + 0x2ac;
KEEP(*(.data.g_em_size))
. = ORIGIN(DTCM) + 0x2b0;
KEEP(*(.data.g_max_nb_active_link))
. = ORIGIN(DTCM) + 0x2b4;
KEEP(*(.data.g_crypto_algo_support))
. = ORIGIN(DTCM) + 0x2b8;
KEEP(*(.data.g_encrypt_ccmctr_setup_tab))
. = ORIGIN(DTCM) + 0x2e8;
KEEP(*(.data.g_encrypt_key_deriv_tab))
. = ORIGIN(DTCM) + 0x318;
KEEP(*(.data.g_encrypt_key_exchange_tab))
. = ORIGIN(DTCM) + 0x348;
KEEP(*(.data.g_es_cancel_margin))
. = ORIGIN(DTCM) + 0x349;
KEEP(*(.data.g_es_process_range))
. = ORIGIN(DTCM) + 0x34a;
KEEP(*(.data.g_es_start_latency))
. = ORIGIN(DTCM) + 0x34b;
KEEP(*(.data.g_es_stop_latency))
. = ORIGIN(DTCM) + 0x34c;
KEEP(*(.data.g_es_timer_prog_delay))
. = ORIGIN(DTCM) + 0x350;
KEEP(*(.data.g_es_last_finetarget_time))
. = ORIGIN(DTCM) + 0x354;
KEEP(*(.data.g_es_last_update_time))
. = ORIGIN(DTCM) + 0x358;
KEEP(*(.data.g_duration_max_dft))
. = ORIGIN(DTCM) + 0x35c;
KEEP(*(.data.g_evt_task_ble_adv_default_aux_channel))
. = ORIGIN(DTCM) + 0x35e;
KEEP(*(.data.g_evt_task_ble_adv_default_aux_offset))
. = ORIGIN(DTCM) + 0x360;
KEEP(*(.data.g_gle_isr_process_tbl))
. = ORIGIN(DTCM) + 0x3c4;
KEEP(*(.data.g_ble_delay_send_chnl_report_timer))
. = ORIGIN(DTCM) + 0x3c8;
KEEP(*(.data.g_ble_dft_min_valid_chnl_num))
. = ORIGIN(DTCM) + 0x3ca;
KEEP(*(.data.g_ble_dft_req_map_update_timer))
. = ORIGIN(DTCM) + 0x3cc;
KEEP(*(.data.g_adv_cmd_class))
. = ORIGIN(DTCM) + 0x3ce;
KEEP(*(.data.g_ble_acl_rssi_avg_cnt))
. = ORIGIN(DTCM) + 0x3d0;
KEEP(*(.data.g_ble_acl_rssi_avg_time))
. = ORIGIN(DTCM) + 0x3d4;
KEEP(*(.data.g_dft_txpower_level))
. = ORIGIN(DTCM) + 0x3d6;
KEEP(*(.data.g_gle_acb_rssi_avg_cnt))
. = ORIGIN(DTCM) + 0x3d8;
KEEP(*(.data.g_gle_acb_rssi_avg_time))
. = ORIGIN(DTCM) + 0x3dc;
KEEP(*(.data.g_rf_rx_path_compensation_val))
. = ORIGIN(DTCM) + 0x3de;
KEEP(*(.data.g_rf_tx_path_compensation_val))
. = ORIGIN(DTCM) + 0x3e0;
