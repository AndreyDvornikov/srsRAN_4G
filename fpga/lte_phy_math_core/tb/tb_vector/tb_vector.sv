`timescale 1ns/1ps

`include "types.svh"
`include "tb_macro.svh"

module tb_vector_op;
    CLOCK o_clock_if();

    logic [31:0] i_vec1;
    logic [31:0] i_vec2;
    logic        i_vec_ready;

    logic [63:0] o_vec;
    logic        o_vec_ready;

    vector_op dut (
        .i_vec1(i_vec1),
        .i_vec2(i_vec2),
        .i_vec_ready(i_vec_ready),
        .o_vec_ready(o_vec_ready),
        .o_vec(o_vec),
        .i_clock(o_clock_if)
    );

    // содержит _HALF_PERIOD_<>_CLOCK переменную для 
    // HOLD_TICKS_<>(number)
    `ADD_CLOCK_NS(o_clock_if, 100) 

    // стимулы
    initial begin        
        i_vec1      = '0;
        i_vec2      = '0;
        i_vec_ready = 0;

        // ждём выхода из reset
        `HOLD_TICKS_NS(5)

        // первый вектор
        i_vec1      = 32'd3;
        i_vec2      = 32'd5;
        i_vec_ready = 1;

        `HOLD_TICKS_NS(5)
        
        i_vec_ready = 0;

        // второй вектор
        `HOLD_TICKS_NS(5)

        i_vec1      = 32'd7;
        i_vec2      = 32'd9;
        i_vec_ready = 1;

        `HOLD_TICKS_NS(5)
        
        i_vec_ready = 0;

        `HOLD_TICKS_NS(10);
        $display("[%0t] TB finished", $time);
        $finish;
    end
endmodule
