#
# Copyright 2013-2023 Software Radio Systems Limited
#
# This file is part of srsRAN
#

# Force the compiler to include the path where we copied ONNX Runtime headers
include_directories(/usr/local/include)

set(SOURCES sched_base.cc sched_time_rr.cc sched_time_pf.cc
    onnx_ranker_engine.cc onnx_ranker_observation.cc sched_time_onnx_ranker.cc)

add_library(mac_schedulers OBJECT ${SOURCES})
