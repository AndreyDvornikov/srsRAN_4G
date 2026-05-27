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

#include "srsenb/hdr/metrics_json.h"
#include "srsran/srslog/context.h"
#include <unordered_map>

using namespace srsenb;

namespace {

/// Bearer container metrics.
DECLARE_METRIC("dl_buffer", metric_dl_buffer, uint32_t, "");
DECLARE_METRIC("expected_bitrate", metric_expected_bitrate, uint32_t, "");
DECLARE_METRIC("dl_avg_rate", metric_dl_avg_rate, float, "");
DECLARE_METRIC("harq_retx_pending", metric_harq_retx_pending, bool, "");
DECLARE_METRIC("bearer_id", metric_bearer_id, uint32_t, "");
DECLARE_METRIC("qci", metric_qci, uint32_t, "");
DECLARE_METRIC("dl_total_bytes", metric_dl_total_bytes, uint64_t, "");
DECLARE_METRIC("ul_total_bytes", metric_ul_total_bytes, uint64_t, "");
DECLARE_METRIC("dl_latency", metric_dl_latency, float, "");
DECLARE_METRIC("ul_latency", metric_ul_latency, float, "");
DECLARE_METRIC("dl_buffered_bytes", metric_dl_buffered_bytes, uint32_t, "");
DECLARE_METRIC("ul_buffered_bytes", metric_ul_buffered_bytes, uint32_t, "");
DECLARE_METRIC_SET("bearer_container",
                   mset_bearer_container,
                   metric_bearer_id,
                   metric_qci,
                   metric_dl_total_bytes,
                   metric_ul_total_bytes,
                   metric_dl_latency,
                   metric_ul_latency,
                   metric_dl_buffered_bytes,
                   metric_ul_buffered_bytes);

/// UE container metrics.
DECLARE_METRIC("ue_rnti", metric_ue_rnti, uint32_t, "");
DECLARE_METRIC("dl_cqi", metric_dl_cqi, float, "");
DECLARE_METRIC("dl_snr", metric_dl_snr, float, "");
DECLARE_METRIC("dl_mcs", metric_dl_mcs, float, "");
DECLARE_METRIC("dl_bitrate", metric_dl_bitrate, float, "");
DECLARE_METRIC("dl_bler", metric_dl_bler, float, "");
DECLARE_METRIC("ul_snr", metric_ul_snr, float, "");
DECLARE_METRIC("ul_mcs", metric_ul_mcs, float, "");
DECLARE_METRIC("ul_pusch_rssi", metric_ul_pusch_rssi, float, "");
DECLARE_METRIC("ul_pucch_rssi", metric_ul_pucch_rssi, float, "");
DECLARE_METRIC("ul_pucch_ni", metric_ul_pucch_ni, float, "");
DECLARE_METRIC("ul_pusch_tpc", metric_ul_pusch_tpc, int64_t, "");
DECLARE_METRIC("ul_pucch_tpc", metric_ul_pucch_tpc, int64_t, "");
DECLARE_METRIC("dl_cqi_offset", metric_dl_cqi_offset, float, "");
DECLARE_METRIC("ul_snr_offset", metric_ul_snr_offset, float, "");
DECLARE_METRIC("ul_bitrate", metric_ul_bitrate, float, "");
DECLARE_METRIC("ul_bler", metric_ul_bler, float, "");
DECLARE_METRIC("ul_phr", metric_ul_phr, float, "");
DECLARE_METRIC("ul_bsr", metric_bsr, uint32_t, "");
DECLARE_METRIC_LIST("bearer_list", mlist_bearers, std::vector<mset_bearer_container>);
DECLARE_METRIC_SET("ue_container",
                   mset_ue_container,
                   metric_ue_rnti,
                   metric_dl_cqi,
                   metric_dl_snr,
                   metric_dl_mcs,
                   metric_ul_pusch_rssi,
                   metric_ul_pucch_rssi,
                   metric_ul_pucch_ni,
                   metric_ul_pusch_tpc,
                   metric_ul_pucch_tpc,
                   metric_dl_cqi_offset,
                   metric_ul_snr_offset,
                   metric_dl_bitrate,
                   metric_dl_bler,
                   metric_ul_snr,
                   metric_ul_mcs,
                   metric_ul_bitrate,
                   metric_ul_bler,
                   metric_ul_phr,
                   metric_bsr,
                   mlist_bearers);

DECLARE_METRIC("rnti", metric_mac_rnti, uint32_t, "");
DECLARE_METRIC("dl_prb", metric_mac_dl_prb, uint32_t, "");
DECLARE_METRIC("dl_prio", metric_mac_dl_prio, float, "");
DECLARE_METRIC("ul_prio", metric_mac_ul_prio, float, "");
DECLARE_METRIC("ul_prb", metric_mac_ul_prb, uint32_t, "");
DECLARE_METRIC("bsr", metric_mac_bsr, uint32_t, "");
DECLARE_METRIC("dl_throughput", metric_mac_dl_throughput, float, "");
DECLARE_METRIC("ul_throughput", metric_mac_ul_throughput, float, "");
DECLARE_METRIC("dl_latency", metric_mac_dl_latency, float, "");
DECLARE_METRIC("dl_bler", metric_mac_dl_bler, float, "");
DECLARE_METRIC("ul_bler", metric_mac_ul_bler, float, "");
DECLARE_METRIC("dl_buffer", metric_mac_dl_buffer, uint32_t, "");
DECLARE_METRIC("dl_retx_count", metric_mac_dl_retx_count, uint32_t, "");
DECLARE_METRIC("dl_retx_flag", metric_mac_dl_retx_flag, bool, "");
DECLARE_METRIC("dl_aggr_level", metric_mac_dl_aggr_level, uint32_t, "");
DECLARE_METRIC("dl_alloc_count", metric_mac_dl_alloc_count, uint32_t, "");
DECLARE_METRIC("jfi", metric_mac_jfi, float, "");
DECLARE_METRIC("avg_dl_prio", metric_avg_dl_prio, float, "");
DECLARE_METRIC("max_dl_prio", metric_max_dl_prio, float, "");

DECLARE_METRIC("avg_ul_prio", metric_avg_ul_prio, float, "");
DECLARE_METRIC("max_ul_prio", metric_max_ul_prio, float, "");
DECLARE_METRIC("num_ues", metric_mac_num_ues, uint32_t, "");
DECLARE_METRIC("scheduler_runtime_us", metric_scheduler_runtime_us, uint64_t, "");
DECLARE_METRIC("prb_util", metric_prb_util, float, "");
DECLARE_METRIC("nof_prb", metric_nof_prb, uint32_t, "");
DECLARE_METRIC("ranker_time_us", metric_ranker_time_us, uint64_t, "");
DECLARE_METRIC("allocation_time_us", metric_allocation_time_us, uint64_t, "");
DECLARE_METRIC("total_sched_time_us", metric_total_sched_time_us, uint64_t, "");
DECLARE_METRIC_SET("mac_ue_container",
                   mset_mac_ue_container,
                   metric_mac_rnti,
                   metric_dl_cqi,
                   metric_dl_snr,
                   metric_dl_mcs,
                   metric_ul_mcs,
                   metric_mac_dl_prb,
                   metric_mac_ul_prb,
                   metric_mac_bsr,
                   metric_mac_dl_prio,
                   metric_mac_ul_prio,
                   metric_mac_dl_throughput,
                   metric_mac_ul_throughput,
                   metric_mac_dl_latency,
                   metric_mac_dl_bler,
                   metric_mac_ul_bler,
                   metric_mac_dl_buffer,
                   metric_mac_dl_retx_count,
                   metric_mac_dl_retx_flag,
                   metric_mac_dl_aggr_level,
                   metric_mac_dl_alloc_count,
                   metric_expected_bitrate,
                   metric_dl_avg_rate,
                   metric_harq_retx_pending);
DECLARE_METRIC_LIST("ue_list", mlist_mac_ues, std::vector<mset_mac_ue_container>);
DECLARE_METRIC_SET("mac", mset_mac_container, metric_mac_jfi, metric_mac_num_ues, metric_scheduler_runtime_us, metric_avg_dl_prio, metric_max_dl_prio, metric_avg_ul_prio, metric_max_ul_prio, metric_prb_util, metric_nof_prb, mlist_mac_ues, metric_ranker_time_us, metric_allocation_time_us, metric_total_sched_time_us);
/// Cell container metrics.
DECLARE_METRIC("carrier_id", metric_carrier_id, uint32_t, "");
DECLARE_METRIC("pci", metric_pci, uint32_t, "");
DECLARE_METRIC("nof_rach", metric_nof_rach, uint32_t, "");
DECLARE_METRIC_LIST("ue_list", mlist_ues, std::vector<mset_ue_container>);
DECLARE_METRIC_SET("cell_container", mset_cell_container, metric_carrier_id, metric_pci, metric_nof_rach, mlist_ues);

/// Metrics root object.
DECLARE_METRIC("type", metric_type_tag, std::string, "");
DECLARE_METRIC("timestamp", metric_timestamp_tag, double, "");
DECLARE_METRIC_LIST("cell_list", mlist_cell, std::vector<mset_cell_container>);

/// Returns the current time in seconds with ms precision since UNIX epoch.
static double get_time_stamp()
{
  auto tp = std::chrono::system_clock::now().time_since_epoch();
  return std::chrono::duration_cast<std::chrono::milliseconds>(tp).count() * 1e-3;
}


/// Metrics context.
using metric_context_t = srslog::build_context_type<metric_type_tag, metric_timestamp_tag, mlist_cell, mset_mac_container>;

} // namespace

/// Fill the metrics for the i'th UE in the enb metrics struct.
static void fill_ue_metrics(mset_ue_container& ue, const enb_metrics_t& m, unsigned i)
{
  uint32_t rnti = m.stack.mac.ues[i].rnti;

  ue.write<metric_ue_rnti>(rnti);
  ue.write<metric_dl_cqi>(m.stack.mac.ues[i].dl_cqi);
  float dl_snr = m.stack.mac.ues[i].dl_cqi * 0.5f - 7.0f;
  ue.write<metric_dl_snr>(dl_snr);

  if (!std::isnan(m.phy[i].dl.mcs)) {
    ue.write<metric_dl_mcs>(m.phy[i].dl.mcs);
  }

  // --- DL BLER ---
  if (m.stack.mac.ues[i].tx_pkts > 0) {
    ue.write<metric_dl_bler>(
        (float)100 * m.stack.mac.ues[i].tx_errors / m.stack.mac.ues[i].tx_pkts);
  } else {
    ue.write<metric_dl_bler>(0.0f);
  }

  // --- UL RADIO ---
  if (!std::isnan(m.phy[i].ul.pusch_sinr)) {
    ue.write<metric_ul_snr>(m.phy[i].ul.pusch_sinr);
  }
  if (!std::isnan(m.phy[i].ul.pusch_rssi)) {
    ue.write<metric_ul_pusch_rssi>(m.phy[i].ul.pusch_rssi);
  }
  if (!std::isnan(m.phy[i].ul.pucch_rssi)) {
    ue.write<metric_ul_pucch_rssi>(m.phy[i].ul.pucch_rssi);
  }
  if (!std::isnan(m.phy[i].ul.pucch_ni)) {
    ue.write<metric_ul_pucch_ni>(m.phy[i].ul.pucch_ni);
  }

  ue.write<metric_ul_pusch_tpc>(m.phy[i].ul.pusch_tpc);
  ue.write<metric_ul_pucch_tpc>(m.phy[i].dl.pucch_tpc);

  if (!std::isnan(m.stack.mac.ues[i].dl_cqi_offset)) {
    ue.write<metric_dl_cqi_offset>(m.stack.mac.ues[i].dl_cqi_offset);
  }
  if (!std::isnan(m.stack.mac.ues[i].ul_snr_offset)) {
    ue.write<metric_ul_snr_offset>(m.stack.mac.ues[i].ul_snr_offset);
  }

  if (!std::isnan(m.phy[i].ul.mcs)) {
    ue.write<metric_ul_mcs>(m.phy[i].ul.mcs);
  }

  // --- UL BLER ---
  if (m.stack.mac.ues[i].rx_pkts > 0) {
    ue.write<metric_ul_bler>(
        (float)100 * m.stack.mac.ues[i].rx_errors / m.stack.mac.ues[i].rx_pkts);
  } else {
    ue.write<metric_ul_bler>(0.0f);
  }

  ue.write<metric_ul_phr>(m.stack.mac.ues[i].phr);
  ue.write<metric_bsr>(m.stack.mac.ues[i].ul_buffer);

  // =========================
  // 🚀 PDCP THROUGHPUT
  // =========================

  static std::unordered_map<uint32_t, uint64_t> prev_dl_bytes_map;
  static std::unordered_map<uint32_t, uint64_t> prev_ul_bytes_map;
  static std::unordered_map<uint32_t, double>   prev_time_map;

  uint64_t dl_bytes = 0;
  uint64_t ul_bytes = 0;

  const auto& pdcp_bearer = m.stack.pdcp.ues[i].bearer;

  for (const auto& drb : m.stack.rrc.ues[i].drb_qci_map) {
    if (drb.first >= SRSRAN_N_RADIO_BEARERS) {
      continue;
    }

    dl_bytes += pdcp_bearer[drb.first].num_tx_acked_bytes;
    ul_bytes += pdcp_bearer[drb.first].num_rx_pdu_bytes;
  }

  double now = get_time_stamp();
  double dt  = 1.0;

  if (prev_time_map.count(rnti)) {
    dt = now - prev_time_map[rnti];
  }

  if (dt <= 0.0) {
    dt = 1.0;
  }

  float dl_tput = 0.0f;
  float ul_tput = 0.0f;

  if (prev_dl_bytes_map.count(rnti) && dl_bytes >= prev_dl_bytes_map[rnti]) {
    dl_tput = (dl_bytes - prev_dl_bytes_map[rnti]) * 8 / dt;
  }

  if (prev_ul_bytes_map.count(rnti) && ul_bytes >= prev_ul_bytes_map[rnti]) {
    ul_tput = (ul_bytes - prev_ul_bytes_map[rnti]) * 8 / dt;
  }

  prev_dl_bytes_map[rnti] = dl_bytes;
  prev_ul_bytes_map[rnti] = ul_bytes;
  prev_time_map[rnti]     = now;

  ue.write<metric_dl_bitrate>(dl_tput);
  ue.write<metric_ul_bitrate>(ul_tput);

  // =========================
  // BEARERS
  // =========================

  auto& bearer_list = ue.get<mlist_bearers>();

  for (const auto& drb : m.stack.rrc.ues[i].drb_qci_map) {
    bearer_list.emplace_back();
    auto& bearer_container = bearer_list.back();

    bearer_container.write<metric_bearer_id>(drb.first);
    bearer_container.write<metric_qci>(drb.second);

    if (drb.first >= SRSRAN_N_RADIO_BEARERS) {
      continue;
    }

    const auto& rlc_bearer  = m.stack.rlc.ues[i].bearer;
    const auto& pdcp_bearer = m.stack.pdcp.ues[i].bearer;

    bearer_container.write<metric_dl_total_bytes>(pdcp_bearer[drb.first].num_tx_acked_bytes);
    bearer_container.write<metric_ul_total_bytes>(pdcp_bearer[drb.first].num_rx_pdu_bytes);

    bearer_container.write<metric_dl_latency>(
        pdcp_bearer[drb.first].tx_notification_latency_ms / 1e3);

    bearer_container.write<metric_ul_latency>(
        rlc_bearer[drb.first].rx_latency_ms / 1e3);

    bearer_container.write<metric_dl_buffered_bytes>(
        pdcp_bearer[drb.first].num_tx_buffered_pdus_bytes);

    bearer_container.write<metric_ul_buffered_bytes>(
        rlc_bearer[drb.first].rx_buffered_bytes);
  }
}

static void fill_mac_metrics(mset_mac_ue_container& ue, const mac_ue_metrics_t& mac_ue)
{
  ue.write<metric_mac_rnti>(mac_ue.rnti);
  ue.write<metric_dl_cqi>(mac_ue.dl_cqi);
  ue.write<metric_dl_mcs>(mac_ue.dl_mcs);
  float dl_snr = mac_ue.dl_cqi * 0.5f - 7.0f;
  ue.write<metric_dl_snr>(dl_snr);
  ue.write<metric_ul_mcs>(mac_ue.ul_mcs);
  ue.write<metric_mac_dl_prb>(mac_ue.dl_prb);
  ue.write<metric_mac_ul_prb>(mac_ue.ul_prb);
  ue.write<metric_mac_dl_prio>(mac_ue.dl_prio);
  ue.write<metric_mac_ul_prio>(mac_ue.ul_prio);
  ue.write<metric_mac_bsr>(mac_ue.bsr);
  ue.write<metric_mac_dl_throughput>(mac_ue.dl_throughput);
  ue.write<metric_mac_ul_throughput>(mac_ue.ul_throughput);
  ue.write<metric_mac_dl_latency>(mac_ue.dl_latency);
  ue.write<metric_mac_dl_bler>(mac_ue.dl_bler);
  ue.write<metric_mac_ul_bler>(mac_ue.ul_bler);
  ue.write<metric_mac_dl_buffer>(mac_ue.dl_buffer);
  ue.write<metric_mac_dl_retx_count>(mac_ue.dl_retx_count);
  ue.write<metric_mac_dl_retx_flag>(mac_ue.dl_retx_flag);
  ue.write<metric_mac_dl_aggr_level>(mac_ue.dl_aggr_level);
  ue.write<metric_mac_dl_alloc_count>(mac_ue.dl_alloc_count);
  ue.write<metric_expected_bitrate>(mac_ue.expected_bitrate);
  ue.write<metric_dl_avg_rate>(mac_ue.dl_avg_rate);
  ue.write<metric_harq_retx_pending>(mac_ue.harq_retx_pending);
}


/// Returns false if the input index is out of bounds in the metrics struct.
static bool has_valid_metric_ranges(const enb_metrics_t& m, unsigned index)
{
  if (index >= m.phy.size()) {
    return false;
  }
  if (index >= m.stack.mac.ues.size()) {
    return false;
  }
  if (index >= m.stack.rlc.ues.size()) {
    return false;
  }
  if (index >= m.stack.pdcp.ues.size()) {
    return false;
  }

  return true;
}

void metrics_json::set_metrics(const enb_metrics_t& m, const uint32_t period_usec)
{
  if (!enb) {
    return;
  }
  if (m.stack.mac.cc_info.empty()) {
    return;
  }

  metric_context_t ctx("JSON Metrics");

  // Fill root object.
  ctx.write<metric_type_tag>("metrics");
  auto& cell_list = ctx.get<mlist_cell>();
  cell_list.resize(m.stack.mac.cc_info.size());

  // For each cell...
  for (unsigned cc_idx = 0, e = cell_list.size(); cc_idx != e; ++cc_idx) {
    auto& cell = cell_list[cc_idx];
    cell.write<metric_carrier_id>(cc_idx);
    cell.write<metric_nof_rach>(m.stack.mac.cc_info[cc_idx].cc_rach_counter);
    cell.write<metric_pci>(m.stack.mac.cc_info[cc_idx].pci);

    // For each UE in this cell...
    for (unsigned i = 0; i != m.stack.rrc.ues.size(); ++i) {
      if (!has_valid_metric_ranges(m, i)) {
        continue;
      }

      // Only record UEs that belong to this cell.
      if (m.stack.mac.ues[i].cc_idx != cc_idx) {
        continue;
      }
      cell.get<mlist_ues>().emplace_back();
      fill_ue_metrics(cell.get<mlist_ues>().back(), m, i);
    }
  }

  auto& mac_container = ctx.get<mset_mac_container>();
  mac_container.write<metric_mac_jfi>(m.stack.mac.jfi);
  mac_container.write<metric_avg_dl_prio>(m.stack.mac.avg_dl_prio);
  mac_container.write<metric_max_dl_prio>(m.stack.mac.max_dl_prio);

  mac_container.write<metric_avg_ul_prio>(m.stack.mac.avg_ul_prio);
  mac_container.write<metric_max_ul_prio>(m.stack.mac.max_ul_prio);
  mac_container.write<metric_mac_num_ues>(m.stack.mac.num_ues);
  mac_container.write<metric_scheduler_runtime_us>(m.stack.mac.scheduler_runtime_us);
  mac_container.write<metric_prb_util>(m.stack.mac.prb_util);
  mac_container.write<metric_nof_prb>(m.stack.mac.nof_prb);
  mac_container.write<metric_ranker_time_us>(m.stack.mac.last_ranker_time_us);
  mac_container.write<metric_allocation_time_us>(m.stack.mac.last_allocation_time_us);
  mac_container.write<metric_total_sched_time_us>(m.stack.mac.last_total_sched_time_us);

  auto& mac_ue_list = mac_container.get<mlist_mac_ues>();
  mac_ue_list.resize(m.stack.mac.ues.size());
  for (unsigned i = 0; i != m.stack.mac.ues.size(); ++i) {
    fill_mac_metrics(mac_ue_list[i], m.stack.mac.ues[i]);
  }

  // Log the context.
  ctx.write<metric_timestamp_tag>(get_time_stamp());
  log_c(ctx);
}