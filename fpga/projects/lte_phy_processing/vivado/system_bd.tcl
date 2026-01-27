# create project
# add source RTL
# create sim set [sim128 and sim128_inv]
# add auto source "view-results.tcl" script after sim
# (then i manual run command)

# это то, с чем я работаю
set ZEDBOARD_ZYNQ "xc7z020clg484-1"

set tcl_dir     [file dirname [file normalize [info script]]]
set repo_root   [file normalize [file join $tcl_dir ..]]

set LTE_PHY_MATH  [file normalize [file join $repo_root .. "lte_phy_math"]]

set required_vivado "2023.2"
set current_vivado  [version -short]
if {![string equal $current_vivado $required_vivado]} {
    puts "ERROR: Vivado version mismatch. Required: $required_vivado, current: $current_vivado"
    exit 1
} else {
    puts {INFO: [check version] OK}
}

# - самое главное, создать проект!!
create_project lte_phy_processing "$repo_root/vivado" -force -part $ZEDBOARD_ZYNQ

# он по умолчанию xsim - но чтобы знали, как это задать!
set_property target_simulator XSim [current_project]

set IP_PATH       [file join $repo_root "ip"]
set HDL_V_PATH    [file join $repo_root "hdl/verilog"]
set HDL_SV_PATH   [file join $repo_root "hdl/systemverilog"]
set HDL_INC_PATH  [file join $repo_root "hdl" "include"]


# добавляем файлы в проект
add_files -fileset sources_1 -norecurse [list                               \
    [file join $HDL_SV_PATH "system_lte.sv"]                                \
    [file join $HDL_SV_PATH "phy_symbol_detection.sv"]                      \
    [file join $HDL_SV_PATH "mem_sdpram_wrap.sv"]                           \
    [file join $LTE_PHY_MATH "hdl" "systemverilog" "math_complex_corr.sv"]  \
    [file join $LTE_PHY_MATH "hdl" "systemverilog" "math_mac_macro.sv"]     \
]
set_property include_dirs [list $HDL_V_PATH $HDL_SV_PATH] [get_filesets sources_1]

set ip_files [list                              \
    [file join $IP_PATH "mem_gen_256k32.xci"]   \
]

set ip_xci_list [import_ip -quiet -srcset sources_1 [file join $IP_PATH "mem_gen_256k32.xci"]]
set ip_xci      [lindex $ip_xci_list 0]

# Дальше работаем с объектом файла, а не со строковым путём
generate_target all -force $ip_xci
set ip_run [create_ip_run -force $ip_xci]
launch_runs $ip_run
wait_on_run $ip_run

# указываем top проекта
set_property top system_lte [get_filesets sources_1]

# пересчитать порядок компиляции
# чтобы выстроить цепочку зависимостей
update_compile_order -fileset sources_1

puts {INFO: [RTL] sources_1 filled OK}

set inc_dirs [list $HDL_V_PATH $HDL_SV_PATH $HDL_INC_PATH]
set_property include_dirs $inc_dirs [get_filesets sources_1]

# dirs
# PSD - phy symbol detection
set TB_PSD_DIR     [file join $repo_root "devl" "phy_symbol_detection"]
# EBMG - example blk mem gen
set TB_EBMG        [file join $repo_root "devl" "example_blk_mem_gen_0"]
#### full stack processing
####
####

if {[string equal [get_filesets -quiet sim_lte_system] ""]} {
    create_fileset -simset sim_lte_system
}

#### phy_symbol_detection
####
####

if {[string equal [get_filesets -quiet sim_phy_symbol_detection] ""]} {
    # s_set - simset
    set s_set sim_phy_symbol_detection
    create_fileset -simset $s_set

    add_files -fileset $s_set -norecurse [list                      \
        [file join $TB_PSD_DIR "testbench.sv"]                      \
        [file join $TB_PSD_DIR "input_signal.hex"]                  \
        [file join $TB_PSD_DIR "view-results.post.tcl"]             \
    ]

    set_property include_dirs $inc_dirs [get_filesets $s_set]
    set_property top testbench          [get_filesets $s_set]
    #set_property xsim.simulate.tcl.post $sim128_post_tcl [get_filesets sim128]

    update_compile_order -fileset $s_set
}

#### example_blk_mem_gen_0 aka mem_gen_256k32
####
####

if {[string equal [get_filesets -quiet example_blk_mem_gen_0] ""]} {
    # s_set - simset
    set s_set example_blk_mem_gen_0
    create_fileset -simset $s_set

    add_files -fileset $s_set -norecurse [list \
        [file join $TB_EBMG "testbench.sv"]
    ]

    set_property include_dirs $inc_dirs [get_filesets $s_set]
    set_property top testbench          [get_filesets $s_set]

    update_compile_order -fileset $s_set
}

# # per-set file lists
# set sim128_files [list \
#     [file join $SIM128_DIR "testbench_128.v"] \
#     [file join $SIM128_DIR "bel_avl_ram.v"] \
#     [file join $SIM128_DIR "input_data_128.dat"] \
# ]
# set sim128_post_tcl [file join $SIM128_DIR "view-results.post.tcl"]

# # по дефолту пусть будет активен sim128
# current_fileset -simset [ get_filesets sim128 ]

# set_property include_dirs [list $HDL_V_PATH $HDL_SV_PATH] [get_filesets sim128]
# add_files -fileset sim128 -norecurse $sim128_post_tcl

# # add sim sources
# add_files -fileset sim128     -norecurse $sim128_files

# # set simulation top (testbench module name)
# set_property top testbench_128      [get_filesets sim128]

# # run view-results after simulation finishes
# set_property xsim.simulate.tcl.post $sim128_post_tcl [get_filesets sim128]

# # compile order for sim filesets
# update_compile_order -fileset sim128