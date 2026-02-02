`include "bel_fft_def.v"


module testbench;

    parameter input_file_name = "input_data_128.dat";
    parameter fft_size = 128;
    parameter inverse = 0;
    parameter word_width = 16;
    parameter ram_awidth = 7;
    
    reg clk;
    reg rst;

    wire [`BEL_FFT_MIF_AWIDTH - 1:0] m_address;
    wire [`BEL_FFT_DWIDTH - 1:0] m_readdata;
    wire [`BEL_FFT_DWIDTH - 1:0] src_m_readdata;
    wire [`BEL_FFT_DWIDTH - 1:0] dst_m_readdata;
    wire [`BEL_FFT_DWIDTH - 1:0] m_writedata;
    wire m_read;
    wire src_m_read;
    wire dst_m_read;
    wire m_write;
    wire src_m_write;
    wire dst_m_write;
    wire m_waitrequest;
    wire m_readdatavalid;
    wire src_m_readdatavalid;
    wire dst_m_readdatavalid;

    reg dat_sel;

    initial begin
        rst = 1'b1;
        #20 rst = 1'b0;
    end
    

    initial begin
        clk = 1'b0;
    end
    

    always begin
        #10 clk = 1'b1;
        #10 clk = 1'b0;
    end

    reg start;
    wire ctrl_finish;

    reg is_running;

    always @(posedge clk or posedge rst) begin
        if (rst) begin 
            start       <= 1'b0;
            is_running  <= 1'b0;
        end else if (is_running == 1'b0) begin 
            start <= 1'b1;
            is_running <= 1'b1;
        end else begin 
            start <= 1'b0;
        end
    end

    initial begin
        // ждём выход из reset
        @(negedge rst);

        // ждём завершение FSM (он ждёт int от bel_fft)
        @(posedge ctrl_finish);
        
        // можно подождать 1-2 такта, если хочешь
        repeat (2) @(posedge clk);

        u_OutputRam.dump;
        $finish;
    end

    initial begin
        // Timeout in case of errors
        
        #100000000 $finish;
    end

    always @(posedge clk or posedge rst) begin
        if (rst == 1'b1) begin
           dat_sel <= 1'b0;
        end else begin
            if (m_read | m_write) begin
                if (m_address[ram_awidth + 3:ram_awidth + 2] == 2'b10) begin
                    dat_sel <= 1'b1;
                end else begin
                    dat_sel <= 1'b0;
                end
            end
        end
    end

    assign src_m_read = (m_address[ram_awidth + 3:ram_awidth + 2] == 2'b01) ? m_read : 1'b0;
    assign dst_m_read = (m_address[ram_awidth + 3:ram_awidth + 2] == 2'b10) ? m_read : 1'b0;
    assign src_m_write = (m_address[ram_awidth + 3:ram_awidth + 2] == 2'b01) ? m_write : 1'b0;
    assign dst_m_write = (m_address[ram_awidth + 3:ram_awidth + 2] == 2'b10) ? m_write : 1'b0;
    assign m_readdata = dat_sel ? dst_m_readdata : src_m_readdata;
    assign m_readdatavalid = dat_sel ? dst_m_readdatavalid : src_m_readdatavalid;
    assign m_waitrequest = 1'b0;


    bel_avl_ram #(fft_size * word_width * 2 / `BEL_FFT_DWIDTH, ram_awidth,
            input_file_name, "/dev/null", "input_ram.log") u_InputRam (
            .clk_i (clk),
            .rst_i (rst),
            .address (m_address[ram_awidth + 1:2]),
            .readdata (src_m_readdata),
            .writedata (m_writedata),
            .read (src_m_read),
            .write (src_m_write),
            .readdatavalid (src_m_readdatavalid));


    bel_avl_ram #(fft_size * (word_width * 2 / `BEL_FFT_DWIDTH), ram_awidth,
            "", "output_data.dat", "output_ram.log") u_OutputRam (
            .clk_i (clk),
            .rst_i (rst),
            .address (m_address[ram_awidth + 1:2]),
            .readdata (dst_m_readdata),
            .writedata (m_writedata),
            .read (dst_m_read),
            .write (dst_m_write),
            .readdatavalid (dst_m_readdatavalid));

    system_lte_phy_fft
        u_system_fft(
            .i_clk(clk),
            .i_rst(rst),
            .i_start(start),
            .m_address(m_address),
            .m_readdata(m_readdata),
            .m_writedata(m_writedata),
            .m_read(m_read),
            .m_write(m_write),
            .m_waitrequest(m_waitrequest),
            .m_readdatavalid(m_readdatavalid),
            .o_finish(ctrl_finish));  
endmodule

