`timescale 1ns/1ps
`include "../headers/header.svh"

`define DUT_NAME_1 dut_1

module tb_math_fma_macro;
    logic clk;

    localparam int C_BIT_DEPTH   = 64;
    localparam int FMA_PIPE_SIZE = 1;

    // Interface + DUT
    fma_if #(
        .A_W (`HW_ADC_WIDTH),
        .B_W (`HW_ADC_WIDTH),
        .C_W (C_BIT_DEPTH),
        .F_W (C_BIT_DEPTH),
        .AB_W(`HW_ADC_WIDTH+`HW_ADC_WIDTH) // смотри примечание про ширину ниже
    ) vif(clk);

    math_fma_macro #(
        .A_WIDTH(`HW_ADC_WIDTH),
        .B_WIDTH(`HW_ADC_WIDTH),
        .C_WIDTH(C_BIT_DEPTH),
        .PIPE   (FMA_PIPE_SIZE)
    ) `DUT_NAME_1 (
        .i_clk   (clk),
        .i_rst   (vif.rst),
        .A       (vif.A),
        .B       (vif.B),
        .C       (vif.C),
        .i_valid (vif.i_valid),
        .F       (vif.F),
        .F_mul   (vif.F_mul),
        .o_valid (vif.o_valid)
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

    task automatic tick(); 
        @(posedge clk);
    endtask 

    // reset in cycles
    task automatic fma_reset(int ticks);
        tick_cb();
        vif.cb.rst <= 1'b1;

        repeat (ticks) tick_cb();

        tick_cb();
        vif.cb.rst <= 1'b0;
    endtask

    // verify reset state (white-box)
    task static v1_verify_rst();
        integer j;
        logic   error_found;

        error_found = 1'b0;

        fma_reset(1);

        $display("[VERIFY] Checking reset state at t=%0t", $time);

        if (`DUT_NAME_1.pipe_i_valid !== '0) begin
            $error("[FAIL] pipe_i_valid = %b, expected 0", dut_1.pipe_i_valid);
            error_found = 1'b1;
        end

        for (j = 0; j < dut_1.PIPE; j++) begin
            if (`DUT_NAME_1.pipe_a[j] !== '0) begin
                $error("[FAIL] pipe_a[%0d] = %0d, expected 0", j, dut_1.pipe_a[j]);
                error_found = 1'b1;
            end

            if (`DUT_NAME_1.pipe_b[j] !== '0) begin
                $error("[FAIL] pipe_b[%0d] = %0d, expected 0", j, dut_1.pipe_b[j]);
                error_found = 1'b1;
            end

            if (`DUT_NAME_1.pipe_c[j] !== '0) begin
                $error("[FAIL] pipe_c[%0d] = %0d, expected 0", j, dut_1.pipe_c[j]);
                error_found = 1'b1;
            end
        end

        if (`DUT_NAME_1.mul_ff[0] !== '0 || dut_1.mul_ff[1] !== '0) begin
            $error("[FAIL] mul_ff[0/1] not zero after reset");
            error_found = 1'b1;
        end

        if (`DUT_NAME_1.c_ff !== '0) begin
            $error("[FAIL] c_ff = %0d, expected 0", dut_1.c_ff);
            error_found = 1'b1;
        end

        if (`DUT_NAME_1.op_valid !== '0) begin
            $error("[FAIL] op_valid = %0d, expected 0", dut_1.op_valid);
            error_found = 1'b1;
        end

        if (`DUT_NAME_1.res_ff !== '0) begin
            $error("[FAIL] res_ff = %0d, expected 0", dut_1.res_ff);
            error_found = 1'b1;
        end

        if (vif.cb.o_valid !== 1'b0) begin
            $error("[FAIL] o_valid = %b, expected 0", vif.cb.o_valid);
            error_found = 1'b1;
        end

        if (!error_found) begin
            $display("[PASS] [v1_verify_rst] All registers reset correctly");
        end
    endtask

    task automatic push_fma(
        logic signed [`DUT_NAME_1.A_WIDTH - 1:0] a,
        logic signed [`DUT_NAME_1.B_WIDTH - 1:0] b,
        logic signed [`DUT_NAME_1.C_WIDTH - 1:0] c
    );
        $display("pushed [a=%0d][b=%0d][c=%0d]", a, b, c);

        vif.cb.A       <= a;
        vif.cb.B       <= b;
        vif.cb.C       <= c;
        vif.cb.i_valid <= 1'b1;
        
        tick_cb();
    endtask

    task automatic fma_pipe_ticks_behv(
        logic signed [dut_1.A_WIDTH-1:0] test_a, 
        logic signed [dut_1.B_WIDTH-1:0] test_b,
        logic signed [dut_1.C_WIDTH-1:0] test_c
    );
        logic signed [C_BIT_DEPTH-1:0]   expected_result;
        integer cycle_count;
        logic   result_ok;

        //
        localparam int EXPECTED_FMA_PIPE_TICKS = FMA_PIPE_SIZE + 1;

        $display("\n[TEST] fma_pipe_ticks_behv: Checking pipeline delay");
        $display("[TEST] Expected delay from i_valid to o_valid: %0d cycles", FMA_PIPE_SIZE);

        expected_result = test_a * test_b + test_c;

        $display("[TEST] Test values: A=%0d, B=%0d, C=%0d, Expected F=%0d",
                test_a, test_b, test_c, expected_result);

        push_fma(test_a, test_b, test_c);

        // в push_fma мы лишь публикуем данные
        // поэтому будем ждать когда в след. событии dut их подхватит
        tick_cb();  

        cycle_count = 0;
        result_ok   = 1'b0;

        while (cycle_count < (FMA_PIPE_SIZE + 5)) begin
            if (vif.cb.o_valid === 1'b1) begin
                $display("[TEST] o_valid asserted at cycle %0d (t=%0t)", cycle_count, $time);

                if (cycle_count == EXPECTED_FMA_PIPE_TICKS) begin
                    $display("[PASS] Pipeline delay correct: %0d cycles", cycle_count);
                end else begin
                    $error("[FAIL] Pipeline delay incorrect: got %0d, expected %0d",
                        cycle_count, EXPECTED_FMA_PIPE_TICKS);
                end

                if (vif.cb.F === expected_result) begin
                    $display("[PASS] Result correct: F=%0d", vif.cb.F);
                end else begin
                    $error("[FAIL] Result incorrect: F=%0d, expected %0d", vif.cb.F, expected_result);
                end

                result_ok = 1'b1;
                break;
            end

            tick_cb(); 
            cycle_count++;
        end

        if (!result_ok) begin
            $error("[FAIL] o_valid never asserted within %0d cycles", cycle_count);
        end

        $display("[TEST] fma_pipe_ticks_behv completed\n");
    endtask

    initial begin
        `ifndef _HEADERS_SVH_
            $display("Header not found/guard mismatch");
        `else
            $display("HW_ADC_WIDTH=%0d", `HW_ADC_WIDTH);
        `endif

        // init interface-driven signals
        vif.rst     = 1'b0;
        vif.A       = '0;
        vif.B       = '0;
        vif.C       = '0;
        vif.i_valid = 1'b0;

        v1_verify_rst();

        // hold 2 cycles
        tick_cb();
        tick_cb();

        // визуальные тесты
        push_fma(1, 2, 3);
        push_fma(10, 23, 12);
        push_fma(9, 5, 4);
        push_fma(`MAX_SIGNED_INT16, `MAX_SIGNED_INT16, `MAX_SIGNED_INT16);
        push_fma(-10, 7, 9);
        push_fma(-11, 5, 89);

        repeat (FMA_PIPE_SIZE) tick_cb();

        fma_reset(2);
        fma_pipe_ticks_behv(10, 3324, 10);

        tick_cb(); tick_cb();
        $finish;
    end

endmodule
