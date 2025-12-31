////////////////////////////////////////////////////////////////////
//
// bel_fft_axi_sif.v
//
//
// This file is part of the "bel_fft" project
//
// Author(s):
//     - Frank Storm (Frank.Storm@gmx.net)
//
////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2012 - 2017 Authors
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


module bel_fft_axi_sif (
        s_aclk,
        s_aresetn,
        s_awaddr,
        s_awvalid,
        s_wdata,
        s_wstrb,
        s_wvalid,
        s_bready,
        s_araddr,
        s_arvalid,
        s_rready,
        s_arready,
        s_rdata,
        s_rresp,
        s_rvalid,
        s_wready,
        s_bresp,
        s_bvalid,
        s_awready,

        adr_o,
        dat_i,
        dat_o,
        bsel_o,
        wr_o,
        rd_o,
        ack_i,
        err_i);

    parameter C_S_AXI_ADDR_WIDTH = 7;

    input s_aclk;
    input s_aresetn;
    input [C_S_AXI_ADDR_WIDTH - 1:0] s_awaddr;
    input s_awvalid;
    input [`BEL_FFT_DWIDTH - 1:0] s_wdata;
    input [`BEL_FFT_DWIDTH / 8 - 1:0] s_wstrb;
    input s_wvalid;
    input s_bready;
    input [C_S_AXI_ADDR_WIDTH - 1:0] s_araddr;
    input s_arvalid;
    input s_rready;

    output s_arready;
    output [`BEL_FFT_DWIDTH - 1:0] s_rdata;
    output [1:0] s_rresp;
    output s_rvalid;
    output s_wready;
    output [1:0] s_bresp;
    output s_bvalid;
    output s_awready;

    output [`BEL_FFT_SIF_AWIDTH-1:0] adr_o;
    input [`BEL_FFT_DWIDTH-1:0] dat_i;
    output [`BEL_FFT_DWIDTH-1:0] dat_o;
    output [`BEL_FFT_BCNT - 1:0] bsel_o;
    output wr_o;
    output rd_o;
    input ack_i;
    input err_i;


    reg   [`BEL_FFT_SIF_AWIDTH - 1:0] rd_adr;
    reg   [`BEL_FFT_SIF_AWIDTH - 1:0] wr_adr;
    reg   s_arready;
    reg   s_awready;
    reg   s_wready;
    reg   s_bvalid;
    reg   s_rvalid;
    reg   rd_o;
    reg   wr_o;
    reg   rd;
    reg   wr_dat_ready;
    reg   wr_adr_ready;
    reg   wr;
    reg [`BEL_FFT_DWIDTH - 1:0] s_rdata;
    reg [1:0] s_bresp;
    reg [1:0] s_rresp;
    reg [`BEL_FFT_DWIDTH-1:0] dat_o;
    reg [`BEL_FFT_BCNT - 1:0] bsel_o;


    always @ (posedge s_aclk) begin
        if (s_arvalid && s_arready) begin
            rd_adr <= s_araddr[C_S_AXI_ADDR_WIDTH - 1:2];
        end
    end


    always @ (posedge s_aclk) begin
        if (s_awvalid && s_awready) begin
            wr_adr <= s_awaddr[C_S_AXI_ADDR_WIDTH - 1:2];
        end
    end

    always @ (posedge s_aclk) begin
        if (s_wvalid && s_wready) begin
            dat_o <= s_wdata;
            bsel_o <= s_wstrb;
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            rd <= 1'b0;
        end else begin
            if (rd) begin
                if (s_rvalid && s_rready) begin
                    rd <= 1'b0;
                end
            end else begin
                if (s_arvalid && s_arready) begin
                    rd <= 1'b1;
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            rd_o <= 1'b0;
        end else begin
            if (rd) begin
                if (ack_i) begin
                    rd_o <= 1'b0;
                end
            end else begin
                if (s_arvalid && s_arready) begin
                    rd_o <= 1'b1;
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            s_rvalid <= 1'b0;
            s_rresp <= `AXI_RESP_OKAY;
        end else begin
            if (rd) begin
                if (s_rvalid && s_rready) begin
                    s_rvalid <= 1'b0;
                end else begin
                    if (ack_i) begin
                        s_rvalid <= 1'b1;
                        s_rdata <= dat_i;
                        s_rresp <= `AXI_RESP_OKAY;
                    end
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            wr <= 1'b0;
        end else begin
            if (wr) begin
                if (s_bvalid && s_bready) begin
                    wr <= 1'b0;
                end
            end else begin
                if ((s_awvalid && s_awready && s_wvalid && s_wready) ||
                        (s_awvalid && s_awready && wr_dat_ready) ||
                        (s_wvalid && s_wready && wr_adr_ready)) begin
                    wr <= 1'b1;
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            wr_dat_ready <= 1'b0;
        end else begin
            if (wr) begin
                if (s_bvalid && s_bready) begin
                    wr_dat_ready <= 1'b0;
                end
            end else begin
                if (s_wvalid && s_wready) begin
                    wr_dat_ready <= 1'b1;
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            wr_adr_ready <= 1'b0;
        end else begin
            if (wr) begin
                if (s_bvalid && s_bready) begin
                    wr_adr_ready <= 1'b0;
                end
            end else begin
                if (s_awvalid && s_awready) begin
                    wr_adr_ready <= 1'b1;
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            wr_o <= 1'b0;
        end else begin
            if (wr) begin
                if (ack_i) begin
                    wr_o <= 1'b0;
                end
            end else begin
                if ((s_awvalid && s_awready && s_wvalid && s_wready) ||
                        (s_awvalid && s_awready && wr_dat_ready) ||
                        (s_wvalid && s_wready && wr_adr_ready)) begin
                    wr_o <= 1'b1;
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            s_bvalid <= 1'b0;
            s_bresp <= `AXI_RESP_OKAY;
        end else begin
            if (wr) begin
                if (s_bvalid && s_bready) begin
                    s_bvalid <= 1'b0;
                end else begin
                    if (ack_i) begin
                        s_bvalid <= 1'b1;
                        s_bresp <= `AXI_RESP_OKAY;
                    end
                end
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            s_arready <= 1'b1;
        end else begin
            if (s_arvalid || s_awvalid || wr || rd) begin
                s_arready <= 1'b0;
            end else begin
                s_arready <= 1'b1;
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            s_awready <= 1'b1;
        end else begin
            if (s_arvalid || s_awvalid || wr || rd) begin
                s_awready <= 1'b0;
            end else begin
                s_awready <= 1'b1;
            end
        end
    end


    always @ (posedge s_aclk) begin
        if (s_aresetn == 1'b0) begin
            s_wready <= 1'b1;
        end else begin
            if (s_wvalid || wr || rd) begin
                s_wready <= 1'b0;
            end else begin
                s_wready <= 1'b1;
            end
        end
    end


    assign adr_o = (wr) ? wr_adr : rd_adr;

endmodule

