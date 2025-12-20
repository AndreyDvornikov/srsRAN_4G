/**
    @author Dmitry Moskovskikh
    @name mathematics field multiply and add
    
    @description
        A * B + C = F operation macro

        A, B, C - операнды 
        i_valid - posedge, данные загружены
        
        I_WIDTH - разрядность операндов
        C_WIDTH - операнда С
        это нужно для того, что fma - mac, где есть обратная связь (костыль короче)
        
        PIPE    - время задержки выхода
        
        F       - результат A * B + C
        o_valid - результат выдан

        Задержка выхода определяется исходя из PIPE
        PIPE + 1 (с учётом того, что у нас F - тоже регистр)
*/ 

`timescale 1ns/1ps

module math_fma_macro #(
    parameter int A_WIDTH   = 16,
    parameter int B_WIDTH   = 16,
    parameter int C_WIDTH   = 64,
    parameter int F_WIDTH   = C_WIDTH,
    parameter int PIPE      = 3,

    // возможный размер переменной после перемножения
    localparam int AB_mul_size = A_WIDTH + B_WIDTH
)( 
    input wire clk,
    input wire rst, 

    input wire signed [A_WIDTH - 1:0]    A,
    input wire signed [B_WIDTH - 1:0]    B,
    input wire signed [C_WIDTH - 1:0]    C,
    input wire                           i_valid,

    output wire signed [F_WIDTH - 1: 0]  F,
    output wire                          o_valid,
    
    output wire signed [AB_mul_size - 1: 0]  ab_mul
);
    // конвейер обработки ДО ОПЕРАЦИИ A * B и A * B + C
    // PIPE + 1 из-за того, что во время такта, когда мы считаем
    // A * B, C ещё ждёт следующего такта 
    reg signed [A_WIDTH - 1:0]       pipe_a [PIPE];
    reg signed [B_WIDTH - 1:0]       pipe_b [PIPE];
    reg signed [C_WIDTH - 1:0]       pipe_c [PIPE + 1];

    // pipe_i_valid прокидывает i_valid по конвейеру 
    // размер PIPE + 1 из-за pipe_c который всегда на 1 больше
    reg [PIPE + 1:0]           pipe_i_valid; 

    // регистр для хранения операции A * B 
    // [2] потому что я хочу, чтобы ab_mul и F выходили в 1 такт
    reg signed [AB_mul_size - 1:0]   mul_ff [2];

    // регистр для хранения результата A * B + C
    reg signed [F_WIDTH - 1:0]       res_ff; 

    integer i; 
    
    always @(posedge clk) begin
        if (rst) begin 
            pipe_i_valid <= '0;
            
            for (i = 0; i < PIPE; i++) begin
                pipe_a[i] <= '0;
                pipe_b[i] <= '0;
                pipe_c[i] <= '0;
            end
            
            pipe_c[PIPE] <= '0;
            mul_ff[0]    <= '0;
            mul_ff[1]    <= '0;
            res_ff       <= '0;
        end else begin 
            pipe_a[0] <= ~i_valid ? 0 : A;
            pipe_b[0] <= ~i_valid ? 0 : B; 
            pipe_c[0] <= ~i_valid ? 0 : C;
            
            // сдвигаем i_valid дальше по конвейеру 
            pipe_i_valid <= (pipe_i_valid << 1);
            pipe_i_valid[0] <= i_valid;

            // далее мы "двигаем" a,b,c дальше по конвейеру
            for (i = 1; i < PIPE; i++) begin
                pipe_a[i] <= pipe_a[i - 1];
                pipe_b[i] <= pipe_b[i - 1];
                pipe_c[i] <= pipe_c[i - 1]; 
            end

            // далее мы работаем с pipe на позиции PIPE - 1
            // и сохраняем pipe_c[PIPE - 1] на pipe_c[PIPE]
            pipe_c[PIPE] <= pipe_c[PIPE - 1];

            // Исправляем ту самую задержку
            mul_ff[0] <= $signed(pipe_a[PIPE - 1]) * $signed(pipe_b[PIPE - 1]);
            mul_ff[1] <= mul_ff[0];

            res_ff <= $signed(mul_ff[0]) + $signed(pipe_c[PIPE]);
        end 
    end

    // пробрасываем наружу 
    assign o_valid = pipe_i_valid[PIPE + 1];
    assign F       = ~o_valid ? 0 : res_ff;

    assign ab_mul  = ~o_valid ? 0 : mul_ff[1];
    
    //for sim
    always @(posedge clk) begin
        if (o_valid) begin 
            $display("[LOG-%0t] from math_fma_macro [F=%0d][ab_mul=%0d]",
                $time, F, ab_mul);
        end 
    end
endmodule