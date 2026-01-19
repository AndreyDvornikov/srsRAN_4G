/**
    @author Dmitry Moskovskikh
    @name mathematics fused multiply add

    @description
        A * B + C = F operation macro

        A, B, C - операнды 
        i_valid - posedge, данные загружены
        
        A_WIDTH, B_WIDTH, C_WIDTH - разрядность операндов
        F_WIDTH - разрядность выходного результата
        по умолчанию равна C_WIDTH

        это нужно для того, что fma - mac, где есть обратная связь (костыль короче)
        
        PIPE    - время задержки выхода
        
        F       - результат A * B + C
        o_valid - результат выдан

        Задержка выхода определяется исходя из PIPE
        PIPE + 1 (с учётом того, что у нас F - тоже регистр)
*/ 

`include "lte_phy_math.vh"

module math_fma_macro #(
    parameter int A_WIDTH   = 16,
    parameter int B_WIDTH   = 16,
    parameter int C_WIDTH   = 64,
    parameter int F_WIDTH   = C_WIDTH,
    // не должен быть < 1
    parameter int PIPE      = 1,
    // возможный размер переменной после перемножения
    localparam int AB_WIDTH = A_WIDTH + B_WIDTH
)( 
    input wire i_clk, i_rst,

    input wire signed [A_WIDTH - 1:0]    A, B, C,
    input wire                           i_valid,

    // A * B + C
    output wire signed [F_WIDTH - 1: 0]  F,
    output wire                          o_valid,

    // A * B
    output wire signed [AB_WIDTH - 1: 0]  F_mul
);  

    // 
    //
    // inernal signal definitions  
    //
    //

    // конвейер обработки ДО ОПЕРАЦ�?�? A * B и A * B + C
    // по сути вносит задержку выхода.
    reg signed [A_WIDTH - 1:0]          pipe_a [PIPE];
    reg signed [B_WIDTH - 1:0]          pipe_b [PIPE];
    reg signed [C_WIDTH - 1:0]          pipe_c [PIPE];
    // pipe_i_valid прокидывает i_valid по конвейеру 
    reg [PIPE - 1:0]                    pipe_i_valid; 

    // регистр для хранения операции A * B 
    // [2] потому что я хочу, чтобы F_mul и F выходили в 1 такт
    reg signed [AB_WIDTH - 1:0]         mul_ff [2];
    // регистр для хранения результата A * B + C
    reg signed [F_WIDTH - 1:0]          res_ff; 
    // регистр для извлечения C
    reg signed [C_WIDTH - 1:0]          c_ff; 
    // вычисление
    reg [1:0]                           op_valid;

    // 
    //
    // logic implementation 
    //
    //

    integer i; 

    wire    s_pipe_end;

    always @(posedge i_clk) begin 
        if (i_rst) begin 
            pipe_i_valid <= '0;

            for (i = 0; i < PIPE; i++) begin
                pipe_a[i] <= '0;
                pipe_b[i] <= '0;
                pipe_c[i] <= '0;
            end
        end else begin 
            pipe_a[0] <= ~i_valid ? 0 : A;
            pipe_b[0] <= ~i_valid ? 0 : B; 
            pipe_c[0] <= ~i_valid ? 0 : C;

            // сдвигаем i_valid дальше по конвейеру 
            pipe_i_valid    <= (pipe_i_valid << 1);
            pipe_i_valid[0] <= i_valid;

            // далее мы "двигаем" a,b,c дальше по конвейеру
            for (i = 1; i < PIPE; i++) begin
                pipe_a[i] <= pipe_a[i - 1];
                pipe_b[i] <= pipe_b[i - 1];
                pipe_c[i] <= pipe_c[i - 1]; 
            end
        end 
    end

    assign s_pipe_end = pipe_i_valid[PIPE - 1];

    always @(posedge i_clk) begin
        if (i_rst) begin 
            mul_ff[0] <= '0;
            mul_ff[1] <= '0;

            c_ff      <= '0;
            res_ff    <= '0;
            op_valid  <= '0;
        end else begin 
            c_ff        <= pipe_c[PIPE - 1];

            // �?справляем ту самую задержку
            mul_ff[0]   <= $signed(pipe_a[PIPE - 1]) * $signed(pipe_b[PIPE - 1]);
            mul_ff[1]   <= mul_ff[0];

            res_ff      <= $signed(mul_ff[0]) + $signed(c_ff);

            // Конвейер кончился, так что приступаем к вычислению
            op_valid    <= (op_valid << 1);
            op_valid[0] <= s_pipe_end;
        end 
    end

    // пробрасываем наружу 
    assign o_valid = op_valid[1];
    assign F       = ~o_valid ? 0 : res_ff;
    assign F_mul   = ~o_valid ? 0 : mul_ff[1];

    //for sim
    always @(posedge i_clk) begin
        if (PIPE == 0) begin 
            $display("[LOG-%0t] from math_fma_macro PIPE==0",$time);
            $display("[LOG-%0t] from math_fma_macro PIPE MUST BE GREATHER THEN ZERO", $time);
        end 

        if (o_valid) begin 
            $display("[LOG-%0t] from math_fma_macro o_valid=1",$time);
            $display("[LOG-%0t] from math_fma_macro [F=%0d][F_mul=%0d]",
                $time, F, F_mul);
        end 

        if (i_valid) begin
            $display("[LOG-%0t] from math_fma_macro i_valid=1",$time);
            $display("[LOG-%0t] from math_fma_macro [A=%0d][B=%0d][C=%0d]", 
                $time, A, B, C);
        end
    end
endmodule