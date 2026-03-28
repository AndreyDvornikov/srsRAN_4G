/**
    @brief module memory single dualport ram wrapper
    @author Dmitry Moskovskikh

    @info просто обёртка над разными sdp ram
    где отличаются только BLK_DEPTH и WORD_WIDTH

    параметры смотреть в ip/mem_gen_256k32.xci
*/
module mem_sdpram_wrap #(
    parameter int BLK_DEPTH    = 256,
    parameter int WORD_WIDTH   = 32,

    localparam int addr_w  = (BLK_DEPTH <= 2) ? 1 : $clog2(BLK_DEPTH)
)(  
    // обязателен common clock (общий clock)
    input wire i_clk,
    input wire i_ena,
    // это просто ньюанс, вход в mem_gen должен быть [0:0] ширины
    // и [0:0] просто для соответствия с сигналом внутри (без [0:0] тоже должно быть корректно)
    input wire [0:0] i_wea,
    input wire [addr_w - 1:0] i_addra,
    input wire [WORD_WIDTH - 1:0] i_dina,

    input wire i_enb, 
    input wire [addr_w - 1:0] i_addrb,

    output wire [WORD_WIDTH - 1:0] o_doutb
);

generate 
    if (BLK_DEPTH == 256 && WORD_WIDTH == 32) begin : gen_blk256
        mem_gen_256k32 u_mem_gen_256k32 (
            .clka  (i_clk),
            .ena   (i_ena),
            .wea   (i_wea),
            .addra (i_addra),
            .dina  (i_dina),
            .clkb  (i_clk),
            .enb   (i_enb),
            .addrb (i_addrb),
            .doutb (o_doutb)
        );
    end else if (BLK_DEPTH == 512 && WORD_WIDTH == 32) begin : gen_blk512
        mem_gen_512k32 u_mem_gen_512k32 (
            .clka  (i_clk),
            .ena   (i_ena),
            .wea   (i_wea),
            .addra (i_addra),
            .dina  (i_dina),
            .clkb  (i_clk),
            .enb   (i_enb),
            .addrb (i_addrb),
            .doutb (o_doutb)
        );
    end else begin : gen_unsupported
        initial $fatal(1, "Unsupported BLK_DEPTH=%0d or WORD_WIDTH=%0d", BLK_DEPTH, WORD_WIDTH);
    end 
endgenerate

endmodule