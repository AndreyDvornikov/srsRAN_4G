`include "bel_fft_def.v"

// Is a top module

module system_lte_phy_fft(
    input wire i_clk, i_rst, i_start,

    output wire  [`BEL_FFT_MIF_AWIDTH - 1:0]    m_address,       // FFT -> RAM
    input  wire [`BEL_FFT_DWIDTH - 1:0]         m_readdata,      // RAM -> FFT
    output wire  [`BEL_FFT_DWIDTH - 1:0]        m_writedata,     // FFT -> RAM  
    output wire                                 m_read,          // FFT -> RAM
    output wire                                 m_write,         // FFT -> RAM
    input  wire                                 m_waitrequest,   // RAM -> FFT
    input  wire                                 m_readdatavalid, // RAM -> FFT

    output wire                                 o_finish
);  
    wire [`BEL_FFT_SIF_AWIDTH - 1:0]    s_address;
    wire [`BEL_FFT_DWIDTH - 1:0]        s_readdata;
    wire [`BEL_FFT_DWIDTH - 1:0]        s_writedata;
    wire                                s_read;
    wire                                s_write;
    wire [`BEL_FFT_BCNT - 1:0]          s_byteenable;
    wire                                s_waitrequest;
    wire                                s_readdatavalid;

    wire                                interrupt;
    wire                                ctrl_finish;

    localparam fft_size = 128;
    localparam inverse  = 0; 

    assign o_finish = ctrl_finish;

    main_fft_control u_ctrl (
        .i_clk             (i_clk),
        .i_rst             (i_rst),

        .i_start           (i_start),
        .i_int             (interrupt),
        .i_inverse         (inverse),

        .i_fft_size        (fft_size),

        .o_state           (),
        .o_next_state      (),

        .o_s_address       (s_address),
        .i_s_readdata      (s_readdata),
        .o_s_writedata     (s_writedata),
        .o_s_read          (s_read),
        .o_s_write         (s_write),
        .o_s_byteenable    (s_byteenable),
        .i_s_waitrequest   (s_waitrequest),
        .i_s_readdatavalid (s_readdatavalid),

        .o_finish          (ctrl_finish)
    );

    lte_phy_fft 
        u_fft (
        .clk_i (i_clk),
        .rst_i (i_rst),
        .m_address (m_address),
        .m_readdata (m_readdata),
        .m_writedata (m_writedata),
        .m_read (m_read),
        .m_write (m_write),
        .m_waitrequest (m_waitrequest),
        .m_readdatavalid (m_readdatavalid),
        .s_address (s_address),
        .s_readdata (s_readdata),
        .s_writedata (s_writedata),
        .s_read (s_read),
        .s_write (s_write),
        .s_byteenable (s_byteenable),
        .s_waitrequest (s_waitrequest),
        .s_readdatavalid (s_readdatavalid),
        .int_o (interrupt)
    );
endmodule