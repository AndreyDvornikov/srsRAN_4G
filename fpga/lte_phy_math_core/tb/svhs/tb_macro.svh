// see tb_clock_gen.sv
// for timescale 1ps/1ps
`define ADD_CLOCK_NS(clock_sig_instance, freq_mhz) \
    localparam int _HALF_PERIOD_NS_CLOCK = 1_000 / (2 * freq_mhz); \
    tb_clock_gen #(_HALF_PERIOD_NS_CLOCK) tb_clock_instance (.o_clock(clock_sig_instance));

// see tb_clock_gen.sv
// for timescale 1ps/1ps
`define ADD_CLOCK_PS(clock_sig_instance, freq_mhz) \
    localparam int _HALF_PERIOD_PS_CLOCK = 1_000_000 / (2 * freq_mhz); \
    tb_clock_gen #(_HALF_PERIOD_PS_CLOCK) tb_clock_instance (.o_clock(clock_sig_instance));

// see tb_clock_gen.sv
// for timescale 1ns/1ps
`define HOLD_TICKS_NS(ticks_cnt) \
    #(ticks_cnt * 2 * _HALF_PERIOD_NS_CLOCK);

// see tb_clock_gen.sv
// for timescale 1ps/1ps
`define HOLD_TICKS_PS(ticks_cnt) \
    #(ticks_cnt * 2 * _HALF_PERIOD_PS_CLOCK);
