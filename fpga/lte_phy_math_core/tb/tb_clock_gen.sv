`timescale 1ns/1ps

`include "types.svh"
`include "tb_macro.svh"

/**
    module: testbench clock generator 
    description: просто имитирует работу интерфейса CLOCK

    parameter MHz - задаётся исходя из разрешения timescale - в моём случае 1ns

    просто информация, как идёт рассчёт
    MHz - колебания в секунду, в 1 секунду 10^-9 пикосекунд

    (1/MHz) / 10^-9. т.к. всё задаётся в MHz, то (1/MHz) / 10^-3
    и т.к. мы учитываем полупериод (negedge и posedge , то ещё делим на 2)
    итого: T_half = 1E3/(2*F_MHZ)
*/ 

module tb_clock_gen #(
    parameter int HALF_PERIOD_TU = 0
)(
    CLOCK.o o_clock
);
    initial begin
        o_clock.clk = 0;
        forever #(HALF_PERIOD_TU) o_clock.clk = ~o_clock.clk;
    end

    initial begin
        o_clock.rst       = 0;
        o_clock.is_locked = 0;
        #(1 * 2 * HALF_PERIOD_TU);
        o_clock.rst       = 1;
        o_clock.is_locked = 1;
    end
endmodule