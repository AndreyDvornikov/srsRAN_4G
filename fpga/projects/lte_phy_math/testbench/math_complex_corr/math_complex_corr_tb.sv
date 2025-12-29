`timescale 1ns/1ps

`include "../headers/header.svh"

`define DUT_NAME_1 dut_1

module math_complex_corr_tb;
    logic clk;

    localparam int fma_acc_size = 64;
    localparam int fma_corr_seq_size = 3;
    localparam int FMA_PIPE_SIZE = 1;

    // Interface + DUT
    c_corr_if #(
        .WIDTH          (`HW_ADC_WIDTH),
        .fma_acc_size   (fma_acc_size)
    ) vif(clk);
    
    math_complex_corr #(
        .WIDTH         	(`HW_ADC_WIDTH      ),
        .CORR_SEQ_SIZE 	(fma_corr_seq_size  ),
        .fma_pipe_size 	(FMA_PIPE_SIZE      ),
        .fma_acc_size  	(fma_acc_size       ))
    `DUT_NAME_1 (
        .i_clk         	(clk                ),
        .i_rst         	(vif.i_rst          ),
        .i_data_i1     	(vif.i_data_i1      ),
        .i_data_q1     	(vif.i_data_q1      ),
        .i_data1_valid 	(vif.i_data_1_valid ),
        .i_data_i2     	(vif.i_data_i2      ),
        .i_data_q2     	(vif.i_data_q2      ),
        .i_data2_valid 	(vif.i_data_2_valid ),
        .o_valid  	    (vif.o_corr_valid   ),
        .mag           	(vif.mag            )
    );

    // clock 100 MHz
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 1 cycle = 1 clocking event
    task automatic tick_cb();
        @(vif.cb);
    endtask

    task automatic push_corr(
        logic signed [`DUT_NAME_1.WIDTH - 1: 0] i1, q1, i2, q2
    );
        vif.cb.i_data_1_valid <= 1'b1;
        vif.cb.i_data_2_valid <= 1'b1;

        vif.cb.i_data_i1 <= i1;
        vif.cb.i_data_q1 <= q1;
        vif.cb.i_data_i2 <= i2;
        vif.cb.i_data_q2 <= q2;

        tick_cb();

        vif.cb.i_data_1_valid <= 1'b0;
        vif.cb.i_data_2_valid <= 1'b0;
    endtask

    task static init();
        vif.cb.i_rst           <= '0;
        vif.cb.i_data_i1       <= '0;
        vif.cb.i_data_q1       <= '0;
        vif.cb.i_data_1_valid  <= '0;
        vif.cb.i_data_i2       <= '0;
        vif.cb.i_data_q2       <= '0;
        vif.cb.i_data_2_valid  <= '0;

        tick_cb(); 

        vif.cb.i_rst <= 1'b1;

        tick_cb(); 
        
        vif.cb.i_rst <= 1'b0;
    endtask 
    
    logic signed [`HW_ADC_WIDTH - 1:0] test_seq_i_y [7] = '{
        1, 2, 3, 4, 3, 2, 1
    };

    logic signed [`HW_ADC_WIDTH - 1:0] test_seq_q_y [7] = '{
        3, 2, 1, 5, 3, 1, 6
    };

    logic signed [`HW_ADC_WIDTH - 1:0] test_seq_i_s [3] = '{
        4, 3, 2
    };

    logic signed [`HW_ADC_WIDTH - 1:0] test_seq_q_s [3] = '{
        -5, -3, -1
    };

    initial begin
        init();

        push_corr(test_seq_i_y[0], test_seq_q_y[0], test_seq_i_s[0], test_seq_q_s[0]);
        push_corr(test_seq_i_y[1], test_seq_q_y[1], test_seq_i_s[1], test_seq_q_s[1]);
        push_corr(test_seq_i_y[2], test_seq_q_y[2], test_seq_i_s[2], test_seq_q_s[2]);
        push_corr(test_seq_i_y[3], test_seq_q_y[3], test_seq_i_s[0], test_seq_q_s[0]);
        push_corr(test_seq_i_y[4], test_seq_q_y[4], test_seq_i_s[1], test_seq_q_s[1]);
        push_corr(test_seq_i_y[5], test_seq_q_y[5], test_seq_i_s[2], test_seq_q_s[2]);
        push_corr(test_seq_i_y[6], test_seq_q_y[6], test_seq_i_s[0], test_seq_q_s[0]);

        tick_cb();
        tick_cb();
        tick_cb();

        // >> hdl_math
        // acc_re_1=4, acc_re_2=15, acc_im_1=-5, acc_im_2=12
        // acc_re_1=10, acc_re_2=21, acc_im_1=-11, acc_im_2=18
        // acc_re_1=16, acc_re_2=22, acc_im_1=-14, acc_im_2=20 <- с этим сравнивать
        // pow=1480 sum=44
        // acc_re_1=16, acc_re_2=25, acc_im_1=-20, acc_im_2=20
        // acc_re_1=25, acc_re_2=34, acc_im_1=-29, acc_im_2=29
        // acc_re_1=29, acc_re_2=35, acc_im_1=-31, acc_im_2=31 <- с этим сравнивать
        // pow=4096 sum=64
        // acc_re_1=4, acc_re_2=30, acc_im_1=-5, acc_im_2=24
        // max_ref = max_mag = 4096
        // >> 

        $finish;
    end
endmodule