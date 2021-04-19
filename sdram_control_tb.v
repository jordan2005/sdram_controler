 
`timescale 1ns/1ns
 
module sdram_control_tb (); /* this is automatically generated */
 
    reg rst_n;
    reg clk;
 
    parameter clk_period = 10;
 
    localparam TWAIT_200us   = 15'd20000;
    localparam TRP           = 2'd3;
    localparam TRC           = 4'd10;
    localparam TRSC          = 2'd3;
    localparam TRCD          = 2'd2;
    localparam TREAD_10      = 4'd10;
    localparam TWRITE_7      = 3'd7;
    localparam AUTO_REF_TIME = 11'd1562;
    localparam NOP           = 3'd0;
    localparam PRECHARGE     = 3'd1;
    localparam REF           = 3'd2;
    localparam MODE          = 3'd3;
    localparam IDLE          = 3'd4;
    localparam ACTIVE        = 3'd5;
    localparam WRITE         = 3'd6;
    localparam READ          = 3'd7;
    localparam NOP_CMD       = 4'b0111;
    localparam PRECHARGE_CMD = 4'b0010;
    localparam REF_CMD       = 4'b0001;
    localparam MODE_CMD      = 4'b0000;
    localparam ACTIVE_CMD    = 4'b0011;
    localparam WRITE_CMD     = 4'b0100;
    localparam READ_CMD      = 4'b0101;
    localparam ALL_BANK      = 12'b01_0_00_000_0_000;
    localparam MODE_CONFIG   = 12'b00_0_00_011_0_011;
 
    reg         wr_en;
    reg  [15:0] wr_data;
    reg         rd_en;
    reg   [1:0] bank_addr;
    reg  [12:0] row_addr;
    reg   [8:0] col_addr;
    wire [15:0] rd_data;
    wire        rd_data_vld;
    wire        wr_data_vld;
    wire        wdata_done;
    wire        rdata_done;
    wire        sdram_clk;
    wire  [3:0] sdram_commond;
    wire        sdram_cke;
    wire  [1:0] sdram_dqm;
    wire [11:0] sdram_addr;
    wire  [1:0] sdram_bank;
    wire [15:0] sdram_dq;
 
    //reg sdram_dq_en;
    //reg    sdram_dq_r;
    //assign sdram_dq = sdram_dq_en ? sdram_dq_r : 16'hzzzz;
 
    sdram_control inst_sdram_control
        (
            .clk           (clk),
            .rst_n         (rst_n),
            .wr_en         (wr_en),
            .wr_data       (wr_data),
            .rd_en         (rd_en),
            .bank_addr     (bank_addr),
            .row_addr      (row_addr),
            .col_addr      (col_addr),
            .rd_data       (rd_data),
            .rddata_vld    (rd_data_vld),
            .wrdata_vld    (wr_data_vld),
            .sdram_clk     (sdram_clk),
            .sdram_cmd     (sdram_commond),
            .sdram_cke     (sdram_cke),
            .sdram_dqm     (sdram_dqm),
            .sdram_addr    (sdram_addr),
            .sdram_bank    (sdram_bank),
            .sdram_dq      (sdram_dq)
        );
 
    mt48lc32m16a2 #(
        .addr_bits(12),
        .data_bits(16),
        .col_bits(9),
        .mem_sizes(2*1024*1024)
    ) inst_sdram_model (
        .Dq    (sdram_dq),
        .Addr  (sdram_addr),
        .Ba    (sdram_bank),
        .Clk   (sdram_clk),
        .Cke   (sdram_cke),
        .Cs_n  (sdram_commond[3]),
        .Ras_n (sdram_commond[2]),
        .Cas_n (sdram_commond[1]),
        .We_n  (sdram_commond[0]),
        .Dqm   (sdram_dqm)
    );
 
 
    initial clk = 1;
    always #(clk_period/2) clk = ~clk;
 
    initial begin
        #1;
        rst_n = 0;
        wr_en = 0;
        wr_data = 16'd0;
        rd_en = 0;
        bank_addr = 2'b00;
        row_addr = 12'd0;
        col_addr = 9'd0;
        //sdram_dq_en = 0;
        #(clk_period*20);
        rst_n = 1;
        #(clk_period*20);
        #(20100*clk_period);
 
        wr_en = 1;
        row_addr = 12'd100;
        col_addr = 9'd8;
        #clk_period;
        wr_en = 0;
        row_addr = 12'd0;
        #(clk_period*50);
 
        rd_en = 1;
        row_addr = 12'd100;
        col_addr = 9'd8;
        #clk_period;
        rd_en = 0;
        #(clk_period*50);
 
        //测试读写优先级，应该是读优先级高于写优先级
        wr_en = 1;
        rd_en = 1;
        row_addr = 12'd200;
        col_addr = 9'd16;
        #clk_period;
        wr_en = 0;
        rd_en = 0;
        #(clk_period*50);
 
        $stop;
    end
 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_data <= 0;    
        end
        else if (wr_data_vld) begin
            wr_data <= wr_data + 2'd2;
        end
    end
 
endmodule