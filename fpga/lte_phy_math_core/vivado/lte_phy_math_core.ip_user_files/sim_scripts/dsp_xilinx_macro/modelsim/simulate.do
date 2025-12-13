onbreak {quit -f}
onerror {quit -f}

vsim -voptargs="+acc"  -L xil_defaultlib -L xbip_dsp48_wrapper_v3_0_6 -L xbip_utils_v3_0_14 -L xbip_pipe_v3_0_10 -L dsp_macro_v1_0_7 -L secureip -lib xil_defaultlib xil_defaultlib.dsp_xilinx_macro

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {dsp_xilinx_macro.udo}

run 1000ns

quit -force
