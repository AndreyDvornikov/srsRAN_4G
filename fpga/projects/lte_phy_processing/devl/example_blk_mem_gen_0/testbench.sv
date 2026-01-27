`timescale 1ns/1ps

module testbench;

    logic clk;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100 MHz
    end

    logic        ena;
    logic [0:0]  wea;
    logic [7:0]  addra;
    logic [31:0] dina;

    logic        enb;
    logic [7:0]  addrb;
    logic [31:0] doutb;

    // ----------------------------------------------------------------
    // DUT instance
    // ----------------------------------------------------------------
    mem_sdpram_wrap dut (
        .i_clk   (clk),
        .i_ena   (ena),
        .i_wea   (wea),
        .i_addra (addra),
        .i_dina  (dina),
        
        .i_enb   (enb),
        .i_addrb (addrb),
        .o_doutb (doutb)
    );

    // ----------------------------------------------------------------
    // Helpers
    // ----------------------------------------------------------------
    task automatic tick();
        @(posedge clk);
    endtask

    // вся задача этого task отразить
    // связь между настройками выходных регистров и задержкой выхода в тактах    
    task automatic in_reg_wait();
        // на вход нет включеных регистров
        tick();
    endtask

    task automatic out_reg_wait();
        // это задержка выхода БЕЗ выходных регистров
        // т.е. addrb подаём, значение появится на 1 такт позже
        tick();
        // но! ещё и стоит упомянуть выбранную опцию Primitives Output registers
        tick();
        // т.е. итоговая задержка выхода 2 такта!
    endtask 

    task automatic init_signals();
        ena   = 1'b0;
        wea   = 1'b0;
        addra = '0;
        dina  = '0;

        enb   = 1'b0;
        addrb = '0;

        tick();
        tick();
    endtask

    task automatic check_equal(input int addr, input logic [31:0] got, input logic [31:0] exp);
        if (got !== exp) begin
            $error("ADDR=%0d (0x%02h) GOT=0x%08h EXP=0x%08h", addr, addr[7:0], got, exp);
            $finish;
        end
    endtask

    task automatic read_word(input logic [7:0] addr, output logic [31:0] data);
        enb     = 1'b1;
        addrb   = addr; 

        // адрес появится на след. фронте
        tick(); 
        out_reg_wait();

        data    = doutb;
        enb     = 1'b0;
    endtask

    // write: 1 word / cycle
    task automatic write_all_const(input logic [31:0] val);
        ena = 1'b1;
        wea = 1'b1;
        for (int i = 0; i < 256; i++) begin
            // i - int 32, а addra - 8 бит, поэтому и от 7:0
            addra = i[7:0]; 
            dina  = val;
            in_reg_wait();
        end
        ena = 1'b0;
        wea = 1'b0;
    endtask

    task automatic write_1_to_256();
        ena = 1'b1;
        wea = 1'b1;
        for (int i = 0; i < 256; i++) begin
            addra = i[7:0];
            dina  = 32'(i+1);
            in_reg_wait();
        end
        ena = 1'b0;
        wea = 1'b0;
    endtask

    //
    task automatic read_check_const(input logic [31:0] exp_val);
        logic [31:0] r;

        for (int i = 0; i < 256; i++) begin
            read_word(i[7:0], r);
            check_equal(i, r, exp_val);
        end
    endtask

    task automatic read_check_1_to_256();
        logic [31:0] r;

        for (int i = 0; i < 256; i++) begin
            read_word(i[7:0], r);
            check_equal(i, r, 32'(i+1));
        end
    endtask

    // ----------------------------------------------------------------
    // Test scenario
    // ----------------------------------------------------------------
    initial begin : tb_main
        init_signals();

        // 1) fill all memory with 0xDEAD_DEAD
        write_all_const(32'hDEAD_DEAD);

        // 2) read verify DEAD
        read_check_const(32'hDEAD_DEAD);

        // 3) write 1..256 into addresses 0..255
        write_1_to_256();

        // 4) read verify 1..256
        read_check_1_to_256();

        $display("PASS: DUT R/W test finished OK");
        $finish;
    end

endmodule
