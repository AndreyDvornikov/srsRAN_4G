transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib riviera/xbip_dsp48_wrapper_v3_0_6
vlib riviera/xbip_utils_v3_0_14
vlib riviera/xbip_pipe_v3_0_10
vlib riviera/dsp_macro_v1_0_7
vlib riviera/xil_defaultlib

vmap xbip_dsp48_wrapper_v3_0_6 riviera/xbip_dsp48_wrapper_v3_0_6
vmap xbip_utils_v3_0_14 riviera/xbip_utils_v3_0_14
vmap xbip_pipe_v3_0_10 riviera/xbip_pipe_v3_0_10
vmap dsp_macro_v1_0_7 riviera/dsp_macro_v1_0_7
vmap xil_defaultlib riviera/xil_defaultlib

vcom -work xbip_dsp48_wrapper_v3_0_6 -93  -incr \
"../../../ipstatic/hdl/xbip_dsp48_wrapper_v3_0_vh_rfs.vhd" \

vcom -work xbip_utils_v3_0_14 -93  -incr \
"../../../ipstatic/hdl/xbip_utils_v3_0_vh_rfs.vhd" \

vcom -work xbip_pipe_v3_0_10 -93  -incr \
"../../../ipstatic/hdl/xbip_pipe_v3_0_vh_rfs.vhd" \

vcom -work dsp_macro_v1_0_7 -93  -incr \
"../../../ipstatic/hdl/dsp_macro_v1_0_rfs.vhd" \

vcom -work xil_defaultlib -93  -incr \
"../../../../lte_phy_math_core.gen/sources_1/ip/dsp_xilinx_macro/sim/dsp_xilinx_macro.vhd" \


