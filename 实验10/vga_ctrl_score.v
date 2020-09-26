`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/12/11 10:35:07
// Design Name: 
// Module Name: vga_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module vga_ctrl(
    input clk,
    input rst,//clk=65MHz
    //output [9:0] h_addr,v_addr,
    //output rd_vld,
    //input [11:0] rd_data, //r[3:0],g[3:0],b[3:0]
    input btnc,
    input [15:0]sw,
    output reg hs,vs,
    output [11:0] vga_data,
    output reg [7:0]an,
    output [7:0] seg);

parameter H_CNT = 11'd1343; //136+160+1024+24=1343
parameter V_CNT = 11'd805; //6+29+768+3=806
parameter       
    C_H_SYNC_PULSE      =   136   , 
    C_H_BACK_PORCH      =   160  ,
    C_H_ACTIVE_TIME     =   1024 ,
    C_H_FRONT_PORCH     =   24  ,
    C_H_LINE_PERIOD     =   1344 ;
// 分辨率为1280*720时场时序各个参数定义               
parameter       
    C_V_SYNC_PULSE      =   6    , 
    C_V_BACK_PORCH      =   29   ,
    C_V_ACTIVE_TIME     =   768  ,
    C_V_FRONT_PORCH     =   3    ,
    C_V_FRAME_PERIOD    =   806  ;                
parameter       
    C_IMAGE_WIDTH_dinosaur       =   128   ,
    C_IMAGE_HEIGHT_dinosaur      =   128   ,
    C_IMAGE_PIX_NUM_dinosaur     =   16384 ,   
    
    C_IMAGE_WIDTH_ground       =   768   ,
    C_IMAGE_HEIGHT_ground      =   12   ,
    C_IMAGE_PIX_NUM_ground     =   9216 ,   
    
    C_IMAGE_WIDTH_cactus1       =   64   ,
    C_IMAGE_HEIGHT_cactus1      =   128   ,
    C_IMAGE_PIX_NUM_cactus1     =   8192 ;      

//parameter   C_COLOR_BAR_WIDTH   =   C_H_ACTIVE_TIME / 8  ;  
parameter   C_H_OFFSET_dinosaur = 128;
parameter   C_V_OFFSET_dinosaur = 450;
                
reg [10:0] h_cnt,v_cnt;
reg h_de,v_de;//data_enable
reg [11:0]rd_data;
reg [3:0] data;

reg     [13:0]  R_rom_dinosaur_addr      ; // ROM的地址
reg     [13:0]  R_rom_ground_addr      ; // ROM的地址
reg     [13:0]  R_rom_cactus1_addr      ; // ROM的地址

wire     [3:0]   speed;
assign speed = sw[15:12];

reg     [11:0]  W_rom_data;
reg     [11:0]  W_rom_data_dinosaur      ; // ROM中存储的数据
wire    [11:0]  W_rom_dinosaur_jump;
wire    [11:0]  W_rom_dinosaur_leftup;
wire    [11:0]  W_rom_dinosaur_rightup;
wire    [11:0]  W_rom_dinosaur_dead;
wire    [11:0]  W_rom_data_ground;
wire    [11:0]  W_rom_data_cactus1;

reg [3:0] vga_r;
reg [3:0] vga_g;
reg [3:0] vga_b;
wire W_active_flag;
reg ground_flag;
reg dinosaur_flag;
reg cactus_flag;

reg [13:0]HIGH;

wire crash;
assign crash = (dinosaur_flag && cactus_flag);
//////////////////////////////////////////////////////////////////
//状态机相关
//////////////////////////////////////////////////////////////////
reg     [10:0]      R_dinosaur_h_pos         ; // 图片在屏幕上显示的水平位置，当它为0时，图片贴紧屏幕的左边沿
reg     [10:0]      R_dinosaur_v_pos         ; // 图片在屏幕上显示的垂直位置，当它为0时，图片贴紧屏幕的上边沿
reg     [10:0]      R_ground_h_pos         ; // 图片在屏幕上显示的水平位置，当它为0时，图片贴紧屏幕的左边沿
reg     [10:0]      R_ground_v_pos         ; // 图片在屏幕上显示的垂直位置，当它为0时，图片贴紧屏幕的上边沿
reg     [10:0]      R_cactus1_h_pos         ; // 图片在屏幕上显示的水平位置，当它为0时，图片贴紧屏幕的左边沿
reg     [10:0]      R_cactus1_v_pos         ; // 图片在屏幕上显示的垂直位置，当它为0时，图片贴紧屏幕的上边沿
reg     [1:0]       R_state         ;//屏保状态机

reg cactus_come;//仙人掌出现

wire W_vs_neg;
reg                 R_vs_reg1       ;
reg                 R_vs_reg2       ;

reg [2:0] CURRENT_STATE;
reg [2:0] NEXT_STATE;
parameter SCREEN_SAVER = 3'b000;
parameter GAME_START = 3'b001;
parameter GAMING = 3'b010;
parameter GAME_OVER  = 3'b011;

wire btnc_clean;
wire jumping;

//////////////////////////////////////////////////////////////////
// 功能：行走时左右脚
//////////////////////////////////////////////////////////////////
reg [24:0]  walk_cnt;
reg [13:0]   score;
wire walk_state;
wire jump_pulse;
wire score_pulse;
always@(posedge clk or posedge rst) //
begin
    if(rst) walk_cnt <= 25'h0;
    else if(walk_cnt>=25'h1ffffff) walk_cnt <= 25'h0;
    else walk_cnt <= walk_cnt + 1'b1;
end
assign walk_state = (walk_cnt[18]==1'b1) ? 1'b0 : 1'b1;
assign jump_pulse = (walk_cnt[18]==1'b1) ? 1'b0 : 1'b1;
assign score_pulse = (walk_cnt[22]==1'b1)? 1'b0 : 1'b1;

always@(posedge score_pulse or posedge rst)
begin
    if(rst) score <= 14'h0;
    else if(score==14'h3fff) score <= 14'h0;
    else score <= score + 1'b1;
    if(rst) HIGH <= 14'h0;
    else if(score>HIGH) HIGH<=score;
end
//////////////////////////////////////////////////////////////////
// 功能：跳跃模仿
//////////////////////////////////////////////////////////////////
reg [10:0] R_dinosaur_jump;
reg [6:0] jump_cnt;
always@(posedge rst or posedge jump_pulse or posedge jumping) 
begin
    if(rst) jump_cnt <= 7'h0;
    else if(jumping && jump_cnt==7'b0) jump_cnt<=7'b1;
    else if(jump_cnt==7'd64) jump_cnt <= 7'd0;
    else if(jump_cnt>7'b0) jump_cnt <= jump_cnt + 7'b1;
    R_dinosaur_jump <= (7'd32*7'd32)/3 - ((jump_cnt-7'd32)*(jump_cnt-7'd32))/3;
end

//////////////////////////////////////////////////////////////////
//功能：游戏中恐龙ROM地址和恐龙检测
//////////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst)
begin
    if(rst) 
        R_rom_dinosaur_addr  <=  14'd0 ;
    else if(W_active_flag)
        //////////////////////////////////////////////////////////////////
        //游戏中
        //////////////////////////////////////////////////////////////////
        begin
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos                        )  && 
                h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos + C_IMAGE_WIDTH_dinosaur  - 1'b1)  &&
                v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_dinosaur_v_pos                        )  && 
                v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_dinosaur_v_pos + C_IMAGE_HEIGHT_dinosaur - 1'b1)  )
            begin
                if(R_rom_dinosaur_addr == C_IMAGE_PIX_NUM_dinosaur - 1'b1)
                    R_rom_dinosaur_addr  <=  14'd0 ;
                else
                    R_rom_dinosaur_addr  <=  R_rom_dinosaur_addr  +  1'b1 ;    
                if(W_rom_data_dinosaur < 12'hfff)
                    dinosaur_flag<=1'b1;
                else
                    dinosaur_flag<=1'b0; 
            end  
            else dinosaur_flag<=1'b0;                    
        end
    else
    begin
        R_rom_dinosaur_addr  <=  R_rom_dinosaur_addr  ;
        dinosaur_flag<=1'b0; 
    end
end

//////////////////////////////////////////////////////////////////
//功能：游戏中地面ROM地址和地面检测
//////////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst)
begin
    if(rst) 
        R_rom_ground_addr  <=  14'd0 ;
    else if(W_active_flag && CURRENT_STATE!=SCREEN_SAVER)
        //////////////////////////////////////////////////////////////////
        //游戏中
        //////////////////////////////////////////////////////////////////
        begin
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_ground_h_pos                        )  && 
                h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_ground_h_pos + C_IMAGE_WIDTH_ground  - 1'b1)  &&
                v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_ground_v_pos                        )  && 
                v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_ground_v_pos + C_IMAGE_HEIGHT_ground - 1'b1)  )
            begin
                if(R_rom_ground_addr == C_IMAGE_PIX_NUM_ground - 1'b1)
                    R_rom_ground_addr  <=  14'd0 ;
                else
                    R_rom_ground_addr  <=  R_rom_ground_addr  +  1'b1 ;    
                if(W_rom_data_ground < 12'hfff)
                    ground_flag <= 1'b1;
                else
                    ground_flag <= 1'b0;
            end 
            else 
                ground_flag <= 1'b0; 
        end                       
    else if(!W_active_flag)
        R_rom_ground_addr  <=  R_rom_ground_addr  ;
end

//////////////////////////////////////////////////////////////////
//功能：游戏中仙人掌1ROM地址和仙人掌1检测
//////////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst)
begin
    if(rst) 
        R_rom_cactus1_addr  <=  14'd0 ;
    else if(W_active_flag && CURRENT_STATE!=SCREEN_SAVER)
        //////////////////////////////////////////////////////////////////
        //游戏中
        //////////////////////////////////////////////////////////////////
        begin
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_cactus1_h_pos                        )  && 
                h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_cactus1_h_pos + C_IMAGE_WIDTH_cactus1  - 1'b1)  &&
                v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_cactus1_v_pos                        )  && 
                v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_cactus1_v_pos + C_IMAGE_HEIGHT_cactus1 - 1'b1)  )
            begin
                if(R_rom_cactus1_addr == C_IMAGE_PIX_NUM_cactus1 - 1'b1)
                    R_rom_cactus1_addr  <=  14'd0 ;
                else
                    R_rom_cactus1_addr  <=  R_rom_cactus1_addr  +  1'b1 ;    
                if(W_rom_data_cactus1 < 12'hfff)
                    cactus_flag <= 1'b1;
                else
                    cactus_flag <= 1'b0;
            end 
            else 
                cactus_flag <= 1'b0; 
        end                       
    else if(!W_active_flag)
    begin
        R_rom_cactus1_addr  <=  R_rom_cactus1_addr  ;
        cactus_flag <= 1'b0; 
    end
end

//////////////////////////////////////////////////////////////////
//功能：vga预赋值和游戏结束信号检测
//////////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst)
begin
    if(rst) 
        W_rom_data  <=  12'hfff ;
    else if(W_active_flag)
    begin
        if(CURRENT_STATE==SCREEN_SAVER)
            W_rom_data<=W_rom_data_dinosaur;
        else
        begin 
            if (dinosaur_flag) 
            begin
                W_rom_data<=W_rom_data_dinosaur;
            end
            else if (cactus_flag) 
                W_rom_data<=W_rom_data_cactus1;
            else if (ground_flag)
                W_rom_data<=W_rom_data_ground;
            else 
                W_rom_data<=12'hfff;
        end
    end                       
    else
        W_rom_data<=12'hfff;
end

//////////////////////////////////////////////////////////////////
//功能：输出rgb信号
//////////////////////////////////////////////////////////////////
always @(posedge clk)
begin
    //R_dinosaur_h_pos <= R_h_pos_saver;
    //R_dinosaur_v_pos <= R_v_pos_saver;
    if(rst) 
        begin
            vga_r <= 4'hf;
            vga_g <= 4'hf;
            vga_b <= 4'hf;
        end
    else if(W_active_flag)
        if(CURRENT_STATE==SCREEN_SAVER)
        begin
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos)  && 
                h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos + C_IMAGE_WIDTH_dinosaur - 1'b1)  &&
                v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_dinosaur_v_pos  )  && 
                v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_dinosaur_v_pos + C_IMAGE_HEIGHT_dinosaur - 1'b1)  )
            begin
                vga_r <= W_rom_data[11:8]    ; // 红色分量
                vga_g <= W_rom_data[7:4]     ; // 绿色分量
                vga_b <= W_rom_data[3:0]      ; // 蓝色分量                                     
            end
            else
            begin
                vga_r <=  4'hf ;
                vga_g <=  4'hf ;
                vga_b <=  4'hf ;
            end
        end
        else //游戏中
        begin
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos -10'd10 )  && 
                h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos + 10'd600  - 1'b1)  &&
                v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_dinosaur_v_pos  )  && 
                v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_ground_v_pos + C_IMAGE_HEIGHT_ground - 1'b1)  )     
            begin
                vga_r <= W_rom_data[11:8]    ; // 红色分量
                vga_g <= W_rom_data[7:4]     ; // 绿色分量
                vga_b <= W_rom_data[3:0]      ; // 蓝色分量                                     
            end
            else
            begin
                vga_r <=  4'hf ;
                vga_g <=  4'hf ;
                vga_b <=  4'hf ;
            end
        end
    else
        begin
            vga_r <=  4'hf ;
            vga_g <=  4'hf ;
            vga_b <=  4'hf ;
        end  
end

//////////////////////////////////////////////////////////////////
//功能：检测时钟下降沿
//////////////////////////////////////////////////////////////////
always @(posedge clk or posedge rst)
begin
    if(rst)
        begin
            R_vs_reg1   <=  1'b0        ;
            R_vs_reg2   <=  1'b0        ;
        end
    else
        begin
            R_vs_reg1   <=  vs        ;
            R_vs_reg2   <=  R_vs_reg1   ;
        end         
end
assign W_vs_neg = ~R_vs_reg1 & R_vs_reg2 ;

/*
screen_saver screen_saver(
.clk(clk),
.rst(rst),
.C_IMAGE_WIDTH_dinosaur(C_IMAGE_WIDTH_dinosaur),
.C_IMAGE_HEIGHT_dinosaur(C_IMAGE_HEIGHT_dinosaur),
.C_H_ACTIVE_TIME(C_H_ACTIVE_TIME),
.C_V_ACTIVE_TIME(C_V_ACTIVE_TIME),
.W_vs_neg(W_vs_neg),
.R_dinosaur_h_pos(R_h_pos_saver),
.R_dinosaur_v_pos(R_v_pos_saver)
);
*/

//////////////////////////////////////////////////////////////////
//有限状态机第一部分
//////////////////////////////////////////////////////////////////
always@(posedge clk) 
begin
    case(CURRENT_STATE)
        SCREEN_SAVER:
        begin
            if (jumping)
                NEXT_STATE<=GAME_START;
            else 
                NEXT_STATE<=SCREEN_SAVER;
        end
        GAME_START:
        begin
            if (jump_cnt>7'd63) NEXT_STATE<=GAMING;
            else NEXT_STATE<=GAME_START;
        end
        GAMING:
        begin
            if (1) NEXT_STATE<=GAMING;
            else if(sw[0]==1) NEXT_STATE<=GAMING;
            else NEXT_STATE<=GAME_OVER;
        end
        GAME_OVER:
        begin
            if (jumping)
            NEXT_STATE<=GAME_START;
        end
        default:
        begin
            NEXT_STATE<=CURRENT_STATE;
        end
    endcase
end
//////////////////////////////////////////////////////////////////
//有限状态机第二部分
//////////////////////////////////////////////////////////////////
always@(posedge clk or posedge rst) 
begin
    if(rst)
        CURRENT_STATE<=SCREEN_SAVER;
    else
        CURRENT_STATE<=NEXT_STATE;
end
//////////////////////////////////////////////////////////////////
//有限状态机第三部分
//////////////////////////////////////////////////////////////////
always@(posedge clk)
begin
    if(rst)
    begin
        R_dinosaur_h_pos <= 1'b0;
        R_dinosaur_v_pos <= 1'b0; 
        R_ground_h_pos <= C_H_OFFSET_dinosaur;
        R_ground_v_pos <= C_V_OFFSET_dinosaur + C_IMAGE_HEIGHT_dinosaur - C_IMAGE_HEIGHT_ground;
        R_state <=  2'b00;     
    end
    else
    case(CURRENT_STATE)
        //////////////////////////////////////////////////////////////////
        //功能：显示屏保
        //////////////////////////////////////////////////////////////////
        SCREEN_SAVER:
        begin
            W_rom_data_dinosaur <= W_rom_dinosaur_jump;
            if(W_vs_neg)    
            begin 
            case(R_state)
                2'b00: // 图片往右下方移动
                begin 
                    R_dinosaur_h_pos     <=  R_dinosaur_h_pos + 1 ;
                    R_dinosaur_v_pos     <=  R_dinosaur_v_pos + 1 ;
                    if(R_dinosaur_h_pos + C_IMAGE_WIDTH_dinosaur == C_H_ACTIVE_TIME) // 如果碰到右边框
                        R_state <=  2'b10       ;
                    else if((R_dinosaur_v_pos + C_IMAGE_HEIGHT_dinosaur) == C_V_ACTIVE_TIME) // 如果碰到下边框
                        R_state <=  2'b01       ;                            
                end
                2'b01: // 图片往右上方移动
                begin 
                    R_dinosaur_h_pos     <=  R_dinosaur_h_pos + 1 ;
                    R_dinosaur_v_pos     <=  R_dinosaur_v_pos - 1 ;
                    if(R_dinosaur_h_pos + C_IMAGE_WIDTH_dinosaur == C_H_ACTIVE_TIME) // 如果碰到右边框
                        R_state <=  2'b11       ;
                    else if(R_dinosaur_v_pos == 1)     // 如果碰到上边框
                        R_state <=  2'b00       ;
                end
                2'b10: // 图片往左下方移动
                begin 
                    R_dinosaur_h_pos     <=  R_dinosaur_h_pos - 1 ;
                    R_dinosaur_v_pos     <=  R_dinosaur_v_pos + 1 ;
                    if(R_dinosaur_h_pos == 1)    // 如果碰到左边框
                        R_state <=  2'b00       ;
                    else if(R_dinosaur_v_pos + C_IMAGE_HEIGHT_dinosaur == C_V_ACTIVE_TIME) // 如果碰到下边框
                        R_state <=  2'b11       ;
                end
                2'b11: // 图片往左上方移动
                begin 
                    R_dinosaur_h_pos     <=  R_dinosaur_h_pos - 1 ;
                    R_dinosaur_v_pos     <=  R_dinosaur_v_pos - 1 ;
                    if(R_dinosaur_h_pos == 1)    // 如果碰到上边框
                        R_state <=  2'b01       ;
                    else if(R_dinosaur_v_pos == 1) // 如果碰到左边框
                        R_state <=  2'b10       ;
                end
                default:R_state <=  2'b00           ;            
            endcase       
            end
        end  
        GAME_START:
        begin
            cactus_come<=1'b0;
            W_rom_data_dinosaur <= W_rom_dinosaur_jump;
            if(W_vs_neg)
            begin
                R_dinosaur_h_pos <= C_H_OFFSET_dinosaur;
                R_dinosaur_v_pos <= C_V_OFFSET_dinosaur - R_dinosaur_jump; 
                R_ground_h_pos <= C_H_OFFSET_dinosaur;
                R_ground_v_pos <= C_V_OFFSET_dinosaur + C_IMAGE_HEIGHT_dinosaur - C_IMAGE_HEIGHT_ground;  
            end              
        end
        GAMING:
        begin
            if(W_vs_neg)
            begin 
                R_dinosaur_h_pos <= C_H_OFFSET_dinosaur;
                R_dinosaur_v_pos <= C_V_OFFSET_dinosaur - R_dinosaur_jump; 
                R_ground_v_pos <= C_V_OFFSET_dinosaur + C_IMAGE_HEIGHT_dinosaur - C_IMAGE_HEIGHT_ground;
                R_ground_h_pos <= (R_ground_h_pos + C_H_OFFSET_dinosaur - speed) % C_H_OFFSET_dinosaur ;
                if (cactus_come)
                begin
                    R_cactus1_v_pos <= C_V_OFFSET_dinosaur;
                    if (R_cactus1_h_pos > speed)
                        R_cactus1_h_pos <= (R_cactus1_h_pos - speed);
                    else
                    begin
                        cactus_come<=1'b0;
                        R_cactus1_h_pos <= R_dinosaur_h_pos + 10'd600 + C_IMAGE_WIDTH_cactus1 - 1'b1 ;
                    end
                end
                else
                begin
                    if (walk_cnt[20]==1'b1)cactus_come<=1'b1;
                    R_cactus1_h_pos <= R_dinosaur_h_pos + 10'd600 + C_IMAGE_WIDTH_cactus1 - 1'b1 ;
                end
            end  
            if (jump_cnt > 7'h0) W_rom_data_dinosaur <= W_rom_dinosaur_jump;
            else if(walk_state==1'b0) W_rom_data_dinosaur <= W_rom_dinosaur_leftup;
            else W_rom_data_dinosaur <= W_rom_dinosaur_rightup; 
        end
        GAME_OVER:
        begin
            W_rom_data_dinosaur <= W_rom_dinosaur_dead;
        end
        default:
        begin
            W_rom_data_dinosaur <= W_rom_dinosaur_dead;
        end
    endcase
end

//////////////////////////////////////////////////////////////////
// 功能：产生行时序
//////////////////////////////////////////////////////////////////
always@(posedge clk)
begin
    if(rst)
        h_cnt <= 11'd0;
    else if(h_cnt >= C_H_LINE_PERIOD - 1'd1)
        h_cnt <= 11'd0;
    else
        h_cnt <= h_cnt + 11'd1;
end
always@(posedge clk)
begin
    if(rst)
        h_de <= 1'b0;
    else if((h_cnt>=296)&&(h_cnt<=1319))
        h_de <= 1'b1;
    else
        h_de <= 1'b0;
end
//////////////////////////////////////////////////////////////////
// 功能：产生场时序
//////////////////////////////////////////////////////////////////
always@(posedge clk)
begin
    if(rst)
        v_cnt <= 11'd0;
    else if(h_cnt == C_H_LINE_PERIOD - 1'd1)
        begin
            if(v_cnt >= C_V_FRAME_PERIOD - 1'd1)
                v_cnt <= 11'd0;
            else
                v_cnt <= v_cnt + 11'd1;
        end
end
always@(posedge clk)
begin
    if(rst)
        v_de <= 1'b0;
    else if((v_cnt>=35)&&(v_cnt<=802))
        v_de <= 1'b1;
    else
        v_de <= 1'b0;
end

//////////////////////////////////////////////////////////////////
//功能：输出hs和vs信号
//////////////////////////////////////////////////////////////////
always@(posedge clk)
begin
    hs <= ((h_cnt > C_H_SYNC_PULSE)||rst)? 1'b1 : 1'b0 ;
    vs <= ((v_cnt > C_V_SYNC_PULSE)||rst)? 1'b1 : 1'b0 ;
end

assign W_active_flag =  (h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH                    ))  &&
                        (h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + C_H_ACTIVE_TIME  ))  && 
                        (v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH                    ))  &&
                        (v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + C_V_ACTIVE_TIME  ))  ;   
assign vga_data = ((v_de==1)&&(h_de==1))? {vga_r,vga_g,vga_b} : 12'h0;
//assign vga_data = ((v_de==1)&&(h_de==1))? 12'hfff : 12'h0;

//////////////////////////////////////////////////////////////////
//功能：取跳跃信号jumping
//////////////////////////////////////////////////////////////////
jitter_clr jitter_clr(
.clk(clk),
.button(btnc),
.button_clean(btnc_clean)
);

signal_edge signal_edge(
.clk(clk),
.button(btnc_clean),
.button_redge(jumping)
);

blk_mem_gen_jump blk_mem_gen_jump (
  .clka(clk), // input clka
  .addra(R_rom_dinosaur_addr), // input [13 : 0] addra
  .douta(W_rom_dinosaur_jump) // output [11 : 0] douta
);

blk_mem_gen_leftup blk_mem_gen_leftup (
  .clka(clk), // input clka
  .addra(R_rom_dinosaur_addr), // input [13 : 0] addra
  .douta(W_rom_dinosaur_leftup) // output [11 : 0] douta
);

blk_mem_gen_rightup blk_mem_gen_rightup (
  .clka(clk), // input clka
  .addra(R_rom_dinosaur_addr), // input [13 : 0] addra
  .douta(W_rom_dinosaur_rightup) // output [11 : 0] douta
);
//leftup walk
blk_mem_gen_dead blk_mem_gen_dead (
  .clka(clk), // input clka
  .addra(R_rom_dinosaur_addr), // input [13 : 0] addra
  .douta(W_rom_dinosaur_dead) // output [11 : 0] douta
);

blk_mem_gen_ground blk_mem_gen_ground (
  .clka(clk), // input clka
  .addra(R_rom_ground_addr), // input [13 : 0] addra
  .douta(W_rom_data_ground) // output [11 : 0] douta
);

blk_mem_gen_cactus1 blk_mem_gen_cactus1 (
  .clka(clk), // input clka
  .addra(R_rom_cactus1_addr), // input [13 : 0] addra
  .douta(W_rom_data_cactus1) // output [11 : 0] douta
);

always@(posedge clk) //分时复用
begin
    case(walk_cnt[18:16])
        3'h0:   begin
                    an <= 8'b1111_1110;
                    data <= score[3:0];
                end
        3'h1:   begin
                    an <= 8'b1111_1101;
                    data <= score[7:4];
                end
        3'h2:   begin
                    an <= 8'b1111_1011;
                    data <= score[11:8];
                end
        3'h3:   begin
                    an <= 8'b1111_0111;
                    data <= score[13:11];
                end    
        3'h4:   begin
                    an <= 8'b1110_1111;
                    data <= HIGH[0];
                end
        3'h5:   begin
                    an <= 8'b1101_1111;
                    data <= HIGH[1];
                end  
        3'h6:   begin
                    an <= 8'b1011_1111;
                    data <= HIGH[2];
                end
        3'h7:   begin
                    an <= 8'b0111_1111;
                    data <= HIGH[3];
                end    
        default:begin
                    an <= 8'b1111_1110;
                    data <= walk_cnt[21];
                end                            
    endcase
end

dist_mem_gen_0 dist_mem_gen_0(
.a (data),
.spo (seg));
endmodule