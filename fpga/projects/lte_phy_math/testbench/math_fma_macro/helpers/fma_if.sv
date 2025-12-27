interface fma_if #(int A_W=16, B_W=16, C_W=64, F_W=64, AB_W=32) (input logic clk);
    logic rst;
    logic signed [A_W-1:0]  A, B;
    logic signed [C_W-1:0]  C;
    logic                   i_valid;

    logic signed [F_W-1:0]  F;
    logic signed [AB_W-1:0] F_mul;
    logic                   o_valid;


    clocking cb @(posedge clk);
        default input #1step output #1step;
        // tb -> dut_tb
        output rst, A, B, C, i_valid;
        // dut_tb -> tb
        input  F, F_mul, o_valid;
    endclocking
endinterface

// названия SPI

/*
    Тут пришлось немного научиться пользоваться clocking_block и interface
    
    interface - просто обёртка над сигналами
    clocking - механизм, который контролирует "драйв" этих сигналов внутрь модуля, который мы тестируем
    и из него и всё это происходит относительно clk, который мы задали
    
    1) какие сигналы TB драйвит (output), а какие сэмплит (input),
    2) и когда именно это делать относительно clk

    тут подробнее стоит обратить внимание на то, зачем это и почему пришлось это использовать

    самое главное - обратить внимание на default input и default output 
    и на то, почему там #1step (где step - единица времени, как ms,ns,ps и т.д.)

    но 1step - это специальная единица, один минимальный шаг точности симуляции, т.е. если у нас разрешение 1us (точность), то
    1step - 1us

    1step - задаёт нам смещение
    Для input #1step: значение входа сэмплится "в самом конце предыдущего time-step", то есть берётся последнее стабильное значение непосредственно перед clock event.
    ​Для output #1step: значение выхода драйвится на "микрошаг" после clock event, чтобы TB не менял вход в тот же момент, когда DUT его сэмплит на фронте.

    зачем это надо?

    module dut(input logic clk, input logic a, output logic q);
        always_ff @(posedge clk) q <= a;
    endmodule

    module tb_bad;
        logic clk=0, a;
        logic q;

        always #5 clk = ~clk;

        dut u(.clk(clk), .a(a), .q(q));

        // TB меняет a на том же событии posedge clk, где DUT сэмплит a
        initial begin
            a = 0;
            @(posedge clk);
            a = 1;
            @(posedge clk);
            if (q !== 1) $error("Race: expected q=1, got q=%0b", q);
        end
    endmodule

    т.е. механически это выглядит так.
    Мы подали a на вход dut
    a = 0 (q в этот момент ещё неизвестно)
    @(posedge clk);
    
    Важно! module dut и наш tb ждёт один и тот же event - posegde clk и кто будет "первым" - решает наш симулятор
    и это приводит к разным ситуациям

    Сценарий 1 (TB выполняется первым на 1-м posedge):
        TB делает a = 1;
        Затем DUT сэмплит a=1 и планирует q <= 1;
        В конце этого же posedge q станет 1.
        На следующем posedge проверка q пройдет.

    Сценарий 2 (DUT выполняется первым на 1-м posedge):
        DUT сэмплит a=0 и планирует q <= 0;
        Затем TB делает a = 1 (но для этого фронта уже поздно);
        В конце этого же posedge q станет 0.
        На следующем posedge проверка увидит q=0 и упадет.

    clocking block с задержкой 1step говорит нам
    если сигнал на input, то мы не приниамем его сразу во время события,а ждём 1step 
    если сигнал на output, то мы не отправялем его сразу во время события, а ждём 1step
*/