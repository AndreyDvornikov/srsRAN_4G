`timescale 1ns/1ps
`include "../headers/header.svh"

`define DUT_NAME_1 dut_1

module math_mac_macro_tb;
    logic clk;

    localparam int ACC_WIDTH        = 64;
    localparam int FMA_PIPE_SIZE    = 1;

    mac_if #(
        .A_W (`HW_ADC_WIDTH),
        .B_W (`HW_ADC_WIDTH),
        .ACC_W (ACC_WIDTH)
    ) vif(clk);

    math_mac_macro #(
        .A_WIDTH    (`HW_ADC_WIDTH  ), 
        .B_WIDTH    (`HW_ADC_WIDTH  ),
        .ACC_WIDTH  (ACC_WIDTH      ),
        .PIPE       (FMA_PIPE_SIZE  )
    ) `DUT_NAME_1 (
        .i_clk      (clk),
        .i_rst      (vif.rst),
        .i_clr      (vif.clr),
        .i_a        (vif.i_a),
        .i_b        (vif.i_b),
        .i_valid    (vif.i_valid),
        .o_c        (vif.o_c),
        .o_valid    (vif.o_valid),
        .o_valid_mul(vif.o_valid_mul),
        .o_mul      (vif.o_mul)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end 

    task automatic tick_cb();
        @(vif.cb);
    endtask

    task automatic mac_reset(int ticks);
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

        mac_reset(1);

        $display("[VERIFY] Checking reset state at t=%0t", $time);

        // shift reg check
        if (`DUT_NAME_1.pipe_i_valid !== '0) begin
            $error("[FAIL] pipe_i_valid = %b, expected 0", dut_1.pipe_i_valid);
            error_found = 1'b1;
        end

        // shift reg check
        for (j = 0; j < `DUT_NAME_1.PIPE; j++) begin
            if (`DUT_NAME_1.pipe_a[j] !== '0) begin
                $error("[FAIL] pipe_a[%0d] = %0d, expected 0", j, dut_1.pipe_a[j]);
                error_found = 1'b1;
            end

            if (`DUT_NAME_1.pipe_b[j] !== '0) begin
                $error("[FAIL] pipe_b[%0d] = %0d, expected 0", j, dut_1.pipe_b[j]);
                error_found = 1'b1;
            end
        end

        if (`DUT_NAME_1.op_acc_r !== '0) begin
            $error("[FAIL] op_acc_r not zero after reset");
            error_found = 1'b1;
        end

        if (`DUT_NAME_1.op_acc_snap_r !== '0) begin
            $error("[FAIL] op_acc_snap_r not zero after reset");
            error_found = 1'b1;
        end

        if (`DUT_NAME_1.op_acc_valid !== 1'b0) begin
            $error("[FAIL] op_acc_valid not zero after reset");
            error_found = 1'b1;
        end
        
        if (vif.cb.o_valid_mul !== 1'b0) begin
            $error("[FAIL] o_next = %b, expected 0", vif.cb.o_valid_mul);
            error_found = 1'b1;
        end 

        if (vif.cb.o_valid !== 1'b0) begin // wtf
            $error("[FAIL] o_valid = %b, expected 0", vif.cb.o_valid);
            error_found = 1'b1;
        end

        if (!error_found) begin
            $display("[PASS] [v1_verify_rst] All registers reset correctly");
        end
    endtask

    task automatic push_mac(
        logic signed [`DUT_NAME_1.A_WIDTH - 1:0] a,
        logic signed [`DUT_NAME_1.B_WIDTH - 1:0] b
    );
        $display("pushed [a=%0d][b=%0d]", a, b);

        vif.cb.i_valid  <= '1;
        vif.cb.i_a      <= a;
        vif.cb.i_b      <= b;

        tick_cb();

        vif.cb.i_valid  <= '0;
    endtask

    task automatic mac_clear();
        vif.cb.clr <= 1'b1;                     
        do tick_cb(); while (vif.cb.o_valid_mul !== 1'b1);
        tick_cb();
        vif.cb.clr <= 1'b0;
    endtask

    task automatic mac_expected(
        logic signed [`DUT_NAME_1.ACC_WIDTH - 1:0] expected
    );
        if (vif.cb.o_valid !== 1'b1) begin 
            $error("[LOG-%0t]Unexpected signal o_valid. Please use this function after 'mac_clear'", $time);
            return; 
        end 

        if (vif.cb.o_c === $signed(expected)) begin 
            $display("[LOG-%0t][mac_expected:OK] expected val %0d", $time, expected);
        end else begin 
            $error("[LOG-%0t][mac_expected:NOK] expected val %0d, but val %0d", $time, expected, $signed(vif.cb.o_c));
        end 
    endtask

    initial begin
        `ifndef _HEADERS_SVH_
            $display("Header not found/guard mismatch");
        `else
            $display("HW_ADC_WIDTH=%0d", `HW_ADC_WIDTH);
        `endif

        // init interface-driven signals
        vif.rst       = 1'b0;
        vif.clr       = 1'b0;
        vif.i_a       = '0;
        vif.i_b       = '0;
        vif.i_valid   = '0;

        v1_verify_rst();

        push_mac(1,1);
        mac_clear(); 
        mac_expected(1);

        tick_cb();
        tick_cb();

        push_mac(10,5);
        push_mac(9,10);
        push_mac(-10,-9);
        push_mac(-10,9);
        tick_cb();  // просто внёс задержку
        push_mac(10,-14);
        mac_clear();
        mac_expected(0);

        push_mac(10, 5);
        push_mac(4,1);
        mac_clear();
        mac_expected(54);
        // подаём A = 10    B = 5;      C <= 50
        // подаём A = 9     B = 10;     C <= 140
        // подаём A = -10   B = -9;     C <= 230 
        // подаём A = -10   B = 9;      C <= 140
        // подаём A = 10    B = -14;    C <= 0
        // mac_clear; < последнее поданное значение в этот момент, которое находится в mul - то, что относится к циклу до сброса
        // подаём A = 10    B = 5;      C <= 50
        // подаём A = 4     B = 1;      C <= 54 
        // mac_clear 
        
        tick_cb();
        tick_cb();
        $finish;
    end 
endmodule
