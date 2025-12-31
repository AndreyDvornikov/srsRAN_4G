////////////////////////////////////////////////////////////////////
//
// testbench_128_inv.v
//
//
// This file is part of the "bel_fft" project
//
// Author(s):
//     - Frank Storm (Frank.Storm@gmx.net)
//
////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2012-2014 Authors
//
// This source file may be used and distributed without
// restriction provided that this copyright statement is not
// removed from the file and that any derivative work contains
// the original copyright notice and the associated disclaimer.
//
// This source file is free software; you can redistribute it
// and/or modify it under the terms of the GNU Lesser General
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any
// later version.
//
// This source is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
// PURPOSE.  See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General
// Public License along with this source; if not, download it
// from http://www.gnu.org/licenses/lgpl.html
//
////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log$
//
////////////////////////////////////////////////////////////////////


`include "bel_fft_def.v"
`include "bel_axi_def.v"

// `timescale 1ns/1ps


module testbench_128_inv;

    parameter input_file_name = "input_data_128.dat";
    parameter fft_size = 128;
    parameter inverse = 1;
    parameter word_width = 16;
    parameter ram_awidth = 7;
    parameter C_S_AXI_ADDR_WIDTH = 12;
    parameter C_M_AXI_DATA_WIDTH = 16 * 2;

    reg aclk;
    reg aresetn;

    reg [C_S_AXI_ADDR_WIDTH - 1:0] s_awaddr;
    reg s_awvalid;
    reg [`BEL_FFT_DWIDTH - 1:0] s_wdata;
    reg [`BEL_FFT_DWIDTH / 8 - 1:0] s_wstrb;
    reg s_wvalid;
    reg s_bready;
    reg [C_S_AXI_ADDR_WIDTH - 1:0] s_araddr;
    reg s_arvalid;
    reg s_rready;

    wire s_arready;
    wire [`BEL_FFT_DWIDTH - 1:0] s_rdata;
    wire [1:0] s_rresp;
    wire s_rvalid;
    wire s_wready;
    wire [1:0] s_bresp;
    wire s_bvalid;
    wire s_awready;

    wire m_arvalid;
    wire src_m_arvalid;
    wire dst_m_arvalid;
    wire m_arready;
    wire src_m_arready;
    wire dst_m_arready;

    wire [`BEL_FFT_AWIDTH - 1:0] m_araddr;
    wire [2:0] m_arprot;
    wire [7:0] m_arlen;
    wire [2:0] m_arsize;
    wire [3:0] m_arcache;
    wire [4:0] m_aruser;
    wire [1:0] m_arburst;
    wire m_rready;
    wire m_rvalid;
    wire src_m_rvalid;
    wire dst_m_rvalid;
    wire [C_M_AXI_DATA_WIDTH - 1:0] m_rdata;
    wire [C_M_AXI_DATA_WIDTH - 1:0] src_m_rdata;
    wire [C_M_AXI_DATA_WIDTH - 1:0] dst_m_rdata;
    wire [1:0] m_rresp;
    wire [1:0] src_m_rresp;
    wire [1:0] dst_m_rresp;
    wire m_rlast;
    wire m_awready;
    wire src_m_awready;
    wire dst_m_awready;
    wire m_awvalid;
    wire src_m_awvalid;
    wire dst_m_awvalid;
    wire [`BEL_FFT_AWIDTH - 1:0] m_awaddr;
    wire [2:0] m_awprot;
    wire [7:0] m_awlen;
    wire [2:0] m_awsize;
    wire [3:0] m_awcache;
    wire [4:0] m_awuser;
    wire [1:0] m_awburst;
    wire m_wready;
    wire src_m_wready;
    wire dst_m_wready;
    wire m_wvalid;
    wire src_m_wvalid;
    wire dst_m_wvalid;
    wire [C_M_AXI_DATA_WIDTH - 1:0] m_wdata;
    wire [C_M_AXI_DATA_WIDTH / 8 - 1:0] m_wstrb;
    wire m_wlast;
    wire m_bready;
    wire m_bvalid;
    wire src_m_bvalid;
    wire dst_m_bvalid;
    wire [1:0] m_bresp;
    wire [1:0] src_m_bresp;
    wire [1:0] dst_m_bresp;

    wire event_o;
    wire int;

    reg last_dat_sel;
    reg dat_sel;
    wire src_raddr_sel;   
    wire dst_raddr_sel;   
    wire src_waddr_sel;   
    wire dst_waddr_sel;   
   
   
    task idleCycle;
        input [31:0] cycle_count;
        begin
            #1
            s_araddr = 0;
            s_awaddr = 0;
            s_wdata = 0;
            s_wstrb = 0;
            s_arvalid = 1'b0;
            s_awvalid = 1'b0;
            s_wvalid = 1'b0;
            s_rready = 1'b0;
            s_bready = 1'b0;
            repeat (cycle_count)
                @(posedge aclk);
        end
    endtask

    
    task writeRegister;
        input [C_S_AXI_ADDR_WIDTH - 1:0] address;
        input [`BEL_FFT_DWIDTH - 1:0] data;
        begin
            #1 
            s_awaddr = address << 2;
            s_wdata = data;
            s_wstrb = 4'b1111;
            s_awvalid = 1'b1;
            s_wvalid = 1'b1;
            s_bready = 1'b1;
            @(posedge aclk);
            while ((s_awready == 1'b0) && (s_wready == 1'b0))
                @(posedge aclk);
            #1 
            s_awvalid = 1'b0;
            s_wvalid = 1'b0;
            s_awaddr = 0;
            s_wdata = 0;
            s_wstrb = 4'b0000;
            @(posedge aclk);
            while (s_bvalid == 1'b0)
                @(posedge aclk);
            #1 
            s_bready = 1'b0;
            @(posedge aclk);
        end
    endtask // input


    task readRegister;
        input [C_S_AXI_ADDR_WIDTH - 1:0] address;
        begin
            #1 
            s_araddr = address << 2;
            s_arvalid = 1'b1;
            s_rready = 1'b1;
            @(posedge aclk);
            while (s_arready == 1'b0)
                @(posedge aclk);
            #1 
            s_araddr = 0;
            s_arvalid = 1'b0;
            while (s_rvalid == 1'b0)
                @(posedge aclk);
            #1 
            s_rready = 1'b0;
            @(posedge aclk);
        end
    endtask // input


    task waitForInterrupt;
        begin
            @(posedge int);
        end
    endtask
    
    
    initial begin
        aresetn = 1'b0;
        #80 aresetn = 1'b1;
    end
    

    initial begin
        aclk = 1'b0;
    end
    

    always begin
        #10 aclk = 1'b1;
        #10 aclk = 1'b0;
    end


    initial begin
        idleCycle (10);

        writeRegister (`BEL_FFT_SIZE_REG_ADDR, fft_size);

        // The input data is located at one time the size of the input data.
        // It is not located at 0, because this is the default address.
        // finadr = FFT size * number of 32 bit word for a complex number
        writeRegister (`BEL_FFT_SOURCE_REG_ADDR, fft_size * (word_width * 2 / `BEL_FFT_DWIDTH * `BEL_FFT_BCNT));

        // Write the resulting data above the input data (2 * FFT size * number of bytes per complex value)
        // foutadr = 2 * FFT size * number of 32 bit word for a complex number
        writeRegister (`BEL_FFT_DEST_REG_ADDR, 2 * fft_size * (word_width * 2 / `BEL_FFT_DWIDTH * `BEL_FFT_BCNT));

        // p[0] = 0004, m[0] = 0020
        writeRegister (`BEL_FFT_FACTORS_REG_ADDR + 0, 32'h0004_0020);

        readRegister (`BEL_FFT_FACTORS_REG_ADDR + 0);

        // p[1] = 0004, m[1] = 0008
        writeRegister (`BEL_FFT_FACTORS_REG_ADDR + 1, 32'h0004_0008);

        readRegister (`BEL_FFT_FACTORS_REG_ADDR + 1);

        // p[2] = 0004, m[2] = 0002
        writeRegister (`BEL_FFT_FACTORS_REG_ADDR + 2, 32'h0004_0002);

        readRegister (`BEL_FFT_FACTORS_REG_ADDR + 2);

        // p[3] = 0002, m[3] = 0001
        writeRegister (`BEL_FFT_FACTORS_REG_ADDR + 3, 32'h0002_0001);

        readRegister (`BEL_FFT_FACTORS_REG_ADDR + 3);


        writeRegister (`BEL_FFT_USER_REG_ADDR, 32'h0F010F01);


        // start + enable interrupt
        writeRegister (`BEL_FFT_CONTROL_REG_ADDR, inverse * 65536 + 257);

        waitForInterrupt;
        
        idleCycle (1);

        // Read the status register
        readRegister (`BEL_FFT_STATUS_REG_ADDR);

        idleCycle (1);

        u_OutputRam.dump;
        $finish;
    end


    initial begin
        // Timeout in case of errors
        
        #100000000 $finish;
    end


    assign src_raddr_sel = (m_araddr[ram_awidth + 2 +
            (word_width * 2 / `BEL_FFT_DWIDTH):ram_awidth + 1 +
            (word_width * 2 / `BEL_FFT_DWIDTH)] == 2'b01);
    assign dst_raddr_sel = (m_araddr[ram_awidth + 2 +
            (word_width * 2 / `BEL_FFT_DWIDTH):ram_awidth + 1 +
            (word_width * 2 / `BEL_FFT_DWIDTH)] == 2'b10);
    assign src_waddr_sel = (m_awaddr[ram_awidth + 2 +
            (word_width * 2 / `BEL_FFT_DWIDTH):ram_awidth + 1 +
            (word_width * 2 / `BEL_FFT_DWIDTH)] == 2'b01);
    assign dst_waddr_sel = (m_awaddr[ram_awidth + 2 +
            (word_width * 2 / `BEL_FFT_DWIDTH):ram_awidth + 1 +
            (word_width * 2 / `BEL_FFT_DWIDTH)] == 2'b10);


    always @(posedge aclk or negedge aresetn) begin
        if (aresetn == 1'b0) begin
           last_dat_sel <= 1'b0;
        end else begin
            if ((m_arvalid && dst_raddr_sel) || 
                    (m_awvalid  && dst_waddr_sel)) begin
                last_dat_sel <= 1'b1;
            end else begin
                if ((m_arvalid && src_raddr_sel) || 
                        (m_awvalid && src_waddr_sel)) begin
                    last_dat_sel <= 1'b0;
                end
            end
        end
    end


    always @(m_arvalid or m_awvalid or dst_waddr_sel or dst_raddr_sel or
            src_waddr_sel or src_raddr_sel or last_dat_sel) begin
        if ((m_arvalid && dst_raddr_sel) || 
                    (m_awvalid  && dst_waddr_sel)) begin
                dat_sel = 1'b1;
        end else begin
            if ((m_arvalid && src_raddr_sel) || 
                    (m_awvalid && src_waddr_sel)) begin
                dat_sel = 1'b0;
            end else begin
                dat_sel = last_dat_sel;
            end
        end
    end


    assign src_m_arvalid = (src_raddr_sel) ? m_arvalid : 1'b0;
    assign dst_m_arvalid = (dst_raddr_sel) ? m_arvalid : 1'b0;
    assign src_m_awvalid = (src_waddr_sel) ? m_awvalid : 1'b0;
    assign dst_m_awvalid = (dst_waddr_sel) ? m_awvalid : 1'b0;

    assign src_m_wvalid = (src_waddr_sel) ? m_wvalid : 1'b0;
    assign dst_m_wvalid = (dst_waddr_sel) ? m_wvalid : 1'b0;

    assign m_rdata = dat_sel ? dst_m_rdata : src_m_rdata;
    assign m_rresp = dat_sel ? dst_m_rresp : src_m_rresp;
    assign m_bresp = dat_sel ? dst_m_bresp : src_m_bresp;
    assign m_wready = dat_sel ? dst_m_wready : src_m_wready;

    assign m_arready = src_m_arready | dst_m_arready;
    assign m_awready = src_m_awready | dst_m_awready;

    assign m_bvalid = src_m_bvalid | dst_m_bvalid;
    assign m_rvalid = src_m_rvalid | dst_m_rvalid;

    assign m_rlast = 1'b1;


    bel_axi_ram #(
            .size (fft_size * word_width * 2 / C_M_AXI_DATA_WIDTH),
            .adr_width (ram_awidth + 3),
            .data_width (C_M_AXI_DATA_WIDTH),
            .input_file_name (input_file_name),
            .output_file_name ("/dev/null"))
        u_InputRam (
            .s_aclk (aclk),
            .s_aresetn (aresetn),
            .s_awaddr (m_awaddr[ram_awidth + 2:0]),
            .s_awvalid (src_m_awvalid),
            .s_awlen (m_awlen),
            .s_awsize (m_awsize),
            .s_wdata (m_wdata),
            .s_wstrb (m_wstrb),
            .s_wvalid (src_m_wvalid),
            .s_bready (m_bready),
            .s_araddr (m_araddr[ram_awidth + 2:0]),
            .s_arvalid (src_m_arvalid),
            .s_arlen (m_arlen),
            .s_arsize (m_arsize),
            .s_rready (m_rready),
            .s_arready (src_m_arready),
            .s_rdata (src_m_rdata),
            .s_rresp (src_m_rresp),
            .s_rvalid (src_m_rvalid),
            .s_wready (src_m_wready),
            .s_bresp (src_m_bresp),
            .s_bvalid (src_m_bvalid),
            .s_awready (src_m_awready));


    bel_axi_ram #(
            .size (fft_size * word_width * 2 / C_M_AXI_DATA_WIDTH),
            .adr_width (ram_awidth + 3),
            .data_width (C_M_AXI_DATA_WIDTH),
            .input_file_name (""),
            .output_file_name ("output_data.dat"))
        u_OutputRam (
            .s_aclk (aclk),
            .s_aresetn (aresetn),
            .s_awaddr (m_awaddr[ram_awidth + 2:0]),
            .s_awvalid (dst_m_awvalid),
            .s_awlen (m_awlen),
            .s_awsize (m_awsize),
            .s_wdata (m_wdata),
            .s_wstrb (m_wstrb),
            .s_wvalid (dst_m_wvalid),
            .s_bready (m_bready),
            .s_araddr (m_araddr[ram_awidth + 2:0]),
            .s_arvalid (dst_m_arvalid),
            .s_arlen (m_arlen),
            .s_arsize (m_arsize),
            .s_rready (m_rready),
            .s_arready (dst_m_arready),
            .s_rdata (dst_m_rdata),
            .s_rresp (dst_m_rresp),
            .s_rvalid (dst_m_rvalid),
            .s_wready (dst_m_wready),
            .s_bresp (dst_m_bresp),
            .s_bvalid (dst_m_bvalid),
            .s_awready (dst_m_awready));

    
    lte_phy_fft u_fft (
            .m_aclk (aclk),
            .m_aresetn (aresetn),
            .m_arready (m_arready),
            .m_arvalid (m_arvalid),
            .m_araddr (m_araddr),
            .m_arprot (m_arprot),
            .m_arlen (m_arlen),
            .m_arsize (m_arsize),
            .m_arcache (m_arcache),
            .m_aruser (m_aruser),
            .m_arburst (m_arburst),
            .m_rready (m_rready),
            .m_rvalid (m_rvalid),
            .m_rdata (m_rdata),
            .m_rresp (m_rresp),
            .m_rlast (m_rlast),
            .m_awready (m_awready),
            .m_awvalid (m_awvalid),
            .m_awaddr (m_awaddr),
            .m_awprot (m_awprot),
            .m_awsize (m_awsize),
            .m_awlen (m_awlen),
            .m_awcache (m_awcache),
            .m_awuser (m_awuser),
            .m_awburst (m_awburst),
            .m_wready (m_wready),
            .m_wvalid (m_wvalid),
            .m_wdata (m_wdata),
            .m_wstrb (m_wstrb),
            .m_wlast (m_wlast),
            .m_bready (m_bready),
            .m_bvalid (m_bvalid),
            .m_bresp (m_bresp),

            .s_aclk (aclk),
            .s_aresetn (aresetn),
            .s_awaddr (s_awaddr),
            .s_awvalid (s_awvalid),
            .s_wdata (s_wdata),
            .s_wstrb (s_wstrb),
            .s_wvalid (s_wvalid),
            .s_bready (s_bready),
            .s_araddr (s_araddr),
            .s_arvalid (s_arvalid),
            .s_rready (s_rready),
            .s_arready (s_arready),
            .s_rdata (s_rdata),
            .s_rresp (s_rresp),
            .s_rvalid (s_rvalid),
            .s_wready (s_wready),
            .s_bresp (s_bresp),
            .s_bvalid (s_bvalid),
            .s_awready (s_awready),

            .event_o (event_o),
            .int_o (int));

endmodule

