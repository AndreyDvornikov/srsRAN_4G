vlib questa_lib/work
vlib questa_lib/msim

vlib questa_lib/msim/xpm
vlib questa_lib/msim/xil_defaultlib

vmap xpm questa_lib/msim/xpm
vmap xil_defaultlib questa_lib/msim/xil_defaultlib

vlog -work xpm  -incr -mfcu  -sv "+incdir+../../../ipstatic" \
"C:/WorkPrograms/Engineering/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \

vcom -work xpm  -93  \
"C:/WorkPrograms/Engineering/Xilinx/Vivado/2024.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../ipstatic" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_mmcm_pll_drp.v" \

vcom -work xil_defaultlib  -93  \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/proc_common_v3_00_a/hdl/src/vhdl/clk_wiz_0_conv_funs_pkg.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/proc_common_v3_00_a/hdl/src/vhdl/clk_wiz_0_proc_common_pkg.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/proc_common_v3_00_a/hdl/src/vhdl/clk_wiz_0_ipif_pkg.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/proc_common_v3_00_a/hdl/src/vhdl/clk_wiz_0_family_support.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/proc_common_v3_00_a/hdl/src/vhdl/clk_wiz_0_family.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/proc_common_v3_00_a/hdl/src/vhdl/clk_wiz_0_soft_reset.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/proc_common_v3_00_a/hdl/src/vhdl/clk_wiz_0_pselect_f.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/axi_lite_ipif_v1_01_a/hdl/src/vhdl/clk_wiz_0_address_decoder.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/axi_lite_ipif_v1_01_a/hdl/src/vhdl/clk_wiz_0_slave_attachment.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/axi_lite_ipif_v1_01_a/hdl/src/vhdl/clk_wiz_0_axi_lite_ipif.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_clk_wiz_drp.vhd" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_axi_clk_config.vhd" \

vlog -work xil_defaultlib  -incr -mfcu  "+incdir+../../../ipstatic" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/clk_wiz_0_clk_wiz.v" \
"../../../../lte_phy_math_core.gen/sources_1/ip/clk_wiz_0/clk_wiz_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

