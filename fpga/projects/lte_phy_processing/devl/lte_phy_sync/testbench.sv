`timescale 1ns/1ps
`include "lte_hw_params.vh"

module testbench;
    parameter longint CLK_HZ   = 200_000_000; // ������� ���� ������ �����������
    parameter longint FS_HZ    = 1_920_000;   // ������� ������� IQ samples
    parameter int     SPEEDUP  = 1;           // 1 = �������� Fs; >1 �������� ���

    localparam longint FS_EFF_HZ = FS_HZ * SPEEDUP;

    // ������ ����� (ns) ��� real
    real CLK_PERIOD_NS = 1e9 / CLK_HZ;

    // ============================
    // Clock / Reset
    // ============================
    logic clk = 1'b0;
    always #(CLK_PERIOD_NS/2.0) clk = ~clk;

    logic rst;

    // ============================
    // DUT I/O
    // ============================
    logic signed [`HW_ADC_WIDTH-1:0]    i_data_i1;
    logic signed [`HW_ADC_WIDTH-1:0]    i_data_q1;
    logic                               i_valid;

    logic [$clog2(`LTE_PSS_COUNT)-1:0]  o_pss_idx;
    logic                               o_pss_valid;
    logic [31:0]                        o_shift;
    logic                               o_busy;

    lte_phy_pss_detector #(
        .K_LANES(2)
    ) dut (
        .i_clk       (clk),
        .i_rst       (rst),
        .i_data_i1   (i_data_i1),
        .i_data_q1   (i_data_q1),
        .i_valid     (i_valid),
        .o_pss_idx   (o_pss_idx),
        .o_pss_valid (o_pss_valid),
        .o_shift     (o_shift),
        .o_busy      (o_busy)
    );

    // ============================
    // File reader
    // ============================
    int     fd;
    string  line;
    int     addr, val;
    int     r;
    int     sample_count;

    task automatic read_next_word(output int addr_out, output int val_out, output bit ok);
        ok = 1'b0;
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            if (r == 0) continue;
            r = $sscanf(line, "@%x %d", addr_out, val_out);
            if (r == 2) begin
                ok = 1'b1;
                return;
            end
        end
    endtask

    // ============================
    // i_valid generator
    //   clk     = ������� ���� ��������������� ������
    //   i_valid = 1-cycle strobe ������� ������ IQ sample
    //   ����� �����������, o_busy �� ������ ����� �� ������
    // ============================
    bit     use_int_div;
    int     ce_div;
    longint acc;     // DDS accumulator
    int     ce_cnt;
    bit     done;

    initial begin
        if (FS_EFF_HZ > CLK_HZ)
            $fatal(1, "ERROR: FS_EFF_HZ (%0d) must be <= CLK_HZ (%0d)", FS_EFF_HZ, CLK_HZ);

        if ((CLK_HZ % FS_EFF_HZ) == 0) begin
            use_int_div = 1'b1;
            ce_div = CLK_HZ / FS_EFF_HZ;
        end else begin
            use_int_div = 1'b0;
            ce_div = 0;
        end

        $display("TB: CLK_HZ=%0d, FS_HZ=%0d, SPEEDUP=%0d => FS_EFF_HZ=%0d", CLK_HZ, FS_HZ, SPEEDUP, FS_EFF_HZ);
        if (use_int_div)
            $display("TB: integer CE divider = %0d cycles/sample", ce_div);
        else
            $display("TB: fractional CE via DDS accumulator (�1 cycle jitter)");
    end

    always @(negedge clk) begin
        bit fire;
        bit ok_i, ok_q;
        int addr_i, addr_q;
        int val_i,  val_q;

        fire = 1'b0;

        if (rst) begin
            i_valid   <= 1'b0;
            i_data_i1 <= '0;
            i_data_q1 <= '0;
            ce_cnt    <= 0;
            acc       <= 0;
            done      <= 1'b0;
        end else if (!done) begin
            // default: ������ �� ��������
            i_valid <= 1'b0;

            // --- generate 1-cycle strobe fire ---
            if (use_int_div) begin
                if (ce_cnt == (ce_div-1)) begin
                    ce_cnt <= 0;
                    fire   = 1'b1;
                end else begin
                    ce_cnt <= ce_cnt + 1;
                end
            end else begin
                longint acc_next;
                acc_next = acc + FS_EFF_HZ;
                if (acc_next >= CLK_HZ) begin
                    acc  <= acc_next - CLK_HZ;
                    fire = 1'b1;
                end else begin
                    acc <= acc_next;
                end
            end

            // --- when strobe, read next IQ pair and put on bus ---
            if (fire) begin
                read_next_word(addr_i, val_i, ok_i);
                read_next_word(addr_q, val_q, ok_q);

                if (!ok_i || !ok_q) begin
                    done    <= 1'b1;
                    i_valid <= 1'b0;
                end else begin
                    i_valid      <= 1'b1;
                    i_data_i1    <= $signed(val_i);
                    i_data_q1    <= $signed(val_q);
                    sample_count <= sample_count + 1;
                end
            end
        end else begin
            i_valid <= 1'b0;
        end
    end

    // ============================
    // Monitor
    // ============================
    integer file;

    logic   o_busy_d;

    longint busy_cycles_cur;
    longint busy_cycles_max;
    longint busy_cycles_total;

    longint busy_samples_cur;
    longint busy_samples_max;
    longint busy_samples_total;

    int     busy_event_count;

    initial begin
        file = $fopen("pss_log.txt", "w");
    end

    always @(posedge clk) begin
        if (o_pss_valid) begin
            $display("[%0t] PSS%0d detected at sample position %0d (busy=%0b)",
                     $time, o_pss_idx, o_shift, o_busy);

            $fdisplay(file, "%0d;%0d", o_pss_idx, o_shift);
        end
    end

    // BUSY monitor:
    // ������� �������� "��������/�� ��������" = ������� i_valid ������ �� ����� o_busy=1
    always @(posedge clk) begin
        if (rst) begin
            o_busy_d           <= 1'b0;
            busy_cycles_cur    <= 0;
            busy_cycles_max    <= 0;
            busy_cycles_total  <= 0;
            busy_samples_cur   <= 0;
            busy_samples_max   <= 0;
            busy_samples_total <= 0;
            busy_event_count   <= 0;
        end else begin
            // ����� busy
            if (!o_busy_d && o_busy) begin
                busy_event_count <= busy_event_count + 1;
                busy_cycles_cur  <= 1;
                busy_samples_cur <= i_valid ? 1 : 0;

                $display("[%0t] BUSY rise: sample_count=%0d",
                         $time, sample_count);
            end
            // busy ������������
            else if (o_busy_d && o_busy) begin
                busy_cycles_cur <= busy_cycles_cur + 1;
                if (i_valid)
                    busy_samples_cur <= busy_samples_cur + 1;
            end
            // ���� busy
            else if (o_busy_d && !o_busy) begin
                busy_cycles_total  <= busy_cycles_total + busy_cycles_cur;
                busy_samples_total <= busy_samples_total + busy_samples_cur;

                if (busy_cycles_cur  > busy_cycles_max)  busy_cycles_max  <= busy_cycles_cur;
                if (busy_samples_cur > busy_samples_max) busy_samples_max <= busy_samples_cur;

                if (busy_samples_cur == 0) begin
                    $display("[%0t] BUSY fall: duration=%0d clk cycles, ignored_input_samples=%0d -> OK",
                             $time, busy_cycles_cur, busy_samples_cur);
                end else begin
                    $display("[%0t] BUSY fall: duration=%0d clk cycles, ignored_input_samples=%0d -> NOT KEEPING UP",
                             $time, busy_cycles_cur, busy_samples_cur);
                end

                if (use_int_div)
                    $display("         cycles/sample=%0d", ce_div);

                busy_cycles_cur  <= 0;
                busy_samples_cur <= 0;
            end

            o_busy_d <= o_busy;
        end
    end

    final begin
        $fclose(file);
    end

    // ============================
    // Main
    // ============================
    initial begin
        rst          = 1'b1;
        i_valid      = 1'b0;
        i_data_i1    = '0;
        i_data_q1    = '0;
        sample_count = 0;
        done         = 1'b0;

        fd = $fopen("input_signal.hex", "r");
        if (fd == 0) $fatal(1, "ERROR: Can't open input_signal.hex");

        repeat (20) @(posedge clk);
        rst <= 1'b0;

        // ��� ���� ���� ����������
        wait(done);

        $fclose(fd);
        $display("\n[%0t] All samples loaded (%0d IQ samples)", $time, sample_count);
        $display("[%0t] Waiting extra cycles...\n", $time);

        repeat (200000) @(posedge clk);

        $display("\nTB BUSY SUMMARY:");
        $display("  busy events                = %0d", busy_event_count);
        $display("  total busy cycles          = %0d", busy_cycles_total);
        $display("  max busy cycles            = %0d", busy_cycles_max);
        $display("  total ignored samples      = %0d", busy_samples_total);
        $display("  max ignored per busy burst = %0d", busy_samples_max);

        if (busy_samples_total == 0)
            $display("  RESULT: correlator keeps up with continuous stream");
        else
            $display("  RESULT: correlator does NOT keep up with continuous stream");

        $finish;
    end

    // �������
    initial begin
        #2s;
        $display("\n[%0t] ERROR: Simulation timeout!", $time);
        $finish;
    end

endmodule