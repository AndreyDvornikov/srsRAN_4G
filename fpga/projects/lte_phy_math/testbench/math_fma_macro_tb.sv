`timescale 1ns/1ps

`include "headers/header.svh"

module tb_math_fma_macro;
    logic clk;
    logic rst;

    localparam int C_BIT_DEPTH   = 64; 
    localparam int FMA_PIPE_SIZE = 4;

    logic signed [`HW_ADC_WIDTH-1:0]    A;
    logic signed [`HW_ADC_WIDTH-1:0]    B;

    logic signed [C_BIT_DEPTH-1:0]      C;
    logic                               i_valid;

    logic signed [C_BIT_DEPTH-1:0]      F;
    logic                               o_valid;

    // fma rst
    // ticks - задаёт время сигнала ресета в тактах
    task automatic fma_reset(int ticks);
        rst = 1'b1;
        
        repeat(ticks) begin
            tick();
        end
        
        rst = 1'b0;
    endtask

    // проверка значений регистров внутри модуля
    // после сигнала reset (и во время)
    task static v1_verify_rst();
        integer j;
        logic error_found;
        
        error_found = 1'b0;

        fma_reset(2);

        $display("[VERIFY] Checking reset state at t=%0t", $time);
        
        // проверяем pipe_i_valid
        if (dut_1.pipe_i_valid !== '0) begin
            $error("[FAIL] pipe_i_valid = %b, expected 0", dut_1.pipe_i_valid);
            error_found = 1'b1;
        end
        
        // проверяем pipe_a
        for (j = 0; j < dut_1.PIPE; j++) begin
            if (dut_1.pipe_a[j] !== '0) begin
                $error("[FAIL] pipe_a[%0d] = %0d, expected 0", j, dut_1.pipe_a[j]);
                error_found = 1'b1;
            end
        end
        
        // проверяем pipe_b
        for (j = 0; j < dut_1.PIPE; j++) begin
            if (dut_1.pipe_b[j] !== '0) begin
                $error("[FAIL] pipe_b[%0d] = %0d, expected 0", j, dut_1.pipe_b[j]);
                error_found = 1'b1;
            end
        end
        
        // проверяем pipe_c (включая PIPE элемент)
        for (j = 0; j <= dut_1.PIPE; j++) begin
            if (dut_1.pipe_c[j] !== '0) begin
                $error("[FAIL] pipe_c[%0d] = %0d, expected 0", j, dut_1.pipe_c[j]);
                error_found = 1'b1;
            end
        end
        
        // проверяем mul_ff
        if (dut_1.mul_ff !== '0) begin
            $error("[FAIL] mul_ff = %0d, expected 0", dut_1.mul_ff);
            error_found = 1'b1;
        end
        
        // проверяем res_ff
        if (dut_1.res_ff !== '0) begin
            $error("[FAIL] res_ff = %0d, expected 0", dut_1.res_ff);
            error_found = 1'b1;
        end
        
        // проверяем выходы
        if (o_valid !== 1'b0) begin
            $error("[FAIL] o_valid = %b, expected 0", o_valid);
            error_found = 1'b1;
        end
        
        if (!error_found) begin
            $display("[PASS] [v1_verify_rst] All registers reset correctly");
        end
    endtask


    // DUT
    math_fma_macro #(
        .A_WIDTH(`HW_ADC_WIDTH),
        .B_WIDTH(`HW_ADC_WIDTH),
        .C_WIDTH(C_BIT_DEPTH),
        .PIPE(FMA_PIPE_SIZE)
    ) dut_1 (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .C(C),
        .i_valid(i_valid),
        .F(F),
        .o_valid(o_valid)
    );

    // clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100MHz
    end

    task automatic tick();
        @(posedge clk);
    endtask

    task automatic push_fma(
        logic signed [`HW_ADC_WIDTH-1:0] a,
        logic signed [`HW_ADC_WIDTH-1:0] b,
        logic signed [C_BIT_DEPTH - 1:0] c
    );
        $display("pushed [a=%d][b=%d][c=%d]\n", a,b,c);

        A = a;
        B = b;
        C = c;
        i_valid = 1'b1;

        tick();
    endtask

    // тут просто проверяется, что fma
    // возвращает результат через заданное кол-во тактов (ещё и определённое)
    // такты зависят от PIPE (FMA_PIPE_SIZE)
    task automatic fma_pipe_ticks_behv();
        logic signed [`HW_ADC_WIDTH-1:0] test_a, test_b;
        logic signed [C_BIT_DEPTH-1:0]   test_c;
        logic signed [C_BIT_DEPTH-1:0]   expected_result;
        integer cycle_count;
        logic result_ok;
        localparam int EXPECTED_FMA_PIPE_TICKS = FMA_PIPE_SIZE + 1;
        
        $display("\n[TEST] fma_pipe_ticks_behv: Checking pipeline delay");
        $display("[TEST] Expected delay from i_valid to o_valid: %0d cycles", FMA_PIPE_SIZE);
        
        // тестовые значения: -10 * 5 + 60 = 10
        test_a = -10;
        test_b = 5;
        test_c = 60;
        expected_result = test_a * test_b + test_c;
        
        $display("[TEST] Test values: A=%0d, B=%0d, C=%0d, Expected F=%0d", 
                test_a, test_b, test_c, expected_result);
        
        // подаём данные
        A = test_a;
        B = test_b;
        C = test_c;
        i_valid = 1'b1;
        
        tick();
        i_valid = 1'b0;
        
        // считаем такты до o_valid
        cycle_count = 0;
        result_ok = 1'b0;

        while (cycle_count < (FMA_PIPE_SIZE + 5)) begin
            if (o_valid === 1'b1) begin
                $display("[TEST] o_valid asserted at cycle %0d (t=%0t)", cycle_count, $time);
                
                // проверяем задержку
                if (cycle_count === EXPECTED_FMA_PIPE_TICKS) begin
                    $display("[PASS] Pipeline delay correct: %0d cycles", cycle_count);
                end else begin
                    $error("[FAIL] Pipeline delay incorrect: got %0d, expected %0d", 
                        cycle_count, EXPECTED_FMA_PIPE_TICKS);
                end
                
                // проверяем результат
                if (F === expected_result) begin
                    $display("[PASS] Result correct: F=%0d", F);
                end else begin
                    $error("[FAIL] Result incorrect: F=%0d, expected %0d", F, expected_result);
                end
                
                result_ok = 1'b1;
                break;
            end
            
            tick();
            cycle_count++;
        end
        
        if (!result_ok) begin
            $error("[FAIL] o_valid never asserted within %0d cycles", cycle_count);
        end
        
        // сброс входов
        A = '0;
        B = '0;
        C = '0;
        
        $display("[TEST] fma_pipe_ticks_behv completed\n");
    endtask

    initial begin
        // init
        rst = 1'b1;
        A = '0; B = '0; C = '0;
        i_valid = 1'b0;

        `ifndef _HEADERS_SVH_
            $display("ну короче, что-то не так пошло))");
        `else
            $display("HW_ADC_WIDTH=%d\n", `HW_ADC_WIDTH);
        `endif

        v1_verify_rst();

        // hold reset 2 cycles
        tick();
        tick();

        rst = 1'b0;

        tick();

        // визуальные тесты (вручную глядеть waveform)

        // A * B + C = 5;
        push_fma(16'sd1, 16'sd2, 16'sd3); 

        // A * B + C = 7;
        push_fma(3, 2, 1); 

        // A * B + C = 5;
        push_fma(1, 2, 3); 

        // 32767 * 32767 + 32767 = 1 073 709 056
        push_fma(`MAX_SIGNED_INT16, `MAX_SIGNED_INT16, `MAX_SIGNED_INT16); 

        // A * B + C = -46
        push_fma(-10, 5, 4); 

        // A * B + C = 10
        push_fma(-10, 5, 60); 

        repeat(FMA_PIPE_SIZE) begin
            tick();
        end

        A = '0; B = '0; C = '0;
        i_valid = 1'b0;
    
        fma_reset(2); 

        fma_pipe_ticks_behv();

        tick();
        tick();
        tick();
        tick();
        tick();
        tick();
        tick();
        tick();
        tick();
        tick();
        tick();
        $finish;
    end

endmodule
