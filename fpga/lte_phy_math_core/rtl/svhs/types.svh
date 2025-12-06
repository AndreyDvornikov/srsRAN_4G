`ifndef _types_svh_
`define _types_svh_

`define SIMULATION

`define TRUE  1'b1
`define FALSE 1'b0

/*
    Интерфейс взаимодействия
    с источником тактового сигнала
*/
interface CLOCK;
    logic clk;
    logic is_locked;
    logic rst;

    // i - входит в модулю
    modport i (
        input clk,
        input is_locked,
        input rst
    );

    // o - выходит из модуля
    modport o (
        output clk,
        output is_locked,
        output rst
    );  
endinterface // clock_if

/*
    gavno
*/
interface AXI_LITE;

endinterface // axi_lite_if 

/*
    gavno
*/
interface axi_stream_if; 
endinterface // axi_stream_if 

`endif