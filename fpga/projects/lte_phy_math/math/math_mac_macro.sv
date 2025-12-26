/**
    @author Dmitry Moskovskikh
    @name mathematics multiply accumulate
    
    @description
        A * B + C = C operation macro (FMA with loopback C)

*/ 

`timescale 1ns/1ps

module math_mac_macro #(
    parameter int A_WIDTH   = 16,
    parameter int B_WIDTH   = 16,
    parameter int ACC_WIDTH = 64,
    // не должен быть < 1
    parameter int PIPE      = 1,

    localparam int MUL_WIDTH = A_WIDTH + B_WIDTH
)(
    input  wire                        i_clk, i_rst, i_clr,

    input  wire signed [A_WIDTH-1:0]   i_a,
    input  wire signed [B_WIDTH-1:0]   i_b,
    input  wire                        i_valid,

    output wire signed [ACC_WIDTH-1:0] o_c,
    output wire                        o_valid,

    output wire signed [MUL_WIDTH-1:0] o_mul,
    output wire                        o_valid_mul
);

    //
    //
    // signal definitions
    //
    //

    // по сути это shiftreg
    reg signed [A_WIDTH - 1: 0]     pipe_a [PIPE];
    reg signed [B_WIDTH - 1: 0]     pipe_b [PIPE]; 
    reg [PIPE - 1:0]                pipe_i_valid; 

    // хранит аккумулированное значение
    reg signed [ACC_WIDTH - 1:0]    op_acc_r;
    // для последнего аккумулированного значения
    // в момент, как мы дёрнули i_clr
    reg signed [ACC_WIDTH - 1:0]    op_acc_snap_r;
    reg signed                      op_acc_valid;

    // для комбинаторного перемножения
    wire signed [MUL_WIDTH - 1:0]     mul; 

    //
    //
    // logic implementations
    //
    //

    integer i; 

    wire s_pipe_end;

    always @(posedge i_clk) begin 
        if (i_rst) begin 
            pipe_i_valid <= '0;

            for (i = 0; i < PIPE; i++) begin 
                pipe_a[i] <= '0;
                pipe_b[i] <= '0;
            end 
        end else begin 
            pipe_a[0] <= ~i_valid ? '0 : i_a;
            pipe_b[0] <= ~i_valid ? '0 : i_b; 

            pipe_i_valid    <= (pipe_i_valid << 1); 
            pipe_i_valid[0] <= i_valid;  

            for (i = 1; i < PIPE; i++) begin
                pipe_a[i] <= pipe_a[i - 1]; 
                pipe_b[i] <= pipe_b[i - 1];
            end
        end 
    end 

    assign s_pipe_end = pipe_i_valid[PIPE - 1];
    // как только элементы дошли до последнего регистра 
    // комбинаторно считаем умножение
    assign mul        = s_pipe_end ? $signed(pipe_b[PIPE - 1]) * $signed(pipe_a[PIPE - 1]) : 0;

    // accumulator logic 
    // просто вынес в отдельный блок, чтобы не захламлять
    // если i_rst - сброс
    always @(posedge i_clk) begin
        if (i_rst) begin
            op_acc_r <= '0;
        end else if (i_clr) begin 
            op_acc_r <= '0;
        end else if (s_pipe_end) begin
            op_acc_r <= $signed(op_acc_r) + $signed(mul);
        end 
    end

    // i_clr logic block
    // просто вынес в отдельный блок, чтобы не захламлять
    // если i_rst - сброс
    // не i_rst, но i_clr 
    // сохраянем op_acc_r в op_acc_snap_r и вешаем valid
    // на след такте у нас появятся эти сигналы и дёрнутся o_c и o_valid
    // если не i_rst и не i_clr -> просто держим в нуле
    always @(posedge i_clk) begin 
        if (i_rst) begin 
            op_acc_valid  <= '0;
            op_acc_snap_r <= '0;
        end else if (i_clr) begin 
            op_acc_snap_r <= $signed(op_acc_r) + $signed(mul); 
            op_acc_valid  <= '1; 
        end else begin 
            op_acc_snap_r <= '0;
            op_acc_valid  <= '0;
        end 
    end 

    // по сути тут валид всегда, когда мы сбрасываем аккумулятор
    assign o_valid      = op_acc_valid;
    assign o_c          = o_valid ? op_acc_snap_r : '0;

    // после умножения это можно сразу пробросить наружу, для других целей
    assign o_valid_mul  = s_pipe_end;
    assign o_mul        = o_valid_mul ? mul : '0; 

    //for sim
    always @(posedge i_clk) begin
        if (PIPE == 0) begin 
            $display("[LOG-%0t] from math_mac_macro PIPE==0",$time);
            $display("[LOG-%0t] from math_mac_macro PIPE MUST BE GREATHER THEN ZERO", $time);
        end 

        if (o_valid_mul) begin 
            $display("[LOG-%0t] from math_fma_macro o_valid_mul=1",$time);
            $display("[LOG-%0t] from math_fma_macro [o_mul=%0d]",
                $time, o_mul);
        end 

        if (i_valid) begin
            $display("[LOG-%0t] from math_fma_macro i_valid=1",$time);
            $display("[LOG-%0t] from math_fma_macro [o_c=%0d]", 
                $time, o_c);
        end
    end
endmodule