`include "lte_hw_params.vh"

// ============================================================================
// lte_pss_detector
//  - black-box: на вход только IQ + valid
//  - внутри: ROM load PSS0/PSS1/PSS2, single-frame capture 5ms, block-scan
//  - K_LANES = число параллельных стартов окна (k..k+K_LANES-1)
//  - использует math_complex_corr (sum(rx * conj(pss)))
//  - o_shift = PEAK(end) absolute (0-based) в пространстве принятых samples
//  - o_busy  = 1 -> новые input samples подавать нельзя
// ============================================================================
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
    input  wire                               i_valid,

    output reg  [$clog2(`LTE_PSS_COUNT)-1:0]  o_pss_idx,
    output reg                                o_pss_valid,
    output reg  [31:0]                        o_shift,         // PEAK(end) absolute (0-based)

    output wire                               o_busy,

    output reg  [33:0]                        o_dbg_mag_pss0,
    output reg  [33:0]                        o_dbg_mag_pss1,
    output reg  [33:0]                        o_dbg_mag_pss2
);

    // =========================================================================
    // Params
    // =========================================================================
    localparam int PSS_LEN        = LTE_PSS_TD_LEN;
    localparam int PSS_ADDR_WIDTH = `LTE_PSS_ADDR_WIDTH;

    localparam int BUF_LEN = (LTE_TARGET_FS / 200);     // 5ms samples
    localparam int MAX_POS = (BUF_LEN > PSS_LEN) ? (BUF_LEN - PSS_LEN) : 0;
    localparam int BUF_AW  = (BUF_LEN <= 2) ? 1 : $clog2(BUF_LEN);

    localparam int ADC_W   = `HW_ADC_WIDTH;
    localparam int CORR_W  = 16;
    localparam int MAG_W   = FMA_ACC_SIZE + 2;

    initial begin
        if (K_LANES < 1) $fatal(1, "K_LANES must be >= 1");
    end

    // =========================================================================
    // Helpers
    // =========================================================================
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
    // Accepted-sample counter
    //   Считаем только реально принятые в frame-buffer samples
    // =========================================================================
    reg [31:0] abs_sample;

    // =========================================================================
    // PSS ROMs
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

    // =========================================================================
    // PSS coefficients: DIRECT (no flip, no conj)
    // =========================================================================
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

    // =========================================================================
    // Single capture buffer
    // =========================================================================
    (* ram_style="block" *) reg signed [ADC_W-1:0] frame_i [0:BUF_LEN-1];
    (* ram_style="block" *) reg signed [ADC_W-1:0] frame_q [0:BUF_LEN-1];

    reg [BUF_AW-1:0] wr_idx;
    reg [31:0]       frame_abs0;
    reg              scan_active;

    wire cap_accept = pss_loaded && !scan_active && i_valid;

    // busy high while coefficients are not loaded yet or while scanning
    assign o_busy = (!pss_loaded) || scan_active;

    always @(posedge i_clk) begin
        if (i_rst) abs_sample <= 32'd0;
        else if (i_valid) abs_sample <= abs_sample + 1'b1;
    end

    // =========================================================================
    // Scan engine
    // =========================================================================
    localparam [2:0] S_IDLE=3'd0, S_INIT=3'd1, S_FEED=3'd2, S_WAIT=3'd3, S_EVAL=3'd4, S_OUT=3'd5;
    reg [2:0] sst;

    reg [31:0] scan_abs0;
    reg [31:0] scan_pos;
    reg [15:0] tap_idx;

    reg [MAG_W-1:0] best0_mag, best1_mag, best2_mag;
    reg [31:0]      best0_pos, best1_pos, best2_pos;

    reg [31:0] last_peak_abs;
    reg        have_last_peak;
    reg [31:0] pss_period_sps;

    wire lane_en   [0:K_LANES-1];
    wire feed_lane [0:K_LANES-1];

    genvar gv;
    generate
        for (gv=0; gv<K_LANES; gv=gv+1) begin : gen_lane_en
            assign lane_en[gv]   = ((scan_pos + gv) <= MAX_POS);
            assign feed_lane[gv] = scan_active && (sst == S_FEED) && lane_en[gv];
        end
    endgenerate

    wire signed [CORR_W-1:0] coef0_i = pss0_i_mem[tap_idx];
    wire signed [CORR_W-1:0] coef0_q = pss0_q_mem[tap_idx];
    wire signed [CORR_W-1:0] coef1_i = pss1_i_mem[tap_idx];
    wire signed [CORR_W-1:0] coef1_q = pss1_q_mem[tap_idx];
    wire signed [CORR_W-1:0] coef2_i = pss2_i_mem[tap_idx];
    wire signed [CORR_W-1:0] coef2_q = pss2_q_mem[tap_idx];

    wire signed [CORR_W-1:0] rx_i_lane [0:K_LANES-1];
    wire signed [CORR_W-1:0] rx_q_lane [0:K_LANES-1];

    generate
        for (gv=0; gv<K_LANES; gv=gv+1) begin : gen_lane_rx
            wire [31:0] idx = scan_pos + gv + tap_idx;
            wire signed [ADC_W-1:0] rx_i = frame_i[idx];
            wire signed [ADC_W-1:0] rx_q = frame_q[idx];
            assign rx_i_lane[gv] = sx_adc(rx_i);
            assign rx_q_lane[gv] = sx_adc(rx_q);
        end
    endgenerate

    wire c0_v [0:K_LANES-1];
    wire c1_v [0:K_LANES-1];
    wire c2_v [0:K_LANES-1];

    wire signed [FMA_ACC_SIZE-1:0] c0_re [0:K_LANES-1];
    wire signed [FMA_ACC_SIZE-1:0] c0_im [0:K_LANES-1];
    wire signed [FMA_ACC_SIZE-1:0] c1_re [0:K_LANES-1];
    wire signed [FMA_ACC_SIZE-1:0] c1_im [0:K_LANES-1];
    wire signed [FMA_ACC_SIZE-1:0] c2_re [0:K_LANES-1];
    wire signed [FMA_ACC_SIZE-1:0] c2_im [0:K_LANES-1];

    reg signed [FMA_ACC_SIZE-1:0] c0_re_lat [0:K_LANES-1];
    reg signed [FMA_ACC_SIZE-1:0] c0_im_lat [0:K_LANES-1];
    reg signed [FMA_ACC_SIZE-1:0] c1_re_lat [0:K_LANES-1];
    reg signed [FMA_ACC_SIZE-1:0] c1_im_lat [0:K_LANES-1];
    reg signed [FMA_ACC_SIZE-1:0] c2_re_lat [0:K_LANES-1];
    reg signed [FMA_ACC_SIZE-1:0] c2_im_lat [0:K_LANES-1];

    generate
        for (gv=0; gv<K_LANES; gv=gv+1) begin : gen_corr
            math_complex_corr #(
                .WIDTH(CORR_W),
                .CORR_SEQ_SIZE(PSS_LEN),
                .fma_pipe_size(FMA_PIPE_SIZE),
                .fma_acc_size(FMA_ACC_SIZE)
            ) u_c0 (
                .i_rst(i_rst), .i_clk(i_clk),
                .i_data_i1(rx_i_lane[gv]), .i_data_q1(rx_q_lane[gv]), .i_data1_valid(feed_lane[gv]),
                .i_data_i2(coef0_i),       .i_data_q2(coef0_q),       .i_data2_valid(feed_lane[gv]),
                .o_valid(c0_v[gv]), .o_im(c0_im[gv]), .o_re(c0_re[gv])
            );

            math_complex_corr #(
                .WIDTH(CORR_W),
                .CORR_SEQ_SIZE(PSS_LEN),
                .fma_pipe_size(FMA_PIPE_SIZE),
                .fma_acc_size(FMA_ACC_SIZE)
            ) u_c1 (
                .i_rst(i_rst), .i_clk(i_clk),
                .i_data_i1(rx_i_lane[gv]), .i_data_q1(rx_q_lane[gv]), .i_data1_valid(feed_lane[gv]),
                .i_data_i2(coef1_i),       .i_data_q2(coef1_q),       .i_data2_valid(feed_lane[gv]),
                .o_valid(c1_v[gv]), .o_im(c1_im[gv]), .o_re(c1_re[gv])
            );

            math_complex_corr #(
                .WIDTH(CORR_W),
                .CORR_SEQ_SIZE(PSS_LEN),
                .fma_pipe_size(FMA_PIPE_SIZE),
                .fma_acc_size(FMA_ACC_SIZE)
            ) u_c2 (
                .i_rst(i_rst), .i_clk(i_clk),
                .i_data_i1(rx_i_lane[gv]), .i_data_q1(rx_q_lane[gv]), .i_data1_valid(feed_lane[gv]),
                .i_data_i2(coef2_i),       .i_data_q2(coef2_q),       .i_data2_valid(feed_lane[gv]),
                .o_valid(c2_v[gv]), .o_im(c2_im[gv]), .o_re(c2_re[gv])
            );
        end
    endgenerate

    integer li;
    reg wait_ready;

    always @(posedge i_clk) begin
        if (i_rst) begin
            sst <= S_IDLE;

            wr_idx      <= '0;
            frame_abs0  <= 32'd0;
            scan_active <= 1'b0;

            scan_abs0 <= 32'd0;
            scan_pos  <= 32'd0;
            tap_idx   <= 16'd0;

            best0_mag <= '0; best1_mag <= '0; best2_mag <= '0;
            best0_pos <= 32'd0; best1_pos <= 32'd0; best2_pos <= 32'd0;

            last_peak_abs  <= 32'd0;
            have_last_peak <= 1'b0;
            pss_period_sps <= 32'd0;

            o_pss_valid <= 1'b0;
            o_pss_idx   <= '0;
            o_shift     <= 32'd0;

            o_dbg_mag_pss0 <= 34'd0;
            o_dbg_mag_pss1 <= 34'd0;
            o_dbg_mag_pss2 <= 34'd0;

            for (li=0; li<K_LANES; li=li+1) begin
                c0_re_lat[li] <= '0; c0_im_lat[li] <= '0;
                c1_re_lat[li] <= '0; c1_im_lat[li] <= '0;
                c2_re_lat[li] <= '0; c2_im_lat[li] <= '0;
            end
        end else begin
            o_pss_valid <= 1'b0;

            wait_ready = 1'b1;
            for (li=0; li<K_LANES; li=li+1)
                if (lane_en[li]) wait_ready &= (c0_v[li] & c1_v[li] & c2_v[li]);

            // -----------------------------------------------------------------
            // Capture phase: o_busy=0
            // -----------------------------------------------------------------
            if (!scan_active) begin
                sst <= S_IDLE;

                if (cap_accept) begin
                    if (wr_idx == 0)
                        frame_abs0 <= abs_sample;

                    frame_i[wr_idx] <= i_data_i1;
                    frame_q[wr_idx] <= i_data_q1;

                    if (wr_idx == (BUF_LEN-1)) begin
                        wr_idx      <= '0;
                        scan_abs0   <= frame_abs0;
                        scan_active <= 1'b1;
                        sst         <= S_INIT;

                        $display("[%0t] CAP done: BUF_LEN=%0d abs0=%0d",
                                 $time, BUF_LEN, frame_abs0);
                    end else begin
                        wr_idx <= wr_idx + 1'b1;
                    end
                end
            end

            // -----------------------------------------------------------------
            // Scan phase: o_busy=1
            // -----------------------------------------------------------------
            else begin
                case (sst)
                    S_INIT: begin
                        scan_pos <= 32'd0;
                        tap_idx  <= 16'd0;

                        best0_mag <= '0; best1_mag <= '0; best2_mag <= '0;
                        best0_pos <= 32'd0; best1_pos <= 32'd0; best2_pos <= 32'd0;

                        sst <= S_FEED;
                    end

                    S_FEED: begin
                        if (tap_idx == (PSS_LEN-1)) begin
                            tap_idx <= 16'd0;
                            sst <= S_WAIT;
                        end else begin
                            tap_idx <= tap_idx + 1'b1;
                        end
                    end

                    S_WAIT: begin
                        if (wait_ready) begin
                            for (li=0; li<K_LANES; li=li+1) begin
                                if (lane_en[li]) begin
                                    c0_re_lat[li] <= c0_re[li]; c0_im_lat[li] <= c0_im[li];
                                    c1_re_lat[li] <= c1_re[li]; c1_im_lat[li] <= c1_im[li];
                                    c2_re_lat[li] <= c2_re[li]; c2_im_lat[li] <= c2_im[li];
                                end else begin
                                    c0_re_lat[li] <= '0; c0_im_lat[li] <= '0;
                                    c1_re_lat[li] <= '0; c1_im_lat[li] <= '0;
                                    c2_re_lat[li] <= '0; c2_im_lat[li] <= '0;
                                end
                            end
                            sst <= S_EVAL;
                        end
                    end

                    S_EVAL: begin
                        reg [MAG_W-1:0] mag0, mag1, mag2;
                        reg [31:0] pos_k;

                        for (li=0; li<K_LANES; li=li+1) begin
                            if (lane_en[li]) begin
                                pos_k = scan_pos + li;

                                mag0 = l1mag(c0_re_lat[li], c0_im_lat[li]);
                                mag1 = l1mag(c1_re_lat[li], c1_im_lat[li]);
                                mag2 = l1mag(c2_re_lat[li], c2_im_lat[li]);

                                if (mag0 > best0_mag) begin best0_mag <= mag0; best0_pos <= pos_k; end
                                if (mag1 > best1_mag) begin best1_mag <= mag1; best1_pos <= pos_k; end
                                if (mag2 > best2_mag) begin best2_mag <= mag2; best2_pos <= pos_k; end
                            end
                        end

                        if ((scan_pos + K_LANES) > MAX_POS) sst <= S_OUT;
                        else begin
                            scan_pos <= scan_pos + K_LANES;
                            sst <= S_FEED;
                        end
                    end

                    S_OUT: begin
                        reg [1:0]  win_idx;
                        reg [31:0] win_start_abs;
                        reg [31:0] win_peak_abs;

                        o_dbg_mag_pss0 <= best0_mag[33:0];
                        o_dbg_mag_pss1 <= best1_mag[33:0];
                        o_dbg_mag_pss2 <= best2_mag[33:0];

                        if ((best2_mag >= best1_mag) && (best2_mag >= best0_mag)) begin
                            win_idx       = 2'd2;
                            win_start_abs = scan_abs0 + best2_pos;
                        end else if (best1_mag >= best0_mag) begin
                            win_idx       = 2'd1;
                            win_start_abs = scan_abs0 + best1_pos;
                        end else begin
                            win_idx       = 2'd0;
                            win_start_abs = scan_abs0 + best0_pos;
                        end

                        win_peak_abs = win_start_abs + (PSS_LEN-1);

                        if (have_last_peak) pss_period_sps <= (win_peak_abs - last_peak_abs);
                        else                pss_period_sps <= 32'd0;

                        last_peak_abs  <= win_peak_abs;
                        have_last_peak <= 1'b1;

                        o_pss_idx   <= win_idx[$clog2(`LTE_PSS_COUNT)-1:0];
                        o_shift     <= win_peak_abs;
                        o_pss_valid <= 1'b1;

                        $display("[%0t] PEAK(K_LANES=%0d): PSS0 start=%0d peak=%0d mag=%0d | PSS1 start=%0d peak=%0d mag=%0d | PSS2 start=%0d peak=%0d mag=%0d | WIN=%0d peak_abs=%0d | period=%0d",
                                 $time, K_LANES,
                                 scan_abs0 + best0_pos, scan_abs0 + best0_pos + (PSS_LEN-1), best0_mag,
                                 scan_abs0 + best1_pos, scan_abs0 + best1_pos + (PSS_LEN-1), best1_mag,
                                 scan_abs0 + best2_pos, scan_abs0 + best2_pos + (PSS_LEN-1), best2_mag,
                                 win_idx, win_peak_abs, pss_period_sps);

                        scan_active <= 1'b0;
                        sst         <= S_IDLE;
                    end

                    default: begin
                        scan_active <= 1'b0;
                        sst         <= S_IDLE;
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // PSS load FSM
    // =========================================================================
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
                        $display("[%0t] PSS0/PSS1/PSS2 loaded (direct taps, len=%0d)", $time, PSS_LEN);
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

endmodule


// ============================================================================
// Wrapper
// ============================================================================
module lte_phy_sync #(
    parameter int K_LANES        = 2,
    parameter int FMA_PIPE_SIZE  = 1,
    parameter int FMA_ACC_SIZE   = 48,
    parameter int LTE_PSS_TD_LEN = 128
)(
    input  wire                               i_clk,
    input  wire                               i_rst,
    input  wire signed [`HW_ADC_WIDTH-1:0]    i_data_i1,
    input  wire signed [`HW_ADC_WIDTH-1:0]    i_data_q1,
    input  wire                               i_valid,

    output wire [$clog2(`LTE_PSS_COUNT)-1:0]  o_pss_idx,
    output wire                               o_pss_valid,
    output wire [31:0]                        o_shift,
    output wire                               o_busy,

    output wire [33:0]                        o_dbg_mag_pss0,
    output wire [33:0]                        o_dbg_mag_pss1,
    output wire [33:0]                        o_dbg_mag_pss2
);
    lte_pss_detector #(
        .K_LANES(K_LANES),
        .FMA_PIPE_SIZE(FMA_PIPE_SIZE),
        .FMA_ACC_SIZE(FMA_ACC_SIZE),
        .LTE_PSS_TD_LEN(LTE_PSS_TD_LEN)
    ) u_det (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_data_i1(i_data_i1),
        .i_data_q1(i_data_q1),
        .i_valid(i_valid),
        .o_pss_idx(o_pss_idx),
        .o_pss_valid(o_pss_valid),
        .o_shift(o_shift),
        .o_busy(o_busy),
        .o_dbg_mag_pss0(o_dbg_mag_pss0),
        .o_dbg_mag_pss1(o_dbg_mag_pss1),
        .o_dbg_mag_pss2(o_dbg_mag_pss2)
    );
endmodule