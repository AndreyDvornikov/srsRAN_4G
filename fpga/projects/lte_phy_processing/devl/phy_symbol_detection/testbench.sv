`timescale 1ns/1ps
`include "lte_hw_params.vh"

module testbench;
    logic clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    logic rst;

    logic signed [`HW_ADC_WIDTH-1:0] i_data_i1;
    logic signed [`HW_ADC_WIDTH-1:0] i_data_q1;
    logic                            i_valid;

    phy_symbol_detection dut(
        .i_clk      (clk),
        .i_rst      (rst),
        .i_data_i1  (i_data_i1),
        .i_data_q1  (i_data_q1),
        .i_valid    (i_valid)
    );

    int     fd;
    string  line;
    int     addr_i, addr_q;
    int     val_i,  val_q;
    int     r;

    task automatic read_next_word(output int addr, output int val, output bit ok);
        ok = 1'b0;
        while (!$feof(fd)) begin
            r = $fgets(line, fd);
            if (r == 0) continue;

            // @0000 0
            r = $sscanf(line, "@%x %d", addr, val);
            if (r == 2) begin
                ok = 1'b1;
                return;
            end
        end
    endtask

    initial begin
        // init
        rst      = 1'b1;
        i_valid  = 1'b0;
        i_data_i1 = '0;
        i_data_q1 = '0;

        fd = $fopen("input_signal.hex", "r");
        if (fd == 0) begin
            $fatal(1, "Can't open ss.hex");
        end

        repeat (10) @(posedge clk);
        rst <= 1'b0;

        forever begin
            bit ok_i, ok_q;

            read_next_word(addr_i, val_i, ok_i);
            if (!ok_i) break;

            read_next_word(addr_q, val_q, ok_q);
            if (!ok_q) break;

            repeat ($urandom_range(0, 7)) @(posedge clk);

            @(posedge clk);
            i_data_i1 <= $signed(val_i);
            i_data_q1 <= $signed(val_q);
            i_valid   <= 1'b1;

            @(posedge clk);
            i_valid   <= 1'b0;
        end

        $fclose(fd);
        repeat (20) @(posedge clk);
        $finish;
    end
endmodule
