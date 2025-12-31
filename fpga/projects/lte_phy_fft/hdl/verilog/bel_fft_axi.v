////////////////////////////////////////////////////////////////////
//
// bel_fft_axi.v
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


module bel_fft_axi (
        aclk,
        aresetn,

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

        tw_adr,
        tw_rd,
        tw_re,
        tw_im,
        tw_cfg_sel,

        event_o,
        int_o);

    parameter C_S_AXI_ADDR_WIDTH = 7;
    parameter C_M_AXI_DATA_WIDTH = 64;
    parameter C_M_AXI_ADDR_WIDTH = 32;

    parameter word_width = 16;
    parameter config_num = 1;
    parameter stage_num = 4;
    parameter twiddle_rom_max_awidth = 8;
    parameter fft_size = 256;
    parameter fft_size1 = 256;
    parameter fft_size2 = 256;
    parameter fft_size3 = 256;
    parameter has_butterfly2 = 1;

    input aclk;
    input aresetn;

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

    output [twiddle_rom_max_awidth - 1:0] tw_adr;
    output tw_rd;
    input [word_width - 1:0] tw_re;
    input [word_width - 1:0] tw_im;
    output [config_num - 1:0] tw_cfg_sel;

    output event_o;
    output int_o;

    wire [`BEL_FFT_AWIDTH-1:0] butterfly_generic_adr;
    wire [word_width-1:0] butterfly_generic_dat_re_i;
    wire [word_width-1:0] butterfly_generic_dat_re_o;
    wire [word_width-1:0] butterfly_generic_dat_im_i;
    wire [word_width-1:0] butterfly_generic_dat_im_o;
    wire butterfly_generic_wr;
    wire butterfly_generic_rd;
    wire butterfly_generic_ack;
    wire butterfly_generic_err;

    wire [`BEL_FFT_AWIDTH-1:0] butterfly2_adr;
    wire [word_width-1:0] butterfly2_dat_re_i;
    wire [word_width-1:0] butterfly2_dat_re_o;
    wire [word_width-1:0] butterfly2_dat_im_i;
    wire [word_width-1:0] butterfly2_dat_im_o;
    wire butterfly2_wr;
    wire butterfly2_rd;
    wire butterfly2_ack;
    wire butterfly2_err;

    wire [`BEL_FFT_AWIDTH-1:0] butterfly4_adr;
    wire [word_width-1:0] butterfly4_dat_re_i;
    wire [word_width-1:0] butterfly4_dat_re_o;
    wire [word_width-1:0] butterfly4_dat_im_i;
    wire [word_width-1:0] butterfly4_dat_im_o;
    wire butterfly4_wr;
    wire butterfly4_rd;
    wire butterfly4_ack;
    wire butterfly4_err;

    wire [`BEL_FFT_AWIDTH-1:0] copy_adr;
    wire [word_width-1:0] copy_dat_re_i;
    wire [word_width-1:0] copy_dat_re_o;
    wire [word_width-1:0] copy_dat_im_i;
    wire [word_width-1:0] copy_dat_im_o;
    wire copy_wr;
    wire copy_rd;
    wire copy_ack;
    wire copy_err;

    wire [`BEL_FFT_SIF_AWIDTH-1:0] ctrl_adr;
    wire [`BEL_FFT_DWIDTH-1:0] ctrl_dat_i;
    wire [`BEL_FFT_DWIDTH-1:0] ctrl_dat_o;
    wire ctrl_wr;
    wire ctrl_rd;
    wire ctrl_ack;
    wire ctrl_err;
    wire [`BEL_FFT_BCNT-1:0] ctrl_bsel;

    wire [`BEL_FFT_DWIDTH-1:0] user;


    bel_fft_axi_mif #(
            .word_width (word_width),
            .addr_width (C_M_AXI_ADDR_WIDTH))
            u_mif (
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

            .adr0_i (butterfly4_adr),
            .dat_re0_i (butterfly4_dat_re_o),
            .dat_re0_o (butterfly4_dat_re_i),
            .dat_im0_i (butterfly4_dat_im_o),
            .dat_im0_o (butterfly4_dat_im_i),
            .wr0_i (butterfly4_wr),
            .rd0_i (butterfly4_rd),
            .ack0_o (butterfly4_ack),
            .err0_o (butterfly4_err),

            .adr1_i (copy_adr),
            .dat_re1_i (copy_dat_re_o),
            .dat_re1_o (copy_dat_re_i),
            .dat_im1_i (copy_dat_im_o),
            .dat_im1_o (copy_dat_im_i),
            .wr1_i (copy_wr),
            .rd1_i (copy_rd),
            .ack1_o (copy_ack),
            .err1_o (copy_err),

            .adr2_i (butterfly2_adr),
            .dat_re2_i (butterfly2_dat_re_o),
            .dat_re2_o (butterfly2_dat_re_i),
            .dat_im2_i (butterfly2_dat_im_o),
            .dat_im2_o (butterfly2_dat_im_i),
            .wr2_i (butterfly2_wr),
            .rd2_i (butterfly2_rd),
            .ack2_o (butterfly2_ack),
            .err2_o (butterfly2_err),

            .adr3_i (butterfly_generic_adr),
            .dat_re3_i (butterfly_generic_dat_re_o),
            .dat_re3_o (butterfly_generic_dat_re_i),
            .dat_im3_i (butterfly_generic_dat_im_o),
            .dat_im3_o (butterfly_generic_dat_im_i),
            .wr3_i (butterfly_generic_wr),
            .rd3_i (butterfly_generic_rd),
            .ack3_o (butterfly_generic_ack),
            .err3_o (butterfly_generic_err),

            .user_i (user));


    bel_fft_axi_sif #(
            .C_S_AXI_ADDR_WIDTH (C_S_AXI_ADDR_WIDTH))
            u_sif (
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

            .adr_o (ctrl_adr),
            .dat_i (ctrl_dat_o),
            .dat_o (ctrl_dat_i),
            .bsel_o (ctrl_bsel),
            .wr_o (ctrl_wr),
            .rd_o (ctrl_rd),
            .ack_i (ctrl_ack),
            .err_i (ctrl_err));


    bel_fft_core #(
            .word_width (word_width),
            .config_num (config_num),
            .stage_num (stage_num),
            .twiddle_rom_max_awidth (twiddle_rom_max_awidth),
            .fft_size (fft_size),
            .fft_size1 (fft_size1),
            .fft_size2 (fft_size2),
            .fft_size3 (fft_size3),
            .has_butterfly2 (has_butterfly2))
            u_core (
            .clk_i (aclk),
            .rst_i (~aresetn),

            .butterfly_generic_adr_o (butterfly_generic_adr),
            .butterfly_generic_dat_re_i (butterfly_generic_dat_re_i),
            .butterfly_generic_dat_re_o (butterfly_generic_dat_re_o),
            .butterfly_generic_dat_im_i (butterfly_generic_dat_im_i),
            .butterfly_generic_dat_im_o (butterfly_generic_dat_im_o),
            .butterfly_generic_wr_o (butterfly_generic_wr),
            .butterfly_generic_rd_o (butterfly_generic_rd),
            .butterfly_generic_ack_i (butterfly_generic_ack),
            .butterfly_generic_err_i (butterfly_generic_err),

            .butterfly2_adr_o (butterfly2_adr),
            .butterfly2_dat_re_i (butterfly2_dat_re_i),
            .butterfly2_dat_re_o (butterfly2_dat_re_o),
            .butterfly2_dat_im_i (butterfly2_dat_im_i),
            .butterfly2_dat_im_o (butterfly2_dat_im_o),
            .butterfly2_wr_o (butterfly2_wr),
            .butterfly2_rd_o (butterfly2_rd),
            .butterfly2_ack_i (butterfly2_ack),
            .butterfly2_err_i (butterfly2_err),

            .butterfly4_adr_o (butterfly4_adr),
            .butterfly4_dat_re_i (butterfly4_dat_re_i),
            .butterfly4_dat_re_o (butterfly4_dat_re_o),
            .butterfly4_dat_im_i (butterfly4_dat_im_i),
            .butterfly4_dat_im_o (butterfly4_dat_im_o),
            .butterfly4_wr_o (butterfly4_wr),
            .butterfly4_rd_o (butterfly4_rd),
            .butterfly4_ack_i (butterfly4_ack),
            .butterfly4_err_i (butterfly4_err),

            .copy_adr_o (copy_adr),
            .copy_dat_re_i (copy_dat_re_i),
            .copy_dat_re_o (copy_dat_re_o),
            .copy_dat_im_i (copy_dat_im_i),
            .copy_dat_im_o (copy_dat_im_o),
            .copy_wr_o (copy_wr),
            .copy_rd_o (copy_rd),
            .copy_ack_i (copy_ack),
            .copy_err_i (copy_err),

            .ctrl_adr_i (ctrl_adr),
            .ctrl_dat_i (ctrl_dat_i),
            .ctrl_dat_o (ctrl_dat_o),
            .ctrl_bsel_i (ctrl_bsel),
            .ctrl_wr_i (ctrl_wr),
            .ctrl_rd_i (ctrl_rd),
            .ctrl_ack_o (ctrl_ack),
            .ctrl_err_o (ctrl_err),

            .tw_adr (tw_adr),
            .tw_rd (tw_rd),
            .tw_re (tw_re),
            .tw_im (tw_im),
            .tw_cfg_sel (tw_cfg_sel),

            .event_o (event_o),
            .int_o (int_o),

            .user_o (user));

endmodule
