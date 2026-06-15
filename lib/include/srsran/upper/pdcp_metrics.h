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

#ifndef SRSRAN_PDCP_METRICS_H
#define SRSRAN_PDCP_METRICS_H

#include "srsran/common/common.h"
#include <iostream>

namespace srsran {

typedef struct {
  // PDU metrics
  uint32_t num_tx_pdus = 0;
  uint32_t num_rx_pdus = 0;
  uint64_t num_tx_pdu_bytes = 0;
  uint64_t num_rx_pdu_bytes = 0;

  // ACK specific metrics
  uint64_t num_tx_acked_bytes = 0;
  uint64_t tx_notification_latency_ms = 0;
  uint32_t num_tx_buffered_pdus = 0;
  uint32_t num_tx_buffered_pdus_bytes = 0;

  // Discard metrics
  uint32_t num_tx_discarded_pdus  = 0;
  uint64_t num_tx_discarded_bytes = 0;
  
  // === QoS: QCI ===
  uint32_t qci = 0;   // ← ДОБАВИТЬ
} pdcp_bearer_metrics_t;

typedef struct {
  pdcp_bearer_metrics_t bearer[SRSRAN_N_RADIO_BEARERS];
} pdcp_metrics_t;

} // namespace srsran

#endif // SRSRAN_PDCP_METRICS_H