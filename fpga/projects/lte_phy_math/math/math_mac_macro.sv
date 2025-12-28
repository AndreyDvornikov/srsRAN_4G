/**
    @author Dmitry Moskovskikh
    @name mathematics multiply accumulate
    
    @brief A * B + C = C operation macro (FMA with loopback C)
    @description
*/ 
`default_nettype none

`timescale 1ns/1ps

`define SIGN_SUM(A,B) \
    $signed(A) + $signed(B)

`define SIGN_MUL(A,B) \
    $signed(A) * $signed(B)

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
    reg        [PIPE - 1:0]         pipe_i_valid; 

    // хранит аккумулированное значение
    reg signed [ACC_WIDTH - 1:0]    op_acc_r;
    // для последнего аккумулированного значения
    // в момент, как мы дёрнули i_clr
    reg signed [ACC_WIDTH - 1:0]    op_acc_snap_r;
    reg                             op_acc_valid;

    // для комбинаторного перемножения
    wire signed [MUL_WIDTH - 1:0]   op_mul; 

    //
    //
    // logic implementations
    //
    //

    integer i; 

    // valid end of pipe
    wire s_pipe_end = pipe_i_valid[PIPE - 1];
    
    always @(posedge i_clk) begin 
        if (i_rst) begin 
            pipe_i_valid <= '0;

            for (i = 0; i < PIPE; i++) begin 
                pipe_a[i] <= '0;
                pipe_b[i] <= '0;
            end 
        end else begin 
            pipe_a[0] <= i_a;
            pipe_b[0] <= i_b; 

            pipe_i_valid    <= (pipe_i_valid << 1); 
            pipe_i_valid[0] <= i_valid;  

            for (i = 1; i < PIPE; i++) begin
                pipe_a[i] <= pipe_a[i - 1]; 
                pipe_b[i] <= pipe_b[i - 1];
            end
        end 
    end 

    // как только элементы дошли до последнего регистра 
    // комбинаторно считаем умножение
    assign op_mul = `SIGN_MUL(pipe_b[PIPE - 1], pipe_a[PIPE - 1]);

    always @(posedge i_clk) begin
        if (i_rst) begin
            op_acc_r        <= '0;
            op_acc_snap_r   <= '0;
            op_acc_valid    <= '0;
        end else begin 
            op_acc_valid    <= '0;
            op_acc_snap_r   <= '0;

            if (s_pipe_end) begin 
                if (i_clr) begin 
                    op_acc_snap_r <= `SIGN_SUM(op_acc_r, op_mul);
                    op_acc_valid <= 1'b1;
                    op_acc_r <= '0;
                end else begin 
                    op_acc_r <= `SIGN_SUM(op_acc_r, op_mul);
                end 
            end else if (i_clr) begin 
                // d.moskovskikh [28.12.2026]
                // решил убрать очистку без внешнего знания
                // сигнала o_valid_mul, ибо это вносит неоднозначность
                // последнее поданное значение в конвейере нужно аккумулировать или нет?
                // чтобы это исправить, говорю - нужно, если есть :)
            end
        end 
    end 

    // по сути тут валид всегда, когда мы сбрасываем аккумулятор
    assign o_valid      = op_acc_valid;
    assign o_c          = op_acc_snap_r;

    // после умножения это можно сразу пробросить наружу, для других целей
    assign o_valid_mul  = s_pipe_end;
    assign o_mul        = op_mul; 

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