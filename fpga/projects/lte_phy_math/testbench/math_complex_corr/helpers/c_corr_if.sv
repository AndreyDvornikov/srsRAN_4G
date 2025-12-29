interface c_corr_if #(int WIDTH=16, fma_acc_size = 64) (input logic clk);
    logic i_rst;

    logic signed [WIDTH - 1:0] i_data_i1, i_data_q1, i_data_i2, i_data_q2;
    logic i_data_1_valid, i_data_2_valid;

    logic o_corr_valid;

    logic signed [fma_acc_size - 1:0] mag;


    clocking cb @(posedge clk);
        default input #1step output #1step;
        // tb -> dut_tb
        output i_rst, i_data_i1, i_data_q1, i_data_i2, i_data_q2, i_data_1_valid, i_data_2_valid;

        // dut_tb -> tb
        input  o_corr_valid, mag;
    endclocking
endinterface
