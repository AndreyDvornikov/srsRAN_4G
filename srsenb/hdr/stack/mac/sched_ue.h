/**
 * Copyright 2013-2023 Software Radio Systems Limited
 *
 * This file is part of srsRAN.
 *
 * srsRAN is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * srsRAN is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * A copy of the GNU Affero General Public License can be found in
 * the LICENSE file in the top-level directory of this distribution
 * and at http://www.gnu.org/licenses/.
 *
 */

#ifndef SRSENB_SCHEDULER_UE_H
#define SRSENB_SCHEDULER_UE_H

#include "sched_lte_common.h"
#include "sched_ue_ctrl/sched_lch.h"
#include "sched_ue_ctrl/sched_ue_cell.h"
#include "sched_ue_ctrl/tpc.h"
#include "srsenb/hdr/common/common_enb.h"
#include "srsenb/hdr/stack/mac/common/mac_metrics.h"
#include "srsran/adt/optional.h"
#include "srsran/srslog/srslog.h"
#include <bitset>
#include <chrono>
#include <deque>
#include <map>
#include <vector>

namespace srsenb {

typedef enum { UCI_PUSCH_NONE = 0, UCI_PUSCH_CQI, UCI_PUSCH_ACK, UCI_PUSCH_ACK_CQI } uci_pusch_t;

/** This class is designed to be thread-safe because it is called from workers through scheduler thread and from
 * higher layers and mac threads.
 */
class sched_ue
{
  using ue_cfg_t = sched_interface::ue_cfg_t;

public:
  sched_ue(uint16_t rnti, const std::vector<sched_cell_params_t>& cell_list_params_, const ue_cfg_t& cfg);
  void new_subframe(tti_point tti_rx, uint32_t enb_cc_idx);

  /*************************************************************
   *
   * FAPI-like Interface
   *
   ************************************************************/

  void phy_config_enabled(tti_point tti_rx, bool enabled);
  void set_cfg(const ue_cfg_t& cfg);

  void set_bearer_cfg(uint32_t lc_id, const mac_lc_ch_cfg_t& cfg);
  void rem_bearer(uint32_t lc_id);

  void dl_buffer_state(uint8_t lc_id, uint32_t tx_queue, uint32_t retx_queue);
  void ul_buffer_state(uint8_t lcg_id, uint32_t bsr);
  void ul_phr(int phr, uint32_t grant_nof_prb);
  void mac_buffer_state(uint32_t ce_code, uint32_t nof_cmds);

  void set_ul_snr(tti_point tti_rx, uint32_t enb_cc_idx, float snr, uint32_t ul_ch_code);
  void set_dl_ri(tti_point tti_rx, uint32_t enb_cc_idx, uint32_t ri);
  void set_dl_pmi(tti_point tti_rx, uint32_t enb_cc_idx, uint32_t ri);
  void set_dl_cqi(tti_point tti_rx, uint32_t enb_cc_idx, uint32_t cqi);
  void set_dl_sb_cqi(tti_point tti_rx, uint32_t enb_cc_idx, uint32_t sb_idx, uint32_t cqi);
  int  set_ack_info(tti_point tti_rx, uint32_t enb_cc_idx, uint32_t tb_idx, bool ack);
  void set_ul_crc(tti_point tti_rx, uint32_t enb_cc_idx, bool crc_res);

  /*******************************************************
   * Custom functions
   *******************************************************/

  const dl_harq_proc&       get_dl_harq(uint32_t idx, uint32_t enb_cc_idx) const;
  uint16_t                  get_rnti() const { return rnti; }
  std::pair<bool, uint32_t> get_active_cell_index(uint32_t enb_cc_idx) const;
  const ue_cfg_t&           get_ue_cfg() const { return cfg; }
  uint32_t                  get_aggr_level(uint32_t enb_cc_idx, uint32_t nof_bits);
  void                      ul_buffer_add(uint8_t lcid, uint32_t bytes);
  void                      metrics_read(mac_ue_metrics_t& metrics);
  void                      record_dl_sched_result(uint32_t enb_cc_idx,
                                                   uint32_t pid,
                                                   uint32_t tbs_bytes,
                                                   uint32_t dl_prbs,
                                                   uint32_t dl_mcs,
                                                   bool     is_retx,
                                                   uint32_t aggr_level);
  float                     get_dl_window_throughput_bps() const;

  /*******************************************************
   * Functions used by scheduler metric objects
   *******************************************************/

  uint32_t get_required_prb_ul(uint32_t enb_cc_idx, uint32_t req_bytes);

  /// Get total pending bytes to be transmitted in DL.
  /// The amount of CEs to transmit depends on whether enb_cc_idx is UE's PCell
  uint32_t                   get_pending_dl_bytes(uint32_t enb_cc_idx);
  srsran::interval<uint32_t> get_requested_dl_bytes(uint32_t enb_cc_idx);
  rbg_interval               get_required_dl_rbgs(uint32_t enb_cc_idx);
  uint32_t                   get_pending_dl_rlc_data() const;
  uint32_t                   get_expected_dl_bitrate(uint32_t enb_cc_idx, int nof_rbgs = -1) const;

  uint32_t get_pending_ul_data_total(tti_point tti_tx_ul, int this_enb_cc_idx);
  uint32_t get_pending_ul_new_data(tti_point tti_tx_ul, int this_enb_cc_idx);
  uint32_t get_pending_ul_old_data();
  uint32_t get_pending_ul_old_data(uint32_t enb_cc_idx);
  uint32_t get_expected_ul_bitrate(uint32_t enb_cc_idx, int nof_prbs = -1) const;
  uint64_t dl_bytes_accum = 0;
  uint64_t ul_bytes_accum = 0;
  static constexpr uint32_t DL_METRIC_WINDOW_TTI = 100;
  std::deque<uint8_t>       dl_bler_window;
  uint32_t                  dl_bler_sum = 0;

  dl_harq_proc* get_pending_dl_harq(tti_point tti_tx_dl, uint32_t enb_cc_idx);
  dl_harq_proc* get_empty_dl_harq(tti_point tti_tx_dl, uint32_t enb_cc_idx);
  ul_harq_proc* get_ul_harq(tti_point tti_tx_ul, uint32_t enb_cc_idx);

  /*******************************************************
   * Functions used by the scheduler carrier object
   *******************************************************/

  void finish_tti(tti_point tti_rx, uint32_t enb_cc_idx);

  /*******************************************************
   * Functions used by the scheduler object
   *******************************************************/

  void set_sr();
  void unset_sr();

  int generate_dl_dci_format(uint32_t                          pid,
                             sched_interface::dl_sched_data_t* data,
                             tti_point                         tti_tx_dl,
                             uint32_t                          enb_cc_idx,
                             uint32_t                          cfi,
                             const rbgmask_t&                  user_mask);
  int generate_format0(sched_interface::ul_sched_data_t* data,
                       tti_point                         tti_tx_ul,
                       uint32_t                          enb_cc_idx,
                       prb_interval                      alloc,
                       bool                              needs_pdcch,
                       srsran_dci_location_t             cce_range,
                       int                               explicit_mcs = -1,
                       uci_pusch_t                       uci_type     = UCI_PUSCH_NONE);

  srsran_dci_format_t           get_dci_format();
  const cce_cfi_position_table* get_locations(uint32_t enb_cc_idx, uint32_t current_cfi, uint32_t sf_idx) const;

  sched_ue_cell*                   find_ue_carrier(uint32_t enb_cc_idx);
  size_t                           nof_carriers_configured() const { return cfg.supported_cc_list.size(); }
  std::bitset<SRSRAN_MAX_CARRIERS> scell_activation_mask() const;
  int                              enb_to_ue_cc_idx(uint32_t enb_cc_idx) const;

  uint32_t get_max_retx();

  bool pdsch_enabled(tti_point tti_rx, uint32_t enb_cc_idx) const;
  bool pusch_enabled(tti_point tti_rx, uint32_t enb_cc_idx, bool needs_pdcch) const;
  bool phich_enabled(tti_point tti_rx, uint32_t enb_cc_idx) const;

  float get_last_dl_prio() const { return sched_metrics.dl_prio; }
  float get_last_ul_prio() const { return sched_metrics.ul_prio; }

  void set_last_dl_prio(float v) { sched_metrics.dl_prio = v; }
  void set_dl_prb(uint32_t prb) { sched_metrics.dl_prb = prb; }
  void set_dl_mcs(float mcs) { sched_metrics.dl_mcs = mcs; }
  void set_dl_throughput(float tput) { sched_metrics.dl_throughput = tput; }
  void set_last_ul_prio(float v) { sched_metrics.ul_prio = v; }

private:
  void finalize_dl_metric_tti();
  void update_dl_hol_state(uint32_t curr_buffer);
  void reset_metrics();
  void save_dl_metrics(uint32_t enb_cc_idx, const rbgmask_t& user_mask, int mcs);
  void save_ul_metrics(uint32_t enb_cc_idx, prb_interval alloc, int mcs);

  bool is_sr_triggered();

  tbs_info allocate_new_dl_mac_pdu(sched_interface::dl_sched_data_t* data,
                                   dl_harq_proc*                     h,
                                   const rbgmask_t&                  user_mask,
                                   tti_point                         tti_tx_dl,
                                   uint32_t                          enb_cc_idx,
                                   uint32_t                          cfi,
                                   uint32_t                          tb);

  tbs_info compute_mcs_and_tbs(uint32_t               enb_cc_idx,
                               tti_point              tti_tx_dl,
                               const rbgmask_t&       rbgs,
                               uint32_t               cfi,
                               const srsran_dci_dl_t& dci);

  bool needs_cqi(uint32_t tti, uint32_t enb_cc_idx, bool will_send = false);

  int generate_format1_common(uint32_t                          pid,
                              sched_interface::dl_sched_data_t* data,
                              tti_point                         tti_tx_dl,
                              uint32_t                          enb_cc_idx,
                              uint32_t                          cfi,
                              const rbgmask_t&                  user_mask);
  int generate_format1(uint32_t                          pid,
                       sched_interface::dl_sched_data_t* data,
                       tti_point                         tti_tx_dl,
                       uint32_t                          enb_cc_idx,
                       uint32_t                          cfi,
                       const rbgmask_t&                  user_mask);
  int generate_format1a(uint32_t                          pid,
                        sched_interface::dl_sched_data_t* data,
                        tti_point                         tti_tx_dl,
                        uint32_t                          enb_cc_idx,
                        uint32_t                          cfi,
                        const rbgmask_t&                  user_mask);
  int generate_format2a(uint32_t                          pid,
                        sched_interface::dl_sched_data_t* data,
                        tti_point                         tti_tx_dl,
                        uint32_t                          enb_cc_idx,
                        uint32_t                          cfi,
                        const rbgmask_t&                  user_mask);
  int generate_format2(uint32_t                          pid,
                       sched_interface::dl_sched_data_t* data,
                       tti_point                         tti_tx_dl,
                       uint32_t                          enb_cc_idx,
                       uint32_t                          cfi,
                       const rbgmask_t&                  user_mask);

  /* Args */
  ue_cfg_t                   cfg  = {};
  srsran_cell_t              cell = {};
  srslog::basic_logger&      logger;
  const sched_cell_params_t* main_cc_params = nullptr;

  /* Buffer states */
  bool           sr = false;
  lch_ue_manager lch_handler;

  uint32_t cqi_request_tti = 0;
  uint16_t rnti            = 0;
  uint32_t max_msg3retx    = 0;

  bool phy_config_dedicated_enabled = false;

  uint32_t dl_alloc_count_total   = 0;
  uint32_t current_tti_dl_bytes   = 0;
  uint32_t current_tti_dl_prbs    = 0;
  bool     current_tti_dl_retx    = false;
  uint32_t current_tti_retx_count = 0;
  uint32_t current_tti_dl_aggr    = 0;
  std::deque<uint32_t> dl_tti_bytes_window;
  uint64_t             dl_window_bytes_sum = 0;
  srsran::optional<std::chrono::steady_clock::time_point> dl_hol_ts;
  float                                                   dl_latency_ms = 0.0f;
  uint32_t                                                last_dl_buffer = 0;

  tti_point                  current_tti;
  std::vector<sched_ue_cell> cells; ///< List of eNB cells that may be configured/activated/deactivated for the UE
  mac_ue_metrics_t           sched_metrics = {};
};

using sched_ue_list = rnti_map_t<std::unique_ptr<sched_ue> >;

} // namespace srsenb

#endif // SRSENB_SCHEDULER_UE_H
