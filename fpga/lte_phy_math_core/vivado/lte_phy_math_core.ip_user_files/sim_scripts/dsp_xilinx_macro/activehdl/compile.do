transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xbip_dsp48_wrapper_v3_0_6
vlib activehdl/xbip_utils_v3_0_14
vlib activehdl/xbip_pipe_v3_0_10
vlib activehdl/dsp_macro_v1_0_7
vlib activehdl/xil_defaultlib

vmap xbip_dsp48_wrapper_v3_0_6 activehdl/xbip_dsp48_wrapper_v3_0_6
vmap xbip_utils_v3_0_14 activehdl/xbip_utils_v3_0_14
vmap xbip_pipe_v3_0_10 activehdl/xbip_pipe_v3_0_10
vmap dsp_macro_v1_0_7 activehdl/dsp_macro_v1_0_7
vmap xil_defaultlib activehdl/xil_defaultlib

vcom -work xbip_dsp48_wrapper_v3_0_6 -93  \
"../../../ipstatic/hdl/xbip_dsp48_wrapper_v3_0_vh_rfs.vhd" \

vcom -work xbip_utils_v3_0_14 -93  \
"../../../ipstatic/hdl/xbip_utils_v3_0_vh_rfs.vhd" \

vcom -work xbip_pipe_v3_0_10 -93  \
"../../../ipstatic/hdl/xbip_pipe_v3_0_vh_rfs.vhd" \

vcom -work dsp_macro_v1_0_7 -93  \
"../../../ipstatic/hdl/dsp_macro_v1_0_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../../lte_phy_math_core.gen/sources_1/ip/dsp_xilinx_macro/sim/dsp_xilinx_macro.vhd" \


