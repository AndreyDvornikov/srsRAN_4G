`timescale 1ns/1ps
`include "lte_hw_params.vh"

module testbench_ccf;

    // ========================================================================
    // Clock & Reset
    // ========================================================================
    logic clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz
    
    logic rst;

    // ========================================================================
    // Параметры теста
    // ========================================================================
    localparam int PSS_LEN_128 = 128;
    localparam int PSS_LEN_256 = 256;
    localparam int TEST_MODE_128 = 0;  // 0 - тест 128sps, 1 - тест 256sps
    
    // Размер накопителя для корреляции (зависит от битности и длины последовательности)
    // WIDTH=16, SEQ_SIZE=128 -> нужно log2(128 * 2^32) ≈ 39 бит
    localparam int FMA_ACC_SIZE = 39;
    
    // ========================================================================
    // ROM интерфейсы
    // ========================================================================
    logic        ena_128, ena_256;
    logic [6:0]  addra_128;
    logic [7:0]  addra_256;
    
    logic [31:0] douta_pss0_128, douta_pss0_256;
    logic [31:0] douta_pss1_128, douta_pss1_256;
    logic [31:0] douta_pss2_128, douta_pss2_256;

    // ========================================================================
    // PSS ROM instances
    // ========================================================================
    pss_0_rom_td_128sps pss_0_rom_td_128sps_dut (
        .clka   (clk),
        .ena    (ena_128),
        .addra  (addra_128),
        .douta  (douta_pss0_128)
    );

    pss_0_rom_td_256sps pss_0_rom_td_256sps_dut (
        .clka   (clk),
        .ena    (ena_256),
        .addra  (addra_256),
        .douta  (douta_pss0_256)
    );

    pss_1_rom_td_128sps pss_1_rom_td_128sps_dut (
        .clka   (clk),
        .ena    (ena_128),
        .addra  (addra_128),
        .douta  (douta_pss1_128)
    );

    pss_1_rom_td_256sps pss_1_rom_td_256sps_dut (
        .clka   (clk),
        .ena    (ena_256),
        .addra  (addra_256),
        .douta  (douta_pss1_256)
    );

    pss_2_rom_td_128sps pss_2_rom_td_128sps_dut (
        .clka   (clk),
        .ena    (ena_128),
        .addra  (addra_128),
        .douta  (douta_pss2_128)
    );

    pss_2_rom_td_256sps pss_2_rom_td_256sps_dut (
        .clka   (clk),
        .ena    (ena_256),
        .addra  (addra_256),
        .douta  (douta_pss2_256)
    );

    // ========================================================================
    // Распаковка I/Q из ROM
    // ========================================================================
    wire signed [15:0] pss0_128_i = douta_pss0_128[15:0];
    wire signed [15:0] pss0_128_q = douta_pss0_128[31:16];
    wire signed [15:0] pss0_256_i = douta_pss0_256[15:0];
    wire signed [15:0] pss0_256_q = douta_pss0_256[31:16];
    
    wire signed [15:0] pss1_128_i = douta_pss1_128[15:0];
    wire signed [15:0] pss1_128_q = douta_pss1_128[31:16];
    wire signed [15:0] pss1_256_i = douta_pss1_256[15:0];
    wire signed [15:0] pss1_256_q = douta_pss1_256[31:16];
    
    wire signed [15:0] pss2_128_i = douta_pss2_128[15:0];
    wire signed [15:0] pss2_128_q = douta_pss2_128[31:16];
    wire signed [15:0] pss2_256_i = douta_pss2_256[15:0];
    wire signed [15:0] pss2_256_q = douta_pss2_256[31:16];

    // ========================================================================
    // Correlator inputs (data stream 1 - входящий сигнал)
    // ========================================================================
    logic signed [15:0] data1_i, data1_q;
    logic               data1_valid;
    
    // ========================================================================
    // Correlator inputs (data stream 2 - эталонная последовательность PSS)
    // ========================================================================
    logic signed [15:0] data2_i, data2_q;
    logic               data2_valid;

    // ========================================================================
    // Correlator outputs
    // ========================================================================
    logic               corr_valid_pss0, corr_valid_pss1, corr_valid_pss2;
    logic signed [FMA_ACC_SIZE-1:0] corr_re_pss0, corr_im_pss0;
    logic signed [FMA_ACC_SIZE-1:0] corr_re_pss1, corr_im_pss1;
    logic signed [FMA_ACC_SIZE-1:0] corr_re_pss2, corr_im_pss2;

    // ========================================================================
    // PSS0 Correlator
    // ========================================================================
    math_complex_corr #(
        .WIDTH          (`HW_ADC_WIDTH),
        .CORR_SEQ_SIZE  (PSS_LEN_128),
        .fma_pipe_size  (1),
        .fma_acc_size   (FMA_ACC_SIZE)
    ) u_pss0_correlator (
        .i_rst          (rst),
        .i_clk          (clk),
        .i_data_i1      (data1_i),
        .i_data_q1      (data1_q),
        .i_data1_valid  (data1_valid),
        .i_data_i2      (pss0_128_i),
        .i_data_q2      (pss0_128_q),
        .i_data2_valid  (ena_128),
        .o_valid        (corr_valid_pss0),
        .o_re           (corr_re_pss0),
        .o_im           (corr_im_pss0)
    );

    // ========================================================================
    // PSS1 Correlator
    // ========================================================================
    math_complex_corr #(
        .WIDTH          (`HW_ADC_WIDTH),
        .CORR_SEQ_SIZE  (PSS_LEN_128),
        .fma_pipe_size  (1),
        .fma_acc_size   (FMA_ACC_SIZE)
    ) u_pss1_correlator (
        .i_rst          (rst),
        .i_clk          (clk),
        .i_data_i1      (data1_i),
        .i_data_q1      (data1_q),
        .i_data1_valid  (data1_valid),
        .i_data_i2      (pss1_128_i),
        .i_data_q2      (pss1_128_q),
        .i_data2_valid  (ena_128),
        .o_valid        (corr_valid_pss1),
        .o_re           (corr_re_pss1),
        .o_im           (corr_im_pss1)
    );

    // ========================================================================
    // PSS2 Correlator
    // ========================================================================
    math_complex_corr #(
        .WIDTH          (`HW_ADC_WIDTH),
        .CORR_SEQ_SIZE  (PSS_LEN_128),
        .fma_pipe_size  (1),
        .fma_acc_size   (FMA_ACC_SIZE)
    ) u_pss2_correlator (
        .i_rst          (rst),
        .i_clk          (clk),
        .i_data_i1      (data1_i),
        .i_data_q1      (data1_q),
        .i_data1_valid  (data1_valid),
        .i_data_i2      (pss2_128_i),
        .i_data_q2      (pss2_128_q),
        .i_data2_valid  (ena_128),
        .o_valid        (corr_valid_pss2),
        .o_re           (corr_re_pss2),
        .o_im           (corr_im_pss2)
    );

    // ========================================================================
    // Вычисление магнитуды корреляции (|C|² = Re² + Im²)
    // ========================================================================
    real mag_pss0, mag_pss1, mag_pss2;
    real mag_db_pss0, mag_db_pss1, mag_db_pss2;
    
    always_ff @(posedge clk) begin
        if (corr_valid_pss0) begin
            mag_pss0 = $sqrt($itor(corr_re_pss0)**2 + $itor(corr_im_pss0)**2);
            mag_db_pss0 = 20.0 * $log10(mag_pss0 + 1.0); // +1 чтобы избежать log(0)
        end
        
        if (corr_valid_pss1) begin
            mag_pss1 = $sqrt($itor(corr_re_pss1)**2 + $itor(corr_im_pss1)**2);
            mag_db_pss1 = 20.0 * $log10(mag_pss1 + 1.0);
        end
        
        if (corr_valid_pss2) begin
            mag_pss2 = $sqrt($itor(corr_re_pss2)**2 + $itor(corr_im_pss2)**2);
            mag_db_pss2 = 20.0 * $log10(mag_pss2 + 1.0);
        end
    end

    // ========================================================================
    // Счётчики для отслеживания пика корреляции
    // ========================================================================
    int sample_counter;
    real max_mag_pss0, max_mag_pss1, max_mag_pss2;
    int  max_idx_pss0, max_idx_pss1, max_idx_pss2;

    // ========================================================================
    // Testbench stimulus
    // ========================================================================
    initial begin
        $display("PSSSS %0d", $clog2(3));
        
        // �?нициализация
        rst = 1'b1;
        ena_128 = 1'b0;
        ena_256 = 1'b0;
        addra_128 = 7'd0;
        addra_256 = 8'd0;
        data1_i = 16'd0;
        data1_q = 16'd0;
        data1_valid = 1'b0;
        sample_counter = 0;
        max_mag_pss0 = 0.0;
        max_mag_pss1 = 0.0;
        max_mag_pss2 = 0.0;
        max_idx_pss0 = 0;
        max_idx_pss1 = 0;
        max_idx_pss2 = 0;

        repeat(10) @(posedge clk);
        rst = 1'b0;
        repeat(5) @(posedge clk);

        fork
            // Thread 1: Подача входного сигнала (data1 = PSS0)
            begin
                data1_valid = 1'b1;
                for (int i = 0; i < PSS_LEN_128; i++) begin
                    data1_i = pss0_128_i;
                    data1_q = pss0_128_q;
                    addra_128 = i[6:0];
                    @(posedge clk);
                    #1; // небольшая задержка для стабилизации сигналов
                end
                data1_valid = 1'b0;
            end

            // Thread 2: Чтение эталонной последовательности (data2 = PSS0)
            begin
                ena_128 = 1'b1;
                for (int i = 0; i < PSS_LEN_128; i++) begin
                    @(posedge clk);
                end
                ena_128 = 1'b0;
            end
        join

        // Ждём результата корреляции
        wait(corr_valid_pss0);
        
        $display("[%0t] PSS0 Autocorr: Re=%0d, Im=%0d, |C|=%.2f (%.2f dB)", 
                 $time, corr_re_pss0, corr_im_pss0, mag_pss0, mag_db_pss0);
        $display("[%0t] PSS1 Cross:    Re=%0d, Im=%0d, |C|=%.2f (%.2f dB)", 
                 $time, corr_re_pss1, corr_im_pss1, mag_pss1, mag_db_pss1);
        $display("[%0t] PSS2 Cross:    Re=%0d, Im=%0d, |C|=%.2f (%.2f dB)\n", 
                 $time, corr_re_pss2, corr_im_pss2, mag_pss2, mag_db_pss2);

        data1_valid = 1'b0;
        ena_128 = 1'b0;

        repeat(10) @(posedge clk);

        $display("\n[%0t] ============================================", $time);
        $display("[%0t] Test Results:", $time);
        $display("[%0t] ============================================", $time);
        $display("[%0t] Maximum correlation found at sample: %0d", $time, max_idx_pss0);
        $display("[%0t] Peak magnitude: %.2f (%.2f dB)", $time, max_mag_pss0, 20.0*$log10(max_mag_pss0+1.0));
        $display("[%0t] Expected peak at sample: ~%0d", $time, 64 + PSS_LEN_128);
        
        if (max_idx_pss0 >= 60 && max_idx_pss0 <= 200) begin
            $display("[%0t] ✓ PASS: Peak detected in expected range", $time);
        end else begin
            $display("[%0t] ✗ FAIL: Peak outside expected range!", $time);
        end

        repeat(20) @(posedge clk);

        $display("\n[%0t] Simulation completed successfully!", $time);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #50us;
        $display("\n[%0t] ERROR: Simulation timeout!", $time);
        $finish;
    end
endmodule
