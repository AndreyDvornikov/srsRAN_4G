module mem_tdpram_wrap #(
    parameter DWIDTH = 32,  // размерность данных
    parameter AWIDTH = 7,   // битность адреса
    parameter DEPTH  = 128  // глубина буфера must be 128, 256, 512, 1024
)(
    input i_clk,

    input   wire ena,
    input   wire wea,
    input   wire [AWIDTH - 1:0] addra,
    input   wire [DWIDTH - 1:0] dina,
    output  wire [DWIDTH - 1:0] douta,
    input   wire enb,
    input   wire web,
    input   wire [AWIDTH - 1:0] addrb,
    input   wire [DWIDTH - 1:0] dinb,
    output  wire [DWIDTH - 1:0] doutb
);
    generate 
        if (DWIDTH == 32 && AWIDTH == 7 && DEPTH == 128) begin : gen_blk128
            tdpram_32x128 u_mem_gen_32x128 (
                .clka(i_clk),        // input wire clka
                .ena(ena),      // input wire ena
                .wea(wea),      // input wire [0 : 0] wea
                .addra(addra),  // input wire [6 : 0] addra
                .dina(dina),    // input wire [31 : 0] dina
                .douta(douta),  // output wire [31 : 0] douta
                .clkb(i_clk),        // input wire clkb
                .enb(enb),      // input wire enb
                .web(web),      // input wire [0 : 0] web
                .addrb(addrb),  // input wire [6 : 0] addrb
                .dinb(dinb),    // input wire [31 : 0] dinb
                .doutb(doutb)  // output wire [31 : 0] doutb
            );
        end else if (DWIDTH == 32 && AWIDTH == 8 && DEPTH == 256) begin : gen_blk256
            tdpram_32x256 u_mem_gen_32x256 (
                .clka(i_clk),    // input wire clka
                .ena(n_ena),      // input wire ena
                .wea(n_wea),      // input wire [0 : 0] wea
                .addra(n_addra),  // input wire [7 : 0] addra
                .dina(n_dina),    // input wire [31 : 0] dina
                .douta(n_douta),  // output wire [31 : 0] douta
                .clkb(i_clk),    // input wire clkb
                .enb(n_enb),      // input wire enb
                .web(n_web),      // input wire [0 : 0] web
                .addrb(n_addrb),  // input wire [7 : 0] addrb
                .dinb(n_dinb),    // input wire [31 : 0] dinb
                .doutb(n_doutb)  // output wire [31 : 0] doutb
            );
        end else if (DWIDTH == 32 && AWIDTH == 9 && DEPTH == 512) begin : gen_blk512
            tdpram_32x512 u_mem_gen_32x512 (
                .clka(i_clk),    // input wire clka
                .ena(n_ena),      // input wire ena
                .wea(n_wea),      // input wire [0 : 0] wea
                .addra(n_addra),  // input wire [7 : 0] addra
                .dina(n_dina),    // input wire [31 : 0] dina
                .douta(n_douta),  // output wire [31 : 0] douta
                .clkb(i_clk),    // input wire clkb
                .enb(n_enb),      // input wire enb
                .web(n_web),      // input wire [0 : 0] web
                .addrb(n_addrb),  // input wire [7 : 0] addrb
                .dinb(n_dinb),    // input wire [31 : 0] dinb
                .doutb(n_doutb)  // output wire [31 : 0] doutb
            );
        end else if (DWIDTH == 32 && AWIDTH == 10 && DEPTH == 1024) begin : gen_blk1024
            tdpram_32x1024 u_mem_gen_32x1024 (
                .clka(i_clk),    // input wire clka
                .ena(n_ena),      // input wire ena
                .wea(n_wea),      // input wire [0 : 0] wea
                .addra(n_addra),  // input wire [7 : 0] addra
                .dina(n_dina),    // input wire [31 : 0] dina
                .douta(n_douta),  // output wire [31 : 0] douta
                .clkb(i_clk),    // input wire clkb
                .enb(n_enb),      // input wire enb
                .web(n_web),      // input wire [0 : 0] web
                .addrb(n_addrb),  // input wire [7 : 0] addrb
                .dinb(n_dinb),    // input wire [31 : 0] dinb
                .doutb(n_doutb)  // output wire [31 : 0] doutb
            );      
        end else begin : gen_unsupported
            initial $fatal(1, "Unsupported DWIDTH=%0d or AWIDTH=%0d or DEPTH=%0d", DWIDTH, AWIDTH, DEPTH);
        end 
    endgenerate
endmodule;