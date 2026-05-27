#
# Copyright 2013-2023 Software Radio Systems Limited
#
# This file is part of srsRAN
#
# srsRAN is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# srsRAN is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# A copy of the GNU Affero General Public License can be found in
# the LICENSE file in the top-level directory of this distribution
# and at http://www.gnu.org/licenses/.
#

find_package(LibConfig REQUIRED)
find_package(SCTP REQUIRED)

if(BUILD_STATIC)
  set(LIBCONFIGPP_LIBRARIES "${LIBCONFIGPP_STATIC_LIBRARY_PATH}")
endif(BUILD_STATIC)

if(NOT Boost_FOUND)
    message(FATAL_ERROR "Boost required to compile srsENB")
endif()

include_directories(
    ${Boost_INCLUDE_DIRS}
    ${SEC_INCLUDE_DIRS}
    ${PROJECT_SOURCE_DIR}
)

link_directories(
    ${Boost_LIBRARY_DIRS}
    ${SEC_LIBRARY_DIRS}
)

# Автоматический поиск ONNX Runtime (только поиск)
find_path(ONNXRUNTIME_INCLUDE_DIR onnxruntime_cxx_api.h
    HINTS $ENV{ONNXRUNTIME_DIR}/include
          /usr/local/include/onnxruntime
          /usr/local/include
          /usr/include/onnxruntime
          /usr/include
    PATH_SUFFIXES onnxruntime core/session
)

find_library(ONNXRUNTIME_LIBRARY onnxruntime
    HINTS $ENV{ONNXRUNTIME_DIR}/lib
          /usr/local/lib
          /usr/lib
)

if(ONNXRUNTIME_INCLUDE_DIR AND ONNXRUNTIME_LIBRARY)
    message(STATUS "ONNX Runtime найден: ${ONNXRUNTIME_LIBRARY}, includes: ${ONNXRUNTIME_INCLUDE_DIR}")
    include_directories(${ONNXRUNTIME_INCLUDE_DIR})
else()
    message(WARNING "ONNX Runtime не найден – сборка srsenb будет без onnx")
    set(ONNXRUNTIME_LIBRARY "")   # обнуляем, чтобы не помешало
endif()

add_subdirectory(src)
add_subdirectory(test)

install(FILES enb.conf.example DESTINATION ${DATA_DIR})
install(FILES rb.conf.example  DESTINATION ${DATA_DIR})
install(FILES rr.conf.example  DESTINATION ${DATA_DIR})
install(FILES sib.conf.example DESTINATION ${DATA_DIR})

# ====== Оригинальные определения, которые вы удалили ======

set(SRSENB_SOURCES srsenb_phy srsenb_stack srsenb_common srsenb_s1ap srsenb_upper srsenb_mac srsenb_rrc srslog system)
set(SRSRAN_SOURCES srsran_common srsran_mac srsran_phy srsran_gtpu srsran_rlc srsran_pdcp srsran_radio rrc_asn1 s1ap_asn1 enb_cfg_parser srslog support system)

set(SRSENB_SOURCES ${SRSENB_SOURCES} srsgnb_stack srsgnb_ric srsgnb_ngap srsgnb_mac srsgnb_rrc)
set(SRSRAN_SOURCES ${SRSRAN_SOURCES} rrc_nr_asn1 ngap_nr_asn1 ric_e2)
# ========================================================