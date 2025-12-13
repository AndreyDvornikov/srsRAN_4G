vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xbip_dsp48_wrapper_v3_0_6
vlib questa_lib/msim/xbip_utils_v3_0_14
vlib questa_lib/msim/xbip_pipe_v3_0_10
vlib questa_lib/msim/dsp_macro_v1_0_7
vlib questa_lib/msim/xil_defaultlib

vmap xbip_dsp48_wrapper_v3_0_6 questa_lib/msim/xbip_dsp48_wrapper_v3_0_6
vmap xbip_utils_v3_0_14 questa_lib/msim/xbip_utils_v3_0_14
vmap xbip_pipe_v3_0_10 questa_lib/msim/xbip_pipe_v3_0_10
vmap dsp_macro_v1_0_7 questa_lib/msim/dsp_macro_v1_0_7
vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vcom -work xbip_dsp48_wrapper_v3_0_6  -93  \
"../../../ipstatic/hdl/xbip_dsp48_wrapper_v3_0_vh_rfs.vhd" \

vcom -work xbip_utils_v3_0_14  -93  \
"../../../ipstatic/hdl/xbip_utils_v3_0_vh_rfs.vhd" \

vcom -work xbip_pipe_v3_0_10  -93  \
"../../../ipstatic/hdl/xbip_pipe_v3_0_vh_rfs.vhd" \

vcom -work dsp_macro_v1_0_7  -93  \
"../../../ipstatic/hdl/dsp_macro_v1_0_rfs.vhd" \

vcom -work xil_defaultlib  -93  \
"../../../../lte_phy_math_core.gen/sources_1/ip/dsp_xilinx_macro/sim/dsp_xilinx_macro.vhd" \


