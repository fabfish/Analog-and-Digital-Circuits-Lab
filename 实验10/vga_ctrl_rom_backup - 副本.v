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
output reg hs,vs,
output [11:0] vga_data);

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
    C_IMAGE_PIX_NUM_ground     =   9216 ;   

parameter   C_COLOR_BAR_WIDTH   =   C_H_ACTIVE_TIME / 8  ;  
parameter   C_H_OFFSET_dinosaur = 128;
parameter   C_V_OFFSET_dinosaur = 300;

                
reg [10:0] h_cnt,v_cnt;
reg h_de,v_de;//data_enable
reg [11:0]rd_data;

reg     [13:0]  R_rom_dinosaur_addr      ; // ROM的地址
reg     [13:0]  R_rom_ground_addr      ; // ROM的地址
reg     [6:0]   speed;
reg     [11:0]  W_rom_data      ; // ROM中存储的数据
wire    [11:0]  W_rom_dinosaur_jump;
wire    [11:0]  W_rom_dinosaur_leftup;
wire    [11:0]  W_rom_dinosaur_rightup;
wire    [11:0]  W_rom_dinosaur_dead;
wire    [11:0]  W_rom_ground;

reg [3:0] vga_r;
reg [3:0] vga_g;
reg [3:0] vga_b;
wire W_active_flag;

//////////////////////////////////////////////////////////////////
//状态机相关
//////////////////////////////////////////////////////////////////
reg     [10:0]      R_dinosaur_h_pos         ; // 图片在屏幕上显示的水平位置，当它为0时，图片贴紧屏幕的左边沿
reg     [10:0]      R_dinosaur_v_pos         ; // 图片在屏幕上显示的垂直位置，当它为0时，图片贴紧屏幕的上边沿
reg     [10:0]      R_ground_h_pos         ; // 图片在屏幕上显示的水平位置，当它为0时，图片贴紧屏幕的左边沿
reg     [10:0]      R_ground_v_pos         ; // 图片在屏幕上显示的垂直位置，当它为0时，图片贴紧屏幕的上边沿
reg [10:0] R_dinosaur_jump;

reg     [1:0]       R_state         ;
wire W_vs_neg;
reg                 R_vs_reg1       ;
reg                 R_vs_reg2       ;
//wire [10:0] R_h_pos_saver;
//wire [10:0] R_v_pos_saver;
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
reg [19:0] walk_cnt;
wire walk_state;
wire jump_pulse;
always@(posedge clk or posedge rst) //
begin
    if(rst) walk_cnt <= 20'h0;
    else if(walk_cnt==20'hfffff) walk_cnt <= 19'h0;
    else walk_cnt <= walk_cnt + 1'b1;
end
assign walk_state = (walk_cnt[19]==1'b1) ? 1'b0 : 1'b1;
assign jump_pulse = (walk_cnt[18]==1'b1) ? 1'b0 : 1'b1;

//////////////////////////////////////////////////////////////////
// 功能：跳跃模仿
//////////////////////////////////////////////////////////////////
reg [6:0] jump_cnt;
always@(posedge rst or posedge jump_pulse or posedge jumping) 
begin
    if(rst) jump_cnt <= 7'h0;
    else if(jumping && jump_cnt==7'b0) jump_cnt<=7'b1;
    else if(jump_cnt==7'd64) jump_cnt <= 7'd0;
    else if(jump_cnt>7'b0) jump_cnt <= jump_cnt + 7'b1;
    R_dinosaur_jump <= (7'd32*7'd32)/5 - ((jump_cnt-7'd32)*(jump_cnt-7'd32))/5;
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
//功能：输出rgb信号
//////////////////////////////////////////////////////////////////
always @(posedge clk)
begin
    //R_dinosaur_h_pos <= R_h_pos_saver;
    //R_dinosaur_v_pos <= R_v_pos_saver;
    if(rst) 
        begin
            R_rom_dinosaur_addr  <=  14'd0 ;
            R_rom_ground_addr  <=  14'd0 ;
            vga_r <= 4'hf;
            vga_g <= 4'hf;
            vga_b <= 4'hf;
        end
    else if(W_active_flag)     
        begin
//////////////////////////////////////////////////////////////////
//功能：地面运动
//////////////////////////////////////////////////////////////////
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_ground_h_pos                        )  && 
               h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_ground_h_pos + C_IMAGE_WIDTH_ground  - 1'b1)  &&
               v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_ground_v_pos                        )  && 
               v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_ground_v_pos + C_IMAGE_HEIGHT_ground - 1'b1)  )  
            begin
                if(R_rom_ground_addr == C_IMAGE_PIX_NUM_ground - 1'b1)
                    R_rom_ground_addr  <=  14'd0 ;
                else
                    R_rom_ground_addr  <=  R_rom_ground_addr  +  1'b1 ; 
            end
            /*
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_ground_h_pos                        )  && 
               h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_ground_h_pos + C_IMAGE_WIDTH_ground  - 1'b1)  &&
               v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_ground_v_pos                        )  && 
               v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_ground_v_pos + C_IMAGE_HEIGHT_ground - 1'b1)  )  
            begin
                vga_r   <= W_rom_data[11:8]    ; // 红色分量
                vga_g   <= W_rom_data[7:4]     ; // 绿色分量
                vga_b   <= W_rom_data[3:0]      ; // 蓝色分量
            end
            */
//////////////////////////////////////////////////////////////////
//功能：输出恐龙图片
//////////////////////////////////////////////////////////////////
            if(h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos                        )  && 
               h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_dinosaur_h_pos + C_IMAGE_WIDTH_dinosaur  - 1'b1)  &&
               v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_dinosaur_v_pos                        )  && 
               v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_dinosaur_v_pos + C_IMAGE_HEIGHT_dinosaur - 1'b1)  )
            begin
                vga_r   <= W_rom_data[11:8]    ; // 红色分量
                vga_g   <= W_rom_data[7:4]     ; // 绿色分量
                vga_b   <= W_rom_data[3:0]      ; // 蓝色分量
                if(R_rom_dinosaur_addr == C_IMAGE_PIX_NUM_dinosaur - 1'b1)
                    R_rom_dinosaur_addr  <=  14'd0 ;
                else
                    R_rom_dinosaur_addr  <=  R_rom_dinosaur_addr  +  1'b1 ;        
            end  
            else
                begin
                    vga_r       <=  4'hf        ;
                    vga_g       <=  4'hf        ;
                    vga_b       <=  4'hf        ;
                    R_rom_dinosaur_addr  <=  R_rom_dinosaur_addr  ;
                end                          
        end
    else
        begin
            vga_r       <=  4'hf       ;
            vga_g       <=  4'hf        ;
            vga_b       <=  4'hf        ;
            R_rom_dinosaur_addr  <=  R_rom_dinosaur_addr  ;
        end  
end

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

always@(posedge clk) 
begin
    if(jumping)
    case(CURRENT_STATE)
        SCREEN_SAVER:NEXT_STATE<=GAMING;
        GAMING:
        begin
            if (1) NEXT_STATE<=GAMING;
            else NEXT_STATE<=GAME_OVER;
        end
        GAME_OVER:NEXT_STATE<=GAME_START;
        default:
            NEXT_STATE<=SCREEN_SAVER;
    endcase
    else
        NEXT_STATE<=CURRENT_STATE;
end

always@(posedge clk or posedge rst) 
begin
    if(rst)
        CURRENT_STATE<=SCREEN_SAVER;
    else
        CURRENT_STATE<=NEXT_STATE;
end

always@(posedge clk or posedge rst)
begin
/*
    if(rst)
    begin
        R_dinosaur_h_pos <=  11'd0;
        R_dinosaur_v_pos <=  11'd0; 
        R_state <=  2'b00   ;
        W_rom_data <= W_rom_dinosaur_jump;        
    end
    else
    */
    case(CURRENT_STATE)
//////////////////////////////////////////////////////////////////
//功能：显示屏保
//////////////////////////////////////////////////////////////////
        SCREEN_SAVER:
        begin
            W_rom_data <= W_rom_dinosaur_jump;
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
            speed <= 1'b0;
            W_rom_data <= W_rom_dinosaur_jump;
            if(W_vs_neg)
            begin 
                R_dinosaur_h_pos <= C_H_OFFSET_dinosaur;
                R_dinosaur_v_pos <= C_V_OFFSET_dinosaur - R_dinosaur_jump; 
                R_ground_v_pos <= R_dinosaur_v_pos + C_IMAGE_HEIGHT_dinosaur - C_IMAGE_HEIGHT_ground;
                R_ground_h_pos <= (R_ground_h_pos + C_H_OFFSET_dinosaur - speed) % C_H_OFFSET_dinosaur ;
            end  
        end
        GAMING:
        begin
            speed <= 1'd1;
            if(W_vs_neg)
            begin 
                R_dinosaur_h_pos <= C_H_OFFSET_dinosaur;
                R_dinosaur_v_pos <= C_V_OFFSET_dinosaur - R_dinosaur_jump; 
                R_ground_v_pos <= R_dinosaur_v_pos + C_IMAGE_HEIGHT_dinosaur - C_IMAGE_HEIGHT_ground;
                R_ground_h_pos <= (R_ground_h_pos + C_H_OFFSET_dinosaur - speed) % C_H_OFFSET_dinosaur ;
            end  
            if (jump_cnt > 7'h0) W_rom_data <= W_rom_dinosaur_jump;
            else if(walk_state==1'b0) W_rom_data<=W_rom_dinosaur_leftup;
            else W_rom_data<=W_rom_dinosaur_rightup; 
        end
        GAME_OVER:
        begin
            W_rom_data <= W_rom_dinosaur_dead;
        end
        default:
        begin
            R_dinosaur_h_pos <=  11'd0;
            R_dinosaur_v_pos <=  11'd0; 
            W_rom_data <= W_rom_dinosaur_jump;
        end
    endcase
end

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
  .douta(W_rom_ground) // output [11 : 0] douta
);
endmodule