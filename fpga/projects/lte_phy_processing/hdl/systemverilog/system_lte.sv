module system_lte #(
    // размерность данных верхнего уровня
    parameter int DATA_W            = 16,
    // оставлено для совместимости интерфейса
    parameter int LTE_CORR_FS       = 1_920_000,
    // число MAC-тапов за такт в корреляторе
    parameter int LTE_CORR_LANES    = 4,
    // длительность PSS в семплах
    parameter int LTE_PSS_TD_LEN    = 128,

    parameter int LTE_TARGET_FS     = 1_920_000
)(
    input  wire                           i_clk,
    input  wire                           i_rst,

    input  wire signed [DATA_W-1:0]       i_data_i1,
    input  wire signed [DATA_W-1:0]       i_data_q1,
    input  wire                           i_data_valid_i1,
    input  wire                           i_data_valid_q1,

    output wire signed [DATA_W-1:0]       o_data_i1,
    output wire signed [DATA_W-1:0]       o_data_q1,
    output wire                           o_data_valid_1,

    output wire [2:0]                     o_dbg_pss_idx,
    output wire [31:0]                    o_dbg_shift,

    output wire [33:0]                    o_dbg_mag_pss0,
    output wire [33:0]                    o_dbg_mag_pss1,
    output wire [33:0]                    o_dbg_mag_pss2
);

    localparam int ADC_W = DATA_W;

    // -------------------------------------------------------------------------
    // input valid
    // -------------------------------------------------------------------------
    wire w_iq_valid;
    assign w_iq_valid = i_data_valid_i1 && i_data_valid_q1;

    // -------------------------------------------------------------------------
    // приведение DATA_W -> HW_ADC_WIDTH
    // -------------------------------------------------------------------------
    function automatic signed [ADC_W-1:0] cast_to_adc_w(
        input signed [DATA_W-1:0] din
    );
        begin
            if (DATA_W >= ADC_W)
                cast_to_adc_w = din[ADC_W-1:0];
            else
                cast_to_adc_w = {{(ADC_W-DATA_W){din[DATA_W-1]}}, din};
        end
    endfunction

    wire signed [ADC_W-1:0] w_corr_i;
    wire signed [ADC_W-1:0] w_corr_q;

    assign w_corr_i = cast_to_adc_w(i_data_i1);
    assign w_corr_q = cast_to_adc_w(i_data_q1);

    // -------------------------------------------------------------------------
    // corr engine -> period peak reducer
    // -------------------------------------------------------------------------
    wire         w_corr_busy;
    wire         w_corr_overrun;
    wire         w_corr_valid;
    wire [31:0]  w_corr_shift;
    wire [33:0]  w_mag_pss0;
    wire [33:0]  w_mag_pss1;
    wire [33:0]  w_mag_pss2;

    wire         w_pss_valid;
    wire [$clog2(`LTE_PSS_COUNT)-1:0] w_pss_idx;
    wire [31:0]  w_pss_shift;
    wire [33:0]  w_dbg_mag_pss0;
    wire [33:0]  w_dbg_mag_pss1;
    wire [33:0]  w_dbg_mag_pss2;

    // NOTE:
    // LTE_CORR_FS оставлен в интерфейсе для совместимости,
    // но здесь не используется — периодика в reducer задаётся через TARGET_FS.
    lte_pss_corr_engine #(
        .PSS_TD_LEN (LTE_PSS_TD_LEN),
        .TARGET_FS  (LTE_TARGET_FS),
        .K_TAPS     (LTE_CORR_LANES)
    ) u_lte_pss_corr_engine (
        .i_clk       (i_clk),
        .i_rst       (i_rst),
        .i_sample_ce (w_iq_valid),
        .i_data_i    (w_corr_i),
        .i_data_q    (w_corr_q),
        .o_busy      (w_corr_busy),
        .o_overrun   (w_corr_overrun),
        .o_corr_valid(w_corr_valid),
        .o_corr_shift(w_corr_shift),
        .o_mag_pss0  (w_mag_pss0),
        .o_mag_pss1  (w_mag_pss1),
        .o_mag_pss2  (w_mag_pss2)
    );

    lte_pss_period_peak_reducer #(
        .TARGET_FS(LTE_TARGET_FS)
    ) u_lte_pss_period_peak_reducer (
        .i_clk        (i_clk),
        .i_rst        (i_rst),
        .i_corr_valid (w_corr_valid),
        .i_corr_shift (w_corr_shift),
        .i_mag_pss0   (w_mag_pss0),
        .i_mag_pss1   (w_mag_pss1),
        .i_mag_pss2   (w_mag_pss2),
        .o_pss_valid  (w_pss_valid),
        .o_pss_idx    (w_pss_idx),
        .o_shift      (w_pss_shift),
        .o_dbg_mag_pss0(w_dbg_mag_pss0),
        .o_dbg_mag_pss1(w_dbg_mag_pss1),
        .o_dbg_mag_pss2(w_dbg_mag_pss2)
    );

    // -------------------------------------------------------------------------
    // outputs
    // -------------------------------------------------------------------------
    assign o_dbg_pss_idx  = {{(3-$clog2(`LTE_PSS_COUNT)){1'b0}}, w_pss_idx};
    assign o_dbg_shift    = w_pss_shift;
    assign o_dbg_mag_pss0 = w_dbg_mag_pss0;
    assign o_dbg_mag_pss1 = w_dbg_mag_pss1;
    assign o_dbg_mag_pss2 = w_dbg_mag_pss2;

    // В текущем интерфейсе полезного data-path после детектора нет,
    // поэтому оставляем IQ-выходы заглушкой, а valid = pulse детекта PSS.
    assign o_data_i1      = '0;
    assign o_data_q1      = '0;
    assign o_data_valid_1 = w_pss_valid;

endmodule