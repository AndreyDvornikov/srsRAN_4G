////////////////////////////////////////////////////////////////////
//
// lte_phy_fft_twiddle_rom0.v.v
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


module lte_phy_fft_twiddle_rom0 (
        clka,
        ena,
        addra,
        douta);

    input clka;
    input ena;
    input [7 - 1:0] addra;
    output [32 - 1: 0] douta;

    reg [32 - 1:0] rom [128 - 1:0];
    reg [32 - 1:0] douta;

    always @(posedge clka) begin
        if (ena) begin
            case (addra)
                7'h0000: douta <= 32'h7FFF0000;
                7'h0001: douta <= 32'h7FD8F9B8;
                7'h0002: douta <= 32'h7F61F374;
                7'h0003: douta <= 32'h7E9CED38;
                7'h0004: douta <= 32'h7D89E707;
                7'h0005: douta <= 32'h7C29E0E6;
                7'h0006: douta <= 32'h7A7CDAD8;
                7'h0007: douta <= 32'h7884D4E1;
                7'h0008: douta <= 32'h7641CF05;
                7'h0009: douta <= 32'h73B5C946;
                7'h000A: douta <= 32'h70E2C3AA;
                7'h000B: douta <= 32'h6DC9BE32;
                7'h000C: douta <= 32'h6A6DB8E4;
                7'h000D: douta <= 32'h66CFB3C1;
                7'h000E: douta <= 32'h62F1AECD;
                7'h000F: douta <= 32'h5ED7AA0B;
                7'h0010: douta <= 32'h5A82A57E;
                7'h0011: douta <= 32'h55F5A129;
                7'h0012: douta <= 32'h51339D0F;
                7'h0013: douta <= 32'h4C3F9931;
                7'h0014: douta <= 32'h471C9593;
                7'h0015: douta <= 32'h41CE9237;
                7'h0016: douta <= 32'h3C568F1E;
                7'h0017: douta <= 32'h36BA8C4B;
                7'h0018: douta <= 32'h30FB89BF;
                7'h0019: douta <= 32'h2B1F877C;
                7'h001A: douta <= 32'h25288584;
                7'h001B: douta <= 32'h1F1A83D7;
                7'h001C: douta <= 32'h18F98277;
                7'h001D: douta <= 32'h12C88164;
                7'h001E: douta <= 32'h0C8C809F;
                7'h001F: douta <= 32'h06488028;
                7'h0020: douta <= 32'h00008001;
                7'h0021: douta <= 32'hF9B88028;
                7'h0022: douta <= 32'hF374809F;
                7'h0023: douta <= 32'hED388164;
                7'h0024: douta <= 32'hE7078277;
                7'h0025: douta <= 32'hE0E683D7;
                7'h0026: douta <= 32'hDAD88584;
                7'h0027: douta <= 32'hD4E1877C;
                7'h0028: douta <= 32'hCF0589BF;
                7'h0029: douta <= 32'hC9468C4B;
                7'h002A: douta <= 32'hC3AA8F1E;
                7'h002B: douta <= 32'hBE329237;
                7'h002C: douta <= 32'hB8E49593;
                7'h002D: douta <= 32'hB3C19931;
                7'h002E: douta <= 32'hAECD9D0F;
                7'h002F: douta <= 32'hAA0BA129;
                7'h0030: douta <= 32'hA57EA57E;
                7'h0031: douta <= 32'hA129AA0B;
                7'h0032: douta <= 32'h9D0FAECD;
                7'h0033: douta <= 32'h9931B3C1;
                7'h0034: douta <= 32'h9593B8E4;
                7'h0035: douta <= 32'h9237BE32;
                7'h0036: douta <= 32'h8F1EC3AA;
                7'h0037: douta <= 32'h8C4BC946;
                7'h0038: douta <= 32'h89BFCF05;
                7'h0039: douta <= 32'h877CD4E1;
                7'h003A: douta <= 32'h8584DAD8;
                7'h003B: douta <= 32'h83D7E0E6;
                7'h003C: douta <= 32'h8277E707;
                7'h003D: douta <= 32'h8164ED38;
                7'h003E: douta <= 32'h809FF374;
                7'h003F: douta <= 32'h8028F9B8;
                7'h0040: douta <= 32'h80010000;
                7'h0041: douta <= 32'h80280648;
                7'h0042: douta <= 32'h809F0C8C;
                7'h0043: douta <= 32'h816412C8;
                7'h0044: douta <= 32'h827718F9;
                7'h0045: douta <= 32'h83D71F1A;
                7'h0046: douta <= 32'h85842528;
                7'h0047: douta <= 32'h877C2B1F;
                7'h0048: douta <= 32'h89BF30FB;
                7'h0049: douta <= 32'h8C4B36BA;
                7'h004A: douta <= 32'h8F1E3C56;
                7'h004B: douta <= 32'h923741CE;
                7'h004C: douta <= 32'h9593471C;
                7'h004D: douta <= 32'h99314C3F;
                7'h004E: douta <= 32'h9D0F5133;
                7'h004F: douta <= 32'hA12955F5;
                7'h0050: douta <= 32'hA57E5A82;
                7'h0051: douta <= 32'hAA0B5ED7;
                7'h0052: douta <= 32'hAECD62F1;
                7'h0053: douta <= 32'hB3C166CF;
                7'h0054: douta <= 32'hB8E46A6D;
                7'h0055: douta <= 32'hBE326DC9;
                7'h0056: douta <= 32'hC3AA70E2;
                7'h0057: douta <= 32'hC94673B5;
                7'h0058: douta <= 32'hCF057641;
                7'h0059: douta <= 32'hD4E17884;
                7'h005A: douta <= 32'hDAD87A7C;
                7'h005B: douta <= 32'hE0E67C29;
                7'h005C: douta <= 32'hE7077D89;
                7'h005D: douta <= 32'hED387E9C;
                7'h005E: douta <= 32'hF3747F61;
                7'h005F: douta <= 32'hF9B87FD8;
                7'h0060: douta <= 32'h00007FFF;
                7'h0061: douta <= 32'h06487FD8;
                7'h0062: douta <= 32'h0C8C7F61;
                7'h0063: douta <= 32'h12C87E9C;
                7'h0064: douta <= 32'h18F97D89;
                7'h0065: douta <= 32'h1F1A7C29;
                7'h0066: douta <= 32'h25287A7C;
                7'h0067: douta <= 32'h2B1F7884;
                7'h0068: douta <= 32'h30FB7641;
                7'h0069: douta <= 32'h36BA73B5;
                7'h006A: douta <= 32'h3C5670E2;
                7'h006B: douta <= 32'h41CE6DC9;
                7'h006C: douta <= 32'h471C6A6D;
                7'h006D: douta <= 32'h4C3F66CF;
                7'h006E: douta <= 32'h513362F1;
                7'h006F: douta <= 32'h55F55ED7;
                7'h0070: douta <= 32'h5A825A82;
                7'h0071: douta <= 32'h5ED755F5;
                7'h0072: douta <= 32'h62F15133;
                7'h0073: douta <= 32'h66CF4C3F;
                7'h0074: douta <= 32'h6A6D471C;
                7'h0075: douta <= 32'h6DC941CE;
                7'h0076: douta <= 32'h70E23C56;
                7'h0077: douta <= 32'h73B536BA;
                7'h0078: douta <= 32'h764130FB;
                7'h0079: douta <= 32'h78842B1F;
                7'h007A: douta <= 32'h7A7C2528;
                7'h007B: douta <= 32'h7C291F1A;
                7'h007C: douta <= 32'h7D8918F9;
                7'h007D: douta <= 32'h7E9C12C8;
                7'h007E: douta <= 32'h7F610C8C;
                7'h007F: douta <= 32'h7FD80648;
            endcase
        end
    end

endmodule
