puts "> head.tcl"

# возвращает путь до файла head.tcl ("этот") и .. - как бы кидает на директорию назад
set proj_root [file normalize [file join [file dirname [info script]] ".."]]

set proj_rtl_dir [file join $proj_root "rtl"] 
set proj_tb_dir [file join $proj_root "tb"]

set project_include_dir \
    [file join $proj_rtl_dir "svhs"]

set tb_include_dir \
    [file join $proj_tb_dir "svhs"]

set VLOG_ARGS "+incdir+$project_include_dir+$tb_include_dir"
set VSIM_ARGS "-voptargs=+acc"

set VLOG_FILES [list \
    [file join $proj_tb_dir "tb_clock_gen.sv"]
]

puts "> head.tcl: proj_root         = $proj_root"
puts "> head.tcl: proj_rtl_dir      = $proj_rtl_dir"
puts "> head.tcl: proj_tb_dir       = $proj_tb_dir"

puts "> head.tcl: project_include_dir       = $project_include_dir"
puts "> head.tcl: tb_include_dir            = $tb_include_dir"