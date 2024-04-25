`include "define.v"

`define MAX_TABLE_SIZE 12

module Huff_fetch_huff(
    input clk,
    input rst,
    
    input wr,
    input[3:0] wr_addr,
    input[3:0] wr_huff_size,
    input[15:0] wr_huff_min,
    input[15:0] wr_huff_base,
    
    input[1:0] tb_sel,
    input[15:0] stream,

    output reg[3:0] size,
    output reg[15:0] base,
    output reg[15:0] offset
);

reg[15:0] huff_valid[3:0];

reg[3:0] huff_size[3:0][15:0];
reg[15:0] huff_min[3:0][15:0];
reg[15:0] huff_base[3:0][15:0];

reg[3:0] id;
reg[15:0] result;

reg[15:0] buffed_stream;

always @(*)
begin
    size = huff_size[tb_sel][id];
    base = huff_base[tb_sel][id];
    offset = (buffed_stream - huff_min[tb_sel][id]) >> (~size);
end

integer i;

always @(posedge clk or posedge rst)
begin
    if(rst) begin
        buffed_stream <= 0;
        huff_valid[0] <= 0;
        huff_valid[1] <= 0;
        huff_valid[2] <= 0;
        huff_valid[3] <= 0;
    end else
    if(wr) begin
        huff_size[tb_sel][wr_addr]  <= wr_huff_size;
        huff_min[tb_sel][wr_addr]   <= wr_huff_min;
        huff_base[tb_sel][wr_addr]  <= wr_huff_base;
        huff_valid[tb_sel][wr_addr] <= 1;
    end else
    begin
        buffed_stream <= stream;
        for(i=0; i<16; i=i+1) result[i] = huff_valid[tb_sel][i] ? stream >= huff_min[tb_sel][i] : 0;
        case(result)
        16'h0001: id = 4'h0;
        16'h0003: id = 4'h1;
        16'h0007: id = 4'h2;
        16'h000f: id = 4'h3;
        16'h001f: id = 4'h4;
        16'h003f: id = 4'h5;
        16'h007f: id = 4'h6;
        16'h00ff: id = 4'h7;
        16'h01ff: id = 4'h8;
        16'h03ff: id = 4'h9;
        16'h07ff: id = 4'ha;
        16'h0fff: id = 4'hb;
        16'h1fff: id = 4'hc;
        16'h3fff: id = 4'hd;
        16'h7fff: id = 4'he;
        16'hffff: id = 4'hf;
        endcase
    end
end
endmodule

module Huff_decode_huff(
    input clk,
    
    input wr,
    input[`MAX_TABLE_SIZE-1:0] wr_addr,
    input[7:0] wr_code,

    input[15:0] base,
    input[15:0] offset,

    output[3:0] zero,
    output[3:0] length
);

reg[7:0] huff_code[2**`MAX_TABLE_SIZE-1:0];
reg[15:0] reg_base;
reg[15:0] reg_offset;

wire[7:0] code;
assign code = huff_code[reg_base+reg_offset];
assign zero = code[7:4];
assign length = code[3:0];

always @(posedge clk)
begin
    if (wr) begin
        huff_code[wr_addr] <= wr_code;
    end else
    begin
        reg_base <= base;
        reg_offset <= offset;
    end
end
endmodule

module Huff_fetch_cfg(
    input clk,
    input rst,
    
    input cfg,
    input[7:0] huff_tb_data,
    
    output reg[1:0] wr_tb_sel,
    
    output reg wr,
    output reg[3:0] wr_addr,
    output reg[3:0] wr_huff_size,
    output reg[15:0] wr_huff_min,
    output reg[15:0] wr_huff_base
);

reg huff_cfg_eot; //end of table
reg[1:0] huff_cfg_sel;
reg[3:0] huff_cfg_count;

reg[3:0] huff_cfg_addr;
reg[15:0] huff_cfg_min;
reg[15:0] huff_cfg_base;

always @(posedge clk or posedge rst)
begin
    if(rst) begin
        huff_cfg_sel <= 0;
        huff_cfg_count <= 0;
        huff_cfg_eot <= 0;
        
        huff_cfg_addr <= 0;
        huff_cfg_min  <= 0;
        huff_cfg_base <= 0;
        
        wr <= 0;
        wr_tb_sel <= 0;
        wr_addr <= 0;

        wr_huff_size <= 0;
        wr_huff_min  <= 0;
        wr_huff_base <= 0;
    end else
    begin
        if(cfg) begin
            wr_tb_sel <= huff_cfg_sel;
            if(huff_tb_data != 8'h00)
            begin
                wr <= 1;
                wr_addr <= huff_cfg_addr;
                    
                wr_huff_size <= huff_cfg_count;
                wr_huff_min  <= huff_cfg_min;
                wr_huff_base <= huff_cfg_base;

                huff_cfg_addr <= huff_cfg_eot ? 0 : huff_cfg_addr + 1;                    
                huff_cfg_min  <= huff_cfg_eot ? 0 : huff_cfg_min + (huff_tb_data << (~huff_cfg_count));
                huff_cfg_base <= huff_cfg_base + huff_tb_data;
            end else
            begin
                wr <= 0;
                wr_addr <= 0;
                
                wr_huff_size <= 0;
                wr_huff_min  <= 0;
                wr_huff_base <= 0;
                
                huff_cfg_addr <= huff_cfg_eot ? 0 : huff_cfg_addr;                    
                huff_cfg_min  <= huff_cfg_eot ? 0 : huff_cfg_min;
            end
            if (huff_cfg_eot) huff_cfg_sel <= huff_cfg_sel + 1;
            if (huff_cfg_count == 4'hf) huff_cfg_count <= 0;
            else if(!huff_cfg_eot) huff_cfg_count <= huff_cfg_count + 1;
            huff_cfg_eot <= huff_cfg_count == 4'hf;
        end
    end
end
endmodule

module Huff_decode_cfg(
    input clk,
    input rst,
    
    input cfg,
    input[7:0] huff_tb_data,
    
    output wr,
    output reg[`MAX_TABLE_SIZE-1:0] wr_addr,
    output[7:0] wr_code
);

assign wr = cfg;
assign wr_code = cfg ? huff_tb_data : 0;

always @(posedge clk or posedge rst)
begin
    if(rst) begin
        wr_addr <= 0;
    end else
    begin
        if(cfg) wr_addr <= wr_addr + 1;
    end
end
endmodule

module Huff_shift_fifo(
    input clk,
    input rst,
    
    input rd,
    input[4:0] move,
    
    output reg[23:0] rd_addr,
    input[31:0] rd_data,
    
    output[15:0] huff_stream,
    output[31:0] data_stream
);

reg[127:0] buffer;
reg[7:0] left;

assign huff_stream = buffer[127:112];
assign data_stream = buffer[127:96];

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        buffer <= 0;
        left <= 0;
        rd_addr <= 0;
    end else
    begin
        if(rd) 
        begin
            buffer <= buffer << move;
            left <= left - move;
        end else
        if(left < 96)
        begin
            buffer <= buffer | (rd_data << (96 - left));
            left <= left + 32;
            rd_addr <= rd_addr + 1;
        end
    end
end
endmodule

module Huff_counter(
    input clk,
    input rst,
    
    input wr,
    input[1:0] wr_mode,
    
    input[2:0] fsm,
    
    input[3:0] data_zero,
    input[3:0] data_len,
    
    output reg[6:0] huff_counter,

    output reg eob,
    
    output[1:0] data_type,
    
    output quan_tb_sel,
    output[1:0] huff_tb_sel
);

reg[1:0] map_mode;
reg[4:0] map_pos;

reg[4:0] map_start;
reg[4:0] map_end;

reg[4:0] map_rom[0:27];

reg mv;

initial begin
    $readmemb("huffman_map.txt", map_rom);
end

assign data_type = map_rom[map_pos][4:3];
assign quan_tb_sel = map_rom[map_pos][2];
assign huff_tb_sel = map_rom[map_pos][1:0];

always @(*)
begin
    case(map_mode)
    `SAMP_444:  begin map_start <= 0;  map_end <= 5;  end
    `SAMP_422:  begin map_start <= 6;  map_end <= 13; end
    `SAMP_420:  begin map_start <= 14; map_end <= 25; end
    `SAMP_GRAY: begin map_start <= 26; map_end <= 26; end
    endcase
end

always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        mv <= 0;
        eob <= 0;
        huff_counter <= 0;
        map_mode <= 0;
        map_pos <= 0;
    end else
    if (wr)
    begin
        map_mode <= wr_mode;
        case(wr_mode)
        `SAMP_444:  map_pos <= 0;
        `SAMP_422:  map_pos <= 6;
        `SAMP_420:  map_pos <= 14;
        `SAMP_GRAY: map_pos <= 26;
        endcase
    end
    else
    begin
        if (mv)
        begin
            mv <= 0;
            map_pos <= (map_pos == map_end) ? map_start : map_pos + 1;
        end
        if (fsm == 0) eob <= 0;
        if (fsm == 5)
        begin
            //FIXME: need to be optimized.
            //huff_counter may have timing issues.
            huff_counter = huff_counter + data_zero + 1;
            if (huff_counter[5:0] == 1)
            begin
                mv <= 1;
            end else
            if (huff_counter[6] == 1 || (data_len == 0 && data_zero == 0))
            begin
                mv <= 1;
                eob <= 1;
                huff_counter <= 0;
            end else mv <= 0;
        end
    end
end
endmodule

module HuffDecoder(
    input clk, //this module will fetch data at positive edge.
    input rst, //pull high to reset to default status.
    
    input cfg, //pull high to enter config mode or idle respectly.
    
    input wr,
    input wr_sel,
    //{wr, wr_sel}
    //10: huff_size_tb
    //11: huff_code_tb
    //00: idle
    //01: huff_map
    
    input[7:0] wr_huff_tb,
    input[1:0] wr_map_mode,
    
    output[23:0] rd_addr,
    input[31:0] rd_data,
    
    output reg[2:0] fsm,
    output[6:0] huff_counter,

    output[1:0] data_type,
    output quan_tb_sel,

    output eob,
    output[3:0] huff_size,
    output[3:0] data_zero,
    output[3:0] data_len,
    
    output[31:0] data_stream
);

//fifo
reg fifo_rd;
reg[4:0] fifo_move;

//wire between modules
wire[15:0] huff_stream;

wire[1:0] tb_sel;
wire[1:0] cfg_tb_sel;
wire[1:0] huff_tb_sel;

wire fh_cfg;
wire dh_cfg;

wire hc_wr;
wire fh_wr;
wire dh_wr;

wire[3:0] fh_wr_addr;
wire[3:0] fh_wr_huff_size;
wire[15:0] fh_wr_huff_min;
wire[15:0] fh_wr_huff_base;

wire[`MAX_TABLE_SIZE-1:0] dh_wr_addr;
wire[7:0] dh_wr_code;

wire[15:0] fh_dh_base;
wire[15:0] fh_dh_offset;

//modules
Huff_counter hc(
    .clk(clk),
    .rst(rst),
    
    .wr(hc_wr),
    .wr_mode(wr_map_mode),
    
    .fsm(fsm),
    
    .data_zero(data_zero),
    .data_len(data_len),
    
    .huff_counter(huff_counter),
    
    .eob(eob),
    
    .data_type(data_type),
    .quan_tb_sel(quan_tb_sel),
    .huff_tb_sel(huff_tb_sel)
);

Huff_shift_fifo hf(
    .clk(clk),
    .rst(rst),
    
    .rd(fifo_rd),
    .move(fifo_move),
    
    .rd_addr(rd_addr),
    .rd_data(rd_data),
    
    .huff_stream(huff_stream),
    .data_stream(data_stream)
);

Huff_fetch_huff fh(
    .clk(clk),
    .rst(rst),
    
    .wr(fh_wr),
    .wr_addr(fh_wr_addr),
    .wr_huff_size(fh_wr_huff_size),
    .wr_huff_min(fh_wr_huff_min),
    .wr_huff_base(fh_wr_huff_base),
    
    .tb_sel(tb_sel),
    .stream(huff_stream),

    .size(huff_size),
    .base(fh_dh_base),
    .offset(fh_dh_offset)
);

Huff_fetch_cfg fetchcfg(
    .clk(clk),
    .rst(rst),
    
    .cfg(fh_cfg),
    .huff_tb_data(wr_huff_tb),
    
    .wr_tb_sel(cfg_tb_sel),
    
    .wr(fh_wr),
    .wr_addr(fh_wr_addr),
    .wr_huff_size(fh_wr_huff_size),
    .wr_huff_min(fh_wr_huff_min),
    .wr_huff_base(fh_wr_huff_base)
);

Huff_decode_huff dh(
    .clk(clk),
    
    .wr(dh_wr),
    .wr_addr(dh_wr_addr),
    .wr_code(dh_wr_code),

    .base(fh_dh_base),
    .offset(fh_dh_offset),

    .zero(data_zero),
    .length(data_len)
);

Huff_decode_cfg decodecfg(
    .clk(clk),
    .rst(rst),
    
    .cfg(dh_cfg),
    .huff_tb_data(wr_huff_tb),
    
    .wr(dh_wr),
    .wr_addr(dh_wr_addr),
    .wr_code(dh_wr_code)
);

assign hc_wr = wr ? 0 : wr_sel;

assign fh_cfg = wr ? ~wr_sel : 0;
assign dh_cfg = wr ?  wr_sel : 0;

assign tb_sel = cfg ? cfg_tb_sel : huff_tb_sel;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        fsm <= 0;
        fifo_rd <= 0;
        fifo_move <= 0;
    end else
    if(~cfg)
    begin
        if (fsm == 5) fsm <= 0;
        else fsm <= fsm + 1;
            
        if (fsm == 0) fifo_rd <= 0;
        if (fsm == 5)
        begin
            fifo_rd <= 1;
            fifo_move <= huff_size + data_len + 1;
        end
    end
end
endmodule
