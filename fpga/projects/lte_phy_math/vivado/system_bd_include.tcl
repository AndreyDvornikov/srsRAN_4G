# include helper for external RTL modules

set tcl_dir   [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $tcl_dir ..]]

set RTL_V_DIR [file join $repo_root "hdl" "verilog"]
set RTL_SV_DIR [file join $repo_root "hdl" "systemverilog"]
set INC_DIR    [file join $repo_root "hdl" "include"]

set rtl_files [list \
  [file join $RTL_SV_DIR "math_fma_macro.sv"] \
  [file join $RTL_SV_DIR "math_mac_macro.sv"] \
  [file join $RTL_SV_DIR "math_complex_corr.sv"] \
  [file join $RTL_V_DIR "math_complex_corr_bd.v"] \
]

set inc_files [list \
  [file join $INC_DIR "lte_phy_math.vh"] \
]

add_files -fileset sources_1 -norecurse $rtl_files
add_files -fileset sources_1 -norecurse $inc_files

set_property include_dirs [list $INC_DIR $RTL_SV_DIR] [get_filesets sources_1]

update_compile_order -fileset sources_1

set need_file [file join $RTL_V_DIR "math_complex_corr_bd.v"]
if {[llength [get_files -quiet $need_file]] == 0} {
  puts "ERROR: Expected RTL file not in project: $need_file"
  return -code error
}

# Optional: print compile order snippet (debug)
puts "INFO: External RTL added OK"
puts {INFO: External RTL for BD added OK (module=$need_mod)}
