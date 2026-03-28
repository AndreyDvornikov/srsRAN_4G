`include "lte_hw_params.vh"

module lte_phy_pss_detector #(
    parameter int K_LANES        = 2,
    parameter int FMA_PIPE_SIZE  = 1,
    parameter int FMA_ACC_SIZE   = 48,
    parameter int LTE_PSS_TD_LEN = 128,
    parameter int LTE_TARGET_FS  = 1_920_000
)(
    input  wire                               i_clk,
    input  wire                               i_rst,

    input  wire signed [`HW_ADC_WIDTH-1:0]    i_data_i1,
    input  wire signed [`HW_ADC_WIDTH-1:0]    i_data_q1,
    input  wire                               i_valid,       // sample strobe in FAST domain

    output reg                                o_pss_valid,   // one pulse per period
    output reg  [$clog2(`LTE_PSS_COUNT)-1:0]  o_pss_idx,
    output reg  [31:0]                        o_shift,       // absolute END sample index of best peak in period
    output wire                               o_busy,

    output reg  [33:0]                        o_dbg_mag_pss0,
    output reg  [33:0]                        o_dbg_mag_pss1,
    output reg  [33:0]                        o_dbg_mag_pss2
);

    // =========================================================================
    // Params / helpers
    // =========================================================================
    localparam int PSS_LEN         = LTE_PSS_TD_LEN;
    localparam int HALF_L          = PSS_LEN / 2;
    localparam int PSS_ADDR_WIDTH  = `LTE_PSS_ADDR_WIDTH;
    localparam int PSS_PERIOD_SPS  = LTE_TARGET_FS / 200;

    localparam int ADC_W  = `HW_ADC_WIDTH;
    localparam int CORR_W = 16;
    localparam int MAG_W  = FMA_ACC_SIZE + 2;

    localparam int HALF_AW = (HALF_L <= 1) ? 1 : $clog2(HALF_L);
    localparam int FILL_W  = (PSS_LEN <= 1) ? 1 : $clog2(PSS_LEN + 1);

    initial begin
        if ((PSS_LEN % 2) != 0)
            $fatal(1, "lte_phy_pss_detector: PSS_LEN must be even");

        if (K_LANES != 2)
            $fatal(1, "lte_phy_pss_detector: this implementation is fixed for K_LANES=2");

        if ((LTE_TARGET_FS % 200) != 0)
            $fatal(1, "lte_phy_pss_detector: LTE_TARGET_FS must be divisible by 200");
    end

    function automatic signed [CORR_W-1:0] sx_adc(input signed [ADC_W-1:0] v);
        if (CORR_W == ADC_W) sx_adc = v;
        else                 sx_adc = {{(CORR_W-ADC_W){v[ADC_W-1]}}, v};
    endfunction

    function automatic [MAG_W-1:0] abs_s(input signed [FMA_ACC_SIZE-1:0] v);
        abs_s = v[FMA_ACC_SIZE-1] ? $unsigned(-v) : $unsigned(v);
    endfunction

    function automatic [MAG_W-1:0] l1mag(
        input signed [FMA_ACC_SIZE-1:0] re,
        input signed [FMA_ACC_SIZE-1:0] im
    );
        l1mag = abs_s(re) + abs_s(im);
    endfunction

    // =========================================================================
    // PSS ROM loader
    // =========================================================================
    reg                      rom_ena;
    reg [PSS_ADDR_WIDTH-1:0] rom_addr_cnt;
    wire [31:0]              douta_pss0, douta_pss1, douta_pss2;

    generate
        if (PSS_LEN == 128) begin : gen_pss0_128
            pss_0_rom_td_128sps u_pss0 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss0));
        end else begin : gen_pss0_256
            pss_0_rom_td_256sps u_pss0 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss0));
        end
    endgenerate

    generate
        if (PSS_LEN == 128) begin : gen_pss1_128
            pss_1_rom_td_128sps u_pss1 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss1));
        end else begin : gen_pss1_256
            pss_1_rom_td_256sps u_pss1 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss1));
        end
    endgenerate

    generate
        if (PSS_LEN == 128) begin : gen_pss2_128
            pss_2_rom_td_128sps u_pss2 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss2));
        end else begin : gen_pss2_256
            pss_2_rom_td_256sps u_pss2 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss2));
        end
    endgenerate

    reg signed [15:0] pss0_i_mem [0:PSS_LEN-1];
    reg signed [15:0] pss0_q_mem [0:PSS_LEN-1];
    reg signed [15:0] pss1_i_mem [0:PSS_LEN-1];
    reg signed [15:0] pss1_q_mem [0:PSS_LEN-1];
    reg signed [15:0] pss2_i_mem [0:PSS_LEN-1];
    reg signed [15:0] pss2_q_mem [0:PSS_LEN-1];

    reg                      pss_loaded;
    reg [31:0]               dout0_d, dout1_d, dout2_d;
    reg [PSS_ADDR_WIDTH-1:0] load_wr;

    localparam [1:0] L_IDLE=2'd0, L_PRIME=2'd1, L_RUN=2'd2, L_DONE=2'd3;
    reg [1:0] lstate;

    integer jj;
    always @(posedge i_clk) begin
        if (i_rst) begin
            lstate       <= L_IDLE;
            rom_ena      <= 1'b0;
            rom_addr_cnt <= '0;
            load_wr      <= '0;
            dout0_d      <= 32'd0;
            dout1_d      <= 32'd0;
            dout2_d      <= 32'd0;
            pss_loaded   <= 1'b0;

            for (jj=0; jj<PSS_LEN; jj=jj+1) begin
                pss0_i_mem[jj] <= '0; pss0_q_mem[jj] <= '0;
                pss1_i_mem[jj] <= '0; pss1_q_mem[jj] <= '0;
                pss2_i_mem[jj] <= '0; pss2_q_mem[jj] <= '0;
            end
        end else begin
            dout0_d <= douta_pss0;
            dout1_d <= douta_pss1;
            dout2_d <= douta_pss2;

            case (lstate)
                L_IDLE: begin
                    pss_loaded   <= 1'b0;
                    rom_ena      <= 1'b1;
                    rom_addr_cnt <= '0;
                    load_wr      <= '0;
                    lstate       <= L_PRIME;
                end

                L_PRIME: begin
                    rom_addr_cnt <= 1;
                    lstate       <= L_RUN;
                end

                L_RUN: begin
                    pss0_i_mem[load_wr] <= $signed(dout0_d[15:0]);
                    pss0_q_mem[load_wr] <= $signed(dout0_d[31:16]);

                    pss1_i_mem[load_wr] <= $signed(dout1_d[15:0]);
                    pss1_q_mem[load_wr] <= $signed(dout1_d[31:16]);

                    pss2_i_mem[load_wr] <= $signed(dout2_d[15:0]);
                    pss2_q_mem[load_wr] <= $signed(dout2_d[31:16]);

                    if (load_wr == (PSS_LEN-1)) begin
                        rom_ena    <= 1'b0;
                        pss_loaded <= 1'b1;
                        lstate     <= L_DONE;
                    end else begin
                        load_wr      <= load_wr + 1'b1;
                        rom_addr_cnt <= load_wr + 2;
                    end
                end

                default: begin
                    rom_ena <= 1'b0;
                end
            endcase
        end
    end

    // =========================================================================
    // Sliding window of last PSS_LEN samples
    //   win[0]   = newest
    //   win[L-1] = oldest
    // =========================================================================
    reg signed [ADC_W-1:0] win_i [0:PSS_LEN-1];
    reg signed [ADC_W-1:0] win_q [0:PSS_LEN-1];
    reg [FILL_W-1:0]       win_fill;
    reg [31:0]             abs_sample;

    // period counter on RAW accepted samples
    reg [31:0]             period_cnt_raw;
    reg                    job_period_last;

    integer wi;
    wire sample_accept = pss_loaded && !o_busy && i_valid;

    // =========================================================================
    // Scheduler
    //   One accepted sample -> one correlation job
    //   K=2 is implemented as EVEN/ODD split:
    //     full sum = even_half + odd_half
    // =========================================================================
    localparam [1:0] S_IDLE=2'd0, S_RUN=2'd1, S_WAIT=2'd2, S_OUT=2'd3;
    reg [1:0] sst;
    reg [HALF_AW-1:0] pair_idx;

    reg [31:0] job_end_abs;

    assign o_busy = (!pss_loaded) || (sst != S_IDLE);

    // current pair addresses inside full-length window
    // oldest sample of current window = win_[PSS_LEN-1]
    wire [31:0] tap_even = (pair_idx << 1);
    wire [31:0] tap_odd  = (pair_idx << 1) + 1;

    wire signed [CORR_W-1:0] rx_even_i = sx_adc(win_i[PSS_LEN-1 - tap_even]);
    wire signed [CORR_W-1:0] rx_even_q = sx_adc(win_q[PSS_LEN-1 - tap_even]);
    wire signed [CORR_W-1:0] rx_odd_i  = sx_adc(win_i[PSS_LEN-1 - tap_odd]);
    wire signed [CORR_W-1:0] rx_odd_q  = sx_adc(win_q[PSS_LEN-1 - tap_odd]);

    wire signed [CORR_W-1:0] pss0_even_i = pss0_i_mem[tap_even];
    wire signed [CORR_W-1:0] pss0_even_q = pss0_q_mem[tap_even];
    wire signed [CORR_W-1:0] pss0_odd_i  = pss0_i_mem[tap_odd];
    wire signed [CORR_W-1:0] pss0_odd_q  = pss0_q_mem[tap_odd];

    wire signed [CORR_W-1:0] pss1_even_i = pss1_i_mem[tap_even];
    wire signed [CORR_W-1:0] pss1_even_q = pss1_q_mem[tap_even];
    wire signed [CORR_W-1:0] pss1_odd_i  = pss1_i_mem[tap_odd];
    wire signed [CORR_W-1:0] pss1_odd_q  = pss1_q_mem[tap_odd];

    wire signed [CORR_W-1:0] pss2_even_i = pss2_i_mem[tap_even];
    wire signed [CORR_W-1:0] pss2_even_q = pss2_q_mem[tap_even];
    wire signed [CORR_W-1:0] pss2_odd_i  = pss2_i_mem[tap_odd];
    wire signed [CORR_W-1:0] pss2_odd_q  = pss2_q_mem[tap_odd];

    wire feed_valid = (sst == S_RUN);

    // =========================================================================
    // 6 half-correlators:
    //   3 PSS × 2 parity lanes (even/odd)
    //   each half length = PSS_LEN/2
    // =========================================================================
    wire c0e_v, c0o_v, c1e_v, c1o_v, c2e_v, c2o_v;

    wire signed [FMA_ACC_SIZE-1:0] c0e_re, c0e_im, c0o_re, c0o_im;
    wire signed [FMA_ACC_SIZE-1:0] c1e_re, c1e_im, c1o_re, c1o_im;
    wire signed [FMA_ACC_SIZE-1:0] c2e_re, c2e_im, c2o_re, c2o_im;

    math_complex_corr #(
        .WIDTH(CORR_W),
        .CORR_SEQ_SIZE(HALF_L),
        .fma_pipe_size(FMA_PIPE_SIZE),
        .fma_acc_size(FMA_ACC_SIZE)
    ) u_c0_even (
        .i_rst(i_rst), .i_clk(i_clk),
        .i_data_i1(rx_even_i), .i_data_q1(rx_even_q), .i_data1_valid(feed_valid),
        .i_data_i2(pss0_even_i), .i_data_q2(pss0_even_q), .i_data2_valid(feed_valid),
        .o_valid(c0e_v), .o_im(c0e_im), .o_re(c0e_re)
    );

    math_complex_corr #(
        .WIDTH(CORR_W),
        .CORR_SEQ_SIZE(HALF_L),
        .fma_pipe_size(FMA_PIPE_SIZE),
        .fma_acc_size(FMA_ACC_SIZE)
    ) u_c0_odd (
        .i_rst(i_rst), .i_clk(i_clk),
        .i_data_i1(rx_odd_i), .i_data_q1(rx_odd_q), .i_data1_valid(feed_valid),
        .i_data_i2(pss0_odd_i), .i_data_q2(pss0_odd_q), .i_data2_valid(feed_valid),
        .o_valid(c0o_v), .o_im(c0o_im), .o_re(c0o_re)
    );

    math_complex_corr #(
        .WIDTH(CORR_W),
        .CORR_SEQ_SIZE(HALF_L),
        .fma_pipe_size(FMA_PIPE_SIZE),
        .fma_acc_size(FMA_ACC_SIZE)
    ) u_c1_even (
        .i_rst(i_rst), .i_clk(i_clk),
        .i_data_i1(rx_even_i), .i_data_q1(rx_even_q), .i_data1_valid(feed_valid),
        .i_data_i2(pss1_even_i), .i_data_q2(pss1_even_q), .i_data2_valid(feed_valid),
        .o_valid(c1e_v), .o_im(c1e_im), .o_re(c1e_re)
    );

    math_complex_corr #(
        .WIDTH(CORR_W),
        .CORR_SEQ_SIZE(HALF_L),
        .fma_pipe_size(FMA_PIPE_SIZE),
        .fma_acc_size(FMA_ACC_SIZE)
    ) u_c1_odd (
        .i_rst(i_rst), .i_clk(i_clk),
        .i_data_i1(rx_odd_i), .i_data_q1(rx_odd_q), .i_data1_valid(feed_valid),
        .i_data_i2(pss1_odd_i), .i_data_q2(pss1_odd_q), .i_data2_valid(feed_valid),
        .o_valid(c1o_v), .o_im(c1o_im), .o_re(c1o_re)
    );

    math_complex_corr #(
        .WIDTH(CORR_W),
        .CORR_SEQ_SIZE(HALF_L),
        .fma_pipe_size(FMA_PIPE_SIZE),
        .fma_acc_size(FMA_ACC_SIZE)
    ) u_c2_even (
        .i_rst(i_rst), .i_clk(i_clk),
        .i_data_i1(rx_even_i), .i_data_q1(rx_even_q), .i_data1_valid(feed_valid),
        .i_data_i2(pss2_even_i), .i_data_q2(pss2_even_q), .i_data2_valid(feed_valid),
        .o_valid(c2e_v), .o_im(c2e_im), .o_re(c2e_re)
    );

    math_complex_corr #(
        .WIDTH(CORR_W),
        .CORR_SEQ_SIZE(HALF_L),
        .fma_pipe_size(FMA_PIPE_SIZE),
        .fma_acc_size(FMA_ACC_SIZE)
    ) u_c2_odd (
        .i_rst(i_rst), .i_clk(i_clk),
        .i_data_i1(rx_odd_i), .i_data_q1(rx_odd_q), .i_data1_valid(feed_valid),
        .i_data_i2(pss2_odd_i), .i_data_q2(pss2_odd_q), .i_data2_valid(feed_valid),
        .o_valid(c2o_v), .o_im(c2o_im), .o_re(c2o_re)
    );

    wire all_done = c0e_v & c0o_v & c1e_v & c1o_v & c2e_v & c2o_v;

    reg signed [FMA_ACC_SIZE-1:0] s0_re, s0_im;
    reg signed [FMA_ACC_SIZE-1:0] s1_re, s1_im;
    reg signed [FMA_ACC_SIZE-1:0] s2_re, s2_im;

    // =========================================================================
    // Period-best storage
    // =========================================================================
    reg                               period_best_valid;
    reg [MAG_W-1:0]                   period_best_mag;
    reg [$clog2(`LTE_PSS_COUNT)-1:0]  period_best_idx;
    reg [31:0]                        period_best_shift;
    reg [33:0]                        period_best_mag0;
    reg [33:0]                        period_best_mag1;
    reg [33:0]                        period_best_mag2;

    // =========================================================================
    // Main FSM
    // =========================================================================
    always @(posedge i_clk) begin
        if (i_rst) begin
            o_pss_valid    <= 1'b0;
            o_pss_idx      <= '0;
            o_shift        <= 32'd0;
            o_dbg_mag_pss0 <= 34'd0;
            o_dbg_mag_pss1 <= 34'd0;
            o_dbg_mag_pss2 <= 34'd0;

            sst            <= S_IDLE;
            pair_idx       <= '0;
            job_end_abs    <= 32'd0;
            job_period_last<= 1'b0;

            win_fill       <= '0;
            abs_sample     <= 32'd0;
            period_cnt_raw <= 32'd0;

            s0_re <= '0; s0_im <= '0;
            s1_re <= '0; s1_im <= '0;
            s2_re <= '0; s2_im <= '0;

            period_best_valid <= 1'b0;
            period_best_mag   <= '0;
            period_best_idx   <= '0;
            period_best_shift <= 32'd0;
            period_best_mag0  <= 34'd0;
            period_best_mag1  <= 34'd0;
            period_best_mag2  <= 34'd0;

            for (wi=0; wi<PSS_LEN; wi=wi+1) begin
                win_i[wi] <= '0;
                win_q[wi] <= '0;
            end
        end else begin
            o_pss_valid <= 1'b0;

            // -------------------------------------------------------------
            // accept new sample only when engine idle
            // -------------------------------------------------------------
            if (sample_accept) begin
                for (wi=PSS_LEN-1; wi>0; wi=wi-1) begin
                    win_i[wi] <= win_i[wi-1];
                    win_q[wi] <= win_q[wi-1];
                end
                win_i[0] <= i_data_i1;
                win_q[0] <= i_data_q1;

                if (win_fill != PSS_LEN)
                    win_fill <= win_fill + 1'b1;

                // absolute END index of accepted sample
                job_end_abs <= abs_sample;
                abs_sample  <= abs_sample + 1'b1;

                // period bookkeeping on RAW sample stream
                job_period_last <= (period_cnt_raw == (PSS_PERIOD_SPS-1));
                if (period_cnt_raw == (PSS_PERIOD_SPS-1))
                    period_cnt_raw <= 32'd0;
                else
                    period_cnt_raw <= period_cnt_raw + 1'b1;

                // start correlation only when window is already full
                if (win_fill >= PSS_LEN-1) begin
                    pair_idx <= '0;
                    sst      <= S_RUN;
                end
            end

            // -------------------------------------------------------------
            // engine
            // -------------------------------------------------------------
            case (sst)
                S_IDLE: begin
                    // nothing
                end

                S_RUN: begin
                    if (pair_idx == (HALF_L-1)) begin
                        pair_idx <= '0;
                        sst      <= S_WAIT;
                    end else begin
                        pair_idx <= pair_idx + 1'b1;
                    end
                end

                S_WAIT: begin
                    if (all_done) begin
                        s0_re <= $signed(c0e_re) + $signed(c0o_re);
                        s0_im <= $signed(c0e_im) + $signed(c0o_im);

                        s1_re <= $signed(c1e_re) + $signed(c1o_re);
                        s1_im <= $signed(c1e_im) + $signed(c1o_im);

                        s2_re <= $signed(c2e_re) + $signed(c2o_re);
                        s2_im <= $signed(c2e_im) + $signed(c2o_im);

                        sst <= S_OUT;
                    end
                end

                S_OUT: begin
                    reg [MAG_W-1:0] mag0, mag1, mag2;
                    reg [MAG_W-1:0] cur_best_mag;
                    reg [$clog2(`LTE_PSS_COUNT)-1:0] cur_best_idx;
                    reg use_cur;

                    mag0 = l1mag(s0_re, s0_im);
                    mag1 = l1mag(s1_re, s1_im);
                    mag2 = l1mag(s2_re, s2_im);

                    if ((mag2 >= mag1) && (mag2 >= mag0)) begin
                        cur_best_mag = mag2;
                        cur_best_idx = 2;
                    end else if (mag1 >= mag0) begin
                        cur_best_mag = mag1;
                        cur_best_idx = 1;
                    end else begin
                        cur_best_mag = mag0;
                        cur_best_idx = 0;
                    end

                    use_cur = (!period_best_valid) || (cur_best_mag > period_best_mag);

                    // normal in-period update
                    if (!job_period_last) begin
                        if (use_cur) begin
                            period_best_valid <= 1'b1;
                            period_best_mag   <= cur_best_mag;
                            period_best_idx   <= cur_best_idx;
                            period_best_shift <= job_end_abs;
                            period_best_mag0  <= mag0[33:0];
                            period_best_mag1  <= mag1[33:0];
                            period_best_mag2  <= mag2[33:0];
                        end
                    end
                    // end of period -> emit best over WHOLE period
                    else begin
                        if (use_cur) begin
                            o_pss_valid    <= 1'b1;
                            o_pss_idx      <= cur_best_idx;
                            o_shift        <= job_end_abs;
                            o_dbg_mag_pss0 <= mag0[33:0];
                            o_dbg_mag_pss1 <= mag1[33:0];
                            o_dbg_mag_pss2 <= mag2[33:0];
                        end else if (period_best_valid) begin
                            o_pss_valid    <= 1'b1;
                            o_pss_idx      <= period_best_idx;
                            o_shift        <= period_best_shift;
                            o_dbg_mag_pss0 <= period_best_mag0;
                            o_dbg_mag_pss1 <= period_best_mag1;
                            o_dbg_mag_pss2 <= period_best_mag2;
                        end

                        // clear best for next period
                        period_best_valid <= 1'b0;
                        period_best_mag   <= '0;
                        period_best_idx   <= '0;
                        period_best_shift <= 32'd0;
                        period_best_mag0  <= 34'd0;
                        period_best_mag1  <= 34'd0;
                        period_best_mag2  <= 34'd0;
                    end

                    sst <= S_IDLE;
                end

                default: begin
                    sst <= S_IDLE;
                end
            endcase
        end
    end

endmodule