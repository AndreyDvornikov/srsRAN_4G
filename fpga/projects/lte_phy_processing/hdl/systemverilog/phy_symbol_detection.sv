`include "lte_hw_params.vh"

/**
    @module phy symbol detection
    @description
*/ 

module phy_symbol_detection(
    input wire i_clk, i_rst,

    // analog devices channel 1
    input wire signed [`HW_ADC_WIDTH - 1: 0] i_data_i1,
    input wire signed [`HW_ADC_WIDTH - 1: 0] i_data_q1, 
    input wire                               i_valid
);
    localparam int WORD_WIDTH   = `HW_ADC_WIDTH * 2;
    localparam int DEPTH        = `MEM_BLOCK_DEPTH;
    localparam int AW           = $clog2(DEPTH);

    // for bel fft 
    // and for mem
    wire [WORD_WIDTH - 1:0] wr_iq_packed = {i_data_i1, i_data_q1};
    reg  [AW - 1:0]         wr_addr;

    wire        i_ena               = i_valid;
    wire [0:0]  i_wea               = {i_valid}; // ну это да..
    wire        i_addra             = wr_addr;
    wire [WORD_WIDTH - 1:0] i_dina  = wr_iq_packed; 

    // output declaration of module mem_sdpram_wrap
    wire [WORD_WIDTH-1:0]   rd_iq_packed;
    reg [AW - 1:0]          rd_addr;
    wire                    i_enb   = 1'b0;
    wire                    i_addrb = '0;

    mem_sdpram_wrap #(
        .BLK_DEPTH  	(DEPTH          ),
        .WORD_WIDTH 	(WORD_WIDTH     ))
    u_mem_sdpram_wrap(
        .i_clk   	(i_clk          ),
        .i_ena   	(i_ena          ),
        .i_wea   	(i_wea          ),
        .i_addra 	(i_addra        ),
        .i_dina  	(i_dina         ),
        .i_enb   	(i_enb          ),
        .i_addrb 	(i_addrb        ),
        .o_doutb 	(rd_iq_packed   )
    );
    
    // запись
    always @(posedge i_clk) begin 
        if (i_rst) begin 
            wr_addr <= '0;
        end else if (i_valid) begin 
            // инкрементируем адрес записи
            wr_addr <= wr_addr + 1'b1;
        end 
    end 

    // чтение
    always @(posedge i_clk) begin
        if (i_rst) begin 
            rd_addr <= '0;
        end
    end

    // math_complex_corr #(
    //     .WIDTH(`HW_ADC_WIDTH),
    //     .CORR_SEQ_SIZE(1),
    //     .fma_pipe_size(1),
    //     .fma_acc_size(64))
    // u_math_complex_corr(
    //     .i_rst(i_rst),
    //     .i_clk(i_clk),

    //     i_data_i1(i_data_i1),
    //     i_data_q1(i_data_q1),
    // );

    // decision logic TODO!!
endmodule