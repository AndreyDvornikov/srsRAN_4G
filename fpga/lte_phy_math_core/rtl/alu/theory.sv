`include "types.svh"

/**
    Теоретическая часть, не предназначена для использования
*/ 

// 16-ти битный умножитель 
module mul_16(
    CLOCK.i clock,

    input logic [15:0] i_a,     // вход A
    input logic [15:0] i_b,     // вход B
    input logic        i_valid,

    output logic [31:0] o_c     // выход A * B
);

always_ff @(posedge clock.clk or negedge clock.rst) begin 
    if (~clock.rst | ~clock.is_locked) begin 
        o_c <= 32'd0;
    end else if (i_valid) begin
        o_c <= i_a * i_b;
    end 
end 

endmodule

// 9-ти битный умножитель
module mul_9 (
    CLOCK.i clock,

    input logic [7:0]   i_a,            
    input logic [7:0]   i_b, 
    input logic         i_valid, 

    output logic [16:0] o_c             
);

always_ff @(posedge clock.clk or negedge clock.rst) begin 
    if (~clock.rst | ~clock.is_locked) begin 
        o_c <= 16'd0;
    end else if (i_valid) begin 
        o_c <= i_a * i_b;
    end 
end 

endmodule

module sum_16(
    CLOCK.i clock,

    input logic [8:0]   i_a,            // [1_2_3_4_5_6_7_8_9], где 1 - знаковый бит
    input logic [8:0]   i_b, 
    input logic         i_valid, 

    output logic [16:0] o_c             // [0_..._16], где 1 - знаковый бит
);

always_ff @(posedge clock.clk or negedge clock.rst) begin 
    if (~clock.rst | ~clock.is_locked) begin 
        o_c <= 32'd0;
    end else if (i_valid) begin 
        o_c <= i_a + i_b;
    end 
end 

endmodule