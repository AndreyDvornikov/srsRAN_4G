# vivado/system_bd.tcl
# Usage:
#   vivado -mode batch -source vivado/system_bd.tcl
# or:
#   vivado -mode tcl -source vivado/system_bd.tcl

set ZEDBOARD_ZYNQ "xc7z020clg484-1"

set tcl_dir    [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $tcl_dir ..]]

set required_vivado "2023.2"
set current_vivado  [version -short]
if {![string equal $current_vivado $required_vivado]} {
    puts "ERROR: Vivado version mismatch. Required: $required_vivado, current: $current_vivado"
    exit 1
} else {
    puts "INFO: Vivado version OK: $current_vivado"
}

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
set PRJ_NAME    "lte_phy_math"
set PRJ_DIR     [file join $repo_root "vivado"]

set RTL_SV_DIR  [file join $repo_root "hdl" "systemverilog"]
set INC_DIR     [file join $repo_root "hdl" "include"]
set DEVL_DIR    [file join $repo_root "devl"]

# If you later add XCI here:
set IP_DIR      [file join $repo_root "ip"]

# -----------------------------------------------------------------------------
# Create project
# -----------------------------------------------------------------------------
create_project $PRJ_NAME $PRJ_DIR -force -part $ZEDBOARD_ZYNQ
set_property target_simulator XSim [current_project]

# Keep local output products inside project dir
set_property ip_output_repo [file join $PRJ_DIR "${PRJ_NAME}.cache" "ip"] [current_project]

# -----------------------------------------------------------------------------
# Add RTL sources
# -----------------------------------------------------------------------------
set rtl_files [list \
    [file join $RTL_SV_DIR "math_fma_macro.sv"] \
    [file join $RTL_SV_DIR "math_mac_macro.sv"] \
    [file join $RTL_SV_DIR "math_complex_corr.sv"] \
]

# Add (reference) RTL
add_files -fileset sources_1 -norecurse $rtl_files

# Include dirs for `include "*.vh"
set_property include_dirs [list $INC_DIR $RTL_SV_DIR] [get_filesets sources_1]

# Set top (если у тебя реально top = lte_phy_math.sv / другой модуль — поправь)
# Тут логичнее не ставить top вообще для "math library", но пусть будет corr как top.
set_property top math_complex_corr [get_filesets sources_1]

update_compile_order -fileset sources_1
puts "INFO: sources_1 filled OK"

# -----------------------------------------------------------------------------
# Optional: add IP .xci if any exist
# -----------------------------------------------------------------------------
set ip_files [glob -nocomplain -directory $IP_DIR *.xci]
if {[llength $ip_files] > 0} {
    add_files -fileset sources_1 -norecurse $ip_files
    generate_target all [get_files $ip_files]
    # create out-of-context runs for IP and build them
    foreach xci $ip_files {
        # safer to use get_files; Vivado creates <ipname>_synth_1 run
        create_ip_run [get_files $xci]
    }
    # launch all IP synth runs
    foreach run [get_runs -filter {SRCSET =~ "*_ip"}] {
        launch_runs $run
        wait_on_run $run
    }
    puts "INFO: IP XCI processed: $ip_files"
}

# -----------------------------------------------------------------------------
# Helper proc: create sim fileset for a given TB directory
# -----------------------------------------------------------------------------
proc setup_sim {sim_name tb_dir tb_top inc_dirs} {
    if {[string equal [get_filesets -quiet $sim_name] ""]} {
        create_fileset -simset $sim_name
    }

    # Add all SV/V files from tb_dir (no recursion by default; add -scan_for_includes if needed)
    set tb_files [concat \
        [glob -nocomplain -directory $tb_dir *.sv] \
        [glob -nocomplain -directory $tb_dir *.v] \
    ]

    if {[llength $tb_files] == 0} {
        puts "WARN: No TB files found in $tb_dir (simset=$sim_name)"
        return
    }

    add_files -fileset $sim_name -norecurse $tb_files
    set_property include_dirs $inc_dirs [get_filesets $sim_name]

    set wcfg_files [glob -nocomplain -directory $tb_dir *.wcfg]
    if {[llength $wcfg_files] > 0} {
        # добавляем в проект, чтобы лежали в Simulation Sources
        add_files -fileset $sim_name -norecurse $wcfg_files

        # говорим xsim какой wcfg грузить
        # (xsim.view принимает список, можно несколько)
        set_property xsim.view $wcfg_files [get_filesets $sim_name]
        puts "INFO: WCFG attached for $sim_name: $wcfg_files"
    }
    
    set_property top $tb_top [get_filesets $sim_name]

    # Optional: set a post-sim TCL hook if exists
    set post_tcl [file join $tb_dir "view-results.post.tcl"]
    if {[file exists $post_tcl]} {
        add_files -fileset $sim_name -norecurse $post_tcl
        set_property xsim.simulate.tcl.post $post_tcl [get_filesets $sim_name]
        puts "INFO: post-sim hook enabled for $sim_name: $post_tcl"
    }

    update_compile_order -fileset $sim_name
    puts "INFO: simset ready: $sim_name (top=$tb_top)"
}

# Common include dirs for TB
set tb_inc_dirs [list $INC_DIR $RTL_SV_DIR $DEVL_DIR]

setup_sim "sim_math_complex_corr" \
    [file join $DEVL_DIR "math_complex_corr"] \
    "math_complex_corr_tb" \
    $tb_inc_dirs

setup_sim "sim_math_mac_macro" \
    [file join $DEVL_DIR "math_mac_macro"] \
    "math_mac_macro_tb" \
    $tb_inc_dirs

setup_sim "sim_math_fma_macro" \
    [file join $DEVL_DIR "math_fma_macro"] \
    "math_fma_macro_tb" \
    $tb_inc_dirs

current_fileset -simset [get_filesets sim_math_complex_corr]