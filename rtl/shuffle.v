module Shuf_rom( //zigzag
    input clk,
    
    input[5:0] addr,
    output reg[6:0] data
);

reg[6:0] rom[0:63];
//6:3 column
//2:0 row

initial
begin
    $readmemb("zigzag.txt", rom);
end

always @(posedge clk)
begin
    data <= rom[addr];
end
endmodule

module Shuf_ram( //quantize
    input clk,
    
    input wr,
    input[6:0] wr_addr,
    input reg[7:0] wr_data,
    
    input tb_sel,
    input[5:0] addr,
    output reg[7:0] data
);

reg[7:0] ram[1:0][63:0];

always @(posedge clk)
begin
    if(wr)
    begin
        ram[wr_addr[6]][wr_addr[5:0]] <= wr_data;
    end else
    begin
        data <= ram[tb_sel][addr];
    end
end
endmodule

module Shuf_buffer(
    input clk,
    input rst,

    input notify,
    
    input wr,
    input[6:0] wr_addr,
    input[15:0] wr_data,
    
    input[3:0] rd_addr,
    output reg[127:0] rd_data
);

reg[2:0] buffer_fsm;

reg[1:0] buffer_id_rd;
reg[1:0] buffer_id_wr;

reg[15:0] buffer[2:0][119:0];

integer i, j, k;

always @(*)
begin
    for(i=0;i<3;i=i+1) if(buffer_fsm[i])
    begin
        for(j=0;j<120;j=j+1) buffer[i][j] <= 0;
    end
    case(buffer_fsm)
    3'b001: begin buffer_id_rd <= 1; buffer_id_wr <= 2; end
    3'b010: begin buffer_id_rd <= 2; buffer_id_wr <= 0; end
    3'b100: begin buffer_id_rd <= 0; buffer_id_wr <= 1; end
    endcase
end

always @(posedge clk or posedge rst)
begin
    if(rst) begin
        buffer_fsm <= 1;
        for(j=0;j<120;j=j+1) buffer[2][j] <= 0;
    end
    else
    begin
        if(notify) buffer_fsm <= {buffer_fsm[1:0], buffer_fsm[2]};
        if(wr) buffer[buffer_id_wr][wr_addr] <= wr_data;
        rd_data[15:0]    <= buffer[buffer_id_rd][{rd_addr, 3'h0}];
        rd_data[31:16]   <= buffer[buffer_id_rd][{rd_addr, 3'h1}];
        rd_data[47:32]   <= buffer[buffer_id_rd][{rd_addr, 3'h2}];
        rd_data[63:48]   <= buffer[buffer_id_rd][{rd_addr, 3'h3}];
        rd_data[79:64]   <= buffer[buffer_id_rd][{rd_addr, 3'h4}];
        rd_data[95:80]   <= buffer[buffer_id_rd][{rd_addr, 3'h5}];
        rd_data[111:96]  <= buffer[buffer_id_rd][{rd_addr, 3'h6}];
        rd_data[127:112] <= buffer[buffer_id_rd][{rd_addr, 3'h7}];
    end
end
endmodule

module Shuf_Aprase( //huge asynchronized data praser logic.
    input[3:0] huff_size,
    input[3:0] data_len,
    input[31:0] data_stream,
    
    output reg[15:0] base
);

reg zero;
reg sign;

reg[4:0] shift;
reg[31:0] mask;
reg[15:0] extend;

reg[15:0] buf_data;

always @(*)
begin
    zero = data_len == 0;
    sign = zero ? 0 : ~data_stream[30 - huff_size];

    shift = ~huff_size - data_len;
    mask = 32'h0000ffff << data_len;
    extend = {16{sign}} << data_len;

    buf_data = data_stream >> shift;
    base = ((buf_data & mask[31:16]) | extend) + sign;
end
endmodule

module Shuf_pipe(
    input clk,
    input rst,

    input wr,
    input[6:0] wr_addr,
    input[7:0] wr_data,
    
    input[2:0] fsm_in,
    input[6:0] huff_counter,
    
    input[31:0] data_stream,

    input[1:0] data_type,
    input quan_tb_sel,
    
    input eob,
    input[3:0] huff_size,
    input[3:0] data_zero,
    input[3:0] data_len,

    output reg buf_notify, //notify buffer to flip pages.
    
    output reg buf_wr,
    output reg[6:0] buf_addr,
    output reg[15:0] buf_data
);

reg ap_eob;
reg[3:0] ap_huff_size;
reg[3:0] ap_data_len;
reg[31:0] ap_data_stream;

reg[5:0] ap_addr;
reg ram_sel;
reg[5:0] ram_addr;
wire[7:0] ram_data;

reg[5:0] rom_addr;
wire[6:0] rom_data;

wire[15:0] base;

Shuf_ram qt( //quantize
    .clk(clk),
    
    .wr(wr),
    .wr_addr(wr_addr),
    .wr_data(wr_data),
    
    .tb_sel(ram_sel),
    .addr(ram_addr),
    .data(ram_data)
);

Shuf_rom zz( //zigzag
    .clk(clk),
    
    .addr(rom_addr),
    .data(rom_data)
);

Shuf_Aprase ap(
    .huff_size(ap_huff_size),
    .data_len(ap_data_len),
    .data_stream(ap_data_stream),
    
    .base(base)
);

reg[3:0] fsm; //buffered fsm
reg[15:0] dc[3:0];
//dc[0] = 0
//dc[1,2,3] = old_cofficient_{y,u,v}

reg[1:0] ap_data_type;
reg[15:0] offset;

always @(posedge clk or posedge rst)
begin
    if (rst)
    begin
        fsm <= 4'hf;
        
        dc[0] = 0;
        dc[1] = 0;
        dc[2] = 0;
        dc[3] = 0;

        ap_eob <= 0;
        ap_data_type <= 0;
        
        ap_huff_size <= 0;
        ap_data_len <= 0;
        ap_data_stream <= 0;

        ram_sel <= 0;
        ram_addr <= 0;
        rom_addr <= 0;
        
        offset <= 0;
        
        buf_wr <= 0;
        buf_addr <= 0;
        buf_data <= 0;
        buf_notify <= 0;
        
        ap_addr <= 0;
    end else
    begin
        if(fsm_in == 5) //valid
        begin
            fsm <= 0;

            ap_huff_size <= huff_size;
            ap_data_len <= data_len;
            ap_data_stream <= data_stream;
            
            ram_sel <= quan_tb_sel;
            ap_addr <= huff_counter + data_zero;
            ap_data_type <= data_type;
        end
        else fsm <= fsm[3] ? fsm : fsm + 1;
        
        if(fsm == 0)
        begin
            ram_addr <= ap_addr;
            rom_addr <= ap_addr;
            ap_eob <= eob;
            offset <= ap_data_type == 0 ? 0 : dc[ap_data_type];
        end
        if(fsm == 4)
        begin
            buf_wr <= #4 1;
            buf_addr <= #4 rom_data;
            buf_data <= #4 (base + offset) * ram_data;
            buf_notify <= #4 ap_eob;
            
            dc[ap_data_type] <= base + offset;
        end
        if(fsm == 5)
        begin
            buf_wr <= #4 0;
            buf_addr <= #4 0;
            buf_data <= #4 0;
            buf_notify <= #4 0;
        end
    end
end
endmodule

module Shuffle(
    input clk, //this module will fetch data at positive edge.
    input rst, //pull high to reset to default status.

    input wr,
    input[7:0] wr_quan_tb,

    input[2:0] fsm,

    input[1:0] data_type,
    input quan_tb_gate,
    input quan_tb_sel,
    input[6:0] huff_counter,

    input eob,
    input[3:0] huff_size,
    input[3:0] data_zero,
    input[3:0] data_len,

    input[31:0] data_stream,
    
    output notify,
    input[3:0] rd_addr,
    output[127:0] rd_data
);

wire tb_sel;
assign tb_sel = quan_tb_gate ? 0 : quan_tb_sel;

reg[6:0] wr_addr;

wire sf_sb_wr;
wire[6:0] sf_sb_wr_addr;
wire[15:0] sf_sb_wr_data;

Shuf_buffer sb(
    .clk(clk),
    .rst(rst),
    
    .notify(notify),
    
    .wr(sf_sb_wr),
    .wr_addr(sf_sb_wr_addr),
    .wr_data(sf_sb_wr_data),
    
    .rd_addr(rd_addr),
    .rd_data(rd_data)
);

Shuf_pipe sf(
    .clk(clk),
    .rst(rst),

    .wr(wr),
    .wr_addr(wr_addr),
    .wr_data(wr_quan_tb),
    
    .fsm_in(fsm),
    .huff_counter(huff_counter),
    
    .data_stream(data_stream),

    .data_type(data_type),
    .quan_tb_sel(tb_sel),

    .eob(eob),  
    .huff_size(huff_size),
    .data_zero(data_zero),
    .data_len(data_len),

    .buf_notify(notify),
    
    .buf_wr(sf_sb_wr),
    .buf_addr(sf_sb_wr_addr),
    .buf_data(sf_sb_wr_data)
);

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        wr_addr <= 7'h7f;
    end else
    begin
        if (wr) wr_addr <= wr_addr + 1;
    end
end
endmodule
