`timescale 1ns/1ps
`include "lte_hw_params.vh"

module testbench;
    logic clk = 1'b0;
    always #5 clk = ~clk; // 100 MHz

    logic rst;

    // mem test
    logic        ena_128, ena_256;
    logic [6:0]  addra_128;
    logic [7:0]  addra_256;

    logic [31:0] douta_pss0_128;
    logic [31:0] douta_pss0_256;
    logic [31:0] douta_pss1_128;
    logic [31:0] douta_pss1_256;
    logic [31:0] douta_pss2_128;
    logic [31:0] douta_pss2_256;

    pss_0_rom_td_128sps pss_0_rom_td_128sps_dut (
        .clka(clk),                 // input wire clka
        .ena(ena_128),              // input wire ena
        .addra(addra_128),          // input wire [6 : 0] addra
        .douta(douta_pss0_128)      // output wire [31 : 0] douta
    );

    pss_0_rom_td_256sps pss_0_rom_td_256sps_dut (
        .clka(clk),                 // input wire clka
        .ena(ena_256),              // input wire ena
        .addra(addra_256),          // input wire [7 : 0] addra
        .douta(douta_pss0_256)      // output wire [31 : 0] douta
    );

    pss_1_rom_td_128sps pss_1_rom_td_128sps_dut (
        .clka(clk),                 // input wire clka
        .ena(ena_128),              // input wire ena
        .addra(addra_128),          // input wire [6 : 0] addra
        .douta(douta_pss1_128)      // output wire [31 : 0] douta
    );

    pss_1_rom_td_256sps pss_1_rom_td_256sps_dut (
        .clka(clk),                 // input wire clka
        .ena(ena_256),              // input wire ena
        .addra(addra_256),          // input wire [7 : 0] addra
        .douta(douta_pss1_256)      // output wire [31 : 0] douta
    );

    pss_2_rom_td_128sps pss_2_rom_td_128sps_dut (
        .clka(clk),                 // input wire clka
        .ena(ena_128),              // input wire ena
        .addra(addra_128),          // input wire [6 : 0] addra
        .douta(douta_pss2_128)      // output wire [31 : 0] douta
    );

    pss_2_rom_td_256sps pss_2_rom_td_256sps_dut (
        .clka(clk),                 // input wire clka
        .ena(ena_256),              // input wire ena
        .addra(addra_256),          // input wire [7 : 0] addra
        .douta(douta_pss2_256)      // output wire [31 : 0] douta
    );

    // PSS0
    wire signed [15:0] pss0_128_i = douta_pss0_128[15:0];
    wire signed [15:0] pss0_128_q = douta_pss0_128[31:16];
    wire signed [15:0] pss0_256_i = douta_pss0_256[15:0];
    wire signed [15:0] pss0_256_q = douta_pss0_256[31:16];
    
    // PSS1
    wire signed [15:0] pss1_128_i = douta_pss1_128[15:0];
    wire signed [15:0] pss1_128_q = douta_pss1_128[31:16];
    wire signed [15:0] pss1_256_i = douta_pss1_256[15:0];
    wire signed [15:0] pss1_256_q = douta_pss1_256[31:16];
    
    // PSS2
    wire signed [15:0] pss2_128_i = douta_pss2_128[15:0];
    wire signed [15:0] pss2_128_q = douta_pss2_128[31:16];
    wire signed [15:0] pss2_256_i = douta_pss2_256[15:0];
    wire signed [15:0] pss2_256_q = douta_pss2_256[31:16];

    initial begin
        rst = 1'b1;
        ena_128 = 1'b0;
        ena_256 = 1'b0;
        addra_128 = 7'd0;
        addra_256 = 8'd0;
        
        repeat(5) @(posedge clk);
        rst = 1'b0;

        ena_128 = 1'b1;
        
        for (int i = 0; i < 128; i++) begin
            addra_128 = i[6:0];
            @(posedge clk);
            #1;
            
            if (i < 5 || i >= 125) begin
                $display("[%0t] Addr=%3d | PSS0: I=%6d Q=%6d | PSS1: I=%6d Q=%6d | PSS2: I=%6d Q=%6d", 
                    $time, i, 
                    pss0_128_i, pss0_128_q,
                    pss1_128_i, pss1_128_q,
                    pss2_128_i, pss2_128_q);
            end
        end
        
        ena_128 = 1'b0;
        repeat(5) @(posedge clk);
        ena_256 = 1'b1;
        
        for (int i = 0; i < 256; i++) begin
            addra_256 = i[7:0];
            @(posedge clk);
            #1;
            
            if (i < 5 || i >= 253) begin
                $display("[%0t] Addr=%3d | PSS0: I=%6d Q=%6d | PSS1: I=%6d Q=%6d | PSS2: I=%6d Q=%6d", 
                    $time, i, 
                    pss0_256_i, pss0_256_q,
                    pss1_256_i, pss1_256_q,
                    pss2_256_i, pss2_256_q);
            end
        end
        
        ena_256 = 1'b0;

        repeat(10) @(posedge clk);

        $finish;
    end

    initial begin
        #10us;
        $display("\n[%0t] ERROR: Simulation timeout!", $time);
        $finish;
    end
endmodule