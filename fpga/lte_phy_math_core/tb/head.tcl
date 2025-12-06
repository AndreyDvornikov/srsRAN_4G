puts "> head.tcl"

set proj_root [file normalize [file join [file dirname [info script]] ".."]]

set include_dir [file join $proj_root "rtl" "svhs"]

puts "> head.tcl: proj_root   = $proj_root"
puts "> head.tcl: include_dir = $include_dir"