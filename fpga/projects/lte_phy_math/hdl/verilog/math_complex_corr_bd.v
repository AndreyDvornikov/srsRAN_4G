// for block design wrapper
// more descriptions see in math_complex_corr
module math_complex_corr_bd #(
    parameter WIDTH         = 16,
    parameter CORR_SEQ_SIZE = 5,

    parameter fma_pipe_size = 1,
    parameter fma_acc_size  = 64
)(
    input wire                      i_rst, i_clk,

    input wire signed [WIDTH - 1:0] i_data_i1, i_data_q1,
    input wire                      i_data1_valid, 

    input wire signed [WIDTH - 1:0] i_data_i2, i_data_q2,
    input wire                      i_data2_valid,

    output wire                     o_valid,

    output wire signed [fma_acc_size - 1:0] o_im,
    output wire signed [fma_acc_size - 1:0] o_re
);  

    math_complex_corr #(
        .WIDTH         	(WIDTH              ),
        .CORR_SEQ_SIZE 	(CORR_SEQ_SIZE      ),
        .fma_pipe_size 	(fma_pipe_size      ),
        .fma_acc_size  	(fma_acc_size       ))
    u_math_complex_corr_wrap(
        .i_rst         	(i_rst          ),
        .i_clk         	(i_clk          ),
        .i_data_i1     	(i_data_i1      ),
        .i_data_q1     	(i_data_q1      ),
        .i_data1_valid 	(i_data1_valid  ),
        .i_data_i2     	(i_data_i2      ),
        .i_data_q2     	(i_data_q2      ),
        .i_data2_valid 	(i_data2_valid  ),
        .o_valid       	(o_valid        ),
        .o_im          	(o_im           ),
        .o_re          	(o_re           )
    );
    
endmodule
