/**
    @module true dualport avl adaptor 
    @author Dmitry Moskovskikh

    @description 
    По своей сути это просто "транслятор" чтобы bel fft 
    мог работать с памятью, у которой не avl интерфейс (нативный, например)

    данный враппер относится только к памяти, где A и B порты имеют общий клок
    ещё желательно не ошибиться с output registers, т.к. такие штуки влияют на задержку выхода

    немного про описание сигналов

    // avl iface signals
    m_address       - адрес чтения/записи
    m_readdata      - данные для чтения (если m_read high)
    m_writedata     - данные для записи (если m_write high)
    m_read          - сигнал, что читаем (активный верхний) 
    m_write         - сигнал, что пишем (активный верхний)
    
    PS (по протоколу одновременно m_read и m_write быть не может)

    m_waitrequest   - я хз, но вроде как, это при случае, 
    если адрес отправили для чтения, 
    но допустим у памяти есть задержка и мы должны держать его пока не valid - бред, честно говоря
    m_readdatavalid - валид, полезно, если на выходе из памяти, есть задержка (настраиваются спец. регистры)

**/

module tdpram_avl_adapor #(
    parameter int DWIDTH = 32, // размерность данных
    parameter int AWIDTH = 7, // битность адреса
    parameter int DEPTH  = 128 // глубина буфера must be 128, 256, 512, 1024
)(
    // sys
    input i_clk, input i_rst,

    // avl iface signals
    input  wire [AWIDTH - 1:0]  m_address,
    output wire [DWIDTH - 1:0]  m_readdata,
    input  wire [DWIDTH - 1:0]  m_writedata,
    input  wire                 m_read,
    input  wire                 m_write,
    output wire                 m_waitrequest,
    output wire                 m_readdatavalid,

    input   wire n_ena,
    input   wire n_wea,
    input   wire [AWIDTH - 1:0] n_addra,
    input   wire [DWIDTH - 1:0] n_dina,
    output  wire [DWIDTH - 1:0] n_douta,
    input   wire n_enb,
    input   wire n_web,
    input   wire [AWIDTH - 1:0] n_addrb,
    input   wire [DWIDTH - 1:0] n_dinb,
    output  wire [DWIDTH - 1:0] n_doutb
);
    localparam memdump_file = "ggwp.hex"

    initial begin
        always @(posedge i_clk) begin 
            if (m_write && m_read) begin 
                $fatal(1,"SIGNAL COLLISION DETECTED: m_write=1 and m_read=1");
            end 
        end 
    end 

    // for testbench
    task init_memory;
        integer i;

        for (i = 0; i < DEPTH; i = i + 1) begin
            //ram[i] = {`BEL_FFT_DWIDTH{16'hDEAD}};
        end
    endtask

    always @(posedge i_clk) begin 
        if (i_rst) begin
            
        end else begin

        end
    end 
endmodule;



