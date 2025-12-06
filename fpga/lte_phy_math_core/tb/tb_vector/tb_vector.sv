`timescale 1ns/1ps
`include "types.svh"

module tb_vector_op;
    CLOCK i_clock_if();

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
        .i_clock(i_clock_if)
    );

    // генератор такта
    initial begin
        i_clock_if.clk = 0;
        forever #5 i_clock_if.clk = ~i_clock_if.clk;
    end

    // reset и locked
    initial begin
        i_clock_if.rst       = 0;
        i_clock_if.is_locked = 0;
        #20;
        i_clock_if.rst       = 1;
        i_clock_if.is_locked = 1;
    end

    // стимулы
    initial begin
        i_vec1      = '0;
        i_vec2      = '0;
        i_vec_ready = 0;

        // ждём выхода из reset
        #30;

        // первый вектор
        i_vec1      = 32'd3;
        i_vec2      = 32'd5;
        i_vec_ready = 1;
        #10;
        i_vec_ready = 0;

        // второй вектор
        #20;
        i_vec1      = 32'd7;
        i_vec2      = 32'd9;
        i_vec_ready = 1;
        #10;
        i_vec_ready = 0;

        #50;
        $display("[%0t] TB finished", $time);
        $finish;
    end
endmodule
