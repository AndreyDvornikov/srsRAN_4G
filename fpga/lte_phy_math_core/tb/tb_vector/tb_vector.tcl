set this_dir [file dirname [info script]]

source [file join $this_dir ".." "head.tcl"]

puts "> tb_vector.tcl"

lappend VLOG_FILES [file join $proj_rtl_dir "vector" "vector_op.sv"]
lappend VLOG_FILES [file join $proj_tb_dir "tb_vector" "tb_vector.sv"] 

puts "> VLOG_ARGS=$VLOG_ARGS"
foreach f $VLOG_FILES {
    vlog $VLOG_ARGS -sv $f
}

# append VSIM_ARGS " -wlf tb_vector.wlf"

puts "> VSIM_ARGS=$VSIM_ARGS"
vsim $VSIM_ARGS tb_vector_op

# add wave -radix binary -group clock-sig tb_vector_op/dut/i_clock/*
add wave -recursive tb_vector_op/dut/*