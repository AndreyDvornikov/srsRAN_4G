#ifndef SRSRAN_ENB_METRICS_INTERFACE_H
#define SRSRAN_ENB_METRICS_INTERFACE_H

#include <stdint.h>
#include <vector>

#include "srsenb/hdr/common/common_enb.h"
#include "srsenb/hdr/phy/phy_metrics.h"
#include "srsenb/hdr/stack/rrc/rrc_metrics.h"
#include "srsenb/hdr/stack/s1ap/s1ap_metrics.h"
#include "srsran/common/metrics_hub.h"
#include "srsran/radio/radio_metrics.h"
#include "srsran/rlc/rlc_metrics.h"
#include "srsran/system/sys_metrics.h"
#include "srsran/upper/pdcp_metrics.h"
#include "srsue/hdr/stack/upper/gw_metrics.h"

namespace srsenb {

struct cc_info_t {
    uint32_t cc_rach_counter = 0;
    uint32_t pci             = 0;
};

struct mac_ue_metrics_t {
    uint32_t rnti               = 0;
    float    dl_cqi             = 0.0f;
    float    dl_mcs             = 0.0f;
    float    ul_mcs             = 0.0f;
    uint32_t dl_prb             = 0;
    uint32_t ul_prb             = 0;
    uint32_t bsr                = 0;
    float    dl_throughput      = 0.0f;
    float    ul_throughput      = 0.0f;
    float    dl_latency         = 0.0f;
    float    dl_bler            = 0.0f;
    float    ul_bler            = 0.0f;
    uint32_t dl_buffer          = 0;
    uint32_t dl_retx_count      = 0;
    bool     dl_retx_flag       = false;
    uint32_t dl_aggr_level      = 0;
    uint32_t dl_alloc_count     = 0;
    float    expected_bitrate   = 0.0f;
    float    dl_avg_rate        = 0.0f;
    bool     harq_retx_pending  = false;
    float    dl_cqi_offset      = 0.0f;
    float    ul_snr_offset      = 0.0f;
    float    dl_snr = 0.0f;
    uint32_t tx_pkts            = 0;
    uint32_t tx_errors          = 0;
    uint32_t rx_pkts            = 0;
    uint32_t rx_errors          = 0;
    float    phr                = 0.0f;
    uint32_t ul_buffer          = 0;
    uint32_t cc_idx             = 0;
    uint32_t nof_tti            = 0;  
    uint32_t pci                = 0;
    float    dl_ri              = 0.0f;
    float    dl_pmi             = 0.0f;
    int      rx_brate           = 0;   
    int      tx_brate           = 0;
    uint32_t dl_mcs_samples = 0;
    uint32_t ul_mcs_samples = 0;
    float pusch_sinr = 0.0f;
    float pucch_sinr = 0.0f;
    float ul_rssi = 0.0f;
    float dl_prio = 0.0f;
    float ul_prio = 0.0f;
    uint32_t qci = 0;
    bool     is_gbr_bearer = false;
    float    gbr_required_bps = 0.0f;
    float    gbr_achieved_ratio = 0.0f;
    uint32_t pdb_limit_ms = 0;
    uint32_t pdb_total_packets = 0;
    uint32_t pdb_violated_packets = 0;
    float    pdb_compliance_rate = 0.0f;
    uint32_t pdcp_discarded_pdus = 0;
    uint64_t pdcp_discarded_bytes = 0;

    bool     onnx_candidate = false;
    uint32_t onnx_active_ue_count = 0;
    uint32_t onnx_slot = 0;
    uint32_t onnx_rank = 0;
    float    onnx_score = 0.0f;
    bool     onnx_is_retx = false;
    bool     onnx_allocated = false;
    uint32_t onnx_alloc_bytes = 0;
    uint32_t onnx_alloc_prbs = 0;
    uint32_t onnx_alloc_mcs = 0;
    bool     onnx_alloc_is_retx = false;
    float    onnx_raw_cqi = 0.0f;
    float    onnx_raw_cqi_age_tti = 0.0f;
    float    onnx_raw_buffer_bytes = 0.0f;
    float    onnx_raw_avg_tput_bps = 0.0f;
    float    onnx_raw_dl_gap_tti = 0.0f;
    float    onnx_norm_cqi = 0.0f;
    float    onnx_norm_cqi_age = 0.0f;
    float    onnx_norm_buffer = 0.0f;
    float    onnx_norm_avg_tput = 0.0f;
    float    onnx_norm_dl_gap = 0.0f;
    
};

struct mac_metrics_t {
    std::vector<mac_ue_metrics_t> ues;
    float                         jfi                  = 0.0f;
    float                         avg_dl_prio          = 0.0f;
    float                         max_dl_prio          = 0.0f;

    float                         avg_ul_prio          = 0.0f;
    float                         max_ul_prio          = 0.0f;
    uint32_t                      num_ues              = 0;
    uint64_t                      scheduler_runtime_us = 0;
    float                         prb_util             = 0.0f;
    uint32_t                      nof_prb              = 0;
    std::vector<cc_info_t>        cc_info;
    uint64_t last_ranker_time_us;
    uint64_t last_allocation_time_us;
    uint64_t last_total_sched_time_us;
    float    avg_gbr_achievement = 0.0f;
    uint32_t ues_below_gbr = 0;
    float    max_pdb_violation_rate = 0.0f;
    uint32_t ues_pdb_violation = 0;
    uint64_t total_pdcp_discards = 0;
};

struct rlc_metrics_t {
    std::vector<srsran::rlc_metrics_t> ues;
};

struct pdcp_metrics_t {
    std::vector<srsran::pdcp_metrics_t> ues;
};

struct stack_metrics_t {
    mac_metrics_t  mac;
    rrc_metrics_t  rrc;
    rlc_metrics_t  rlc;
    pdcp_metrics_t pdcp;
    s1ap_metrics_t s1ap;
};

struct enb_metrics_t {
    srsran::rf_metrics_t       rf;
    std::vector<phy_metrics_t> phy;
    stack_metrics_t            stack;
    stack_metrics_t            nr_stack;
    srsran::sys_metrics_t      sys;
    bool                       running;
};

class enb_metrics_interface : public srsran::metrics_interface<enb_metrics_t>
{
public:
    virtual bool get_metrics(enb_metrics_t* m) = 0;
};

} // namespace srsenb

#endif
