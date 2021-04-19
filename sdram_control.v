module sdram_control(
    input              clk        ,  //100Mhz
    input              rst_n      ,
    input              wr_en      ,
    input              rd_en      ,
    input       [1:0]  bank_addr  ,
    input       [12:0] row_addr   ,
    input       [9:0]  col_addr   ,
    input       [15:0] wr_data    , //写入的数据
    output reg  [15:0] rd_data    , //读出的数据
    output reg         rddata_vld , //读出数据有效位
    output             wrdata_vld , //写入数据有效位
    output             sdram_clk  , //SDRAM时钟信号
    output reg  [3:0]  sdram_cmd  , //{cs,ras,cas,we}
    output             sdram_cke  , //时钟使能信号
    output reg  [1:0]  sdram_dqm  , //数据线屏蔽信号
    output reg  [12:0] sdram_addr , //SDRAM地址线
    output reg  [1:0]  sdram_bank , //SDRAM bank选取
    inout  wire [15:0] sdram_dq     //SDRAM数据输出输入总线
);

parameter CLK_FS  = 100_000_000;

//参考 https://blog.csdn.net/qq_33231534/article/details/108731782 

//localparam CNT_200US   = CLK_FS * 200 / 1000_000;
//localparam CNT_AUT_REF = CLK_FS * 64 / 1000 / 8192 - 20;
localparam CNT_200US   = 15'd20_000;
localparam CNT_AUT_REF = 11'd1562;

localparam TRP_CLK  = 10'd4; //预充电有效周期
localparam TRC_CLK  = 10'd6; //自动刷新周期
localparam TRSC_CLK = 10'd6; //模式寄存器设置时钟周期
localparam TRCD_CLK = 10'd2; //行选通周期
localparam TCL_CLK  = 10'd3; //列潜伏期 CAS Latency
localparam TWR_CLK  = 10'd2; //写入校正
localparam TBR_CLK  = 10'd8; //突发时钟周期
    
// SDRAM 初始化过程各个状态
localparam S_NOP    = 8'h00; //等待上电200us稳定期结束
localparam S_PRE    = 8'h01; //预充电状态
localparam S_AR     = 8'h02; //自动刷新
localparam S_MRS    = 8'h03; //模式寄存器设置
localparam S_IDLE   = 8'h04;
localparam S_ACTIVE = 8'h05; //行激活
localparam S_WRITE  = 8'h06; //列写
localparam S_READ   = 8'h07; //列读

localparam CMD_NOP    = 4'b0111; // NOP COMMAND
localparam CMD_ACTIVE = 4'b0011; // ACTIVE COMMAND
localparam CMD_READ   = 4'b0101; // READ COMMADN
localparam CMD_WRITE  = 4'b0100; // WRITE COMMAND
localparam CMD_PRGE   = 4'b0010; // PRECHARGE
localparam CMD_A_REF  = 4'b0001; // AOTO REFRESH
localparam CMD_LMR    = 4'b0000; // LODE MODE REGISTER

localparam MODE_VALUE = 13'b000_0_00_011_0_011;//配置模式寄存器时地址线
localparam ALL_BANK   = 13'b001_00_0000_0000;  //预充电地址线

reg [3:0] state_c;
reg [3:0] state_n;

reg [15:0] cnt;
reg [15:0] cnt_x;
reg [1:0] init_ref_cnt;
reg [10:0] ref_cnt;

reg init_done;     //初始化完成
reg auto_ref_req;  //自动刷新请求

reg flag_wr;
reg flag_rd;

wire add_flag;
wire end_cnt;

wire init_ref_add_flag;
wire init_ref_end_cnt;

wire ref_add_flag;
wire ref_end_cnt;

wire nop_to_pre_start;    
wire pre_to_autoref_start ;
wire pre_to_idle_start;    
wire autoref_to_mrs_start;
wire autoref_to_idle_start;
wire mrs_to_idle_start;    
wire idle_to_active_start;
wire active_to_write_start;
wire active_to_read_start; 
wire read_to_pre_start;    
wire write_to_pre_start;   
wire idle_to_autoref_start;

assign sdram_clk = ~clk;

assign sdram_cke = 1;


always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        cnt <= 0;
    else if(add_flag) begin
        if (end_cnt)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end
end

assign add_flag = state_c != S_IDLE;
assign end_cnt = add_flag && cnt == cnt_x - 1;


//the count for auto refresh in initialization
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        init_ref_cnt <= 0;
    else if(init_ref_add_flag) begin
        if (init_ref_end_cnt)
            init_ref_cnt <= 0;
        else
            init_ref_cnt <= init_ref_cnt + 1;
    end
end

assign init_ref_add_flag = ~init_done && end_cnt && (state_c == S_AR);
assign init_ref_end_cnt = init_ref_add_flag && init_ref_cnt == 2 - 1;


//timer for request of auto refresh
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 0)
        ref_cnt <= 0;
    else if(ref_add_flag) begin
        if (ref_end_cnt)
            ref_cnt <= 0;
        else
            ref_cnt <= ref_cnt + 1;
    end
end

assign ref_add_flag = init_done;
assign ref_end_cnt = ref_add_flag && ref_cnt == CNT_AUT_REF - 1;


always @(*) begin
    case (state_c)
        S_NOP   : cnt_x = CNT_200US;
        S_PRE   : cnt_x = TRP_CLK;
        S_AR    : cnt_x = TRC_CLK;
        S_MRS   : cnt_x = TRSC_CLK;
        S_ACTIVE: cnt_x = TRCD_CLK;
        S_WRITE : cnt_x = TBR_CLK + TWR_CLK;
        S_READ  : cnt_x = TCL_CLK + TBR_CLK; 
        default:  cnt_x = 0;
    endcase
end


always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        state_c <= S_NOP;
    end
    else begin
        state_c <= state_n;
    end
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)
        flag_rd <= 0;
    else if (rd_en && state_c == S_IDLE && !auto_ref_req)
        flag_rd <= 1;
    else if (flag_rd && pre_to_idle_start)
        flag_rd <= 0;
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)
        flag_wr <= 0;
    else if (wr_en && !rd_en && state_c == S_IDLE && !auto_ref_req) //读优先级高于写
        flag_wr <= 1;
    else if (flag_wr && pre_to_idle_start)
        flag_wr <= 0;
end

assign nop_to_pre_start      = (state_c == S_NOP && end_cnt);
assign pre_to_autoref_start  = (state_c == S_PRE && end_cnt && !init_done);
assign pre_to_idle_start     = (state_c == S_PRE && end_cnt && init_done);
assign autoref_to_mrs_start  = (state_c == S_AR && end_cnt && init_ref_end_cnt);
assign autoref_to_idle_start = (state_c == S_AR && end_cnt && init_done);
assign mrs_to_idle_start     = (state_c == S_MRS && end_cnt);
assign idle_to_active_start  = (state_c == S_IDLE && (wr_en || rd_en));
assign active_to_write_start = (state_c == S_ACTIVE && end_cnt && flag_wr);
assign active_to_read_start  = (state_c == S_ACTIVE && end_cnt && flag_rd);
assign read_to_pre_start     = (state_c == S_READ && end_cnt);
assign write_to_pre_start    = (state_c == S_WRITE && end_cnt);
assign idle_to_autoref_start = (state_c == S_IDLE && auto_ref_req);

always@(*)begin
    case(state_c)
        S_NOP:begin
            if (nop_to_pre_start) begin
                state_n = S_PRE;
            end
            else begin
                state_n = state_c;
            end
        end
        S_PRE:begin
            if (pre_to_autoref_start)
                state_n = S_AR;
            else if (pre_to_idle_start)
                state_n = S_IDLE;
            else
                state_n = state_c;
        end
        S_AR:begin
            if (autoref_to_idle_start) begin
                state_n = S_IDLE;
            end
            if (autoref_to_mrs_start) begin
                state_n = S_MRS;
            end
            else begin
                state_n = state_c;
            end
        end
        S_MRS:begin
            if (mrs_to_idle_start)begin
                state_n = S_IDLE;
            end
            else begin
                state_n = state_c;
            end
        end
        S_IDLE:begin
            if (idle_to_active_start)
                state_n = S_ACTIVE;
            else if (idle_to_autoref_start)
                state_n = S_AR;
            else begin
                state_n = state_c;
            end
        end
        S_ACTIVE:begin
            if (active_to_read_start)
                state_n = S_READ;
            else if (active_to_write_start)
                state_n = S_WRITE;
            else begin
                state_n = state_c;
            end
        end
        S_WRITE:begin
            if (write_to_pre_start) begin
                state_n = S_PRE;
            end
            else begin
                state_n = state_c;
            end
        end
        S_READ:begin
            if (read_to_pre_start) begin
                state_n = S_PRE;
            end
            else begin
                state_n = state_c;
            end
        end
        default:begin
            state_n = S_NOP;
        end
    endcase
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)begin
        init_done <= 0;
    end
    else if (state_n == S_IDLE) begin
        init_done <= 1;
    end
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)begin
        auto_ref_req <= 0;
    end
    else begin
        if (ref_end_cnt)
            auto_ref_req <= 1;
        else if (state_c == S_AR)
            auto_ref_req <= 0;
    end
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)
        sdram_cmd <= CMD_NOP;
    else if (nop_to_pre_start || read_to_pre_start || write_to_pre_start)
        sdram_cmd <= CMD_PRGE;
    else if (pre_to_autoref_start || idle_to_autoref_start)
        sdram_cmd <= CMD_A_REF;
    else if (autoref_to_mrs_start)
        sdram_cmd <= CMD_LMR;
    else if (idle_to_active_start)
        sdram_cmd <= CMD_ACTIVE;
    else if (active_to_read_start)
        sdram_cmd <= CMD_READ;
    else if (active_to_write_start)
        sdram_cmd <= CMD_WRITE;
    else
        sdram_cmd <= CMD_NOP;
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)begin
        sdram_addr <= 0;
    end
    else if (nop_to_pre_start || read_to_pre_start || write_to_pre_start)
        sdram_addr <= ALL_BANK;
    else if (autoref_to_mrs_start)
        sdram_addr <= MODE_VALUE;
    else if (idle_to_active_start)
        sdram_addr <= row_addr;
    else if (active_to_read_start || active_to_write_start)
        sdram_addr <= {3'b000, col_addr};
    else
        sdram_addr <= 0;
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)begin
        sdram_bank <= 0;
    end
    else if (idle_to_active_start || active_to_read_start || active_to_write_start)
        sdram_bank <= bank_addr;
    else
        sdram_bank <= 0;
end

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)begin
        sdram_dqm <= 2'b11;
    end
    else if (init_done) begin
        sdram_dqm <= 2'b00;
    end
end

assign wrdata_vld = state_c== S_WRITE;
assign sdram_dq = (S_WRITE == state_c) ? wr_data:16'hzzzz;

always  @(posedge clk or negedge rst_n)begin
    if(rst_n==1'b0)begin
        rd_data <= 0;
    end
    else begin
        rd_data <= sdram_dq;
    end
end


always  @(*)begin
    if(rst_n==1'b0)begin
        rddata_vld = 0;
    end
    else if (state_c == S_READ && cnt > 1 && cnt < 10) begin
        rddata_vld = 1;
    end
    else begin
        rddata_vld = 0;
    end
end


endmodule
