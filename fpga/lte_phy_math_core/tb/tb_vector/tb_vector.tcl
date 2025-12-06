set this_dir [file dirname [info script]]

source [file join $this_dir ".." "head.tcl"]

puts "> tb_vector.tcl"

vlog +incdir+$include_dir -sv \
    [file join $proj_root "rtl" "vector" "vector_op.sv"] \
    [file join $proj_root "tb" "tb_vector" "tb_vector.sv"]

vsim -voptargs=+acc tb_vector_op

add wave -recursive tb_vector_op/dut/*

run 200 ns