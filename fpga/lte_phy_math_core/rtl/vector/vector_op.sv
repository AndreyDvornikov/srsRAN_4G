`include "types.svh"
`include "vector.svh"

/**
    @author d.moskovskikh

    High level module for vector operations
    
    Данный модуль является (исходя из названия) 
    внешним модулем для подключения к циклу работы с векторными операциями

    @parameter WIDTH - задаёт разрядность слов, из которых состоит вектор
    @parameter N     - задаёт количество слов внутри вектора (должен быть степенью двойки)
    @parameter DSP_M - задаёт количество умножителей, которые будут использоваться (должно быть степенью двойки)

    
*/
module vector_op #(
    parameter int WIDTH  = 16,
    parameter int N      = 128,
    parameter int DSP_M  = 64
)(
    // main hw signals

    input logic [31:0] i_vec1,
    input logic [31:0] i_vec2,
    input logic i_vec_ready,

    output logic o_vec_ready,
    output logic [63:0] o_vec,

    CLOCK.i i_clock
);

// 
reg [31:0] internal_vec1 [N];

always_ff @(posedge i_clock.clk or negedge i_clock.rst) begin
    if (!i_clock.rst) begin
        o_vec       <= '0;
        o_vec_ready <= 1'b0;
    end else begin
        if (i_vec_ready) begin 
            o_vec       <= i_vec1 * i_vec2;
            o_vec_ready <= 1'b1;
        end else begin
            o_vec_ready <= 1'b0;
        end
    end

    $display("[%0t] i_vec1=%0d, i_vec2=%0d, i_vec_ready=%0d", $time, i_vec1, i_vec2, i_vec_ready);
    $display("[%0t] o_vec=%0d, o_vec_ready=%0d", $time, o_vec, o_vec_ready);
end

endmodule