# create project
# add source RTL
# create sim set [sim128 and sim128_inv]
# add auto source "view-results.tcl" script after sim
# (then i manual run command)

# это то, с чем я работаю
set ZEDBOARD_ZYNQ "xc7z020clg484-1"

set tcl_dir     [file dirname [file normalize [info script]]]
set repo_root   [file normalize [file join $tcl_dir ..]]

set required_vivado "2023.2"
set current_vivado  [version -short]
if {![string equal $current_vivado $required_vivado]} {
    puts "ERROR: Vivado version mismatch. Required: $required_vivado, current: $current_vivado"
    exit 1
} else {
    puts {INFO: [check version] OK}
}

create_project lte_phy_fft "$repo_root/vivado" -force -part $ZEDBOARD_ZYNQ

# он по умолчанию xsim - но чтобы знали, как это задать!
set_property target_simulator XSim [current_project]

set HDL_V_PATH    [file join $repo_root "hdl/verilog"]
set HDL_SV_PATH   [file join $repo_root "hdl/systemverilog"]

set rtl_files [list                                         \
    [file join $HDL_SV_PATH "phy_fft_control.sv"]           \
    [file join $HDL_SV_PATH "system_lte_phy_fft.sv"]        \
    [file join $HDL_V_PATH "bel_butterfly2.v"]              \
    [file join $HDL_V_PATH "bel_butterfly4.v"]              \
    [file join $HDL_V_PATH "bel_cadd.v"]                    \
    [file join $HDL_V_PATH "bel_caddsub.v"]                 \
    [file join $HDL_V_PATH "bel_cdiv2.v"]                   \
    [file join $HDL_V_PATH "bel_cdiv4.v"]                   \
    [file join $HDL_V_PATH "bel_cmac.v"]                    \
    [file join $HDL_V_PATH "bel_cmul.v"]                    \
    [file join $HDL_V_PATH "bel_copy.v"]                    \
    [file join $HDL_V_PATH "bel_csub.v"]                    \
    [file join $HDL_V_PATH "bel_fft_avl_mif_16.v"]          \
    [file join $HDL_V_PATH "bel_fft_avl_sif.v"]             \
    [file join $HDL_V_PATH "bel_fft_avl.v"]                 \
    [file join $HDL_V_PATH "bel_fft_core.v"]                \
    [file join $HDL_V_PATH "bel_fft_def.v"]                 \
    [file join $HDL_V_PATH "lte_phy_fft_twiddle_rom0.v"]    \
    [file join $HDL_V_PATH "lte_phy_fft_twiddle_roms.v"]    \
    [file join $HDL_V_PATH "lte_phy_fft.v"]                 \
]

# add into sources_1
add_files -fileset sources_1 -norecurse $rtl_files

# ну нас тот же axi_def.v и fft_def.v
# include dirs (на случай `include и т.п.)
set_property include_dirs [list $HDL_V_PATH $HDL_SV_PATH] [get_filesets sources_1]

# указываем top проекта
set_property top system_lte_phy_fft [get_filesets sources_1]

# пересчитать порядок компиляции
# чтобы выстроить цепочку зависимостей
update_compile_order -fileset sources_1

puts {INFO: [RTL] sources_1 filled OK}

# dirs
set SIM128_DIR     [file join $repo_root "devl/simulation_128"]

# per-set file lists
set sim128_files [list \
    [file join $SIM128_DIR "testbench_128.v"] \
    [file join $SIM128_DIR "bel_avl_ram.v"] \
    [file join $SIM128_DIR "input_data_128.dat"] \
]
set sim128_post_tcl [file join $SIM128_DIR "view-results.post.tcl"]

if {[string equal [get_filesets -quiet sim128] ""]} {
    create_fileset -simset sim128
}

# по дефолту пусть будет активен sim128
current_fileset -simset [ get_filesets sim128 ]

set_property include_dirs [list $HDL_V_PATH $HDL_SV_PATH] [get_filesets sim128]
add_files -fileset sim128 -norecurse $sim128_post_tcl

# add sim sources
add_files -fileset sim128     -norecurse $sim128_files

# set simulation top (testbench module name)
set_property top testbench_128      [get_filesets sim128]

# run view-results after simulation finishes
set_property xsim.simulate.tcl.post $sim128_post_tcl [get_filesets sim128]

# compile order for sim filesets
update_compile_order -fileset sim128