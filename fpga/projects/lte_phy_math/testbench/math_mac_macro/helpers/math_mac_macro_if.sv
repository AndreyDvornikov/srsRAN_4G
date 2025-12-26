interface mac_if #(int A_W=16, B_W=16, MUL_W=A_W+B_W, ACC_W=64) (input logic clk);
    logic rst;
    logic clr;

    logic signed [A_W-1:0]      i_a;
    logic signed [B_W-1:0]      i_b;
    logic                       i_valid; 

    logic signed [ACC_W-1:0]    o_c;
    logic                       o_valid;

    logic signed [MUL_W-1:0]    o_mul;
    logic                       o_valid_mul; 

    clocking cb @(posedge clk);
        default input #1step output #1step;

        output rst, clr, i_a, i_b, i_valid;

        input  o_c, o_valid, o_mul, o_valid_mul;
    endclocking
endinterface