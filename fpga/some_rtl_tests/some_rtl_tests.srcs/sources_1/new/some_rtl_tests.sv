`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.11.2025 13:24:57
// Design Name: 
// Module Name: some_rtl_tests
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module some_rtl_tests(
    input  wire        clk,
    input  wire [16:0] a,
    input  wire [16:0] b,
    output reg  [31:0] ab_mul
);

always @(posedge clk) begin
    ab_mul <= a * b;
end

endmodule
