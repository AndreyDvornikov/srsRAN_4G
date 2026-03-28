# -----------------------------------------------------------------------------
# create project
# add source RTL
# create sim sets when DO_PACKAGE == 0
# package custom IP when DO_PACKAGE == 1
# -----------------------------------------------------------------------------

# 1 - запаковываем в ip
# 0 - не запаковываем в ip
set DO_PACKAGE 0

# это то, с чем я работаю
set ZEDBOARD_ZYNQ "xc7z020clg484-1"

set tcl_dir   [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $tcl_dir ..]]

set LTE_PHY_MATH [file normalize [file join $repo_root .. "lte_phy_math"]]
set LTE_PHY_FFT  [file normalize [file join $repo_root .. "lte_phy_fft"]]

set required_vivado "2023.2"
set current_vivado  [version -short]
if {![string equal $current_vivado $required_vivado]} {
    puts "ERROR: Vivado version mismatch. Required: $required_vivado, current: $current_vivado"
    exit 1
} else {
    puts {INFO: [check version] OK}
}

puts "INFO: repo_root    = $repo_root"
puts "INFO: LTE_PHY_MATH = $LTE_PHY_MATH"
puts "INFO: LTE_PHY_FFT  = $LTE_PHY_FFT"

set IP_PKG_ROOT [file normalize [file join $repo_root "ip_pkg"]]
set IP_NAME     "lte_phy_processing"
set IP_PKG_DIR  [file join $IP_PKG_ROOT $IP_NAME]

# -----------------------------------------------------------------------------
# helper procs
# -----------------------------------------------------------------------------

proc require_file_exists {path} {
    if {![file exists $path]} {
        error "ERROR: required file not found: $path"
    }
}

proc mark_header_as_global_include {hdr_path} {
    set hdr_obj [get_files -quiet [file normalize $hdr_path]]
    if {[llength $hdr_obj] > 0} {
        set_property file_type {Verilog Header} $hdr_obj
        set_property is_global_include true      $hdr_obj
        puts "INFO: global include set for $hdr_path"
    } else {
        error "ERROR: header file was not added to project: $hdr_path"
    }
}

proc report_project_coe_refs {} {
    puts "INFO: COE refs currently visible in project:"
    foreach f [lsort -unique [get_files -quiet *]] {
        set fn [file normalize $f]
        if {[string equal -nocase [file extension $fn] ".coe"]} {
            puts "  $fn"
        }
    }
}

proc purge_stale_coe_refs {repo_root} {
    set good_dir [string tolower [file normalize [file join $repo_root "coe"]]]

    foreach f [lsort -unique [get_files -quiet *]] {
        set fn [file normalize $f]

        if {![string equal -nocase [file extension $fn] ".coe"]} {
            continue
        }

        set fn_l [string tolower $fn]

        # Оставляем только coe внутри repo_root/coe
        if {[string first "${good_dir}/" $fn_l] != 0} {
            puts "INFO: removing stale COE reference $fn"
            catch {remove_files $f}
        }
    }
}

proc add_clean_coe_files {srcset repo_root} {
    set clean_coe_list [list \
        [file join $repo_root "coe" "pss_0_td_128.coe"] \
        [file join $repo_root "coe" "pss_0_td_256.coe"] \
        [file join $repo_root "coe" "pss_1_td_128.coe"] \
        [file join $repo_root "coe" "pss_1_td_256.coe"] \
        [file join $repo_root "coe" "pss_2_td_128.coe"] \
        [file join $repo_root "coe" "pss_2_td_256.coe"] \
    ]

    foreach f $clean_coe_list {
        require_file_exists $f
        if {[llength [get_files -quiet [file normalize $f]]] == 0} {
            puts "INFO: adding clean COE $f"
            add_files -fileset $srcset -norecurse $f
        }
    }
}

proc maybe_fix_coe_path_for_ip {ip_name repo_root} {
    array set coe_map {
        pss_0_rom_td_128sps pss_0_td_128.coe
        pss_0_rom_td_256sps pss_0_td_256.coe
        pss_1_rom_td_128sps pss_1_td_128.coe
        pss_1_rom_td_256sps pss_1_td_256.coe
        pss_2_rom_td_128sps pss_2_td_128.coe
        pss_2_rom_td_256sps pss_2_td_256.coe
    }

    if {[info exists coe_map($ip_name)]} {
        set coe_path [file normalize [file join $repo_root "coe" $coe_map($ip_name)]]
        require_file_exists $coe_path

        set ip_obj [get_ips -quiet $ip_name]
        if {[llength $ip_obj] == 0} {
            error "ERROR: IP object not found for $ip_name"
        }

        puts "INFO: setting $ip_name CONFIG.Coe_File = $coe_path"
        set_property -dict [list CONFIG.Coe_File $coe_path] $ip_obj

        catch {set_property -dict [list CONFIG.Load_Init_File true] $ip_obj}
    }
}

proc import_and_build_ip_list {srcset ip_dir ip_names jobs repo_root} {
    set imported_ip_files [list]
    set ip_runs           [list]

    foreach ip_name $ip_names {
        set xci_path [file join $ip_dir $ip_name]
        require_file_exists $xci_path

        puts "INFO: IP import $xci_path"
        set ip_xci_list [import_ip -quiet -srcset $srcset $xci_path]

        if {[llength $ip_xci_list] == 0} {
            error "ERROR: import_ip returned empty list for: $xci_path"
        }

        set ip_xci [lindex $ip_xci_list 0]
        lappend imported_ip_files $ip_xci

        set ip_base [file rootname [file tail $xci_path]]

        # Исправить путь к COE, если это один из PSS ROM IP
        maybe_fix_coe_path_for_ip $ip_base $repo_root

        # Перегенерировать target-файлы уже после фикса путей
        generate_target all -force $ip_xci

        # Синхронизировать collateral user files
        catch {export_ip_user_files -of_objects $ip_xci -no_script -sync -force}

        # Создать OOC run для IP
        set ip_run [create_ip_run -force $ip_xci]
        if {$ip_run eq ""} {
            error "ERROR: create_ip_run failed for: $xci_path"
        }

        lappend ip_runs $ip_run
    }

    if {[llength $ip_runs] > 0} {
        puts "INFO: IP launching [llength $ip_runs] IP runs with -jobs $jobs"
        launch_runs -jobs $jobs {*}$ip_runs
        wait_on_runs {*}$ip_runs
        puts "INFO: IP all IP runs completed"
    }

    return $imported_ip_files
}

# -----------------------------------------------------------------------------
# project creation
# -----------------------------------------------------------------------------

create_project lte_phy_processing "$repo_root/vivado" -force -part $ZEDBOARD_ZYNQ
set_property target_simulator XSim [current_project]

set IP_PATH       [file join $repo_root "ip"]
set HDL_V_PATH    [file join $repo_root "hdl/verilog"]
set HDL_SV_PATH   [file join $repo_root "hdl/systemverilog"]
set HDL_INC_PATH  [file join $repo_root "hdl/include"]
set MATH_INC_PATH [file join $LTE_PHY_MATH "hdl/include"]

# sanity checks
require_file_exists [file join $repo_root "coe" "pss_0_td_128.coe"]
require_file_exists [file join $repo_root "coe" "pss_0_td_256.coe"]
require_file_exists [file join $repo_root "coe" "pss_1_td_128.coe"]
require_file_exists [file join $repo_root "coe" "pss_1_td_256.coe"]
require_file_exists [file join $repo_root "coe" "pss_2_td_128.coe"]
require_file_exists [file join $repo_root "coe" "pss_2_td_256.coe"]

require_file_exists [file join $HDL_INC_PATH "lte_hw_params.vh"]
require_file_exists [file join $HDL_SV_PATH  "lte_phy_sync.sv"]
require_file_exists [file join $HDL_SV_PATH  "system_lte.sv"]
require_file_exists [file join $HDL_V_PATH   "system_lte_bd.v"]

# -----------------------------------------------------------------------------
# sources_1
# -----------------------------------------------------------------------------

set inc_dirs [list \
    $HDL_V_PATH \
    $HDL_SV_PATH \
    $HDL_INC_PATH \
    $MATH_INC_PATH \
]

# ВАЖНО:
# COE здесь специально НЕ добавляем сразу.
# Сначала импортируем XCI, потом чистим мусорные COE refs, потом возвращаем только чистые.
add_files -fileset sources_1 -norecurse [list                               \
    [file join $HDL_INC_PATH "lte_hw_params.vh"]                            \
    [file join $HDL_SV_PATH "lte_phy_sync.sv"]                              \
    [file join $HDL_SV_PATH "system_lte.sv"]                                \
    [file join $HDL_V_PATH  "system_lte_bd.v"]                              \
    [file join $HDL_SV_PATH "mem_sdpram_wrap.sv"]                           \
    [file join $LTE_PHY_MATH "hdl" "systemverilog" "math_complex_corr.sv"]  \
    [file join $LTE_PHY_MATH "hdl" "systemverilog" "math_mac_macro.sv"]     \
    [file join $LTE_PHY_MATH "hdl" "include" "lte_phy_math.vh"]             \
]

set_property include_dirs $inc_dirs [get_filesets sources_1]

mark_header_as_global_include [file join $HDL_INC_PATH "lte_hw_params.vh"]
mark_header_as_global_include [file join $LTE_PHY_MATH "hdl" "include" "lte_phy_math.vh"]

# -----------------------------------------------------------------------------
# import prebuilt XCI and rebuild them
# -----------------------------------------------------------------------------

set IP_BUILD_JOBS 8

set PREBUILT_IP_XCI [list \
    "mem_gen_256k32.xci"       \
    "mem_gen_512k32.xci"       \
    "pss_0_rom_td_128sps.xci"  \
    "pss_0_rom_td_256sps.xci"  \
    "pss_1_rom_td_128sps.xci"  \
    "pss_1_rom_td_256sps.xci"  \
    "pss_2_rom_td_128sps.xci"  \
    "pss_2_rom_td_256sps.xci"  \
]

set imported_ip_files [import_and_build_ip_list sources_1 $IP_PATH $PREBUILT_IP_XCI $IP_BUILD_JOBS $repo_root]

puts "INFO: COE refs before purge"
report_project_coe_refs

purge_stale_coe_refs $repo_root
add_clean_coe_files sources_1 $repo_root

puts "INFO: COE refs after purge/re-add"
report_project_coe_refs

# -----------------------------------------------------------------------------
# top / compile order
# -----------------------------------------------------------------------------

set_property top system_lte_bd [get_filesets sources_1]
update_compile_order -fileset sources_1

puts {INFO: [RTL] sources_1 filled OK}

# -----------------------------------------------------------------------------
# simulation filesets (only when not packaging)
# -----------------------------------------------------------------------------

set TB_EBMG  [file join $repo_root "devl" "example_blk_mem_gen_0"]
set TB_LPPMT [file join $repo_root "devl" "lte_phy_pss_mem_test"]
set TB_LPS   [file join $repo_root "devl" "lte_phy_sync"]

if {!$DO_PACKAGE} {

    if {[string equal [get_filesets -quiet sim_lte_system] ""]} {
        create_fileset -simset sim_lte_system
    }

    # -------------------------------------------------------------------------
    # example_blk_mem_gen_0
    # -------------------------------------------------------------------------
    if {[string equal [get_filesets -quiet example_blk_mem_gen_0] ""]} {
        set s_set example_blk_mem_gen_0
        create_fileset -simset $s_set

        add_files -fileset $s_set -norecurse [list \
            [file join $TB_EBMG "testbench.sv"] \
        ]

        set_property include_dirs $inc_dirs [get_filesets $s_set]
        set_property top testbench          [get_filesets $s_set]

        update_compile_order -fileset $s_set
    }

    # -------------------------------------------------------------------------
    # lte_phy_pss_mem_test
    # -------------------------------------------------------------------------
    if {[string equal [get_filesets -quiet lte_phy_pss_mem_test] ""]} {
        set s_set lte_phy_pss_mem_test
        create_fileset -simset $s_set

        add_files -fileset $s_set -norecurse [list \
            [file join $TB_LPPMT "testbench.sv"]         \
            [file join $TB_LPPMT "testbench_behav.wcfg"] \
        ]

        set_property xsim.view    [file join $TB_LPPMT "testbench_behav.wcfg"] [get_filesets $s_set]
        set_property include_dirs $inc_dirs                                    [get_filesets $s_set]
        set_property top testbench                                             [get_filesets $s_set]

        update_compile_order -fileset $s_set
    }

    # -------------------------------------------------------------------------
    # lte_phy_sync
    # -------------------------------------------------------------------------
    if {[string equal [get_filesets -quiet lte_phy_sync] ""]} {
        set s_set lte_phy_sync
        create_fileset -simset $s_set

        add_files -fileset $s_set -norecurse [list \
            [file join $TB_LPS "testbench.sv"]          \
            [file join $TB_LPS "testbench_behav.wcfg"]  \
            [file join $TB_LPS "input_signal.hex"]      \
            [file join $TB_LPS "input_awgn.hex"]        \
        ]

        set_property xsim.view    [file join $TB_LPS "testbench_behav.wcfg"] [get_filesets $s_set]
        set_property include_dirs $inc_dirs                                  [get_filesets $s_set]
        set_property top testbench                                           [get_filesets $s_set]

        update_compile_order -fileset $s_set
    }
}

# -----------------------------------------------------------------------------
# package project into custom IP
# -----------------------------------------------------------------------------

if {$DO_PACKAGE} {

    if {[file exists $IP_PKG_DIR]} {
        file delete -force $IP_PKG_DIR
    }
    file mkdir $IP_PKG_DIR

    ipx::package_project                        \
        -root_dir    $IP_PKG_DIR                \
        -vendor      aes-technology.ru          \
        -library     user                       \
        -taxonomy    /UserIP                    \
        -import_files                           \
        -set_current true

    set core [ipx::current_core]

    set_property name         $IP_NAME                 $core
    set_property display_name "LTE PHY Processing"    $core
    set_property description  "LTE PHY processing IP" $core
    set_property version      "1.2"                   $core

    ipx::update_checksums $core
    ipx::save_core        $core

    puts "INFO: IP packaged into: $IP_PKG_DIR"
}