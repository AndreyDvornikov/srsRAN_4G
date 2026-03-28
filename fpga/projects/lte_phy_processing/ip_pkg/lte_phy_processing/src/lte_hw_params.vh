`ifndef _HEADERS_SVH_
`define _HEADERS_SVH_

// размер mem на input iq
`define MEM_BLOCK_DEPTH 256 

`default_nettype none

`define MAX_SIGNED_INT16 32767
`define MIN_SIGNED_INT16 -32768

// 16 бит АЦП
`define HW_ADC_WIDTH 16

// размер преобразования фурье для N_prb
// @3GPP constant
`define LTE_N_FFT_6PRB  128
`define LTE_N_FFT_15PRB 256

`define LTE_SELECTED_N_FFT  `LTE_N_FFT_6PRB
`define LTE_N_FFT           `LTE_SELECTED_N_FFT
// FOR 1.92MHZ
`define LTE_PSS_PERIOD_SAMPS_FOR_1_92 9600 

`define LTE_PSS_PERIOD_SAMPS `LTE_PSS_PERIOD_SAMPS_FOR_1_92

// размер циклического префикса OFDMA
// @3GPP constant
`define LTE_OFDMA_CP    9   

// разрядность PSS-семпла
`define LTE_PSS_WORD_WIDTH `HW_ADC_WIDTH
`define LTE_PSS_TD_LEN          `LTE_SELECTED_N_FFT    // PSS длина = FFT size
`define LTE_PSS_ADDR_WIDTH      $clog2(`LTE_PSS_TD_LEN)
`define LTE_PSS_COUNT      3

`define LTE_PSS_ADDR_WIDTH      $clog2(`LTE_PSS_TD_LEN)

 `define HW_ADC_TARGET_FS 3840000
// `define HW_ADC_TARGET_FS 1920000

// разрядность PSS флага
`define F_PSS_IDX_WIDTH    2

`endif // _HEADERS_SVH_