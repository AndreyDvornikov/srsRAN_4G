////////////////////////////////////////////////////////////////////
//
// lte_phy_fft.v
//
//
// This file is part of the "bel_fft" project
//
// Author(s):
//     - Frank Storm (Frank.Storm@gmx.net)
//
////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2012-2013 Authors
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


module lte_phy_fft (
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

        event_o,
        int_o);


    parameter C_BASEADDR = 0;
    parameter C_HIGHADDR = 0;

    parameter C_S_AXI_ADDR_WIDTH = 12;
    parameter C_S_AXI_DATA_WIDTH = 32;
    parameter C_S_AXI_PROTOCOL = "AXI4LITE";

    parameter C_M_AXI_ADDR_WIDTH = 32;
    parameter C_M_AXI_DATA_WIDTH = 16 * 2;
    parameter C_M_AXI_PROTOCOL = "AXI4";
    parameter C_M_AXI_ID_WIDTH = 5;

    input m_aclk;
    input m_aresetn;

    input m_arready;
    output m_arvalid;
    output [C_M_AXI_ADDR_WIDTH - 1:0] m_araddr;
    output [2:0] m_arprot;
    output [7:0] m_arlen;
    output [2:0] m_arsize;
    output [3:0] m_arcache;
    output [4:0] m_aruser;
    output [1:0] m_arburst;
    output m_rready;
    input m_rvalid;
    input [C_M_AXI_DATA_WIDTH - 1:0] m_rdata;
    input [1:0] m_rresp;
    input m_rlast;
    input m_awready;
    output m_awvalid;
    output [C_M_AXI_ADDR_WIDTH - 1:0] m_awaddr;
    output [2:0] m_awprot;
    output [7:0] m_awlen;
    output [2:0] m_awsize;
    output [3:0] m_awcache;
    output [4:0] m_awuser;
    output [1:0] m_awburst;
    input m_wready;
    output m_wvalid;
    output [C_M_AXI_DATA_WIDTH - 1:0] m_wdata;
    output [C_M_AXI_DATA_WIDTH / 8 - 1:0] m_wstrb;
    output m_wlast;
    output m_bready;
    input m_bvalid;
    input [1:0] m_bresp;

    input s_aclk;
    input s_aresetn;
    input [C_S_AXI_ADDR_WIDTH - 1:0] s_awaddr;
    input s_awvalid;
    input [C_S_AXI_DATA_WIDTH - 1:0] s_wdata;
    input [C_S_AXI_DATA_WIDTH / 8 - 1:0] s_wstrb;
    input s_wvalid;
    input s_bready;
    input [C_S_AXI_ADDR_WIDTH - 1:0] s_araddr;
    input s_arvalid;
    input s_rready;

    output s_arready;
    output [C_S_AXI_DATA_WIDTH - 1:0] s_rdata;
    output [1:0] s_rresp;
    output s_rvalid;
    output s_wready;
    output [1:0] s_bresp;
    output s_bvalid;
    output s_awready;

    output event_o;
    output int_o;

    wire [7 - 1:0] tw_adr;
    wire tw_rd;
    wire [16 - 1:0] tw_re;
    wire [16 - 1:0] tw_im;
    wire [2 - 1:0] tw_cfg_sel;

    bel_fft_axi  #(
            .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH),
            .C_M_AXI_DATA_WIDTH (C_M_AXI_DATA_WIDTH),
            .C_M_AXI_ADDR_WIDTH (C_M_AXI_ADDR_WIDTH),
            .word_width (16),
            .config_num (2),
            .stage_num (4),
            .twiddle_rom_max_awidth (7),
            .fft_size (128),
            .fft_size1 (128),
            .fft_size2 (0),
            .fft_size3 (0),
            .has_butterfly2 (1))
            u_core (
            .aclk (m_aclk),
            .aresetn (m_aresetn),
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

            .tw_adr (tw_adr),
            .tw_rd (tw_rd),
            .tw_re (tw_re),
            .tw_im (tw_im),
            .tw_cfg_sel (tw_cfg_sel),

            .event_o (event_o),
            .int_o (int_o));


    lte_phy_fft_twiddle_roms #(.word_width (16),
            .config_num (2),
            .max_awidth (7),
            .size (128),
            .awidth (7),
            .file_name ("lte_phy_fft_twiddle_rom0.dat"),
            .size2 (128),
            .awidth2 (7),
            .file_name2 ("lte_phy_fft_twiddle_rom1.dat"),
            .size3 (0),
            .awidth3 (0),
            .file_name3 (""),
            .size4 (0),
            .awidth4 (0),
            .file_name4 ("")
            ) u_twiddles (
            .clk_i (m_aclk),
            .rst_i (~m_aresetn),
            .adr_i (tw_adr),
            .rd_i (tw_rd),
            .dat_o ({tw_re, tw_im}),
            .cfg_sel_i (tw_cfg_sel));

endmodule

