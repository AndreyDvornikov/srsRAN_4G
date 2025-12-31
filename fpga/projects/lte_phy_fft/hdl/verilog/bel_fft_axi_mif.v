////////////////////////////////////////////////////////////////////
//
// bel_fft_axi_mif.v
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


module bel_fft_axi_mif (

        m_aclk,
        m_aresetn,
        m_arready,
        m_arvalid,
        m_araddr,
        m_arprot,
        m_arlen,
        m_arsize,
        m_arcache,
        m_aruser,
        m_arburst,
        m_rready,
        m_rvalid,
        m_rdata,
        m_rresp,
        m_rlast,
        m_awready,
        m_awvalid,
        m_awaddr,
        m_awprot,
        m_awsize,
        m_awlen,
        m_awcache,
        m_awuser,
        m_awburst,
        m_wready,
        m_wvalid,
        m_wdata,
        m_wstrb,
        m_wlast,
        m_bready,
        m_bvalid,
        m_bresp,

        adr0_i,
        dat_re0_i,
        dat_re0_o,
        dat_im0_i,
        dat_im0_o,
        wr0_i,
        rd0_i,
        ack0_o,
        err0_o,

        adr1_i,
        dat_re1_i,
        dat_re1_o,
        dat_im1_i,
        dat_im1_o,
        wr1_i,
        rd1_i,
        ack1_o,
        err1_o,

        adr2_i,
        dat_re2_i,
        dat_re2_o,
        dat_im2_i,
        dat_im2_o,
        wr2_i,
        rd2_i,
        ack2_o,
        err2_o,

        adr3_i,
        dat_re3_i,
        dat_re3_o,
        dat_im3_i,
        dat_im3_o,
        wr3_i,
        rd3_i,
        ack3_o,
        err3_o,

        user_i);

    parameter word_width = 32;
    parameter addr_width = 32;

    input m_aclk;
    input m_aresetn;
    input m_arready;
    output m_arvalid;
    output [addr_width - 1:0] m_araddr;
    output [2:0] m_arprot;
    output [7:0] m_arlen;
    output [2:0] m_arsize;
    output [3:0] m_arcache;
    output [4:0] m_aruser;
    output [1:0] m_arburst;
    output m_rready;
    input m_rvalid;
    input [word_width * 2 - 1:0] m_rdata;
    input [1:0] m_rresp;
    input m_rlast;
    input m_awready;
    output m_awvalid;
    output [addr_width - 1:0] m_awaddr;
    output [2:0] m_awprot;
    output [7:0] m_awlen;
    output [2:0] m_awsize;
    output [3:0] m_awcache;
    output [4:0] m_awuser;
    output [1:0] m_awburst;
    input m_wready;
    output m_wvalid;
    output [word_width * 2 - 1:0] m_wdata;
    output [word_width * 2 / 8 - 1:0] m_wstrb;
    output m_wlast;
    output m_bready;
    input m_bvalid;
    input [1:0] m_bresp;

    input [`BEL_FFT_AWIDTH-1:0] adr0_i;
    input [word_width-1:0] dat_re0_i;
    output [word_width-1:0] dat_re0_o;
    input [word_width-1:0] dat_im0_i;
    output [word_width-1:0] dat_im0_o;
    input wr0_i;
    input rd0_i;
    output ack0_o;
    output err0_o;

    input [`BEL_FFT_AWIDTH-1:0] adr1_i;
    input [word_width-1:0] dat_re1_i;
    output [word_width-1:0] dat_re1_o;
    input [word_width-1:0] dat_im1_i;
    output [word_width-1:0] dat_im1_o;
    input wr1_i;
    input rd1_i;
    output ack1_o;
    output err1_o;

    input [`BEL_FFT_AWIDTH-1:0] adr2_i;
    input [word_width-1:0] dat_re2_i;
    output [word_width-1:0] dat_re2_o;
    input [word_width-1:0] dat_im2_i;
    output [word_width-1:0] dat_im2_o;
    input wr2_i;
    input rd2_i;
    output ack2_o;
    output err2_o;

    input [`BEL_FFT_AWIDTH-1:0] adr3_i;
    input [word_width-1:0] dat_re3_i;
    output [word_width-1:0] dat_re3_o;
    input [word_width-1:0] dat_im3_i;
    output [word_width-1:0] dat_im3_o;
    input wr3_i;
    input rd3_i;
    output ack3_o;
    output err3_o;

    input [`BEL_FFT_DWIDTH-1:0] user_i;

    reg   m_arvalid;
    reg   m_rready;
    reg   m_awvalid;
    reg   m_wvalid;

    reg   wr_dat_sent;
    reg   wr_adr_sent;

    reg   ack_rd;
    wire  ack_wr;
    wire   ack;
    wire   rd;
    wire   wr;
    reg wait_for_data;

    wire  [word_width * 2 - 1:0] dat_i;
    reg  [word_width * 2 - 1:0] dat_o;
    wire  [word_width - 1:0] dat_im;
    wire  [word_width - 1:0] dat_re;
    wire [`BEL_FFT_AWIDTH-1:0] adr;



    always @ (posedge m_aclk) begin
        if (m_aresetn == 1'b0) begin
            m_arvalid <= 1'b0;
        end else begin
            if (m_arvalid && m_arready) begin
                m_arvalid <= 1'b0;
            end else begin
                if (rd && ! wait_for_data) begin
                    m_arvalid <= 1'b1;
                end
            end
        end
    end


    always @ (posedge m_aclk) begin
        if (m_aresetn == 1'b0) begin
            wait_for_data <= 1'b0;
        end else begin
            if (wait_for_data) begin
                if (ack_rd) begin
                    wait_for_data <= 1'b0;
                end
            end else begin
                if (m_arvalid && m_arready) begin
                    wait_for_data <= 1'b1;
                end
            end
        end
    end


    always @ (posedge m_aclk) begin
        if (m_rvalid && m_rready) begin
            dat_o <= m_rdata;
        end
    end


    always @ (posedge m_aclk) begin
        if (m_aresetn == 1'b0) begin
            ack_rd <= 1'b0;
        end else begin
            if (m_rready && m_rvalid) begin
                ack_rd <= 1'b1;
            end else begin
                ack_rd <= 1'b0;
            end
        end
    end


    always @ (posedge m_aclk) begin
        if (m_aresetn == 1'b0) begin
            m_rready <= 1'b0;
        end else begin
            if (ack_rd) begin
                m_rready <= 1'b0;
            end else begin
                if (rd) begin
                    m_rready <= 1'b1;
                end
            end
        end
    end


    always @ (posedge m_aclk) begin
        if (m_aresetn == 1'b0) begin
            m_awvalid <= 1'b0;
        end else begin
            if (m_awvalid) begin
                if (m_awready) begin
                    m_awvalid <= 1'b0;
                end
            end else begin
                if (wr && ! wr_adr_sent) begin
                    m_awvalid <= 1'b1;
                end
            end
        end
    end


    always @ (posedge m_aclk) begin
        if (m_aresetn == 1'b0) begin
            m_wvalid <= 1'b0;
        end else begin
            if (m_wvalid) begin
                if (m_wready) begin
                    m_wvalid <= 1'b0;
                end
            end else begin
                if (wr && ! wr_dat_sent) begin
                    m_wvalid <= 1'b1;
                end
            end
        end
    end


    always @ (posedge m_aclk) begin
        if (m_aresetn == 1'b0) begin
            wr_dat_sent <= 1'b0;
            wr_adr_sent <= 1'b0;
        end else begin
            if (m_bready && m_bvalid) begin
                wr_dat_sent <= 1'b0;
                wr_adr_sent <= 1'b0;
            end else begin
                if (m_awvalid && m_awready) begin
                    wr_adr_sent <= 1'b1;
                end
                if (m_wvalid && m_wready) begin
                    wr_dat_sent <= 1'b1;
                end
            end
        end
    end


    assign dat_im = dat_o[word_width * 2 - 1:word_width];
    assign dat_re = dat_o[word_width - 1:0];
    assign dat_i[word_width * 2 - 1:word_width] = dat_im0_i | dat_im1_i | dat_im2_i | dat_im3_i;
    assign dat_i[word_width - 1:0] = dat_re0_i | dat_re1_i | dat_re2_i | dat_re3_i;


    assign m_wdata = dat_i;

    assign ack_wr = m_bready & m_bvalid;

    assign ack = ack_rd | ack_wr;
    assign ack0_o = ack;
    assign ack1_o = ack;
    assign ack2_o = ack;
    assign ack3_o = ack;

    assign m_bready = wr_dat_sent & wr_adr_sent;

    assign m_araddr = adr;
    assign m_awaddr = adr;

    assign rd = rd0_i | rd1_i | rd2_i | rd3_i;
    assign wr = wr0_i | wr1_i | wr2_i | wr3_i;
    assign adr = adr0_i | adr1_i | adr2_i | adr3_i;

    assign dat_im0_o = dat_im;
    assign dat_im1_o = dat_im;
    assign dat_im2_o = dat_im;
    assign dat_im3_o = dat_im;

    assign dat_re0_o = dat_re;
    assign dat_re1_o = dat_re;
    assign dat_re2_o = dat_re;
    assign dat_re3_o = dat_re;

    assign err0_o = 1'b0;
    assign err1_o = 1'b0;
    assign err2_o = 1'b0;
    assign err3_o = 1'b0;

    assign m_wstrb = {`BEL_FFT_DWIDTH * 2 / 8{1'b1}};

    assign m_arprot = user_i[7:5];
    assign m_awprot = user_i[23:21];

    assign m_arlen = 0;
    assign m_awlen = 0;

    assign m_arsize = 3'b011;
    assign m_awsize = 3'b011;

    assign m_arcache = user_i[11:8];
    assign m_awcache = user_i[27:24];

    assign m_aruser = user_i[4:0];
    assign m_awuser = user_i[20:16];

    assign m_arburst = 2'b01;
    assign m_awburst = 2'b01;

    assign m_wlast = 1'b1;

endmodule

