`ifndef _vector_svh_
`define _vector_svh_

// битовый флаг для умножения векторов
`define OP_VECTOR_MUL 8'b0000001

// О
typedef enum { 
    MUL
} OP_VECTOR_CODES;

// для vector FSM
typedef enum { 
    IDLE,
    RUN,
    COMPLETE
} VECTOR_ALU_STATES;

`endif 