`include "lte_hw_params.vh"

module lte_pss_corr_engine #(
    parameter int PSS_TD_LEN     = 128,
    parameter int TARGET_FS      = 1_920_000, // stub for now
    parameter int CORR_W         = 16,
    parameter int ACC_W          = 48,
    parameter int K_TAPS         = 2
)(
    input  wire                               i_clk,
    input  wire                               i_rst,

    // fast-domain sample strobe
    input  wire                               i_sample_ce,
    input  wire signed [`HW_ADC_WIDTH-1:0]    i_data_i,
    input  wire signed [`HW_ADC_WIDTH-1:0]    i_data_q,

    output wire                               o_busy,
    output reg                                o_overrun,

    output reg                                o_corr_valid,
    output reg  [31:0]                        o_corr_shift,    // absolute END sample index
    output reg  [33:0]                        o_mag_pss0,
    output reg  [33:0]                        o_mag_pss1,
    output reg  [33:0]                        o_mag_pss2
);

    localparam int L              = PSS_TD_LEN;
    localparam int PSS_ADDR_WIDTH = `LTE_PSS_ADDR_WIDTH;
    localparam int ADC_W          = `HW_ADC_WIDTH;
    localparam int TAP_AW         = (L <= 1) ? 1 : $clog2(L);
    localparam int FILL_W         = (L <= 1) ? 1 : $clog2(L + 1);

    // -------------------------------------------------------------------------
    // helpers
    // -------------------------------------------------------------------------
    function automatic signed [CORR_W-1:0] sx_adc(input signed [ADC_W-1:0] v);
        if (CORR_W == ADC_W) sx_adc = v;
        else                 sx_adc = {{(CORR_W-ADC_W){v[ADC_W-1]}}, v};
    endfunction

    function automatic [ACC_W+1:0] abs_s(input signed [ACC_W-1:0] v);
        abs_s = v[ACC_W-1] ? $unsigned(-v) : $unsigned(v);
    endfunction

    function automatic [ACC_W+1:0] l1mag(
        input signed [ACC_W-1:0] re,
        input signed [ACC_W-1:0] im
    );
        l1mag = abs_s(re) + abs_s(im);
    endfunction

    function automatic [TAP_AW-1:0] idx_wrap(
        input [TAP_AW:0] v
    );
        if (v >= L) idx_wrap = v - L;
        else        idx_wrap = v[TAP_AW-1:0];
    endfunction

    // -------------------------------------------------------------------------
    // PSS ROM loader
    // -------------------------------------------------------------------------
    reg                      rom_ena;
    reg [PSS_ADDR_WIDTH-1:0] rom_addr_cnt;
    wire [31:0]              douta_pss0, douta_pss1, douta_pss2;

    generate
        if (L == 128) begin : gen_pss0_128
            pss_0_rom_td_128sps u_pss0 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss0));
        end else begin : gen_pss0_256
            pss_0_rom_td_256sps u_pss0 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss0));
        end
    endgenerate

    generate
        if (L == 128) begin : gen_pss1_128
            pss_1_rom_td_128sps u_pss1 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss1));
        end else begin : gen_pss1_256
            pss_1_rom_td_256sps u_pss1 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss1));
        end
    endgenerate

    generate
        if (L == 128) begin : gen_pss2_128
            pss_2_rom_td_128sps u_pss2 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss2));
        end else begin : gen_pss2_256
            pss_2_rom_td_256sps u_pss2 (.clka(i_clk), .ena(rom_ena), .addra(rom_addr_cnt), .douta(douta_pss2));
        end
    endgenerate

    reg signed [15:0] pss0_i_mem [0:L-1];
    reg signed [15:0] pss0_q_mem [0:L-1];
    reg signed [15:0] pss1_i_mem [0:L-1];
    reg signed [15:0] pss1_q_mem [0:L-1];
    reg signed [15:0] pss2_i_mem [0:L-1];
    reg signed [15:0] pss2_q_mem [0:L-1];

    reg                      pss_loaded;
    reg [31:0]               dout0_d, dout1_d, dout2_d;
    reg [PSS_ADDR_WIDTH-1:0] load_wr;

    localparam [1:0] L_IDLE=2'd0, L_PRIME=2'd1, L_RUN=2'd2, L_DONE=2'd3;
    reg [1:0] load_state;

    integer jj;
    always @(posedge i_clk) begin
        if (i_rst) begin
            load_state   <= L_IDLE;
            rom_ena      <= 1'b0;
            rom_addr_cnt <= '0;
            load_wr      <= '0;
            dout0_d      <= 32'd0;
            dout1_d      <= 32'd0;
            dout2_d      <= 32'd0;
            pss_loaded   <= 1'b0;

            for (jj=0; jj<L; jj=jj+1) begin
                pss0_i_mem[jj] <= '0; pss0_q_mem[jj] <= '0;
                pss1_i_mem[jj] <= '0; pss1_q_mem[jj] <= '0;
                pss2_i_mem[jj] <= '0; pss2_q_mem[jj] <= '0;
            end
        end else begin
            dout0_d <= douta_pss0;
            dout1_d <= douta_pss1;
            dout2_d <= douta_pss2;

            case (load_state)
                L_IDLE: begin
                    pss_loaded   <= 1'b0;
                    rom_ena      <= 1'b1;
                    rom_addr_cnt <= '0;
                    load_wr      <= '0;
                    load_state   <= L_PRIME;
                end

                L_PRIME: begin
                    rom_addr_cnt <= 1;
                    load_state   <= L_RUN;
                end

                L_RUN: begin
                    pss0_i_mem[load_wr] <= $signed(dout0_d[15:0]);
                    pss0_q_mem[load_wr] <= $signed(dout0_d[31:16]);

                    pss1_i_mem[load_wr] <= $signed(dout1_d[15:0]);
                    pss1_q_mem[load_wr] <= $signed(dout1_d[31:16]);

                    pss2_i_mem[load_wr] <= $signed(dout2_d[15:0]);
                    pss2_q_mem[load_wr] <= $signed(dout2_d[31:16]);

                    if (load_wr == (L-1)) begin
                        rom_ena    <= 1'b0;
                        pss_loaded <= 1'b1;
                        load_state <= L_DONE;
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

    // -------------------------------------------------------------------------
    // sliding window ring buffer
    // wr_ptr points to location being overwritten by newest sample.
    // after write+increment, wr_ptr points to OLDEST sample of current full window.
    // -------------------------------------------------------------------------
    reg signed [ADC_W-1:0] rx_i_mem [0:L-1];
    reg signed [ADC_W-1:0] rx_q_mem [0:L-1];
    reg [TAP_AW-1:0]       wr_ptr;
    reg [FILL_W-1:0]       fill_count;

    reg [31:0]             abs_sample;

    // -------------------------------------------------------------------------
    // job control
    // -------------------------------------------------------------------------
    localparam [1:0] S_IDLE=2'd0, S_RUN=2'd1, S_DONE=2'd2;
    reg [1:0] sst;
    assign o_busy = !pss_loaded || (sst != S_IDLE);

    reg [31:0]       job_shift;
    reg [TAP_AW-1:0] job_base_ptr;   // oldest sample ptr for this job
    reg [TAP_AW:0]   tap_base;

    reg signed [ACC_W-1:0] acc0_re, acc0_im;
    reg signed [ACC_W-1:0] acc1_re, acc1_im;
    reg signed [ACC_W-1:0] acc2_re, acc2_im;

    integer t;
    integer buf_idx_i;

    reg signed [CORR_W-1:0] si, sq;
    reg signed [CORR_W-1:0] c0i, c0q, c1i, c1q, c2i, c2q;

    reg signed [ACC_W-1:0] next_acc0_re, next_acc0_im;
    reg signed [ACC_W-1:0] next_acc1_re, next_acc1_im;
    reg signed [ACC_W-1:0] next_acc2_re, next_acc2_im;

    always @(posedge i_clk) begin
        if (i_rst) begin
            wr_ptr      <= '0;
            fill_count  <= '0;
            abs_sample  <= 32'd0;
            sst         <= S_IDLE;
            tap_base    <= '0;
            job_shift   <= 32'd0;
            job_base_ptr<= '0;

            acc0_re <= '0; acc0_im <= '0;
            acc1_re <= '0; acc1_im <= '0;
            acc2_re <= '0; acc2_im <= '0;

            o_corr_valid <= 1'b0;
            o_corr_shift <= 32'd0;
            o_mag_pss0   <= 34'd0;
            o_mag_pss1   <= 34'd0;
            o_mag_pss2   <= 34'd0;
            o_overrun    <= 1'b0;

            for (jj=0; jj<L; jj=jj+1) begin
                rx_i_mem[jj] <= '0;
                rx_q_mem[jj] <= '0;
            end
        end else begin
            o_corr_valid <= 1'b0;

            // -------------------------------------------------------------
            // input sample arrival
            // -------------------------------------------------------------
            if (i_sample_ce && pss_loaded) begin
                if (sst != S_IDLE) begin
                    o_overrun <= 1'b1; // this config does not keep up
                end else begin
                    // write newest sample
                    rx_i_mem[wr_ptr] <= i_data_i;
                    rx_q_mem[wr_ptr] <= i_data_q;

                    // after increment wr_ptr points to oldest sample
                    if (wr_ptr == (L-1))
                        wr_ptr <= '0;
                    else
                        wr_ptr <= wr_ptr + 1'b1;

                    if (fill_count != L)
                        fill_count <= fill_count + 1'b1;

                    // absolute END sample index
                    job_shift <= abs_sample;
                    abs_sample <= abs_sample + 1'b1;

                    // store job base ptr = pointer AFTER write = oldest sample ptr
                    if (wr_ptr == (L-1))
                        job_base_ptr <= '0;
                    else
                        job_base_ptr <= wr_ptr + 1'b1;

                    if (fill_count >= (L-1)) begin
                        // start correlation job
                        tap_base <= '0;

                        acc0_re <= '0; acc0_im <= '0;
                        acc1_re <= '0; acc1_im <= '0;
                        acc2_re <= '0; acc2_im <= '0;

                        sst <= S_RUN;
                    end
                end
            end

            // -------------------------------------------------------------
            // run K taps per fast clock
            // -------------------------------------------------------------
            if (sst == S_RUN) begin
                next_acc0_re = acc0_re; next_acc0_im = acc0_im;
                next_acc1_re = acc1_re; next_acc1_im = acc1_im;
                next_acc2_re = acc2_re; next_acc2_im = acc2_im;

                for (t = 0; t < K_TAPS; t = t + 1) begin
                    if ((tap_base + t) < L) begin
                        buf_idx_i = job_base_ptr + tap_base + t;
                        if (buf_idx_i >= L)
                            buf_idx_i = buf_idx_i - L;

                        si  = sx_adc(rx_i_mem[buf_idx_i[TAP_AW-1:0]]);
                        sq  = sx_adc(rx_q_mem[buf_idx_i[TAP_AW-1:0]]);

                        c0i = pss0_i_mem[tap_base + t];
                        c0q = pss0_q_mem[tap_base + t];
                        c1i = pss1_i_mem[tap_base + t];
                        c1q = pss1_q_mem[tap_base + t];
                        c2i = pss2_i_mem[tap_base + t];
                        c2q = pss2_q_mem[tap_base + t];

                        // s * conj(c)
                        next_acc0_re = next_acc0_re + ($signed(si) * $signed(c0i)) + ($signed(sq) * $signed(c0q));
                        next_acc0_im = next_acc0_im + ($signed(sq) * $signed(c0i)) - ($signed(si) * $signed(c0q));

                        next_acc1_re = next_acc1_re + ($signed(si) * $signed(c1i)) + ($signed(sq) * $signed(c1q));
                        next_acc1_im = next_acc1_im + ($signed(sq) * $signed(c1i)) - ($signed(si) * $signed(c1q));

                        next_acc2_re = next_acc2_re + ($signed(si) * $signed(c2i)) + ($signed(sq) * $signed(c2q));
                        next_acc2_im = next_acc2_im + ($signed(sq) * $signed(c2i)) - ($signed(si) * $signed(c2q));
                    end
                end

                acc0_re <= next_acc0_re; acc0_im <= next_acc0_im;
                acc1_re <= next_acc1_re; acc1_im <= next_acc1_im;
                acc2_re <= next_acc2_re; acc2_im <= next_acc2_im;

                if ((tap_base + K_TAPS) >= L) begin
                    sst <= S_DONE;
                end else begin
                    tap_base <= tap_base + K_TAPS;
                end
            end

            // -------------------------------------------------------------
            // finish job -> output mags for THIS shift
            // -------------------------------------------------------------
            if (sst == S_DONE) begin
                o_corr_valid <= 1'b1;
                o_corr_shift <= job_shift;
                o_mag_pss0   <= l1mag(acc0_re, acc0_im);
                o_mag_pss1   <= l1mag(acc1_re, acc1_im);
                o_mag_pss2   <= l1mag(acc2_re, acc2_im);
            
                sst <= S_IDLE;
            end
        end
    end

endmodule

module lte_pss_period_peak_reducer #(
    parameter int TARGET_FS = 1_920_000
)(
    input  wire                               i_clk,
    input  wire                               i_rst,

    input  wire                               i_corr_valid,
    input  wire [31:0]                        i_corr_shift,
    input  wire [33:0]                        i_mag_pss0,
    input  wire [33:0]                        i_mag_pss1,
    input  wire [33:0]                        i_mag_pss2,

    output reg                                o_pss_valid,
    output reg  [$clog2(`LTE_PSS_COUNT)-1:0]  o_pss_idx,
    output reg  [31:0]                        o_shift,
    output reg  [33:0]                        o_dbg_mag_pss0,
    output reg  [33:0]                        o_dbg_mag_pss1,
    output reg  [33:0]                        o_dbg_mag_pss2
);

    localparam int PSS_PERIOD_SPS = TARGET_FS / 200;

    reg [31:0] period_end;

    reg                               best_valid;
    reg [33:0]                        best_mag;
    reg [$clog2(`LTE_PSS_COUNT)-1:0]  best_idx;
    reg [31:0]                        best_shift;
    reg [33:0]                        best_mag0;
    reg [33:0]                        best_mag1;
    reg [33:0]                        best_mag2;

    always @(posedge i_clk) begin
        if (i_rst) begin
            period_end    <= PSS_PERIOD_SPS - 1;

            best_valid    <= 1'b0;
            best_mag      <= 34'd0;
            best_idx      <= '0;
            best_shift    <= 32'd0;
            best_mag0     <= 34'd0;
            best_mag1     <= 34'd0;
            best_mag2     <= 34'd0;

            o_pss_valid   <= 1'b0;
            o_pss_idx     <= '0;
            o_shift       <= 32'd0;
            o_dbg_mag_pss0<= 34'd0;
            o_dbg_mag_pss1<= 34'd0;
            o_dbg_mag_pss2<= 34'd0;
        end else begin
            o_pss_valid <= 1'b0;

            if (i_corr_valid) begin
                reg [33:0] cur_best_mag;
                reg [$clog2(`LTE_PSS_COUNT)-1:0] cur_best_idx;
                reg use_cur;

                if ((i_mag_pss2 >= i_mag_pss1) && (i_mag_pss2 >= i_mag_pss0)) begin
                    cur_best_mag = i_mag_pss2;
                    cur_best_idx = 2;
                end else if (i_mag_pss1 >= i_mag_pss0) begin
                    cur_best_mag = i_mag_pss1;
                    cur_best_idx = 1;
                end else begin
                    cur_best_mag = i_mag_pss0;
                    cur_best_idx = 0;
                end

                use_cur = (!best_valid) || (cur_best_mag > best_mag);

                if (use_cur) begin
                    best_valid <= 1'b1;
                    best_mag   <= cur_best_mag;
                    best_idx   <= cur_best_idx;
                    best_shift <= i_corr_shift;
                    best_mag0  <= i_mag_pss0;
                    best_mag1  <= i_mag_pss1;
                    best_mag2  <= i_mag_pss2;
                end

                if (i_corr_shift >= period_end) begin
                    if (use_cur) begin
                        o_pss_valid    <= 1'b1;
                        o_pss_idx      <= cur_best_idx;
                        o_shift        <= i_corr_shift;
                        o_dbg_mag_pss0 <= i_mag_pss0;
                        o_dbg_mag_pss1 <= i_mag_pss1;
                        o_dbg_mag_pss2 <= i_mag_pss2;
                    end else if (best_valid) begin
                        o_pss_valid    <= 1'b1;
                        o_pss_idx      <= best_idx;
                        o_shift        <= best_shift;
                        o_dbg_mag_pss0 <= best_mag0;
                        o_dbg_mag_pss1 <= best_mag1;
                        o_dbg_mag_pss2 <= best_mag2;
                    end

                    period_end <= period_end + PSS_PERIOD_SPS;

                    best_valid <= 1'b0;
                    best_mag   <= 34'd0;
                    best_idx   <= '0;
                    best_shift <= 32'd0;
                    best_mag0  <= 34'd0;
                    best_mag1  <= 34'd0;
                    best_mag2  <= 34'd0;
                end
            end
        end
    end

endmodule